--!strict
-- Client copy of the local player's data, kept in sync by DataService. Read-only: changing it does nothing
-- on the server. Other controllers use Get() and OnChanged() to drive UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

type PlayerData = PlayerDataTypes.PlayerData
type Callback = (value: any) -> ()

local DataController = {}

local data: PlayerData? = nil
local listeners: { [string]: { Callback } } = {}
local loadedEvent = Instance.new("BindableEvent")

local function notify(key: string, value: any)
	for _, callback in listeners[key] or {} do
		task.spawn(callback, value)
	end
end

-- Returns the data, or nil if it hasn't arrived yet.
function DataController:Get(): PlayerData?
	return data
end

-- Yields until the data has arrived.
function DataController:WaitForData(): PlayerData
	while data == nil do
		loadedEvent.Event:Wait()
	end
	return data :: PlayerData
end

-- Calls callback(value) now (once data has arrived) and every time the top-level key changes.
function DataController:OnChanged(key: string, callback: Callback)
	listeners[key] = listeners[key] or {}
	table.insert(listeners[key], callback)
	if data then
		task.spawn(callback, (data :: any)[key])
	end
end

function DataController:Start()
	local changed = ReplicatedStorage.Remotes.PlayerDataChanged :: RemoteEvent
	local getPlayerData = ReplicatedStorage.Remotes.GetPlayerData :: RemoteFunction

	-- Changes can arrive before the snapshot; hold them and apply after (they're newer).
	local pending: { { [string]: any } } = {}
	changed.OnClientEvent:Connect(function(changes: { [string]: any })
		if data == nil then
			table.insert(pending, changes)
			return
		end
		for key, value in changes do
			(data :: any)[key] = value
			notify(key, value)
		end
	end)

	local snapshot = getPlayerData:InvokeServer()
	if snapshot == nil then
		return
	end
	for _, changes in pending do
		for key, value in changes do
			snapshot[key] = value
		end
	end
	data = snapshot
	loadedEvent:Fire()
	for key, value in snapshot do
		notify(key, value)
	end
end

return DataController
