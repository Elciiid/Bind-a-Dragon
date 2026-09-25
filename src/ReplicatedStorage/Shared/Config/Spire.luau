--!strict
-- Dragon Spire (SpireService). Auto-battle: the player's most powerful dragon fights one enemy per floor.
--
-- Enemy power = EnemyBase x EnemyGrowth ^ floor (bosses every BossEvery floors x BossMultiplier).
-- A floor is won if the player's power (best dragon x Wyrmblood Tonic) >= the enemy's.
-- Each climb starts at floor 1. Floors more than TopWindow below the player's record are "far below": they resolve
-- in FastFloorSeconds each with no drops. The TopWindow floors below the record and every new floor are real fights
-- (FightSeconds each), unless the player's power is PowerFastRatio x the enemy's (FastFloorSeconds). A climb ends at the first lost floor, at MaxFloors, or if the player walks away.
--
-- Rewards: a first clear (floor above the record) pays FirstClearIncomeSeconds of roost income and its guaranteed
-- drops; re-clears inside the TopWindow roll the Reclear chances. Conqueror's Brew doubles gold, Stardust,
-- Wyrm Runes and Dragonstones (not potions). Numbers from the approved economy simulation; PLACEHOLDER.

export type Drop = {
	Every: number, -- drops on floors where floor % Every == Offset
	Offset: number?, -- default 0
	SkipBosses: boolean?, -- not on boss floors
	Potion: string?, -- Config/Boosts potion Id
	WyrmRunes: number?,
	Dragonstones: number?,
	Stardust: number?,
	Chance: number?, -- 1 = guaranteed (default)
	RuneOrStone: boolean?, -- one Wyrm Rune or one Dragonstone (50/50)
}

return {
	MaxFloors = 150, -- +10 each weekly update
	EnemyBase = 10,
	EnemyGrowth = 1.215, -- re-simulated with the built game: Dedicated week-1 floor median ~115, p90 ~119
	BossEvery = 10,
	BossMultiplier = 1.5,

	FightSeconds = 20, -- per fought floor
	FastFloorSeconds = 0.25, -- per far-below floor (no drops)
	TopWindow = 10, -- re-clear window below the record
	PowerFastRatio = 3, -- floors where power >= this x the enemy also take FastFloorSeconds: a new one still gives its
	-- first-clear drops (no gold), an already-cleared one gives nothing

	FirstClearIncomeSeconds = 30, -- first-clear gold = this many seconds of roost income

	-- Guaranteed on a floor's first clear (every matching entry is given).
	FirstClearDrops = {
		{ Every = 5, SkipBosses = true, Potion = "GildedDraught" }, -- bosses get the Hoard Elixir instead
		{ Every = 10, Potion = "HoardElixir", WyrmRunes = 1, Dragonstones = 1, Stardust = 10 },
		{ Every = 10, Potion = "RunebrightTonic", Chance = 0.10 },
		{ Every = 20, Potion = "StarlightTonic" },
		{ Every = 25, Potion = "WyrmbloodTonic" },
		{ Every = 50, Potion = "MoonfireTonic" },
		{ Every = 100, Offset = 50, Potion = "ConquerorsBrew" }, -- floors 50, 150, 250 ...
	} :: { Drop },

	-- Chances on re-clears inside the TopWindow.
	ReclearDrops = {
		{ Every = 5, SkipBosses = true, Potion = "GildedDraught", Chance = 0.25 },
		{ Every = 10, Potion = "HoardElixir", Chance = 0.10 },
		{ Every = 10, RuneOrStone = true, Chance = 0.10 },
		{ Every = 10, Potion = "RunebrightTonic", Chance = 0.10 },
	} :: { Drop },

	EntranceRange = 60, -- studs from the Spire (tag "DragonSpire") the player must stay within while climbing
	PromptHoldSeconds = 0.3,
}
