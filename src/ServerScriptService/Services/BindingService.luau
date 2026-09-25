--!strict
-- Binding at Star Altars. Any instance tagged "StarAltar" (a BasePart, or a Model with a PrimaryPart) gets two
-- prompts, open only at night: Bind (E) and Offer Stardust (F). The altar's "AreaId" attribute picks its entry
-- in Config/Areas.
--
-- ProximityPrompt.Triggered fires on the server with the real player, so the client never sends any values.
-- Every player gets their own roll; one bind per player per night (tracked by NightIndex, so it holds across servers).
-- Luck comes from Shared/Luck, the same math the client uses to display it. An armed luck charge
-- (Config/Boosts) is included and used up by the bind. Each bind may be Starborn (Config/Index StarbornChance)
-- and is recorded in the Dragon Index (IndexService). The Auto-bind pass binds for its owner at base luck near the
-- end of any night they haven't bound (Config/Products AutoBindSecondsLeft), at the altar of the area they're in.
-- Rosters: each area binds only its Config/Areas Species; element areas are their element's home (all rarities),
-- Starter Meadow lets tonight's constellation pick the element.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoostService = require(script.Parent.BoostService)
local DataService = require(script.Parent.DataService)
local IndexService = require(script.Parent.IndexService)
local MonetizationService = require(script.Parent.MonetizationService)
local QuestService = require(script.Parent.QuestService)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local Luck = require(ReplicatedStorage.Shared.Luck)
local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local BindingConfig = require(ReplicatedStorage.Shared.Config.Binding)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local IndexConfig = require(ReplicatedStorage.Shared.Config.Index)
local LuckConfig = require(ReplicatedStorage.Shared.Config.Luck)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

local bindResult = ReplicatedStorage.Remotes.BindResult :: RemoteEvent
local announcement = ReplicatedStorage.Remotes.Announcement :: RemoteEvent
local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent

local ALTAR_TAG = "StarAltar"
local DEFAULT_AREA = "StarterMeadow"

local rng = Random.new()
local prompts: { ProximityPrompt } = {}
local busy: { [Player]: boolean } = {}

local BindingService = {}

-- The element tonight's roll uses at this area: the area's home element, else tonight's constellation's (nil = any).
local function getRollElement(areaId: string, constellation: { Element: string? }): string?
	local area = Areas[areaId]
	return if area and area.Element then area.Element else constellation.Element
end

-- Weighted rarity roll over the rarities this area's roster has (Shared/Luck, same math as the luck panel).
local function rollRarity(areaId: string, element: string?, luck: number): Rarities.Rarity?
	local weights = Luck.GetAreaRarityWeights(areaId, element, luck)
	local total = 0
	for _, weight in weights do
		total += weight
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	for index, rarity in Rarities do
		roll -= weights[index]
		if roll < 0 then
			return rarity
		end
	end
	return nil
end

