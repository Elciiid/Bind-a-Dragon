--!strict
-- Ordered stores hold integer scores; metadata is monotonic too. All reads exposed to clients are cached.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local DataService = require(script.Parent.DataService)
local Config = require(ReplicatedStorage.Shared.Config.Leaderboards)
local Stats = require(ReplicatedStorage.Shared.LeaderboardStats)
local Text = require(ReplicatedStorage.Shared.Config.Text).Leaderboards
local remote = ReplicatedStorage.Remotes.GetLeaderboards :: RemoteFunction
local suffix = if RunService:IsStudio() then "_Studio" else ""
local stores: {[string]: OrderedDataStore} = {}
for board, name in Config.Stores do stores[board] = DataStoreService:GetOrderedDataStore(name .. suffix) end
local metadata = DataStoreService:GetDataStore(Config.MetadataStore .. suffix)
local active: {[Player]: any} = {}
local lastWrite: {[Player]: number} = {}
local writing: {[Player]: boolean} = {}
local lastRequest: {[Player]: number} = {}
local cache: {[string]: any} = {}
local names: {[number]: string} = {}
local details: {[number]: any} = {}
local closing = false
local Service = {}

local function budgeted(kind: Enum.DataStoreRequestType, operation: () -> any, readKind: Enum.DataStoreRequestType?): (boolean, any)
	local function ready(): boolean
		return DataStoreService:GetRequestBudgetForRequestType(kind) > 0
			and (not readKind or DataStoreService:GetRequestBudgetForRequestType(readKind) > 0)
	end
	for attempt = 1, Config.RetryCount do
		local deadline = os.clock() + Config.BudgetWaitSeconds
		while not ready() and os.clock() < deadline do task.wait(Config.TickInterval) end
		if ready() then
			local ok, result = pcall(operation)
			if ok then return true, result end
			if attempt == Config.RetryCount then warn(`[Leaderboards] DataStore request failed: {result}`) end
		end
		if attempt < Config.RetryCount then task.wait(Config.RetrySeconds * attempt) end
	end
	warn("[Leaderboards] Request unavailable; retaining last successful snapshot")
	return false, nil
end

local function nameFor(userId: number): string
	local localPlayer = Players:GetPlayerByUserId(userId)
	if localPlayer then return localPlayer.Name end
	if names[userId] then return names[userId] end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	if ok then names[userId] = name; return name end
	return Text.UnknownPlayer
end

local function write(player: Player, leaving: boolean?)
	local data = active[player]
	if not data or writing[player] then return end
	if not leaving and os.clock() - (lastWrite[player] or -math.huge) < Config.WriteInterval then return end
	writing[player] = true
	lastWrite[player] = os.clock()
	local snapshot = {Rebirths = Stats.Encode("Rebirths", data), Gold = Stats.Encode("Gold", data), Rarest = Stats.Encode("Rarest", data)}
	local rare = { OneIn = data.RarestOneIn, Species = data.RarestSpecies, Mutation = data.RarestMutation }
	local key = tostring(player.UserId)
	-- Write metadata before advertising its rare score. An older flush cannot replace a rarer discovery.
	local metaOk = rare.OneIn <= 0 or budgeted(Enum.DataStoreRequestType.UpdateAsync, function()
		return metadata:UpdateAsync(key, function(old)
			if type(old) == "table" and type(old.OneIn) == "number" and old.OneIn >= rare.OneIn then return old end
			return rare
		end)
	end)
	for board, score in snapshot do
		if board ~= "Rarest" or metaOk then
			budgeted(Enum.DataStoreRequestType.SetIncrementSortedAsync, function()
				return stores[board]:UpdateAsync(key, function(old) return math.max(if type(old) == "number" then old else 0, score) end)
			end, Enum.DataStoreRequestType.GetAsync)
		end
	end
	writing[player] = nil
end

local function rareDetails(userId: number): any
	local entry = details[userId]
	if entry and os.clock() - entry.Time < Config.MetadataCacheSeconds then return entry.Data end
	local ok, result = budgeted(Enum.DataStoreRequestType.GetAsync, function() return metadata:GetAsync(tostring(userId)) end)
	if ok then details[userId] = {Time = os.clock(), Data = result}; return result end
	return if entry then entry.Data else nil
end

