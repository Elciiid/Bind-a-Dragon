--!strict
-- Gold sinks besides leveling: the Star Merchant (Stardust for gold) and roost upgrades.
-- Both are kept through rebirth (only gold resets). PLACEHOLDER numbers.

return {
	Merchant = {
		-- Each purchase buys BundleSize Stardust. The price rises with every purchase and resets at dawn,
		-- so rich players can't buy unlimited luck:
		--   price = BasePrice x PriceGrowth ^ (purchases since dawn)
		-- With these numbers the 6 bundles for a full night of offerings (60 Stardust) cost ~10K gold.
		BundleSize = 10,
		BasePrice = 500,
		PriceGrowth = 1.5,
		PromptHoldSeconds = 0.3,
	},

	RoostUpgrades = {
		-- Extra roost slots, bought one at a time: SlotCosts[n] is the cost of the n-th extra slot.
		-- Base slots and the hard max are in Config/Roost (BaseSlots, MaxSlots).
		SlotCosts = { 25_000, 250_000, 2_500_000, 25_000_000, 250_000_000 },

		-- Roost income multiplier: +IncomeBonusPerLevel per level, up to MaxIncomeLevel.
		--   cost of the next level = IncomeBaseCost x IncomeCostGrowth ^ (current level)
		IncomeBonusPerLevel = 0.10,
		MaxIncomeLevel = 10,
		IncomeBaseCost = 10_000,
		IncomeCostGrowth = 2.5,
	},
}
