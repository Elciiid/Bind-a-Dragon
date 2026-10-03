--!strict
-- Presentation only: cover grants/data-sync spoilers until the ceremony's reveal point.
-- Rewards are already owned on the server; no client acknowledgement changes gameplay.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Ceremony = require(ReplicatedStorage.Shared.Config.Ceremony)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local Theme = require(ReplicatedStorage.Shared.Config.UITheme)
local Style = require(script.Parent.Style)
local EffectsQuality = require(script.Parent.Parent.EffectsQuality)

local Gate = {}
local active = false
local cover: ScreenGui? = nil
local saved: { [ScreenGui]: boolean } = {}
local watching: { RBXScriptConnection } = {}
local deferred: { () -> () } = {}
local announced: { [string]: () -> () } = {}
local revealed: { [string]: boolean } = {}
local animations: { Tween } = {}

local function run(callback: () -> ())
	local ok, err = pcall(callback)
	if not ok then warn(`[RevealGate] Deferred display failed: {err}`) end
end

function Gate.AfterDragon(id: string, callback: () -> ())
	if revealed[id] then Gate.Defer(callback) else announced[id] = callback end
end

function Gate.ReleaseDragon(id: string)
	revealed[id] = true
	local callback = announced[id]
	announced[id] = nil
	if callback then Gate.Defer(callback) end
end

function Gate.IsActive(): boolean
	return active
end

function Gate.Defer(callback: () -> ())
	if active then table.insert(deferred, callback) else run(callback) end
end

function Gate.Begin()
	if cover then return end
	local alreadyActive = active
	active = true
	Players.LocalPlayer:SetAttribute("BindRevealActive", true)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local function mask(child: Instance)
		if not child:IsA("ScreenGui") or child:GetAttribute("RevealLayer") == true then return end
		local screen = child :: ScreenGui
		saved[screen] = screen.Enabled
		screen.Enabled = false
		table.insert(watching, screen:GetPropertyChangedSignal("Enabled"):Connect(function()
			if active and screen.Enabled then screen.Enabled = false end
		end))
	end
	if not alreadyActive then
		for _, child in playerGui:GetChildren() do mask(child) end
		table.insert(watching, playerGui.ChildAdded:Connect(mask))
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "BindingCover"
	screen:SetAttribute("RevealLayer", true)
	screen.ScreenInsets = Enum.ScreenInsets.None
	screen.DisplayOrder = Theme.Layers.Notifications + 4
	screen.ResetOnSpawn = false
	screen.Parent = playerGui
	cover = screen
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Theme.Colors.PanelBottom
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.Parent = screen
	local label = Style.Label(frame, Text.Reveal.Waiting, "Title", Theme.TextSizes.Title, Theme.Colors.Gold)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.6)
	label.Size = UDim2.fromScale(0.8, 0.1)
	label.TextWrapped = true
	local reduced = Players.LocalPlayer:GetAttribute("ReducedMotion") == true or EffectsQuality.IsLow()
	for index = 1, Ceremony.WaitingStars do
		local star = Instance.new("ImageLabel")
		star.BackgroundTransparency = 1
		star.Image = Ceremony.Burst.SparkleImage
		star.ImageColor3 = Theme.Colors.Gold
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Size = UDim2.fromOffset(Ceremony.WaitingStarSize, Ceremony.WaitingStarSize)
		local angle = index / Ceremony.WaitingStars * math.pi * 2
		star.Position = UDim2.new(0.5, math.cos(angle) * Ceremony.WaitingRadius, 0.4, math.sin(angle) * Ceremony.WaitingRadius / 2)
		star.Parent = frame
		if not reduced then
			local tween = TweenService:Create(star, TweenInfo.new(Ceremony.WaitingStarSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { ImageTransparency = 0.7 })
			table.insert(animations, tween)
			tween:Play()
		end
	end
end

function Gate.Reveal()
	-- The dragon is now visibly revealed; underlying UI stays masked until cleanup.
	for _, tween in animations do tween:Cancel() end
	table.clear(animations)
	if cover then cover:Destroy(); cover = nil end
end

function Gate.Finish()
	Gate.Reveal()
	active = false
	Players.LocalPlayer:SetAttribute("BindRevealActive", false)
	for _, connection in watching do connection:Disconnect() end
	table.clear(watching)
	for screen, enabled in saved do
		if screen.Parent then screen.Enabled = enabled end
	end
	table.clear(saved)
	local callbacks = deferred
	deferred = {}
	for _, callback in callbacks do run(callback) end
end

-- A refusal/timeout is presentation cancellation, not a gameplay rollback. Release held announcements too;
-- they may already describe a confirmed server grant even if a separate result packet never reached this client.
function Gate.Cancel()
	for id, callback in announced do
		revealed[id] = true
		table.insert(deferred, callback)
	end
	table.clear(announced)
	Gate.Finish()
end

return Gate
