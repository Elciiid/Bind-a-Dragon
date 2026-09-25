--!strict
-- Drives the local sky from the shared cycle: Lighting.ClockTime, a night tint in tonight's element color,
-- and a small HUD label with the phase, constellation and time left. Warns DuskWarningSeconds before night.
-- Placeholder UI.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NotificationController = require(script.Parent.NotificationController)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local DayNight = require(ReplicatedStorage.Shared.Config.DayNight)
local Elements = require(ReplicatedStorage.Shared.Config.Elements)

local NIGHT_TINT = 0.35 -- how strongly tonight's element colors the ambient light
local RARE_NIGHT_TINT = 0.6

local DayNightController = {}

local label: TextLabel
local warnedNight: number? = nil -- NightIndex the dusk warning was last shown for
local baseAmbient: Color3
local baseOutdoorAmbient: Color3

local function formatTime(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

function DayNightController:Init()
	baseAmbient = Lighting.Ambient
	baseOutdoorAmbient = Lighting.OutdoorAmbient

	local gui = Instance.new("ScreenGui")
	gui.Name = "SkyHud"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 12)
	label.Size = UDim2.new(0.9, 0, 0, 44)
	label.BackgroundColor3 = Color3.fromRGB(15, 15, 30)
	label.BackgroundTransparency = 0.35
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui
	Instance.new("UICorner").Parent = label
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(440, 44)
	sizeLimit.Parent = label
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = label
end

function DayNightController:Start()
	RunService.RenderStepped:Connect(function()
		local state = Cycle.GetState()
		local constellation = state.Constellation
		Lighting.ClockTime = state.ClockTime

		local element = if constellation.Element then Elements[constellation.Element] else nil
		local tintColor = if element then element.Color else Color3.new(1, 1, 1)
		local tint = if not state.IsNight then 0 elseif constellation.Rare then RARE_NIGHT_TINT else NIGHT_TINT
		Lighting.Ambient = baseAmbient:Lerp(tintColor, tint)
		Lighting.OutdoorAmbient = baseOutdoorAmbient:Lerp(tintColor, tint)

		if state.IsNight then
			label.Text = `{constellation.Name}  ·  Bind at the Star Altar  ·  {formatTime(state.SecondsLeft)}`
			label.TextColor3 = if element then element.Color else Color3.fromRGB(255, 220, 120)
		else
			label.Text = `Day  ·  Night falls in {formatTime(state.SecondsLeft)}`
			label.TextColor3 = Color3.new(1, 1, 1)
			-- Dusk warning, once per cycle, so players can walk to the altar in time.
			if state.SecondsLeft <= DayNight.DuskWarningSeconds and warnedNight ~= state.NightIndex then
				warnedNight = state.NightIndex
				NotificationController:Show(
					`Night falls in {DayNight.DuskWarningSeconds}s: {constellation.Name} rises. Head to a Star Altar!`,
					Color3.fromRGB(170, 220, 255)
				)
			end
		end
	end)
end

return DayNightController
