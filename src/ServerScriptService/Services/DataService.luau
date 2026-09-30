--!strict
-- Loads, holds, and saves player data using ProfileStore (session-locked).
-- ProfileStore autosaves every 5 minutes, saves on leave, and saves everything on shutdown (BindToClose).
--
-- Other services read and change data through GetData(player). Changes to the returned table are saved
-- automatically; never cache it past the player leaving.
--
-- Client sync: the client asks once for a snapshot (GetPlayerData), then a few times per second the server
-- diffs each player's data against what it last sent and sends only the changed top-level keys
-- (PlayerDataChanged). Services never need to notify anything; just change the data.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.Packages.ProfileStore)
local DataConfig = require(ReplicatedStorage.Shared.Config.Data)
local Mutations = require(ReplicatedStorage.Shared.Config.Mutations)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

type PlayerData = PlayerDataTypes.PlayerData

-- Bump this and add a step to MIGRATIONS whenever existing saved data needs to be reshaped
-- (renamed/moved/removed fields). Plain new fields don't need a migration: Reconcile() fills them in.
local CURRENT_DATA_VERSION = 3

local function defaultSettings(): PlayerDataTypes.Settings
	local defaults = DataConfig.DefaultSettings
	return {
		MusicVolume = defaults.MusicVolume,
		SoundVolume = defaults.SoundVolume,
		LowEffects = defaults.LowEffects,
		QuickBinds = defaults.QuickBinds,
	}
end

-- MIGRATIONS[n] upgrades data from version n to n + 1.
local MIGRATIONS: { [number]: (data: any) -> () } = {
	-- 1 -> 2: player settings (Settings window). Fill any missing value with the default.
	[1] = function(data)
		local settings = if type(data.Settings) == "table" then data.Settings else {}
		for key, value in defaultSettings() :: any do
			if type(settings[key]) ~= type(value) then
				settings[key] = value
			end
		end
		data.Settings = settings
	end,
	-- 2 -> 3: replace the dormant Starborn prototype with the approved Primordial mutation.
	[2] = function(data)
		data.MutationIndex = if type(data.MutationIndex) == "table" then data.MutationIndex else {}
		for _, dragon in if type(data.Dragons) == "table" then data.Dragons else {} do
			if dragon.Starborn == true then
				dragon.MutationId = "Primordial"
				if type(dragon.SpeciesId) == "string" then
					local oldTime = if type(data.Index) == "table" then data.Index[`{dragon.SpeciesId}_Starborn`] else nil
					data.MutationIndex[`{dragon.SpeciesId}:Primordial`] = oldTime or os.time()
				end
			end
			dragon.Starborn = nil
		end
		if type(data.Index) == "table" then
			for key in data.Index do
				if type(key) == "string" and string.match(key, "_Starborn$") then data.Index[key] = nil end
			end
		end
	end,
}

local TEMPLATE: PlayerData = {
	DataVersion = CURRENT_DATA_VERSION,

	Gold = DataConfig.StartingGold,
	Stardust = DataConfig.StartingStardust,
	WyrmRunes = 0,
	Dragonstones = 0,
	Rebirths = 0,

	Dragons = {},
	NextDragonId = 1,
	RoostDragonIds = {},
	RoostUnplacedDragonIds = {},
	RoostSlotUpgrades = 0,
	RoostIncomeLevel = 0,

	MerchantDay = -1,
	MerchantPurchases = 0,

	Potions = {},
	ActiveBoosts = {},
	ArmedLuckPotion = "",
	PotionHintShown = false,

	QuestDay = -1,
	DailyQuests = {},
	QuestWeek = -1,
	WeeklyQuests = {},
	LoginDay = -1,
	LoginStreak = 0,

	SpireRecord = 0,
	ElevatorSkips = 0,
	EchoSigils = 0,
	EchoSigilQuestDay = -1,
	EchoSigilSpireDay = -1,
	EchoSigilSpireProgressDay = -1,
	EchoSigilSpireWins = 0,

	StarAtlas = {},
	Index = {},
	MutationIndex = {},
	IndexMilestones = 0,
	IndexElementsRewarded = {},
	LastBindNight = -1,
	OfferingNight = -1,
	Offerings = 0,

	LastOnline = 0,
	AfkCreditDay = -1,
	AfkCreditSeconds = 0,
	PurchaseIds = {},
	Settings = defaultSettings(),
}

-- Top-level keys that stay on the server and are never sent to the client.
local PRIVATE_KEYS = {
	PurchaseIds = true,
	RoostUnplacedDragonIds = true,
}

-- How often (seconds) changed data is sent to clients.
local SYNC_INTERVAL = 0.2

