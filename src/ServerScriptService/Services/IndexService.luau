--!strict
-- Dragon Index: records every species (and Starborn variant) a player has owned and hands out its rewards
-- (Config/Index). The income bonus itself is computed in Shared/DragonStats GetIndexMultiplier.
--
-- Sync(player, data) is idempotent: it records every owned dragon and grants any reward reached but not yet given.
-- Called on data load (which also backfills older saves), after binds, and after the starter dragon is granted.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoostService = require(script.Parent.BoostService)
local DataService = require(script.Parent.DataService)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Boosts = require(ReplicatedStorage.Shared.Config.Boosts)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local IndexConfig = require(ReplicatedStorage.Shared.Config.Index)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent

local IndexService = {}

local function describeReward(reward: IndexConfig.Reward): string
	local parts = {}
	for potionId, count in reward.Potions or {} do
		local potion = Boosts.ById[potionId]
		table.insert(parts, `{count} {if potion then potion.Name else potionId}`)
	end
	if reward.WyrmRunes then
		table.insert(parts, `{reward.WyrmRunes} Wyrm Runes`)
	end
	if reward.Dragonstones then
		table.insert(parts, `{reward.Dragonstones} Dragonstones`)
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

local function grant(player: Player, data: PlayerDataTypes.PlayerData, reward: IndexConfig.Reward)
	for potionId, count in reward.Potions or {} do
		BoostService:GrantPotion(player, potionId, count)
	end
	data.WyrmRunes += reward.WyrmRunes or 0
	data.Dragonstones += reward.Dragonstones or 0
end

function IndexService:Sync(player: Player, data: PlayerDataTypes.PlayerData)
	local now = os.time()
	for _, dragon in data.Dragons do
		local entryId = DragonStats.GetIndexEntryId(dragon)
		if data.Index[entryId] == nil and Dragons[dragon.SpeciesId] then
			data.Index[entryId] = now
			local species = Dragons[dragon.SpeciesId]
			local name = if dragon.Starborn then `Starborn {species.Name}` else species.Name
			notify:FireClient(
				player,
				`New Index entry: {name}! Index income {Format.Multiplier(DragonStats.GetIndexMultiplier(data))}`,
				"success"
			)
		end
	end

	-- Every MilestoneEvery entries.
	local reached = DragonStats.GetIndexEntryCount(data) // IndexConfig.MilestoneEvery
	while data.IndexMilestones < reached do
		data.IndexMilestones += 1
		grant(player, data, IndexConfig.MilestoneReward)
		notify:FireClient(
			player,
			`Index milestone: {data.IndexMilestones * IndexConfig.MilestoneEvery} entries! +{describeReward(IndexConfig.MilestoneReward)}`,
			"success"
		)
	end

	-- Complete elements.
	local complete = DragonStats.GetIndexCompletion(data)
	for _, element in complete do
		if not data.IndexElementsRewarded[element] then
			data.IndexElementsRewarded[element] = true
			grant(player, data, IndexConfig.ElementReward)
			notify:FireClient(
				player,
				`All {element} dragons found! Income x{IndexConfig.ElementMultiplier}, +{describeReward(IndexConfig.ElementReward)}`,
				"success"
			)
		end
	end
end

function IndexService:Start()
	DataService:OnDataLoaded(function(player, data)
		IndexService:Sync(player, data)
	end)
end

return IndexService
