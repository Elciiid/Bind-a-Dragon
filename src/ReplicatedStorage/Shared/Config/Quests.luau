--!strict
-- Daily/weekly quests and the login streak (QuestService).
--
-- Each UTC day a player gets DailyCount quests picked at random from DailyPool; each week (Monday 00:00 UTC) they
-- get WeeklyCount from WeeklyPool. A quest's reward depends on its slot (DailyRewards[1] for the first quest, ...),
-- so the day's total is always the same. Rewards are granted automatically when a quest completes.
--
-- Quest kinds (tracked by QuestService:Progress):
--   Bind = binds at a Star Altar; Levels = dragon levels bought; Offer = Stardust offerings;
--   Gold = gold earned in game (Target = IncomeSeconds of the player's roost income when the quest is given).
-- Quest Ids are saved in player data, so never rename or remove an Id once live (change Text instead).
--
-- Login streak: the first join of each UTC day counts. Missing a day resets it to day 1; after the last day it
-- starts again at day 1. PLACEHOLDER numbers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rewards = require(ReplicatedStorage.Shared.Rewards)

type Reward = Rewards.Reward

export type Quest = {
	Id: string,
	Kind: "Bind" | "Levels" | "Offer" | "Gold",
	Text: string, -- "{n}" is replaced by the target
	Target: number?, -- fixed target (all kinds except Gold)
	IncomeSeconds: number?, -- Gold: target = this many seconds of roost income at the time
}

local DailyPool: { Quest } = {
	{ Id = "DailyBind", Kind = "Bind", Text = "Bind {n} dragons", Target = 2 },
	{ Id = "DailyLevels", Kind = "Levels", Text = "Buy {n} dragon levels", Target = 20 },
	{ Id = "DailyOffer", Kind = "Offer", Text = "Make {n} Stardust offerings", Target = 2 },
	{ Id = "DailyGold", Kind = "Gold", Text = "Earn {n} gold", IncomeSeconds = 15 * 60 },
}

local WeeklyPool: { Quest } = {
	{ Id = "WeeklyBind", Kind = "Bind", Text = "Bind {n} dragons", Target = 25 },
	{ Id = "WeeklyLevels", Kind = "Levels", Text = "Buy {n} dragon levels", Target = 300 },
	{ Id = "WeeklyGold", Kind = "Gold", Text = "Earn {n} gold", IncomeSeconds = 3 * 3600 },
}

return {
	DailyPool = DailyPool,
	WeeklyPool = WeeklyPool,
	DailyCount = 3,
	WeeklyCount = 2,

	-- By slot. Daily total: 30 Stardust, 2 Gilded Draught, 1 Wyrm Rune + 1 Dragonstone.
	DailyRewards = {
		{ Stardust = 30 },
		{ Potions = { GildedDraught = 2 } },
		{ WyrmRunes = 1, Dragonstones = 1 },
	} :: { Reward },
	-- Weekly total: 2 Hoard Elixir, 3 Wyrm Runes + 3 Dragonstones.
	WeeklyRewards = {
		{ Potions = { HoardElixir = 2 } },
		{ WyrmRunes = 3, Dragonstones = 3 },
	} :: { Reward },

	-- Login streak rewards, day 1..7 (then back to day 1).
	StreakRewards = {
		{ Stardust = 5 },
		{ Stardust = 5 },
		{ Stardust = 10 },
		{ Stardust = 10 },
		{ Stardust = 15 },
		{ Stardust = 15 },
		{ Potions = { MoonfireTonic = 1 } },
	} :: { Reward },
}