-- Picks a species of the given rarity from the area's roster (matching the element, if given).
local function pickSpecies(areaId: string, rarityId: string, element: string?): string?
	local area = Areas[areaId]
	local pool = {}
	for _, speciesId in if area then area.Species else {} do
		local species = Dragons[speciesId]
		if species and species.Rarity == rarityId and (element == nil or species.Element == element) then
			table.insert(pool, speciesId)
		end
	end
	if #pool == 0 then
		return nil
	end
	table.sort(pool) -- stable order so the roll isn't affected by table iteration order
	return pool[rng:NextInteger(1, #pool)]
end

local function getAreaId(altar: Instance): string
	local areaId = altar:GetAttribute("AreaId")
	return if type(areaId) == "string" then areaId else DEFAULT_AREA
end

-- Shared checks for binding and offering. Returns the player's data and the cycle state,
-- or nil after telling the player why not.
local function checkAltarUse(player: Player, altar: Instance): (PlayerDataTypes.PlayerData?, Cycle.State?)
	local data = DataService:GetData(player)
	if data == nil then
		notify:FireClient(player, "Your data is still loading.", "error")
		return nil, nil
	end

	local state = Cycle.GetState()
	if not state.IsNight then
		notify:FireClient(player, "The stars only answer at night.", "error")
		return nil, nil
	end
	if data.LastBindNight == state.NightIndex then
		notify:FireClient(player, "You've already bound tonight. Come back next night!", "error")
		return nil, nil
	end

	local areaId = getAreaId(altar)
	local area = Areas[areaId]
	if area == nil then
		warn(`[BindingService] Altar {altar:GetFullName()} has unknown AreaId {areaId}`)
		notify:FireClient(player, "This altar is broken.", "error")
		return nil, nil
	end
	if data.Rebirths < area.RebirthsRequired then
		notify:FireClient(player, `You need {area.RebirthsRequired} rebirths to use the altar in {area.Name}.`, "error")
		return nil, nil
	end

	return data, state
end

-- Rolls and grants tonight's dragon. usePotion: an armed luck charge is used up (not for Auto-bind).
local function performBind(
	player: Player,
	data: PlayerDataTypes.PlayerData,
	state: Cycle.State,
	areaId: string,
	luck: number,
	usePotion: boolean
)
	local element = getRollElement(areaId, state.Constellation)
	local rarity = rollRarity(areaId, element, luck)
	local speciesId = rarity and pickSpecies(areaId, rarity.Id, element)
	if rarity == nil or speciesId == nil then
		warn(`[BindingService] Area {areaId} has no species to bind (element {element})`)
		notify:FireClient(player, "The stars were silent. Try again.", "error")
		return
	end

	local starborn = rng:NextNumber() < IndexConfig.StarbornChance
	local dragonId = tostring(data.NextDragonId)
	data.NextDragonId += 1
	data.Dragons[dragonId] = {
		Id = dragonId,
		SpeciesId = speciesId,
		Level = 1,
		ObtainedAt = os.time(),
		Starborn = if starborn then true else nil,
	}
	data.LastBindNight = state.NightIndex
	if usePotion then
		BoostService:ConsumeLuckCharge(data) -- the armed luck charge (if any) was used by this bind
	end
	local constellationId = state.Constellation.Id
	data.StarAtlas[constellationId] = (data.StarAtlas[constellationId] or 0) + 1

	bindResult:FireClient(player, {
		DragonId = dragonId,
		SpeciesId = speciesId,
		ConstellationId = constellationId,
		Luck = luck,
		Starborn = starborn,
		Auto = not usePotion,
	})
	IndexService:Sync(player, data)
	QuestService:Progress(player, "Bind", 1)
	if Luck.IsFavored(areaId, state.Constellation) then
		QuestService:Progress(player, "FavoredBind", 1)
	end

	if rarity.AnnounceOnBind or starborn then
		local variant = if starborn then "STARBORN " else ""
		announcement:FireAllClients(`{player.DisplayName} bound a {variant}{rarity.Name} {Dragons[speciesId].Name}!`)
	end
end

local function tryBind(player: Player, altar: Instance, part: BasePart)
	local data, state = checkAltarUse(player, altar)
	if data == nil or state == nil then
		return
	end

	local luck = Luck.Compute(
		getAreaId(altar),
		state.NightIndex,
		Luck.GetOfferingCount(data, state.NightIndex),
		Luck.CountPlayersNear(part.Position, LuckConfig.GroupRadius),
		Luck.GetArmedPotionLuck(data)
	)
	performBind(player, data, state, getAreaId(altar), luck.Total, true)
end

local function tryOffer(player: Player, altar: Instance)
	local data, state = checkAltarUse(player, altar)
	if data == nil or state == nil then
		return
	end

	local count = Luck.GetOfferingCount(data, state.NightIndex)
	local offering = Luck.GetNextOffering(count)
	if offering == nil then
		notify:FireClient(player, "You've made every offering tonight. Time to bind!", "error")
		return
	end
	if data.Stardust < offering.Cost then
		notify:FireClient(player, `You need {offering.Cost} Stardust for this offering.`, "error")
		return
	end

	data.Stardust -= offering.Cost
	if data.OfferingNight ~= state.NightIndex then
		data.OfferingNight = state.NightIndex
		data.Offerings = 0
	end
	data.Offerings += 1
	QuestService:Progress(player, "Offer", 1)

	local stardustLuck = Luck.Compute(getAreaId(altar), state.NightIndex, data.Offerings, 1).Stardust
	notify:FireClient(player, `The stars accept your offering. Stardust luck x{stardustLuck}`, "success")
end

-- Runs fn for a player unless one of their altar actions is already running.
-- Auto-bind: the area of the Star Altar nearest the player (the area they're in), if they've unlocked it.
local function getPlayerAreaId(player: Player, data: PlayerDataTypes.PlayerData): string
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return DEFAULT_AREA
	end
	local bestId, bestDistance = DEFAULT_AREA, math.huge
	for _, altar in CollectionService:GetTagged(ALTAR_TAG) do
		local part = if altar:IsA("BasePart") then altar elseif altar:IsA("Model") then altar.PrimaryPart else nil
		local areaId = getAreaId(altar)
		local area = Areas[areaId]
		if part and area and data.Rebirths >= area.RebirthsRequired then
			local distance = (part.Position - root.Position).Magnitude
			if distance < bestDistance then
				bestId, bestDistance = areaId, distance
			end
		end
	end
	return bestId
end

local function guarded(player: Player, fn: () -> ())
	if busy[player] then
		return
	end
	busy[player] = true
	local ok, err = pcall(fn)
	if not ok then
		warn(`[BindingService] Altar action failed for {player.Name}: {err}`)
	end
	busy[player] = nil
end

local function makePrompt(part: BasePart, name: string, actionText: string, key: Enum.KeyCode, gamepadKey: Enum.KeyCode, hold: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = "Star Altar"
	prompt.KeyboardKeyCode = key
	prompt.GamepadKeyCode = gamepadKey
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = BindingConfig.PromptRange
	prompt.RequiresLineOfSight = false
	prompt.Enabled = Cycle.GetState().IsNight
	prompt.Parent = part
	table.insert(prompts, prompt)
	return prompt
end

local function setupAltar(altar: Instance)
	local part = if altar:IsA("BasePart") then altar elseif altar:IsA("Model") then altar.PrimaryPart else nil
	if part == nil then
		warn(`[BindingService] StarAltar {altar:GetFullName()} needs to be a BasePart or a Model with a PrimaryPart`)
		return
	end

	local bindPrompt = makePrompt(part, "BindPrompt", "Bind", Enum.KeyCode.E, Enum.KeyCode.ButtonX, BindingConfig.PromptHoldSeconds)
	bindPrompt.Triggered:Connect(function(player)
		guarded(player, function()
			tryBind(player, altar, part)
		end)
	end)

	local offerPrompt = makePrompt(part, "OfferPrompt", "Offer Stardust", Enum.KeyCode.F, Enum.KeyCode.ButtonY, LuckConfig.OfferingPromptHoldSeconds)
	offerPrompt.UIOffset = Vector2.new(0, 80) -- stack below the Bind prompt instead of overlapping
	offerPrompt.Triggered:Connect(function(player)
		guarded(player, function()
			tryOffer(player, altar)
		end)
	end)

	altar.Destroying:Connect(function()
		for _, prompt in { bindPrompt, offerPrompt } do
			local index = table.find(prompts, prompt)
			if index then
				table.remove(prompts, index)
			end
		end
	end)
end

function BindingService:Start()
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)

	CollectionService:GetInstanceAddedSignal(ALTAR_TAG):Connect(setupAltar)
	for _, altar in CollectionService:GetTagged(ALTAR_TAG) do
		setupAltar(altar)
	end

	-- Open the altars at night, close them during the day. Near the end of each night, Auto-bind pass owners who
	-- haven't bound yet bind at base luck (no area, moon, offering, group or potion bonuses).
	while true do
		local state = Cycle.GetState()
		for _, prompt in prompts do
			prompt.Enabled = state.IsNight
		end
		if state.IsNight and state.SecondsLeft <= Products.AutoBindSecondsLeft then
			for _, player in Players:GetPlayers() do
				local data = DataService:GetData(player)
				if data and data.LastBindNight ~= state.NightIndex and MonetizationService:OwnsPass(player, "AutoBind") then
					guarded(player, function()
						if data.LastBindNight ~= state.NightIndex then
							performBind(player, data, state, getPlayerAreaId(player, data), Products.AutoBindLuck, false)
						end
					end)
				end
			end
		end
		task.wait(1)
	end
end

return BindingService
