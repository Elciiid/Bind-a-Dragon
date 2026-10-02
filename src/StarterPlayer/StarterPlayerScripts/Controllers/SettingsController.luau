--!strict
-- Settings window (UI kit): music volume, sound volume, "Low effects" and "Quick binds". Saved in player data
-- (SettingsService) so they follow the player; applied right away as LocalPlayer attributes that the effect
-- controllers read (MusicVolume, SoundVolume, LowEffects, QuickBinds). Saves are debounced while dragging.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Window = require(script.Parent.UI.Window)
local DataConfig = require(ReplicatedStorage.Shared.Config.Data)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local Text = require(ReplicatedStorage.Shared.Config.Text)

local saveSettings = ReplicatedStorage.Remotes.SaveSettings :: RemoteEvent

local SAVE_DELAY = 0.6 -- seconds after the last change before saving

type Settings = { MusicVolume: number, SoundVolume: number, LowEffects: boolean, QuickBinds: boolean, ReducedMotion: boolean }

local SettingsController = {}

local player = Players.LocalPlayer
local current: Settings = {
	MusicVolume = DataConfig.DefaultSettings.MusicVolume,
	SoundVolume = DataConfig.DefaultSettings.SoundVolume,
	LowEffects = DataConfig.DefaultSettings.LowEffects,
	QuickBinds = DataConfig.DefaultSettings.QuickBinds,
	ReducedMotion = DataConfig.DefaultSettings.ReducedMotion,
}
local saveToken = 0
local refreshers: { () -> () } = {}

local function apply()
	player:SetAttribute("MusicVolume", current.MusicVolume)
	player:SetAttribute("SoundVolume", current.SoundVolume)
	player:SetAttribute("LowEffects", current.LowEffects)
	player:SetAttribute("QuickBinds", current.QuickBinds)
	player:SetAttribute("ReducedMotion", current.ReducedMotion)
	for _, fn in refreshers do
		fn()
	end
end

local function changed()
	apply()
	saveToken += 1
	local token = saveToken
	task.delay(SAVE_DELAY, function()
		if token == saveToken then
			saveSettings:FireServer(current)
		end
	end)
end

local function row(parent: Instance, order: number, title: string, hint: string): Frame
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -8, 0, 64)
	Style.CardLook(frame)
	frame.Parent = parent
	local label = Style.Label(frame, title, "Title", 20)
	label.Position = UDim2.fromOffset(14, 6)
	label.Size = UDim2.new(0.5, -14, 0, 24)
	label.TextXAlignment = Enum.TextXAlignment.Left
	Style.Outline(label, 1.5)
	local sub = Style.Label(frame, hint, "Body", UITheme.TextSizes.Small, UITheme.Colors.TextMuted)
	sub.Position = UDim2.fromOffset(14, 32)
	sub.Size = UDim2.new(0.5, -14, 0, 24)
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextWrapped = true
	return frame
end

