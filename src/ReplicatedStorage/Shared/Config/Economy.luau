--!strict
-- Gold sinks besides leveling: the Star Merchant (Stardust for gold) and roost upgrades.
-- Both are kept through rebirth (only gold resets). PLACEHOLDER numbers.

return {
	Merchant = {
		-- Each purchase buys BundleSize Stardust. The price scales with the player's next rebirth cost so it stays
		-- meaningful at any point, rises with every purchase, and resets at dawn:
		--   price = next rebirth cost x PriceFractionOfNextRebirth x PriceGrowth ^ (purchases since dawn)
		-- A full night of offerings (6 bundles) costs ~1.2% of the next rebirth.
		BundleSize = 10,
		PriceFractionOfNextRebirth = 0.0006,
		PriceGrowth = 1.5,
		PromptHoldSeconds = 0.3,
	},

	RoostUpgrades = {
		-- Extra roost slots, bought one at a time: SlotCosts[n] is the cost of the n-th extra slot.
		-- Base slots and the hard max are in Config/Roost (BaseSlots, MaxSlots).
		SlotCosts = { 250e3, 25e6, 2.5e9, 250e9, 25e12 },

		-- Roost income multiplier: +IncomeBonusPerLevel per level, up to MaxIncomeLevel.
		--   cost of the next level = IncomeBaseCost x IncomeCostGrowth ^ (current level)
		IncomeBonusPerLevel = 0.10,
		MaxIncomeLevel = 25,
		IncomeBaseCost = 100e3,
		IncomeCostGrowth = 3.5,
	},
}
