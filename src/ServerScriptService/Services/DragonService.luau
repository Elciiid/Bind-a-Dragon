--!strict
-- Dragon leveling and evolution. The client asks to level a dragon (LevelUpDragon: dragonId, count);
-- the server checks ownership, the level cap and gold, and buys as many of the requested levels as it can afford.
-- Crossing a stage's MinLevel evolves the dragon; the constellation in the sky at that moment is recorded
-- as that stage's branch in dragon.Evolutions.
-- Also trait rolls (RollTrait: dragonId, costs Wyrm Runes, at a "RuneShrine") and grade rolls
-- (RollGrade: dragonId, costs Dragonstones, at a "DragonstoneForge"); odds in Config/Traits, improved by an
-- active Runebright Tonic (Config/Boosts).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoostService = require(script.Parent.BoostService)
local DataService = require(script.Parent.DataService)
local IndexService = require(script.Parent.IndexService)
local QuestService = require(script.Parent.QuestService)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Evolution = require(ReplicatedStorage.Shared.Config.Evolution)
local Leveling = require(ReplicatedStorage.Shared.Config.Leveling)
local Luck = require(ReplicatedStorage.Shared.Luck)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local TraitConfig = require(ReplicatedStorage.Shared.Config.Traits)
local DataConfig = require(ReplicatedStorage.Shared.Config.Data)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

local levelUpDragon = ReplicatedStorage.Remotes.LevelUpDragon :: RemoteEvent
local rollTrait = ReplicatedStorage.Remotes.RollTrait :: RemoteEvent
local rollGrade = ReplicatedStorage.Remotes.RollGrade :: RemoteEvent
local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent
local announcement = ReplicatedStorage.Remotes.Announcement :: RemoteEvent

local MIN_REQUEST_INTERVAL = 0.1 -- seconds between level-up requests per player (anti-spam)
local MIN_ROLL_INTERVAL = 0.5 -- seconds between trait/grade rolls per player
local STATION_RANGE = 20 -- studs from a Rune Shrine / Dragonstone Forge to roll there
local MAX_ID_LENGTH = 20

local rng = Random.new()
local lastRequest: { [Player]: number } = {}
local lastRoll: { [Player]: number } = {}

local DragonService = {}

local function onLevelUp(player: Player, dragonId: unknown, count: unknown)
	-- Validate the request shape before touching any data.
	if typeof(dragonId) ~= "string" or #dragonId > MAX_ID_LENGTH then
		return
	end
	local wanted = 1
	if typeof(count) == "number" and count == count then -- count == count rejects NaN
		wanted = math.clamp(math.floor(count), 1, Leveling.MaxLevelsPerRequest)
	end

	local now = os.clock()
	if now - (lastRequest[player] or 0) < MIN_REQUEST_INTERVAL then
		return
	end
	lastRequest[player] = now

	local data = DataService:GetData(player)
	local dragon = data and data.Dragons[dragonId]
	if data == nil or dragon == nil then
		return
	end

	local cap = DragonStats.GetLevelCap(data)
	if dragon.Level >= cap then
		notify:FireClient(player, `Level cap reached ({cap}). Rebirth to raise it!`, "error")
		return
	end

	local species = Dragons[dragon.SpeciesId]
	local leveled = 0
	while leveled < wanted and dragon.Level < cap do
		local cost = DragonStats.GetLevelUpCost(dragon, data.Rebirths)
		if data.Gold < cost then
			break
		end
		local stageBefore = DragonStats.GetStage(dragon.Level)
		data.Gold -= cost
		dragon.Level += 1
		leveled += 1

		local stageAfter = DragonStats.GetStage(dragon.Level)
		if stageAfter.Id ~= stageBefore.Id then
			-- The constellation in the sky becomes this stage's branch; during the day there is none.
			local state = Cycle.GetState()
			local evolutions = dragon.Evolutions or {}
			evolutions[stageAfter.Id] = if state.IsNight then state.Constellation.Id else Evolution.DayBranchId
			dragon.Evolutions = evolutions
			local name = if species then species.Name else "Your dragon"
			local under = if state.IsNight then ` under {state.Constellation.Name}` else " in daylight (no branch bonus)"
			notify:FireClient(player, `{name} evolved into a {stageAfter.Name}{under}!`, "success")
		end
	end

	QuestService:Progress(player, "Levels", leveled)
	if leveled == 0 then
		local cost = DragonStats.GetLevelUpCost(dragon, data.Rebirths)
		notify:FireClient(player, `Not enough gold. You need {Format.Number(cost)}.`, "error")
	end
end

---------------------------------------------------------------------------------------------------------------
-- Traits and grades: rolled at the Rune Shrine (Wyrm Runes -> trait) and the Dragonstone Forge
-- (Dragonstones -> grade). The player must be standing at a station of the right kind.

