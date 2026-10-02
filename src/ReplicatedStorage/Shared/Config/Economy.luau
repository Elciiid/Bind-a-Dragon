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
		-- The merchant's dialog (MerchantController): numbered lines on the screen, the merchant's words in the speech bubble.
		Dialog = {
			ScreenX = 0.5, ScreenY = 0.46, -- left edge / vertical center of the choice lines (fractions of the screen)
			PhoneScreenX = 0.27, PhoneScreenY = 0.5, -- phones: further left, clear of the timer stack on the right
			LineHeight = 46, TextSize = 30, -- PC
			PhoneLineHeight = 44, PhoneTextSize = 22, -- phones: lines stay tappable (>= 44 px)
			HoverShift = 8, -- pixels a hovered line slides right
			BubbleWidth = 320, BubbleHeight = 74,
			-- camera eases toward the merchant while talking (not with Reduced Motion): behind and beside the player, looking at the merchant
			CameraBack = 6, CameraSide = 3, CameraUp = 3, CameraLookBlend = 0.6, CameraLookUp = 3,
			CameraEaseIn = 3, CameraEaseOut = 4, CameraStrength = 0.85,
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

		-- Auto sell (data.AutoSell, edited in the merchant's "Edit auto sell settings"): a newly bound dragon that matches is sold at bind time
		-- (server) and the toast follows after the reveal. These are the defaults for a new player.
		AutoSell = {
			Common = false, Rare = false, Epic = false, Legendary = false, Mythic = false,
			KeepMutated = true,
			KeepNewSpecies = true,
		},
		AutoSellToastDelay = 7, -- seconds after the bind before "Auto-sold ..." shows (the reveal ceremony is over by then)
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
