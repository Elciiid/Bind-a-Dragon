--!strict
-- Roosts: AFK gold income and the dragons shown on each player's roost plot.
--
-- Income: every PayoutInterval, each player earns the gold/sec of the dragons in data.RoostDragonIds.
-- Offline: on join, pays for the time since data.LastOnline (stamped on every save) at OfflineIncomeMultiplier.
-- Idle: a player who hasn't moved for IdleAfterSeconds earns like offline. Offline + idle share one daily
-- allowance of OfflineCapHours (data.AfkCreditDay / AfkCreditSeconds).
-- Weekly rebirth cap: at the cap, banked gold stops at one rebirth's cost, with a message.
-- Slots: empty roost slots are filled automatically with the player's best-earning unplaced dragons.
--
-- World: Models tagged "RoostPlot" are handed out one per player. Each plot is a fenced pen with attributes
-- "RoamCenter" (Vector3, the floor's top center) and "RoamRadius" (studs dragons may roam from it), a "Sign" part
-- for the owner's name, and upgrade stands "UpgradeSlots" / "UpgradeIncome" (prompts added by the owner's client).
-- Dragons spawn at random spots in the pen; clients animate them (RoostAnimationController).
-- Players without a free plot still earn income, they just have no visuals.
--
-- Dragon art: ReplicatedStorage/Assets/Dragons/<SpeciesId>/<StageId> (Model), else .../<SpeciesId> (Model),
-- else .../Placeholder, which is tinted by element (parts with a "Tint" attribute: Primary/Secondary/Accent).
-- Evolution branch color: placeholder Accent parts, and any part in real art with attribute BranchAccent = true,
-- take the element color of the dragon's latest night branch.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Elements = require(ReplicatedStorage.Shared.Config.Elements)
local RoostConfig = require(ReplicatedStorage.Shared.Config.Roost)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

type PlayerData = PlayerDataTypes.PlayerData
type Shown = { Model: Model, Key: string }

local PLOT_TAG = "RoostPlot"

local rng = Random.new()

local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent
local placeInRoost = ReplicatedStorage.Remotes.PlaceInRoost :: RemoteEvent

local plotOwners: { [Model]: Player } = {}
local plotOf: { [Player]: Model } = {}
local shown: { [Player]: { [string]: Shown } } = {} -- dragonId -> model on the player's plot
local unpaid: { [Player]: number } = {} -- fractional gold carried between payouts
local lastPlace: { [Player]: number } = {}
local lastActive: { [Player]: number } = {} -- os.clock() of the player's last movement
local lastPosition: { [Player]: Vector3 } = {}
local capNotified: { [Player]: boolean } = {} -- "rebirth cap reached" shown this session
local PLACE_INTERVAL = 0.25 -- seconds between PlaceInRoost requests per player (anti-spam)

local RoostService = {}

-- TODO(MonetizationService): 2x AFK Income game pass multiplies here.
local function getIncomeMultiplier(_player: Player): number
	return 1
end

-- Drops roost entries for dragons that no longer exist, then fills empty slots with the best unplaced dragons.
local function fillSlots(data: PlayerData)
	local placed: { [string]: boolean } = {}
	for i = #data.RoostDragonIds, 1, -1 do
		local id = data.RoostDragonIds[i]
		if data.Dragons[id] == nil or placed[id] then
			table.remove(data.RoostDragonIds, i)
		else
			placed[id] = true
		end
	end

	local slots = DragonStats.GetRoostSlots(data)
	while #data.RoostDragonIds > slots do
		table.remove(data.RoostDragonIds)
	end
	if #data.RoostDragonIds >= slots then
		return
	end

	local candidates = {}
	for id, dragon in data.Dragons do
		if not placed[id] then
			table.insert(candidates, { Id = id, Income = DragonStats.GetGoldPerSecond(dragon) })
		end
	end
	table.sort(candidates, function(a, b)
		return a.Income > b.Income
	end)
	for _, candidate in candidates do
		if #data.RoostDragonIds >= slots then
			break
		end
		table.insert(data.RoostDragonIds, candidate.Id)
	end
end