local getPlayerData = ReplicatedStorage.Remotes.GetPlayerData :: RemoteFunction
local playerDataChanged = ReplicatedStorage.Remotes.PlayerDataChanged :: RemoteEvent

-- Studio playtests use a separate DataStore so testing never touches live player data.
local storeName = if RunService:IsStudio() then `{DataConfig.StoreName}_Studio` else DataConfig.StoreName
local store = ProfileStore.New(storeName, TEMPLATE)
local profiles: { [Player]: ProfileStore.Profile<PlayerData> } = {}
local loadedCallbacks: { (Player, PlayerData) -> () } = {}
local lastSent: { [Player]: { [string]: any } } = {} -- per player: copy of what their client currently has

local DataService = {}

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[k] = deepCopy(v)
	end
	return copy :: any
end

local function deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

-- Sends each synced player the top-level keys that changed since the last send.
local function syncChanges()
	for player, sent in lastSent do
		local profile = profiles[player]
		if profile == nil then
			continue
		end
		local changes: { [string]: any } = {}
		for key, value in profile.Data :: any do
			if not PRIVATE_KEYS[key] and not deepEqual(value, sent[key]) then
				sent[key] = deepCopy(value)
				changes[key] = value
			end
		end
		if next(changes) ~= nil then
			playerDataChanged:FireClient(player, changes)
		end
	end
end

local function migrate(data: PlayerData)
	while data.DataVersion < CURRENT_DATA_VERSION do
		local step = MIGRATIONS[data.DataVersion]
		if step then
			step(data)
		end
		data.DataVersion += 1
	end
end

local function sanitizeMutations(data: PlayerData)
	for _, dragon in data.Dragons do
		if dragon.MutationId ~= nil and Mutations.ById[dragon.MutationId] == nil then
			warn(`[DataService] Unknown mutation {dragon.MutationId} on dragon {dragon.Id}; using Normal`)
			dragon.MutationId = nil
		end
	end
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		player:Kick("Your data couldn't be loaded. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId) -- GDPR
	profile:Reconcile()
	migrate(profile.Data)
	sanitizeMutations(profile.Data)

	profile.OnSave:Connect(function()
		profile.Data.LastOnline = os.time()
	end)

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		lastSent[player] = nil
		player:Kick("Your data was loaded on another server. Please rejoin.")
	end)

	if player.Parent ~= Players then
		-- Left while loading.
		profile:EndSession()
		return
	end

	profiles[player] = profile
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile.Data)
	end
end

local function onPlayerRemoving(player: Player)
	lastSent[player] = nil
	local profile = profiles[player]
	if profile then
		profile:EndSession()
	end
end

-- Client's first request: returns a snapshot of their data (minus private keys) and starts syncing changes.
-- Yields until their data loads. Safe to call again; it just resends the full snapshot.
local function onGetPlayerData(player: Player): { [string]: any }?
	local data = DataService:WaitForData(player)
	if data == nil then
		return nil
	end
	local snapshot = {}
	for key, value in data :: any do
		if not PRIVATE_KEYS[key] then
			snapshot[key] = deepCopy(value)
		end
	end
	lastSent[player] = deepCopy(snapshot)
	return snapshot
end

-- Returns the player's live data, or nil if it hasn't loaded (or they've left).
function DataService:GetData(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

-- Returns the raw profile. Only MonetizationService should need this (LastSavedData, Save()).
function DataService:GetProfile(player: Player): ProfileStore.Profile<PlayerData>?
	return profiles[player]
end

-- Yields until the player's data loads. Returns nil if they leave first.
function DataService:WaitForData(player: Player): PlayerData?
	while player.Parent == Players do
		local data = self:GetData(player)
		if data then
			return data
		end
		task.wait()
	end
	return nil
end

-- Runs callback(player, data) each time a player's data finishes loading,
-- including for players already loaded when this is called.
function DataService:OnDataLoaded(callback: (Player, PlayerData) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile.Data)
	end
end

-- Records a developer product receipt as granted. Returns false if it was already recorded.
function DataService:RecordPurchaseId(player: Player, purchaseId: string): boolean
	local data = self:GetData(player)
	if data == nil or table.find(data.PurchaseIds, purchaseId) then
		return false
	end
	table.insert(data.PurchaseIds, purchaseId)
	while #data.PurchaseIds > DataConfig.MaxStoredPurchaseIds do
		table.remove(data.PurchaseIds, 1)
	end
	return true
end

function DataService:Init()
	-- Set in Init (not Start) so it's ready before any client can ask.
	getPlayerData.OnServerInvoke = onGetPlayerData
end

function DataService:Start()
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	while true do
		task.wait(SYNC_INTERVAL)
		syncChanges()
	end
end

return DataService
