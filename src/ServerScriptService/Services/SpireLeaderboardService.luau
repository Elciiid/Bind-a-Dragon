--!strict
-- Weekly Infinite Spire leaderboard (numbers in Config/Spire.Leaderboard): the deepest Infinite floor a player reached this week.
-- One OrderedDataStore, one scope per week (weeks start Monday 00:00 UTC); the store name gets "_Studio" in Studio so tests never touch the
-- live board. Writes are throttled (a new weekly best is written at most every WriteIntervalSeconds, and when the player leaves or the
-- server closes) and the top list is cached for CacheSeconds. When the DataStore is unreachable (Studio without API access) the board
-- falls back to a per-server memory table and says so (Offline = true).
--   SpireLeaderboardService:Submit(player, floor)   called by SpireService after every Infinite win
--   SpireLeaderboardService:GetBoard(player)        { Entries = { { Rank, UserId, Name, Score } }, MyBest, MyRank, SecondsLeft, Offline }

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SpireConfig = require(ReplicatedStorage.Shared.Config.Spire)

local Config = SpireConfig.Leaderboard
local WEEK = 7 * 86400

export type Entry = { Rank: number, UserId: number, Name: string, Score: number }
export type Board = { Entries: { Entry }, MyBest: number, MyRank: number?, SecondsLeft: number, Offline: boolean }

local best: { [Player]: number } = {} -- this week's best per player in this server (loaded from the store on join)
local weekOf: { [Player]: number } = {} -- the week `best` belongs to
local written: { [Player]: number } = {} -- the last value written
local lastWrite: { [Player]: number } = {}
local memory: { [number]: { [number]: number } } = {} -- offline fallback: week -> userId -> score
local offline = false
local nameCache: { [number]: string } = {}
local cache: { Week: number, At: number, Entries: { Entry } }? = nil

local SpireLeaderboardService = {}

local function now(): number
	return os.time()
end

local function currentWeek(): number
	return math.floor((now() - Config.WeekStartOffsetDays * 86400) / WEEK)
end

local function secondsLeft(): number
	return (currentWeek() + 1) * WEEK + Config.WeekStartOffsetDays * 86400 - now()
end

local function store(week: number): OrderedDataStore
	local name = Config.StoreName .. (if RunService:IsStudio() then "_Studio" else "")
	return DataStoreService:GetOrderedDataStore(name, tostring(week))
end

local function key(userId: number): string
	return tostring(userId)
end

-- Reads a player's stored best for the week (falls back to memory when the store is unreachable).
local function readBest(userId: number, week: number): number
	local ok, value = pcall(function()
		return store(week):GetAsync(key(userId))
	end)
	if ok then
		return if type(value) == "number" then value else 0
	end
	offline = true
	return (memory[week] or {})[userId] or 0
end

local function writeBest(userId: number, week: number, score: number): boolean
	local ok = pcall(function()
		store(week):UpdateAsync(key(userId), function(old: any)
			if type(old) == "number" and old >= score then
				return nil -- keep the better stored value
			end
			return score
		end)
	end)
	if not ok then
		offline = true
	end
	memory[week] = memory[week] or {}
	memory[week][userId] = math.max(memory[week][userId] or 0, score)
	cache = nil -- the top list changed
	return ok
end

local function nameOf(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nameCache[userId] = if ok and type(name) == "string" then name else "Binder"
	return nameCache[userId]
end

local function flush(player: Player, force: boolean?)
	local score = best[player]
	local week = weekOf[player]
	if score == nil or week == nil or score <= (written[player] or 0) then
		return
	end
	if not force and now() - (lastWrite[player] or 0) < Config.WriteIntervalSeconds then
		return
	end
	lastWrite[player] = now()
	written[player] = score
	writeBest(player.UserId, week, score)
end

local function loadPlayer(player: Player)
	local week = currentWeek()
	local value = readBest(player.UserId, week)
	if player.Parent ~= Players then
		return
	end
	weekOf[player] = week
	best[player] = math.max(best[player] or 0, value)
	written[player] = value
end

-- The top list for this week (cached).
local function topList(): { Entry }
	local week = currentWeek()
	if cache and cache.Week == week and now() - cache.At < Config.CacheSeconds then
		return cache.Entries
	end
	local entries: { Entry } = {}
	local ok, page = pcall(function()
		return store(week):GetSortedAsync(false, Config.TopCount):GetCurrentPage()
	end)
	if ok then
		for rank, item in page do
			local userId = tonumber(item.key)
			if userId and type(item.value) == "number" then
				table.insert(entries, { Rank = rank, UserId = userId, Name = nameOf(userId), Score = item.value })
			end
		end
	else
		offline = true
		local scores = {}
		for userId, score in memory[week] or {} do
			table.insert(scores, { UserId = userId, Score = score })
		end
		table.sort(scores, function(a, b)
			return a.Score > b.Score
		end)
		for rank = 1, math.min(#scores, Config.TopCount) do
			local row = scores[rank]
			table.insert(entries, { Rank = rank, UserId = row.UserId, Name = nameOf(row.UserId), Score = row.Score })
		end
	end
	cache = { Week = week, At = now(), Entries = entries }
	return entries
end

-- Called after an Infinite win on `floor`.
function SpireLeaderboardService:Submit(player: Player, floor: number)
	local week = currentWeek()
	if weekOf[player] ~= week then
		-- a new week started while they were here: begin again from 0
		weekOf[player] = week
		best[player] = 0
		written[player] = 0
	end
	if floor > (best[player] or 0) then
		best[player] = floor
		flush(player, false)
	end
end

function SpireLeaderboardService:GetBoard(player: Player): Board
	flush(player, true) -- the board shows their latest floor
	local entries = topList()
	local myBest = if weekOf[player] == currentWeek() then best[player] or 0 else 0
	local myRank: number? = nil
	for _, entry in entries do
		if entry.UserId == player.UserId then
			myRank = entry.Rank
		end
	end
	return { Entries = entries, MyBest = myBest, MyRank = myRank, SecondsLeft = secondsLeft(), Offline = offline }
end

function SpireLeaderboardService:Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadPlayer, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		flush(player, true)
		best[player] = nil
		weekOf[player] = nil
		written[player] = nil
		lastWrite[player] = nil
	end)
	-- throttled writes catch up here
	task.spawn(function()
		while true do
			task.wait(Config.WriteIntervalSeconds)
			for player in best do
				flush(player, false)
			end
		end
	end)
	game:BindToClose(function()
		for player in best do
			flush(player, true)
		end
	end)
end

return SpireLeaderboardService