local function refresh(board: string)
	local ok, pages = budgeted(Enum.DataStoreRequestType.GetSortedAsync, function() return stores[board]:GetSortedAsync(false, Config.PageSize) end)
	if not ok then return end -- keep the last good board, never replace it with mock results
	local top, ranks, scores = {}, {}, {}
	local rank = 0
	local unresolved = {}
	for player in active do unresolved[player.UserId] = true end
	for page = 1, Config.RankPageLimit do
		for _, row in pages:GetCurrentPage() do
			rank += 1
			local userId = tonumber(row.key)
			if userId and (userId > 0 or RunService:IsStudio()) then
				unresolved[userId] = nil
				ranks[userId], scores[userId] = rank, row.value
				local rare = if board == "Rarest" and row.value > 0 and (#top < Config.TopCount or active[Players:GetPlayerByUserId(userId)]) then rareDetails(userId) else nil
				if rare and math.round(rare.OneIn or 0) ~= row.value then rare = nil end
				if #top < Config.TopCount then
					table.insert(top, {UserId = userId, Name = nameFor(userId), Rank = rank, Score = row.value,
						Value = if board == "Gold" then Stats.DecodeGold(row.value) else row.value,
						Rare = rare})
				end
			end
		end
		if pages.IsFinished or page >= Config.RankPageLimit or (#top >= Config.TopCount and next(unresolved) == nil) then break end
		local advanced = budgeted(Enum.DataStoreRequestType.GetSortedAsync, function() pages:AdvanceToNextPageAsync() end)
		if not advanced then break end
	end
	cache[board] = {Top = top, Ranks = ranks, Scores = scores, UpdatedAt = os.time(), Scanned = rank}
end

local function snapshot(player: Player): any
	local data = active[player]
	if not data then return nil end
	local boards = {}
	for board in Config.Stores do
		local c = cache[board]
		local ownScore = if c then c.Scores[player.UserId] else nil
		local entry = details[player.UserId]
		local ownRare = if board == "Rarest" and ownScore ~= nil and entry then entry.Data else nil
		if ownRare and math.round(ownRare.OneIn or 0) ~= ownScore then ownRare = nil end
		boards[board] = {
			Top = if c then c.Top else {}, UpdatedAt = if c then c.UpdatedAt else 0,
			Own = {Rank = if c then c.Ranks[player.UserId] else nil, Score = ownScore,
				-- Show the same cached value the rank describes, not a misleading fresh value with an old rank.
				Value = if ownScore ~= nil then (if board == "Gold" then Stats.DecodeGold(ownScore) else ownScore)
					else (if board == "Gold" then data.LifetimeGold else if board == "Rebirths" then data.Rebirths else data.RarestOneIn),
				Rare = ownRare},
		}
	end
	return boards
end

function Service:Start()
	DataService:OnDataLoaded(function(player, data)
		Stats.Backfill(data)
		active[player] = data -- retain until our leave flush; DataService's leave handler may remove its reference first
		local leaderstats = Instance.new("Folder"); leaderstats.Name = "leaderstats"; leaderstats.Parent = player
		local rebirths = Instance.new("IntValue"); rebirths.Name = "Rebirths"; rebirths.Value = data.Rebirths; rebirths.Parent = leaderstats
		task.spawn(write, player)
	end)
	remote.OnServerInvoke = function(player: Player, ...: any)
		if select("#", ...) ~= 0 then return nil end
		local now = os.clock()
		if now - (lastRequest[player] or -math.huge) < Config.RequestCooldown then return nil end
		lastRequest[player] = now
		return snapshot(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		-- If a routine write is in flight, wait for it, then flush the latest values once.
		local deadline = os.clock() + Config.ShutdownSeconds
		while writing[player] and os.clock() < deadline do task.wait(Config.RetrySeconds) end
		write(player, true)
		active[player], lastRequest[player], lastWrite[player] = nil, nil, nil
	end)
	game:BindToClose(function()
		closing = true
		local pending = 0
		for player in active do
			pending += 1
			task.spawn(function() while writing[player] do task.wait(Config.RetrySeconds) end; write(player, true); pending -= 1 end)
		end
		local deadline = os.clock() + Config.ShutdownSeconds
		while pending > 0 and os.clock() < deadline do task.wait(Config.RetrySeconds) end
	end)
	task.spawn(function()
		while not closing do
			for board in Config.Stores do refresh(board) end
			task.wait(Config.RefreshInterval)
		end
	end)
	while not closing do
		for player, data in active do
			local folder = player:FindFirstChild("leaderstats")
			local stat = folder and folder:FindFirstChild("Rebirths")
			if stat and stat:IsA("IntValue") then stat.Value = data.Rebirths end
			task.spawn(write, player)
		end
		task.wait(Config.TickInterval)
	end
end
return Service