-- PlaceInRoost(dragonId): put an owned dragon in the roost. If the roost is full, it takes the slot of the
-- lowest-earning roost dragon (so a slot is never left empty and auto-fill never fights the player).
local function onPlaceInRoost(player: Player, dragonId: unknown)
	if typeof(dragonId) ~= "string" or #dragonId > 20 then
		return
	end
	local now = os.clock()
	if now - (lastPlace[player] or 0) < PLACE_INTERVAL then
		return
	end
	lastPlace[player] = now

	local data = DataService:GetData(player)
	local dragon = data and data.Dragons[dragonId]
	if data == nil or dragon == nil or table.find(data.RoostDragonIds, dragonId) then
		return
	end

	local slots = DragonStats.GetRoostSlots(data)
	if #data.RoostDragonIds < slots then
		table.insert(data.RoostDragonIds, dragonId)
	else
		local weakestIndex, weakestIncome = nil, math.huge
		for index, id in data.RoostDragonIds do
			local placed = data.Dragons[id]
			local income = if placed then DragonStats.GetGoldPerSecond(placed) else -1
			if income < weakestIncome then
				weakestIndex, weakestIncome = index, income
			end
		end
		if weakestIndex == nil then
			return
		end
		data.RoostDragonIds[weakestIndex] = dragonId
	end
	local species = Dragons[dragon.SpeciesId]
	notify:FireClient(player, `{if species then species.Name else "Dragon"} is now in your roost.`, "success")
end

-- Offline and idle time share one daily allowance (Config/Roost OfflineCapHours), reset each UTC day.
local function afkSecondsLeft(data: PlayerData): number
	local today = os.time() // 86400
	if data.AfkCreditDay ~= today then
		data.AfkCreditDay = today
		data.AfkCreditSeconds = 0
	end
	return math.max(0, RoostConfig.OfflineCapHours * 3600 - data.AfkCreditSeconds)
end

-- At the weekly rebirth cap, banked gold stops at one rebirth's cost (so a new update can't be cleared from savings).
local function clampAtRebirthCap(player: Player, data: PlayerData)
	if not DragonStats.IsAtRebirthCap(data) then
		return
	end
	local limit = DragonStats.GetRebirthCost(data.Rebirths)
	if data.Gold >= limit then
		data.Gold = limit
		if not capNotified[player] then
			capNotified[player] = true
			notify:FireClient(player, "Rebirth cap reached. More rebirths in the next update!", "info")
		end
	end
end

local function payOffline(player: Player, data: PlayerData)
	if data.LastOnline <= 0 then
		return -- first session
	end
	local seconds = math.clamp(os.time() - data.LastOnline, 0, afkSecondsLeft(data))
	data.AfkCreditSeconds += seconds
	fillSlots(data)
	local earned = math.floor(
		DragonStats.GetRoostIncome(data) * seconds * RoostConfig.OfflineIncomeMultiplier * getIncomeMultiplier(player)
	)
	if earned > 0 then
		data.Gold += earned
		clampAtRebirthCap(player, data)
		notify:FireClient(player, `While you were away, your dragons earned {Format.Number(earned)} gold!`, "success")
	end
end

