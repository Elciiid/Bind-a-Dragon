--!strict
-- Game feel (client only): a consistent sound, a small camera shake and a screen flash for rewards and actions.
-- Events come from data changes (level-ups, purchases, runes/stones/potions/Stardust gained, Index entries, rebirths,
-- Spire records) and the Spire climb (start, floors cleared). The palette sound also takes the place of the toast
-- chime when both happen together. Shake and flash are off with Low effects. Settings: Config/Feedback.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local DataController = require(script.Parent.DataController)
local EffectsQuality = require(script.Parent.EffectsQuality)
local Style = require(script.Parent.UI.Style)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Feedback = require(ReplicatedStorage.Shared.Config.Feedback)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local FeedbackController = {}

local sounds: { [string]: Sound } = {}
local shakeUntil = 0
local shakeAngle = 0
local shakeSeconds = 1
local flash: Frame

local function soundVolume(): number
	local value = Players.LocalPlayer:GetAttribute("SoundVolume")
	return if type(value) == "number" then math.clamp(value, 0, 1) else 1
end

local function playSound(key: string)
	local id = Feedback.Sounds[key]
	if id == nil or id == "" then
		return
	end
	local sound = sounds[key]
	if sound == nil then
		local newSound = Instance.new("Sound")
		newSound.Name = `Feedback_{key}`
		newSound.SoundId = id
		newSound.Parent = SoundService
		sounds[key] = newSound
		sound = newSound
	end
	local s = sound :: Sound
	s.Volume = Feedback.Volume * soundVolume()
	SoundService:PlayLocalSound(s)
	Style.MarkFeedbackSound()
end

-- Plays a named event from Config/Feedback Events.
function FeedbackController.Fire(eventName: string)
	local event = Feedback.Events[eventName]
	if event == nil then
		return
	end
	if event.Sound ~= "" then
		playSound(event.Sound)
	end
	if EffectsQuality.IsLow() then
		return
	end
	if event.Shake > 0 then
		local shake = Feedback.Shake[event.Shake]
		if shake and shake.Angle >= shakeAngle * math.max(0, (shakeUntil - os.clock()) / shakeSeconds) then
			shakeAngle = shake.Angle
			shakeSeconds = shake.Seconds
			shakeUntil = os.clock() + shake.Seconds
		end
	end
	if event.Flash and flash then
		flash.BackgroundColor3 = event.Flash
		flash.BackgroundTransparency = Feedback.FlashTransparency
		flash.Visible = true
		local start = os.clock()
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			local t = (os.clock() - start) / Feedback.FlashSeconds
			if t >= 1 then
				flash.Visible = false
				connection:Disconnect()
				return
			end
			flash.BackgroundTransparency = Feedback.FlashTransparency + (1 - Feedback.FlashTransparency) * t
		end)
	end
end

-- Compares the new data with the last copy and fires events for what went up.
local last: { [string]: any } = {}

local function potionTotal(potions: { [string]: number }): number
	local total = 0
	for _, count in potions do
		total += count
	end
	return total
end

local function countKeys(t: { [string]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function snapshot(data: any): { [string]: any }
	local levels = {}
	for id, dragon in data.Dragons do
		levels[id] = dragon.Level
	end
	return {
		Levels = levels,
		MerchantPurchases = data.MerchantPurchases,
		Roost = data.RoostSlotUpgrades + data.RoostIncomeLevel,
		Armed = data.ArmedLuckPotion,
		Runes = data.WyrmRunes,
		Stones = data.Dragonstones,
		Potions = potionTotal(data.Potions),
		Stardust = data.Stardust,
		Index = countKeys(data.Index),
		Rebirths = data.Rebirths,
		SpireRecord = data.SpireRecord,
	}
end

local function compare()
	local data = DataController:Get()
	if data == nil then
		return
	end
	local now = snapshot(data)
	local before = last
	last = now
	if before.Levels == nil then
		return -- first snapshot
	end
	if now.Rebirths > before.Rebirths then
		FeedbackController.Fire("Rebirth")
		return
	end
	-- level-ups (an evolution is louder)
	local leveled, evolved = false, false
	for id, level in now.Levels do
		local old = before.Levels[id]
		if old and level > old then
			leveled = true
			if DragonStats.GetStage(level).Id ~= DragonStats.GetStage(old).Id then
				evolved = true
			end
		end
	end
	if evolved then
		FeedbackController.Fire("Evolve")
	elseif leveled then
		FeedbackController.Fire("LevelUp")
	end
	if now.Index > before.Index then
		FeedbackController.Fire("IndexEntry")
	elseif now.SpireRecord > before.SpireRecord then
		FeedbackController.Fire("NewRecord")
	elseif now.Roost > before.Roost then
		FeedbackController.Fire("RoostUpgrade")
	elseif now.MerchantPurchases > before.MerchantPurchases and before.MerchantPurchases >= 0 then
		FeedbackController.Fire("Buy")
	elseif now.Armed ~= before.Armed and now.Armed ~= "" then
		FeedbackController.Fire("Arm")
	elseif now.Runes > before.Runes or now.Stones > before.Stones or now.Potions > before.Potions
		or (now.Stardust > before.Stardust and now.MerchantPurchases == before.MerchantPurchases) then
		FeedbackController.Fire("Reward")
	end
end

function FeedbackController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "FeedbackFlash"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = UITheme.Layers.Notifications - 1
	flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BorderSizePixel = 0
	flash.BackgroundTransparency = 1
	flash.Visible = false
	flash.Active = false
	flash.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- camera shake, applied after the default camera
	RunService:BindToRenderStep("FeedbackShake", Enum.RenderPriority.Camera.Value + 2, function()
		local left = shakeUntil - os.clock()
		if left <= 0 then
			return
		end
		local strength = shakeAngle * (left / shakeSeconds)
		local t = os.clock() * 40
		local camera = workspace.CurrentCamera
		camera.CFrame *= CFrame.Angles(math.rad(math.noise(t, 1) * strength), math.rad(math.noise(t, 2) * strength), 0)
	end)

	task.spawn(function()
		local data = DataController:WaitForData()
		last = snapshot(data)
		for _, key in { "Dragons", "MerchantPurchases", "RoostSlotUpgrades", "RoostIncomeLevel", "ArmedLuckPotion", "WyrmRunes", "Dragonstones", "Potions", "Stardust", "Index", "Rebirths", "SpireRecord" } do
			DataController:OnChanged(key, compare)
		end
	end)

	-- Spire climb: a whoosh when a climb starts, a small sound per floor won
	local climbing = false
	local spireUpdate = ReplicatedStorage.Remotes:WaitForChild("SpireUpdate") :: RemoteEvent
	spireUpdate.OnClientEvent:Connect(function(update)
		if type(update) ~= "table" then
			return
		end
		if update.Phase == "Ended" then
			climbing = false
		elseif not climbing then
			climbing = true
			FeedbackController.Fire("ClimbStart")
		elseif update.Phase == "Won" then
			FeedbackController.Fire("FloorClear")
		end
	end)
end

return FeedbackController
