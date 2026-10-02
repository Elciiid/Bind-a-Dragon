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
		PromptDistance = 12, -- touch/keyboard interaction reach
		PurchaseRange = 16, -- server purchase and client menu-close boundary
		RequestInterval = 0.25, -- server anti-spam interval
		MenuUpdateInterval = 0.5, -- live price / departure polling
		BubbleRaise = 1.15, -- the "Welcome, binder!" bubble sits this many bubble heights above the price board over the merchant's head

		-- Idle motion of the merchant NPC (MerchantIdleController): the imported art keeps one working bone (the root), so the
		-- whole body breathes, sways and turns toward the player. Angles are radians; periods are seconds per cycle.
		Idle = {
			BreathPeriod = 3.4,
			BreathPitch = 0.028, -- forward/back rock of the body with each breath
			BreathBob = 0.05, -- studs the root rises with each breath
			SwayPeriod = 7.5,
			SwayRoll = 0.045, -- slow side-to-side lean
			NoticeRange = 22, -- studs: the merchant turns to face you inside this range
			MaxTurn = 0.7, -- the most it turns (about 40 degrees)
			TurnSpeed = 3.5, -- how quickly the turn eases (higher = snappier)
			LookAwayPeriod = 11, -- with nobody near, now and then a small glance to one side
			LookAwayTurn = 0.25,
			AnimateDistance = 90, -- not animated beyond this (the model is client-side only, nobody sees it)
		},
	},

	-- Selling at the Star Merchant (SellService; DragonStats.GetSellValue / GetSellProtection). PROPOSED numbers, waiting for approval
	-- (docs/Merchant_Selling_Proposal.md, checked with tools/sim).
	Selling = {
		RequestInterval = 0.5, -- server anti-spam interval for sell/lock requests
		MaxDragonsPerRequest = 60,

		Dragons = {
			-- gold = the dragon's own earning rate (level, stage, trait, grade, mutation, roost upgrade, rebirth bonus, Index) x Seconds[rarity]
			-- x MutationMultiplier[mutation]: it scales with progress, so a sale is always small next to what the dragon earns in the roost.
			Seconds = { Common = 90, Rare = 150, Epic = 240, Legendary = 480, Mythic = 900 },
			MutationMultiplier = { Hoardscale = 1.25, Warcrest = 1.5, Aetherwing = 1.5, Primordial = 2 },
			-- Wyrm Runes / Dragonstones that come with a sale ("rare ones also give a few"); mutated dragons give RewardMutatedMultiplier x
			Rewards = {
				Rare = { WyrmRunes = 1, Dragonstones = 0 },
				Epic = { WyrmRunes = 1, Dragonstones = 1 },
				Legendary = { WyrmRunes = 3, Dragonstones = 3 },
				Mythic = { WyrmRunes = 8, Dragonstones = 8 },
			},
			RewardMutatedMultiplier = 2,
			-- the confirm dialog adds a warning (and the server demands ConfirmedRisky) for these
			ConfirmRarities = { Epic = true, Legendary = true, Mythic = true },
			ConfirmMutated = true,
		},

		Items = {
			-- seconds of the player's current roost income per item (potions: well under their boost value; runes/stones: small,
			-- so Spire drops can't be farmed into gold). Stardust is not sold (the merchant's own price makes it a loop).
			Potions = {
				GildedDraught = 60,
				HoardElixir = 120,
				StarlightTonic = 90,
				MoonfireTonic = 240,
				WyrmbloodTonic = 90,
				ConquerorsBrew = 300,
				RunebrightTonic = 120,
			},
			WyrmRunes = 10,
			Dragonstones = 10,
			MaxPerRequest = 1000,
		},
	},

	RoostUpgrades = {
		-- Extra roost slots, bought one at a time: SlotCosts[n] is the cost of the n-th extra slot.
		-- Base slots and the hard max are in Config/Roost (BaseSlots, MaxSlots).
		SlotCosts = { 250e3, 25e6, 2.5e9, 250e9, 25e12 },

		-- Roost income multiplier: +IncomeBonusPerLevel per level, up to MaxIncomeLevel.
		--   cost of the next level = IncomeBaseCost x IncomeCostGrowth ^ (current level)
		IncomeBonusPerLevel = 0.04,
		MaxIncomeLevel = 25,
		IncomeBaseCost = 100e3,
		IncomeCostGrowth = 3.5,
	},
}