local function slider(parent: Frame, get: () -> number, set: (number) -> ())
	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.new(1, -70, 0.5, 0)
	track.Size = UDim2.new(0.42, -40, 0, 10)
	track.BackgroundColor3 = UITheme.Colors.PanelInnerLine
	Style.Round(track)
	track.Parent = parent
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	Style.Gradient(fill, UITheme.Colors.Trim, UITheme.Colors.TrimDark)
	Style.Round(fill)
	fill.Parent = track
	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(22, 22)
	knob.BackgroundColor3 = UITheme.Colors.Gold
	Style.Round(knob)
	Style.Stroke(knob, UITheme.Colors.TextStroke, 2)
	knob.ZIndex = 3
	knob.Parent = track
	local percent = Style.Label(parent, "", "Heavy", 16, UITheme.Colors.Gold)
	percent.AnchorPoint = Vector2.new(1, 0.5)
	percent.Position = UDim2.new(1, -12, 0.5, 0)
	percent.Size = UDim2.fromOffset(52, 24)
	local hit = Instance.new("TextButton")
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.new(1, 20, 0, 40)
	hit.Position = UDim2.fromOffset(-10, -15)
	hit.ZIndex = 4
	hit.Parent = track

	local function draw()
		local value = get()
		fill.Size = UDim2.fromScale(value, 1)
		knob.Position = UDim2.fromScale(value, 0.5)
		percent.Text = `{math.round(value * 100)}%`
	end
	local dragging = false
	local function fromInput(x: number)
		local value = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		set(math.round(value * 20) / 20) -- steps of 5%
		draw()
	end
	hit.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging = true
			fromInput(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		local t = input.UserInputType
		if dragging and (t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch) then
			fromInput(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	table.insert(refreshers, draw)
	draw()
end

-- A switch: a jewel pill (jade when on, dusk blue when off) with a gold knob that slides across.
local function toggle(parent: Frame, get: () -> boolean, set: (boolean) -> ())
	local colors = UITheme.Colors
	local switch = Instance.new("TextButton")
	switch.Name = "Switch"
	switch.Text = ""
	switch.AutoButtonColor = false
	switch.AnchorPoint = Vector2.new(1, 0.5)
	switch.Position = UDim2.new(1, -12, 0.5, 0)
	switch.Size = UDim2.fromOffset(92, 40)
	switch.BackgroundColor3 = Color3.new(1, 1, 1)
	Style.Round(switch)
	Style.GoldBorder(switch, 2.5)
	local gradient = Style.Gradient(switch, colors.Neutral, colors.Neutral)
	switch.Parent = parent
	local word = Style.Label(switch, "", "Title", 16)
	word.Size = UDim2.new(0.6, 0, 1, 0)
	word.ZIndex = 2
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(30, 30)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.ZIndex = 3
	Style.Gradient(knob, colors.TrimLight, colors.TrimDark)
	Style.Round(knob)
	Style.Stroke(knob, colors.TextStroke, 1.5)
	knob.Parent = switch
	Style.AttachPress(switch)
	switch.Activated:Connect(function()
		set(not get())
	end)
	local function draw()
		local on = get()
		local base = if on then colors.Confirm else colors.Neutral
		gradient.Color = ColorSequence.new(Style.Shade(base, 0.16), Style.Shade(base, -0.2))
		word.Text = if on then "ON" else "OFF"
		word.Position = if on then UDim2.fromScale(0.04, 0) else UDim2.fromScale(0.38, 0)
		TweenService:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Back), {
			Position = if on then UDim2.new(1, -20, 0.5, 0) else UDim2.new(0, 20, 0.5, 0),
		}):Play()
	end
	table.insert(refreshers, draw)
	draw()
end

function SettingsController:Init()
	-- the gear sits right after Roblox's own top-bar buttons
	local open = HudLayout.AddTopbarButton("Settings", UITheme.Icons.Settings, 1)
	local window = Window.new({
		Name = "Settings",
		Title = "Settings",
		Icon = "Settings",
		Size = UDim2.new(0.9, 0, 0.7, 0),
		MaxSize = Vector2.new(520, 380),
	})
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = UITheme.Colors.Trim
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = window.Content
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	Style.Pad(list, 2, 3)

	slider(row(list, 1, "Music", "Day and night music"), function()
		return current.MusicVolume
	end, function(value)
		current.MusicVolume = value
		changed()
	end)
	slider(row(list, 2, "Sound", "Effects, ambience and UI sounds"), function()
		return current.SoundVolume
	end, function(value)
		current.SoundVolume = value
		changed()
	end)
	toggle(row(list, 3, "Low effects", "Fewer lights and particles, no shake or blur"), function()
		return current.LowEffects
	end, function(value)
		current.LowEffects = value
		changed()
	end)
	toggle(row(list, 4, "Quick binds", Text.Reveal.QuickHint), function()
		return current.QuickBinds
	end, function(value)
		current.QuickBinds = value
		changed()
	end)
	toggle(row(list, 5, Text.Reveal.ReducedMotion, Text.Reveal.ReducedMotionHint), function()
		return current.ReducedMotion
	end, function(value)
		current.ReducedMotion = value
		changed()
	end)

	open.Activated:Connect(function()
		window:Toggle()
	end)
end

function SettingsController:Start()
	local data = DataController:WaitForData()
	local saved = (data :: any).Settings
	if type(saved) == "table" then
		for key, value in saved do
			if type((current :: any)[key]) == type(value) then
				(current :: any)[key] = value
			end
		end
	end
	apply()
end

return SettingsController
