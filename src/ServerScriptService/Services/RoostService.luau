--!strict
-- Roosts: AFK gold income and the dragons shown on each player's roost plot.
--
-- Income: every PayoutInterval, each player earns the gold/sec of the dragons in data.RoostDragonIds.
-- Offline: on join, pays for the time since data.LastOnline (stamped on every save), capped at OfflineCapHours.
-- Slots: empty roost slots are filled automatically with the player's best-earning unplaced dragons.
--
-- World: Models tagged "RoostPlot" are handed out one per player. Each plot needs a "Perches" folder of Models
-- (each with a number attribute "Index" and its pivot at the spot where a dragon sits), and may have a "Sign"
-- part for the owner's name. Players without a free plot still earn income, they just have no visuals.
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
local EMPTY_RING_COLOR = Color3.fromRGB(80, 85, 105)

local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent

local plotOwners: { [Model]: Player } = {}
local plotOf: { [Player]: Model } = {}
local shown: { [Player]: { [string]: Shown } } = {} -- dragonId -> model on the player's plot
local unpaid: { [Player]: number } = {} -- fractional gold carried between payouts

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

local function payOffline(player: Player, data: PlayerData)
	if data.LastOnline <= 0 then
		return -- first session
	end
	local seconds = math.clamp(os.time() - data.LastOnline, 0, RoostConfig.OfflineCapHours * 3600)
	fillSlots(data)
	local earned = math.floor(
		DragonStats.GetRoostIncome(data) * seconds * RoostConfig.OfflineIncomeMultiplier * getIncomeMultiplier(player)
	)
	if earned > 0 then
		data.Gold += earned
		notify:FireClient(player, `While you were away, your dragons earned {Format.Number(earned)} gold!`, "success")
	end
end

---------------------------------------------------------------------------------------------------------------
-- Plot visuals

local function getPerch(plot: Model, index: number): Model?
	local perches = plot:FindFirstChild("Perches")
	if perches == nil then
		return nil
	end
	for _, perch in perches:GetChildren() do
		if perch:IsA("Model") and perch:GetAttribute("Index") == index then
			return perch
		end
	end
	return nil
end

local function setRing(perch: Model, color: Color3)
	local ring = perch:FindFirstChild("Ring")
	if ring and ring:IsA("BasePart") then
		ring.Color = color
	end
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

local function buildDragonModel(dragon: PlayerDataTypes.Dragon, perch: Model): Model?
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

	-- Stand on the perch, facing its LookVector.
	local size = model:GetExtentsSize()
	local boxCFrame = model:GetBoundingBox()
	local pivotOffset = boxCFrame:ToObjectSpace(model:GetPivot())
	model:PivotTo(perch:GetPivot() * CFrame.new(0, size.Y / 2, 0) * pivotOffset)

	local rarity = DragonStats.GetRarity(species.Rarity)
	makeNameplate(model, `{species.Name}  Lv {dragon.Level}`, if rarity then rarity.Color else Color3.new(1, 1, 1))
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
	for index = 1, RoostConfig.MaxSlots do
		local perch = getPerch(plot, index)
		local dragonId = data.RoostDragonIds[index]
		local dragon = dragonId and data.Dragons[dragonId]
		if perch == nil then
			continue
		end
		if dragon == nil then
			setRing(perch, EMPTY_RING_COLOR)
			continue
		end

		wanted[dragon.Id] = true
		local key = `{index}:{dragon.SpeciesId}:{dragon.Level}`
		local existing = current[dragon.Id]
		if existing == nil or existing.Key ~= key then
			if existing then
				existing.Model:Destroy()
			end
			local model = buildDragonModel(dragon, perch)
			if model then
				model.Parent = plot
				current[dragon.Id] = { Model = model, Key = key }
			else
				current[dragon.Id] = nil
			end
			local species = Dragons[dragon.SpeciesId]
			local rarity = species and DragonStats.GetRarity(species.Rarity)
			setRing(perch, if rarity then rarity.Color else EMPTY_RING_COLOR)
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
	for index = 1, RoostConfig.MaxSlots do
		local perch = getPerch(plot, index)
		if perch then
			setRing(perch, EMPTY_RING_COLOR)
		end
	end
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

	DataService:OnDataLoaded(function(player, data)
		payOffline(player, data)
		assignPlot(player)
		fillSlots(data)
		refreshPlot(player, data)
	end)

	Players.PlayerRemoving:Connect(function(player)
		releasePlot(player)
		unpaid[player] = nil
	end)

	while true do
		task.wait(RoostConfig.PayoutInterval)
		for _, player in Players:GetPlayers() do
			local data = DataService:GetData(player)
			if data == nil then
				continue
			end
			fillSlots(data)
			local earned = (unpaid[player] or 0)
				+ DragonStats.GetRoostIncome(data) * RoostConfig.PayoutInterval * getIncomeMultiplier(player)
			local whole = math.floor(earned)
			data.Gold += whole
			unpaid[player] = earned - whole
			refreshPlot(player, data)
		end
	end
end

return RoostService