-- Idle detection: a player whose character hasn't moved for IdleAfterSeconds counts as idle.
local function updateActivity(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local now = os.clock()
	if root == nil or not root:IsA("BasePart") then
		lastActive[player] = lastActive[player] or now
		return
	end
	local previous = lastPosition[player]
	if previous == nil or (root.Position - previous).Magnitude > 1 then
		lastActive[player] = now
		lastPosition[player] = root.Position
	end
end

local function isIdle(player: Player): boolean
	return os.clock() - (lastActive[player] or os.clock()) > RoostConfig.IdleAfterSeconds
end

---------------------------------------------------------------------------------------------------------------
-- Plot visuals

-- The pen's floor center (top surface) and how far from it dragons may roam.
local function getPen(plot: Model): (Vector3?, number)
	local center = plot:GetAttribute("RoamCenter")
	local radius = plot:GetAttribute("RoamRadius")
	return if typeof(center) == "Vector3" then center else nil, if type(radius) == "number" then radius else 12
end

local function setSign(plot: Model, owner: Player?)
	local sign = plot:FindFirstChild("Sign")
	if sign == nil or not sign:IsA("BasePart") then
		return
	end
	local gui = sign:FindFirstChild("OwnerGui") :: BillboardGui?
	if gui == nil then
		local newGui = Instance.new("BillboardGui")
		newGui.Name = "OwnerGui"
		newGui.Size = UDim2.new(0, 260, 0, 50)
		newGui.StudsOffset = Vector3.new(0, 4, 0)
		newGui.MaxDistance = 400
		newGui.AlwaysOnTop = true
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextStrokeTransparency = 0.4
		label.Parent = newGui
		newGui.Parent = sign
		gui = newGui
	end
	local label = (gui :: BillboardGui):FindFirstChild("Label") :: TextLabel
	label.Text = if owner then `{owner.DisplayName}'s Roost` else "Empty Roost"
	label.TextColor3 = if owner then Color3.fromRGB(255, 220, 120) else Color3.fromRGB(180, 180, 180)
end

local function findTemplate(speciesId: string, stageId: string): (Model?, boolean)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Dragons")
	if folder == nil then
		return nil, false
	end
	local speciesArt = folder:FindFirstChild(speciesId)
	if speciesArt then
		local stageArt = speciesArt:FindFirstChild(stageId)
		if stageArt and stageArt:IsA("Model") then
			return stageArt, false
		end
		if speciesArt:IsA("Model") then
			return speciesArt, false
		end
	end
	local placeholder = folder:FindFirstChild("Placeholder")
	return if placeholder and placeholder:IsA("Model") then placeholder else nil, true
end

local function makeNameplate(model: Model, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Size = UDim2.new(0, 160, 0, 36)
	gui.StudsOffsetWorldSpace = Vector3.new(0, model:GetExtentsSize().Y / 2 + 1.5, 0)
	gui.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	gui.Parent = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function buildDragonModel(dragon: PlayerDataTypes.Dragon, plot: Model): Model?
	local species = Dragons[dragon.SpeciesId]
	if species == nil then
		return nil
	end
	local stage = DragonStats.GetStage(dragon.Level)
	local template, isPlaceholder = findTemplate(dragon.SpeciesId, stage.Id)
	if template == nil then
		return nil
	end

	local model = template:Clone()
	model.Name = `Dragon_{dragon.Id}`
	-- Stream the whole model at once, so clients never animate a dragon that's missing parts.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	-- Evolution branch accent: the element color of the latest night constellation it evolved under.
	local branchElementId = DragonStats.GetBranchElement(dragon)
	local branchElement = branchElementId and Elements[branchElementId]
	if branchElement then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part:GetAttribute("BranchAccent") == true then
				part.Color = branchElement.Color
			end
		end
	end

	if isPlaceholder then
		local element = Elements[species.Element]
		local primary = if element then element.Color else Color3.new(1, 1, 1)
		local tints = {
			Primary = primary,
			Secondary = primary:Lerp(Color3.new(0, 0, 0), 0.45),
			Accent = if branchElement then branchElement.Color else primary:Lerp(Color3.new(1, 1, 1), 0.6),
		}
		for _, part in model:GetDescendants() do
			local tint = part:GetAttribute("Tint")
			if part:IsA("BasePart") and type(tint) == "string" and tints[tint] then
				part.Color = tints[tint]
			end
		end
		model:ScaleTo(model:GetScale() * stage.ModelScale) -- relative to the template's own scale
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end

	-- Stand on the pen floor at a random spot, facing a random way. Clients take over from here and animate it
	-- (RoostAnimationController) using the movement attributes below; the server never moves it again.
	local center, radius = getPen(plot)
	if center then
		local angle, distance = rng:NextNumber(0, 2 * math.pi), rng:NextNumber(0, radius * 0.7)
		local spot = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local size = model:GetExtentsSize()
		local boxCFrame = model:GetBoundingBox()
		local pivotOffset = boxCFrame:ToObjectSpace(model:GetPivot())
		model:PivotTo(CFrame.new(spot) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0) * CFrame.new(0, size.Y / 2, 0) * pivotOffset)
	end
	model:SetAttribute("Movement", stage.Movement)
	model:SetAttribute("MoveSpeed", stage.MoveSpeed)
	model:SetAttribute("FlyHeight", stage.FlyHeight)

	local rarity = DragonStats.GetRarity(species.Rarity)
	local grade = DragonStats.GetGrade(dragon)
	local gradeText = if grade then `  [{grade.Id}]` else ""
	makeNameplate(model, `{species.Name}  Lv {dragon.Level}{gradeText}`, if rarity then rarity.Color else Color3.new(1, 1, 1))
	return model
end

-- Makes the models on the player's plot match data.RoostDragonIds.
local function refreshPlot(player: Player, data: PlayerData)
	local plot = plotOf[player]
	local current = shown[player]
	if plot == nil or current == nil then
		return
	end

	local wanted: { [string]: boolean } = {}
	for _, dragonId in data.RoostDragonIds do
		local dragon = data.Dragons[dragonId]
		if dragon == nil then
			continue
		end
		wanted[dragon.Id] = true
		-- Rebuild when anything visible changes (level/stage, branch color, trait/grade on the nameplate).
		local key = `{dragon.SpeciesId}:{dragon.Level}:{dragon.Trait or ""}:{dragon.Grade or ""}`
		local existing = current[dragon.Id]
		if existing == nil or existing.Key ~= key then
			if existing then
				existing.Model:Destroy()
			end
			local model = buildDragonModel(dragon, plot)
			if model then
				model.Parent = plot
				current[dragon.Id] = { Model = model, Key = key }
			else
				current[dragon.Id] = nil
			end
		end
	end

	for dragonId, entry in current do
		if not wanted[dragonId] then
			entry.Model:Destroy()
			current[dragonId] = nil
		end
	end
end

local function clearPlot(plot: Model)
	setSign(plot, nil)
end

local function assignPlot(player: Player)
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		if plot:IsA("Model") and plotOwners[plot] == nil then
			plotOwners[plot] = player
			plotOf[player] = plot
			shown[player] = {}
			plot:SetAttribute("OwnerUserId", player.UserId)
			setSign(plot, player)
			return
		end
	end
	warn(`[RoostService] No free roost plot for {player.Name}; add more plots or lower max players`)
end

local function releasePlot(player: Player)
	for _, entry in shown[player] or {} do
		entry.Model:Destroy()
	end
	shown[player] = nil
	local plot = plotOf[player]
	if plot then
		plotOwners[plot] = nil
		plotOf[player] = nil
		plot:SetAttribute("OwnerUserId", nil)
		clearPlot(plot)
	end
end

---------------------------------------------------------------------------------------------------------------

function RoostService:GetPlot(player: Player): Model?
	return plotOf[player]
end

function RoostService:Start()
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		if plot:IsA("Model") then
			clearPlot(plot)
		end
	end

	placeInRoost.OnServerEvent:Connect(onPlaceInRoost)

	DataService:OnDataLoaded(function(player, data)
		payOffline(player, data)
		assignPlot(player)
		fillSlots(data)
		refreshPlot(player, data)
	end)

	Players.PlayerRemoving:Connect(function(player)
		releasePlot(player)
		unpaid[player] = nil
		lastPlace[player] = nil
		lastActive[player] = nil
		lastPosition[player] = nil
		capNotified[player] = nil
	end)

	while true do
		task.wait(RoostConfig.PayoutInterval)
		for _, player in Players:GetPlayers() do
			local data = DataService:GetData(player)
			if data == nil then
				continue
			end
			fillSlots(data)
			updateActivity(player)
			-- Idle players earn like offline, from the same daily allowance.
			local seconds, rate = RoostConfig.PayoutInterval, 1
			if isIdle(player) then
				seconds = math.min(seconds, afkSecondsLeft(data))
				data.AfkCreditSeconds += seconds
				rate = RoostConfig.OfflineIncomeMultiplier
			end
			local earned = (unpaid[player] or 0)
				+ DragonStats.GetRoostIncome(data) * seconds * rate * getIncomeMultiplier(player)
			local whole = math.floor(earned)
			data.Gold += whole
			unpaid[player] = earned - whole
			clampAtRebirthCap(player, data)
			refreshPlot(player, data)
		end
	end
end

return RoostService
