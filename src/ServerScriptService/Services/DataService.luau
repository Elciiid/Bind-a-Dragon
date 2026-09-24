--!strict
-- Loads, holds, and saves player data using ProfileStore (session-locked).
-- ProfileStore autosaves every 5 minutes, saves on leave, and saves everything on shutdown (BindToClose).
--
-- Other services read and change data through GetData(player). Changes to the returned table are saved
-- automatically; never cache it past the player leaving.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.Packages.ProfileStore)
local DataConfig = require(ReplicatedStorage.Shared.Config.Data)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

type PlayerData = PlayerDataTypes.PlayerData

-- Bump this and add a step to MIGRATIONS whenever existing saved data needs to be reshaped
-- (renamed/moved/removed fields). Plain new fields don't need a migration: Reconcile() fills them in.
local CURRENT_DATA_VERSION = 1

-- MIGRATIONS[n] upgrades data from version n to n + 1.
local MIGRATIONS: { [number]: (data: any) -> () } = {}

local TEMPLATE: PlayerData = {
	DataVersion = CURRENT_DATA_VERSION,

	Gold = DataConfig.StartingGold,
	Stardust = DataConfig.StartingStardust,
	Rebirths = 0,

	Dragons = {},
	NextDragonId = 1,

	StarAtlas = {},

	LastOnline = 0,
	PurchaseIds = {},
}

local store = ProfileStore.New(DataConfig.StoreName, TEMPLATE)
local profiles: { [Player]: ProfileStore.Profile<PlayerData> } = {}
local loadedCallbacks: { (Player, PlayerData) -> () } = {}

local DataService = {}

local function migrate(data: PlayerData)
	while data.DataVersion < CURRENT_DATA_VERSION do
		local step = MIGRATIONS[data.DataVersion]
		if step then
			step(data)
		end
		data.DataVersion += 1
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

	profile.OnSave:Connect(function()
		profile.Data.LastOnline = os.time()
	end)

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
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
	local profile = profiles[player]
	if profile then
		profile:EndSession()
	end
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

function DataService:Start()
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return DataService
