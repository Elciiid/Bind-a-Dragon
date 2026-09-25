--!strict
-- Dragon Index (extends the Star Atlas) and Starborn variants.
--
-- Index: every species a player has ever owned is an entry; a Starborn of that species is a separate entry.
-- Bonuses multiply roost income (Shared/DragonStats GetIndexMultiplier):
--   (1 + IncomePerEntry x entries) x ElementMultiplier per complete element x AllSpeciesMultiplier
-- A complete element = all its normal species (one per rarity). All species = every normal species in Config/Dragons.
-- Rewards are granted automatically when reached (IndexService), never twice.
--
-- Starborn: a rare variant rolled on every bind (not the starter). Multiplies that dragon's income and power.
-- PLACEHOLDER numbers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rewards = require(ReplicatedStorage.Shared.Rewards)

type Reward = Rewards.Reward

return {
	IncomePerEntry = 0.01, -- +1% roost income per Index entry
	ElementMultiplier = 1.3, -- per complete element (multiplies)
	AllSpeciesMultiplier = 1.5, -- once every normal species is found

	-- Every MilestoneEvery entries: this reward.
	MilestoneEvery = 5,
	MilestoneReward = { Potions = { HoardElixir = 1 }, WyrmRunes = 2 } :: Reward,
	ElementReward = { Potions = { MoonfireTonic = 1 }, WyrmRunes = 5, Dragonstones = 5 } :: Reward,

	StarbornChance = 1 / 850, -- per bind
	StarbornIncome = 3, -- x income
	StarbornPower = 2, -- x Spire power
	StarbornColor = Color3.fromRGB(255, 240, 170), -- tint and sparkle on the model until real art exists
	StarbornTint = 0.35, -- how far the placeholder's colors blend toward StarbornColor
}
