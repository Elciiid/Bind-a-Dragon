--!strict
-- Binding at Star Altars. Any instance tagged "StarAltar" (a BasePart, or a Model with a PrimaryPart) gets two
-- prompts, open only at night: Bind (E) and Offer Stardust (F). The altar's "AreaId" attribute picks its entry
-- in Config/Areas.
--
-- ProximityPrompt.Triggered fires on the server with the real player, so the client never sends any values.
-- Every player gets their own roll; one bind per player per night (tracked by NightIndex, so it holds across servers).
-- Luck comes from Shared/Luck, the same math the client uses to display it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local Luck = require(ReplicatedStorage.Shared.Luck)
local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local BindingConfig = require(ReplicatedStorage.Shared.Config.Binding)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local LuckConfig = require(ReplicatedStorage.Shared.Config.Luck)
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

-- Weighted rarity roll using the luck-adjusted weights from Shared/Luck.
local function rollRarity(luck: number): Rarities.Rarity
	local weights = Luck.GetRarityWeights(luck)
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local roll = rng:NextNumber() * total
	for index, rarity in Rarities do
		roll -= weights[index]
		if roll < 0 then
			return rarity
		end
	end
	return Rarities[#Rarities]
end

-- Picks a species of the given rarity, matching the element if one is given.
-- Falls back to any element if no species matches (e.g. a gap in the roster).
local function pickSpecies(rarityId: string, element: string?): string?
	local matches, anyElement = {}, {}
	for speciesId, species in Dragons do
		if species.Rarity == rarityId then
			table.insert(anyElement, speciesId)
			if element == nil or species.Element == element then
				table.insert(matches, speciesId)
			end
		end
	end
	local pool = if #matches > 0 then matches else anyElement
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

local function tryBind(player: Player, altar: Instance, part: BasePart)
	local data, state = checkAltarUse(player, altar)
	if data == nil or state == nil then
		return
	end

	local luck = Luck.Compute(
		getAreaId(altar),
		state.NightIndex,
		Luck.GetOfferingCount(data, state.NightIndex),
		Luck.CountPlayersNear(part.Position, LuckConfig.GroupRadius)
	)
	local rarity = rollRarity(luck.Total)
	local speciesId = pickSpecies(rarity.Id, state.Constellation.Element)
	if speciesId == nil then
		warn(`[BindingService] No species with rarity {rarity.Id} in Config/Dragons`)
		notify:FireClient(player, "The stars were silent. Try again.", "error")
		return
	end

	local dragonId = tostring(data.NextDragonId)
	data.NextDragonId += 1
	data.Dragons[dragonId] = {
		Id = dragonId,
		SpeciesId = speciesId,
		Level = 1,
		ObtainedAt = os.time(),
	}
	data.LastBindNight = state.NightIndex
	local constellationId = state.Constellation.Id
	data.StarAtlas[constellationId] = (data.StarAtlas[constellationId] or 0) + 1

	bindResult:FireClient(player, {
		DragonId = dragonId,
		SpeciesId = speciesId,
		ConstellationId = constellationId,
		Luck = luck.Total,
	})

	if rarity.AnnounceOnBind then
		announcement:FireAllClients(`{player.DisplayName} bound a {rarity.Name} {Dragons[speciesId].Name}!`)
	end
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

	local stardustLuck = Luck.Compute(getAreaId(altar), state.NightIndex, data.Offerings, 1).Stardust
	notify:FireClient(player, `The stars accept your offering. Stardust luck x{stardustLuck}`, "success")
end

-- Runs fn for a player unless one of their altar actions is already running.
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

	-- Open the altars at night, close them during the day.
	while true do
		local isNight = Cycle.GetState().IsNight
		for _, prompt in prompts do
			prompt.Enabled = isNight
		end
		task.wait(1)
	end
end

return BindingService
