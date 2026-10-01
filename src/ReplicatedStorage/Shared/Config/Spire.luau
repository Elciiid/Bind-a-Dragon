--!strict
-- Dragon Spire (SpireService). Auto-battle: the player's most powerful dragon fights one enemy per floor.
--
-- Enemy power = EnemyBase x EnemyGrowth ^ floor (bosses every BossEvery floors x BossMultiplier).
-- A floor is won if the player's power (best dragon x Wyrmblood Tonic) >= the enemy's.
-- Every run fights stages 1..100 in order. The player can opt into a new run after stage 100.
-- A loss, Stop, death or departure ends the run.
--
-- Rewards: a first clear (floor above the record) pays FirstClearIncomeSeconds of roost income and its guaranteed
-- drops; all re-clears roll the Reclear chances. Every boss gives baseline stones and runes. Conqueror's Brew doubles gold, Stardust,
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
	MaxFloors = 100, -- every run attempts stages 1 through 100 in order
	EnemyBase = 10,
	EnemyGrowth = 1.15, -- retuned with tools/sim after the mutation economy: Dedicated week-1 floor median ~98
	BossEvery = 10,
	BossMultiplier = 1.5,

	FightSeconds = 12, -- every stage; a full successful run takes 20 minutes
	CheckInterval = 0.25, -- check alive/range/stop during a fight
	ActionCooldown = 0.5, -- rate-limit manual start and toggle requests
	StopCooldown = 0.1, -- separate limiter so Stop remains available immediately after Start
	PromptDistance = 15, -- keyboard, gamepad and mobile prompt reach
	RepeatPauseSeconds = 1, -- completion breath before an opted-in repeat

	FirstClearIncomeSeconds = 30, -- first-clear gold = this many seconds of roost income

	-- Guaranteed on a floor's first clear (every matching entry is given).
	FirstClearDrops = {
		{ Every = 5, SkipBosses = true, Potion = "GildedDraught", WyrmRunes = 1, Dragonstones = 1 },
		{ Every = 10, Potion = "HoardElixir", WyrmRunes = 1, Dragonstones = 1, Stardust = 10 },
		{ Every = 10, Potion = "RunebrightTonic", Chance = 0.10 },
		{ Every = 20, Potion = "StarlightTonic" },
		{ Every = 25, Potion = "WyrmbloodTonic" },
		{ Every = 50, Potion = "MoonfireTonic" },
		{ Every = 100, Offset = 50, Potion = "ConquerorsBrew" }, -- floors 50, 150, 250 ...
	} :: { Drop },

	-- Every victory gives these baseline rewards, including repeat runs.
	VictoryDrops = { { Every = 10, WyrmRunes = 1, Dragonstones = 1 } } :: { Drop },
	-- Potion chances on all re-clears; currency comes from VictoryDrops.
	ReclearDrops = {
		{ Every = 5, SkipBosses = true, Potion = "GildedDraught", Chance = 0.25 },
		{ Every = 10, Potion = "HoardElixir", Chance = 0.10 },
		{ Every = 10, Potion = "RunebrightTonic", Chance = 0.10 },
	} :: { Drop },

	EntranceRange = 60, -- studs from the Spire (tag "DragonSpire") the player must stay within while climbing
	PromptHoldSeconds = 0.3,
}