local function isNearStation(player: Player, tag: string): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	for _, station in CollectionService:GetTagged(tag) do
		local position = if station:IsA("Model")
			then station:GetPivot().Position
			elseif station:IsA("BasePart") then station.Position
			else nil
		if position and (root.Position - position).Magnitude <= STATION_RANGE then
			return true
		end
	end
	return false
end

local function tierIndex(tierId: string): number
	for index, rarity in Rarities do
		if rarity.Id == tierId then
			return index
		end
	end
	return 1
end

-- Picks one entry at random by Weight. Roll luck (Runebright Tonic) boosts rarer tiers the same way bind luck
-- does (Shared/Luck GetTierWeights, which the station UI also uses to show the odds).
local function weightedPick(entries: { any }, luck: number): any
	local weights = Luck.GetTierWeights(entries, luck)
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local roll = rng:NextNumber() * total
	for index, entry in entries do
		roll -= weights[index]
		if roll < 0 then
			return entry
		end
	end
	return entries[#entries]
end

local function tierAtLeast(tierId: string, minimumId: string): boolean
	return tierIndex(tierId) >= tierIndex(minimumId)
end

local function onRoll(player: Player, dragonId: unknown, kind: "Trait" | "Grade")
	if typeof(dragonId) ~= "string" or #dragonId > MAX_ID_LENGTH then
		return
	end
	local now = os.clock()
	if now - (lastRoll[player] or 0) < MIN_ROLL_INTERVAL then
		return
	end
	lastRoll[player] = now

	local data = DataService:GetData(player)
	local dragon = data and data.Dragons[dragonId]
	if data == nil or dragon == nil then
		return
	end
	local stationTag = if kind == "Trait" then "RuneShrine" else "DragonstoneForge"
	if not isNearStation(player, stationTag) then
		notify:FireClient(player, if kind == "Trait" then "Go to the Rune Shrine to roll traits." else "Go to the Dragonstone Forge to roll grades.", "error")
		return
	end

	local species = Dragons[dragon.SpeciesId]
	local name = if species then species.Name else "Your dragon"
	if kind == "Trait" then
		if data.WyrmRunes < TraitConfig.TraitRollCost then
			notify:FireClient(player, "You're out of Wyrm Runes. Earn more in the Dragon Spire.", "error")
			return
		end
		data.WyrmRunes -= TraitConfig.TraitRollCost
		local trait = weightedPick(TraitConfig.Traits, BoostService:GetMultiplier(player, "RollLuck"))
		dragon.Trait = trait.Id
		notify:FireClient(player, `{name} gained the {trait.Name} trait!`, "success")
		if tierAtLeast(trait.Tier, TraitConfig.AnnounceTier) then
			announcement:FireAllClients(`{player.DisplayName} rolled the {trait.Name} trait!`)
		end
	else
		if data.Dragonstones < TraitConfig.GradeRollCost then
			notify:FireClient(player, "You're out of Dragonstones. Earn more in the Dragon Spire.", "error")
			return
		end
		data.Dragonstones -= TraitConfig.GradeRollCost
		local grade = weightedPick(TraitConfig.Grades, BoostService:GetMultiplier(player, "RollLuck"))
		dragon.Grade = grade.Id
		notify:FireClient(player, `{name} is now grade {grade.Id}!`, "success")
		if tierAtLeast(grade.Tier, TraitConfig.AnnounceTier) then
			announcement:FireAllClients(`{player.DisplayName} rolled grade {grade.Id}!`)
		end
	end
end

-- Brand-new players (no dragons ever) get the starter dragon from Config/Data, so income starts right away.
local function grantStarter(player: Player, data: PlayerDataTypes.PlayerData)
	local speciesId = DataConfig.StarterDragon
	if speciesId == nil or Dragons[speciesId] == nil or data.NextDragonId ~= 1 or next(data.Dragons) ~= nil then
		return
	end
	local dragonId = tostring(data.NextDragonId)
	data.NextDragonId += 1
	data.Dragons[dragonId] = { Id = dragonId, SpeciesId = speciesId, Level = 1, ObtainedAt = os.time() }
	table.insert(data.RoostDragonIds, dragonId)
	IndexService:Sync(player, data)
	notify:FireClient(player, `Your first dragon, {Dragons[speciesId].Name}, has hatched in your roost!`, "success")
end

function DragonService:Start()
	DataService:OnDataLoaded(grantStarter)
	levelUpDragon.OnServerEvent:Connect(onLevelUp)
	rollTrait.OnServerEvent:Connect(function(player, dragonId)
		onRoll(player, dragonId, "Trait")
	end)
	rollGrade.OnServerEvent:Connect(function(player, dragonId)
		onRoll(player, dragonId, "Grade")
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		lastRoll[player] = nil
	end)
end

return DragonService
