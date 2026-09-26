--!strict
-- "Low effects": fewer lights and particles for phones and slow devices. On when the player turns it on in Settings
-- (LocalPlayer attribute "LowEffects") or when Roblox's graphics quality is at/below Config/Atmosphere AutoLowQuality.
-- Effects call IsLow() and OnChanged(fn).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AtmosphereConfig = require(ReplicatedStorage.Shared.Config.Atmosphere)

local EffectsQuality = {}

local listeners: { (boolean) -> () } = {}
local current = false

local function qualityIsLow(): boolean
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if not ok or level == Enum.SavedQualitySetting.Automatic then
		return false
	end
	return level.Value <= AtmosphereConfig.AutoLowQuality
end

local function compute(): boolean
	return Players.LocalPlayer:GetAttribute("LowEffects") == true or qualityIsLow()
end

local function update()
	local now = compute()
	if now ~= current then
		current = now
		for _, fn in listeners do
			task.spawn(fn, now)
		end
	end
end

function EffectsQuality.IsLow(): boolean
	return current
end

-- Calls fn(isLow) now and whenever it changes.
function EffectsQuality.OnChanged(fn: (boolean) -> ())
	table.insert(listeners, fn)
	task.spawn(fn, current)
end

current = compute()
Players.LocalPlayer:GetAttributeChangedSignal("LowEffects"):Connect(update)
pcall(function()
	UserSettings():GetService("UserGameSettings"):GetPropertyChangedSignal("SavedQualityLevel"):Connect(update)
end)

return EffectsQuality
