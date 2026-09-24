--!strict
-- Dragon leveling with gold (the main gold sink).
-- Cost of the next level = BaseCost[rarity] x CostGrowth ^ (current level - 1)
-- Level caps come from Config/Areas (highest unlocked area's LevelCap).
-- PLACEHOLDER numbers.

return {
	BaseCost = {
		Common = 25,
		Rare = 100,
		Epic = 400,
		Legendary = 2000,
		Mythic = 10000,
	} :: { [string]: number },

	CostGrowth = 1.2, -- each level costs 20% more than the last

	MaxLevelsPerRequest = 100, -- most levels one "level up xN" request can buy
}
