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

	-- ===== Difficulties (2026-10-03 update, checkpoint 4). PROPOSED numbers: not read by SpireService until approved. =====
	-- Enemy power on a floor of a difficulty = EnemyBase x EnemyScale x EnemyGrowth ^ (floor + FloorOffset) (x BossMultiplier on bosses).
	-- Unlock: the previous difficulty's floor MaxFloors was cleared (UnlockFrom). Infinite has no top floor (MaxFloors = nil):
	-- it continues Hard's curve, so its floor 1 is about Hard's floor 101.
	-- RewardMultiplier multiplies the Wyrm Runes / Dragonstones / Stardust of every boss victory (Easy = the original values; potions
	-- are never multiplied); FirstClearMultiplier does the same for a floor's first-clear drops. DepthRewardEvery (Infinite): the
	-- boss multiplier grows by RewardMultiplier x floor / DepthRewardEvery, so deeper bosses pay more. ExtraFirstClearDrops / ExtraReclearDrops are added to
	-- the base tables above for that difficulty only; SkipBaseFirstClear = true leaves the base first-clear table out for it (Medium, Hard and
	-- Infinite give their first clears boss-victory rewards, the extras and 30 s of gold, but not another full set of Easy's potions/runes).
	Difficulties = {
		Order = { "Easy", "Medium", "Hard", "Infinite" },
		Easy = {
			Name = "Easy", EnemyScale = 1, FloorOffset = 0, MaxFloors = 100, RewardMultiplier = 1, FirstClearMultiplier = 1, FirstClearIncomeSeconds = 30,
		},
		Medium = {
			Name = "Medium", EnemyScale = 20, FloorOffset = 0, MaxFloors = 100, RewardMultiplier = 2, FirstClearMultiplier = 1, FirstClearIncomeSeconds = 30,
			UnlockFrom = "Easy", SkipBaseFirstClear = true,
		},
		Hard = {
			Name = "Hard", EnemyScale = 400, FloorOffset = 0, MaxFloors = 100, RewardMultiplier = 4, FirstClearMultiplier = 1, FirstClearIncomeSeconds = 30,
			UnlockFrom = "Medium", SkipBaseFirstClear = true,
			ExtraFirstClearDrops = {
				{ Every = 25, Potion = "MoonfireTonic" },
				{ Every = 10, Potion = "RunebrightTonic", Chance = 0.25 },
			} :: { Drop },
			ExtraReclearDrops = {
				{ Every = 25, Potion = "MoonfireTonic", Chance = 0.05 },
				{ Every = 10, Potion = "RunebrightTonic", Chance = 0.15 },
			} :: { Drop },
		},
		Infinite = {
			Name = "Infinite", EnemyScale = 400, FloorOffset = 100, MaxFloors = nil, RewardMultiplier = 4, FirstClearMultiplier = 1, DepthRewardEvery = 50,
			FirstClearIncomeSeconds = 30, UnlockFrom = "Hard", SkipBaseFirstClear = true,
			ExtraFirstClearDrops = {
				{ Every = 25, Potion = "MoonfireTonic" },
				{ Every = 10, Potion = "RunebrightTonic", Chance = 0.25 },
				{ Every = 50, Potion = "ConquerorsBrew" },
			} :: { Drop },
			ExtraReclearDrops = {
				{ Every = 25, Potion = "MoonfireTonic", Chance = 0.05 },
				{ Every = 10, Potion = "RunebrightTonic", Chance = 0.15 },
				{ Every = 50, Potion = "ConquerorsBrew", Chance = 0.10 },
			} :: { Drop },
		},
	} :: { [string]: any },

	-- Floors you have ALREADY cleared that are far below your dragon's power resolve faster. The first row whose PowerRatio (your power /
	-- the enemy's) is reached sets the fight time; RewardShare scales the boss Wyrm Runes / Dragonstones / Stardust of that floor, so
	-- repeat runs stay worth about what the original 20-minute run was. A floor you have not cleared always takes FightSeconds at full pay.
	FastFloors = {
		{ PowerRatio = 25, Seconds = 1.5, RewardShare = 0.25 },
		{ PowerRatio = 4, Seconds = 5, RewardShare = 0.5 },
	},

	EntranceRange = 60, -- studs from the Spire (tag "DragonSpire") the player must stay within while climbing
	PromptHoldSeconds = 0.3,
}
