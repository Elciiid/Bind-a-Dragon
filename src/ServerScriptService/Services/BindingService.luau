--!strict
-- Binding at Star Altars. Any instance tagged "StarAltar" (a BasePart, or a Model with a PrimaryPart) gets a
-- Bind prompt, open only at night. The altar's "AreaId" attribute picks its entry in Config/Areas.
--
-- ProximityPrompt.Triggered fires on the server with the real player, so the client never sends any values.
-- Every player gets their own roll; one bind per player per night (tracked by NightIndex, so it holds across servers).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local BindingConfig = require(ReplicatedStorage.Shared.Config.Binding)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

local bindResult = ReplicatedStorage.Remotes.BindResult :: RemoteEvent
local announcement = ReplicatedStorage.Remotes.Announcement :: RemoteEvent

local ALTAR_TAG = "StarAltar"
local DEFAULT_AREA = "StarterMeadow"

local rng = Random.new()
local prompts: { ProximityPrompt } = {}
local busy: { [Player]: boolean } = {}

local rarityById: { [string]: Rarities.Rarity } = {}
for _, rarity in Rarities do
	rarityById[rarity.Id] = rarity
end

local BindingService = {}

-- Weighted rarity roll. Luck multiplies the weight of every tier above the first (Common).
local function rollRarity(luck: number): Rarities.Rarity
	local total = 0
	for index, rarity in Rarities do
		total += rarity.BindWeight * (if index > 1 then luck else 1)
	end
	local roll = rng:NextNumber() * total
	for index, rarity in Rarities do
		roll -= rarity.BindWeight * (if index > 1 then luck else 1)
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

local function reject(player: Player, message: string)
	bindResult:FireClient(player, { Ok = false, Message = message })
end

local function tryBind(player: Player, altar: Instance)
	local data = DataService:GetData(player)
	if data == nil then
		return reject(player, "Your data is still loading.")
	end

	local state = Cycle.GetState()
	if not state.IsNight then
		return reject(player, "The stars only answer at night.")
	end
	if data.LastBindNight == state.NightIndex then
		return reject(player, "You've already bound tonight. Come back next night!")
	end

	local areaId = altar:GetAttribute("AreaId")
	local area = Areas[if type(areaId) == "string" then areaId else DEFAULT_AREA]
	if area == nil then
		warn(`[BindingService] Altar {altar:GetFullName()} has unknown AreaId {areaId}`)
		return reject(player, "This altar is broken.")
	end
	if data.Rebirths < area.RebirthsRequired then
		return reject(player, `You need {area.RebirthsRequired} rebirths to bind in {area.Name}.`)
	end

	-- TODO(LuckService): stack Stardust, moon, group and event luck here, with the total cap.
	local luck = area.BindLuck
	local rarity = rollRarity(luck)
	local speciesId = pickSpecies(rarity.Id, state.Constellation.Element)
	if speciesId == nil then
		warn(`[BindingService] No species with rarity {rarity.Id} in Config/Dragons`)
		return reject(player, "The stars were silent. Try again.")
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
		Ok = true,
		DragonId = dragonId,
		SpeciesId = speciesId,
		ConstellationId = constellationId,
	})

	if rarity.AnnounceOnBind then
		announcement:FireAllClients(`{player.DisplayName} bound a {rarity.Name} {Dragons[speciesId].Name}!`)
	end
end

local function setupAltar(altar: Instance)
	local part = if altar:IsA("BasePart") then altar elseif altar:IsA("Model") then altar.PrimaryPart else nil
	if part == nil then
		warn(`[BindingService] StarAltar {altar:GetFullName()} needs to be a BasePart or a Model with a PrimaryPart`)
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BindPrompt"
	prompt.ActionText = "Bind"
	prompt.ObjectText = "Star Altar"
	prompt.HoldDuration = BindingConfig.PromptHoldSeconds
	prompt.MaxActivationDistance = BindingConfig.PromptRange
	prompt.RequiresLineOfSight = false
	prompt.Enabled = Cycle.GetState().IsNight
	prompt.Parent = part
	table.insert(prompts, prompt)

	prompt.Triggered:Connect(function(player)
		if busy[player] then
			return
		end
		busy[player] = true
		local ok, err = pcall(tryBind, player, altar)
		if not ok then
			warn(`[BindingService] Bind failed for {player.Name}: {err}`)
		end
		busy[player] = nil
	end)

	altar.Destroying:Connect(function()
		local index = table.find(prompts, prompt)
		if index then
			table.remove(prompts, index)
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
