--!strict
-- Daily/weekly quests and the login streak (numbers in Config/Quests).
--
-- Quests are (re)assigned when the UTC day/week changes: on join, on every progress update, and in a slow loop for
-- players who stay online across midnight. Other services report progress with Progress(player, kind, amount);
-- a quest that reaches its target grants its slot's reward right away (no claim step, nothing for the client to send).
-- The login streak is counted on the first join of each UTC day.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local QuestConfig = require(ReplicatedStorage.Shared.Config.Quests)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

type PlayerData = PlayerDataTypes.PlayerData
type QuestState = PlayerDataTypes.QuestState

local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent

local ROLLOVER_CHECK_SECONDS = 10

local rng = Random.new()
local questById: { [string]: QuestConfig.Quest } = {}
for _, quest in QuestConfig.DailyPool do
	questById[quest.Id] = quest
end
for _, quest in QuestConfig.WeeklyPool do
	questById[quest.Id] = quest
end

local QuestService = {}

local function getDay(): number
	return os.time() // 86400
end

-- Weeks start Monday 00:00 UTC (day 0, 1 Jan 1970, was a Thursday).
local function getWeek(): number
	return (getDay() + 3) // 7
end

local function makeQuests(pool: { QuestConfig.Quest }, count: number, data: PlayerData): { QuestState }
	local indices = {}
	for i = 1, #pool do
		indices[i] = i
	end
	local quests = {}
	for _ = 1, math.min(count, #pool) do
		local quest = pool[table.remove(indices, rng:NextInteger(1, #indices))]
		local target = if quest.Kind == "Gold"
			then math.max(1000, math.floor(DragonStats.GetRoostIncome(data) * (quest.IncomeSeconds or 0)))
			else quest.Target or 1
		table.insert(quests, { Id = quest.Id, Target = target, Progress = 0, Done = false })
	end
	return quests
end

local function ensureCurrent(data: PlayerData)
	local day, week = getDay(), getWeek()
	if data.QuestDay ~= day then
		data.QuestDay = day
		data.DailyQuests = makeQuests(QuestConfig.DailyPool, QuestConfig.DailyCount, data)
	end
	if data.QuestWeek ~= week then
		data.QuestWeek = week
		data.WeeklyQuests = makeQuests(QuestConfig.WeeklyPool, QuestConfig.WeeklyCount, data)
	end
end

local function countLogin(player: Player, data: PlayerData)
	local day = getDay()
	if data.LoginDay == day then
		return
	end
	local continues = data.LoginDay == day - 1 and data.LoginStreak < #QuestConfig.StreakRewards
	data.LoginStreak = if continues then data.LoginStreak + 1 else 1
	data.LoginDay = day
	local reward = QuestConfig.StreakRewards[data.LoginStreak]
	Rewards.Apply(data, reward)
	notify:FireClient(
		player,
		`Login streak day {data.LoginStreak}/{#QuestConfig.StreakRewards}: +{Rewards.Describe(reward)}`,
		"success"
	)
end

local function advance(player: Player, quests: { QuestState }, rewards: { Rewards.Reward }, kind: string, amount: number, label: string)
	for slot, state in quests do
		local quest = questById[state.Id]
		if state.Done or quest == nil or quest.Kind ~= kind then
			continue
		end
		state.Progress = math.min(state.Target, state.Progress + amount)
		if state.Progress >= state.Target then
			state.Done = true
			local reward = rewards[slot]
			local data = DataService:GetData(player)
			if reward and data then
				Rewards.Apply(data, reward)
				local text = quest.Text:gsub("{n}", Format.Number(state.Target))
				notify:FireClient(player, `{label} quest complete: {text}! +{Rewards.Describe(reward)}`, "success")
			end
		end
	end
end

-- Reports progress on every quest of this kind ("Bind", "Levels", "Offer", "Gold").
function QuestService:Progress(player: Player, kind: string, amount: number)
	local data = DataService:GetData(player)
	if data == nil or amount <= 0 then
		return
	end
	ensureCurrent(data)
	advance(player, data.DailyQuests, QuestConfig.DailyRewards, kind, amount, "Daily")
	advance(player, data.WeeklyQuests, QuestConfig.WeeklyRewards, kind, amount, "Weekly")
end

function QuestService:Start()
	DataService:OnDataLoaded(function(player, data)
		ensureCurrent(data)
		countLogin(player, data)
	end)

	-- Midnight rollover for players who stay online.
	while true do
		task.wait(ROLLOVER_CHECK_SECONDS)
		for _, player in Players:GetPlayers() do
			local data = DataService:GetData(player)
			if data then
				ensureCurrent(data)
				countLogin(player, data)
			end
		end
	end
end

return QuestService
