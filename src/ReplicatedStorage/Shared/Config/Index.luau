--!strict
-- Dragon Index (extends the Star Atlas). Mutation discoveries are cosmetic badges and never multiply income.
--
-- Index: every normal species a player has ever owned is one progression entry.
-- Bonuses multiply roost income (Shared/DragonStats GetIndexMultiplier):
--   (1 + IncomePerEntry x entries) x ElementMultiplier per complete element x AllSpeciesMultiplier
-- A complete element = all its normal species (one per rarity). All species = every normal species in Config/Dragons.
-- Rewards are granted automatically when reached (IndexService), never twice.
--
-- PLACEHOLDER numbers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rewards = require(ReplicatedStorage.Shared.Rewards)

type Reward = Rewards.Reward

return {
	IncomePerEntry = 0.005, -- +0.5% per normal species; mutations never inflate income
	ElementMultiplier = 1.10,
	AllSpeciesMultiplier = 1.20,

	-- Every MilestoneEvery entries: this reward.
	MilestoneEvery = 5,
	MilestoneReward = { Potions = { HoardElixir = 1 }, WyrmRunes = 2 } :: Reward,
	ElementReward = { Potions = { MoonfireTonic = 1 }, WyrmRunes = 5, Dragonstones = 5 } :: Reward,

}
