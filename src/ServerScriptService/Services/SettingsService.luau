--!strict
-- Player settings (the Settings window): music and sound volume, Low effects, Quick binds. Saved in data.Settings so
-- they follow the player to any device. The client sends SaveSettings(settings); every value is type-checked and
-- clamped here, unknown keys are ignored, and requests are rate-limited. Settings only change visuals and sound.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)

local saveSettings = ReplicatedStorage.Remotes.SaveSettings :: RemoteEvent

local MIN_INTERVAL = 0.3 -- seconds between saves per player

local SettingsService = {}

local lastSave: { [Player]: number } = {}

local function volume(value: any): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return math.clamp(value, 0, 1)
end

function SettingsService:Start()
	saveSettings.OnServerEvent:Connect(function(player: Player, incoming: any)
		if type(incoming) ~= "table" then
			return
		end
		local now = os.clock()
		if now - (lastSave[player] or 0) < MIN_INTERVAL then
			return
		end
		lastSave[player] = now
		local data = DataService:GetData(player)
		if data == nil then
			return
		end
		local settings = data.Settings
		local music = volume(incoming.MusicVolume)
		if music then
			settings.MusicVolume = music
		end
		local sound = volume(incoming.SoundVolume)
		if sound then
			settings.SoundVolume = sound
		end
		if type(incoming.LowEffects) == "boolean" then
			settings.LowEffects = incoming.LowEffects
		end
		if type(incoming.QuickBinds) == "boolean" then
			settings.QuickBinds = incoming.QuickBinds
		end
		if type(incoming.ReducedMotion) == "boolean" then
			settings.ReducedMotion = incoming.ReducedMotion
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastSave[player] = nil
	end)
end

return SettingsService
