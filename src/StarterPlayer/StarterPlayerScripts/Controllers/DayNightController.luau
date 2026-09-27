--!strict
-- Drives the shared day/night cycle and shows a compact, animated celestial HUD card.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local NotificationController = require(script.Parent.NotificationController)
local HudLayout = require(script.Parent.HudLayout)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local Format = require(ReplicatedStorage.Shared.Format)
local Luck = require(ReplicatedStorage.Shared.Luck)
local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local DayNight = require(ReplicatedStorage.Shared.Config.DayNight)
local LuckConfig = require(ReplicatedStorage.Shared.Config.Luck)
local Elements = require(ReplicatedStorage.Shared.Config.Elements)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local Style = require(script.Parent.UI.Style)

local DayNightController = {}

local phaseLabel: TextLabel
local detailLabel: TextLabel
local iconLabel: TextLabel
local progressFill: Frame
local bar: Frame
local outline: UIStroke
local warnedNight: number? = nil
local lastPhase: boolean? = nil
local previousText = 0

local function duskWhere(constellation: { Element: string?, Luck: number }): string
	local favoredId = Luck.GetFavoredAreaId(constellation)
	local favored = if favoredId then Areas[favoredId] else nil
	return if favored then `It favors {favored.Name}!` else "Head to a Star Altar!"
end

local function favoredSummary(constellation: { Element: string?, Luck: number }): string
	local favoredId = Luck.GetFavoredAreaId(constellation)
	local favored = if favoredId then Areas[favoredId] else nil
	local everywhere = if constellation.Luck > 1 then `{Format.Multiplier(constellation.Luck)} luck at every altar` else nil
	local favoredText = if favored then `favors {favored.Name} ({Format.Multiplier(LuckConfig.FavoredAreaLuck)})` else nil
	return if everywhere and favoredText then `{everywhere} · {favoredText}` else everywhere or favoredText or "Visit a Star Altar"
end

local function formatTime(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

local function playPhaseTransition(isNight: boolean, color: Color3)
	local scale = bar:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 0.94
	outline.Color = color
	TweenService:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(outline, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Color = UITheme.Colors.Trim,
	}):Play()
	iconLabel.Rotation = if isNight then -20 else 20
	TweenService:Create(iconLabel, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
end

function DayNightController:Init()
	local gui = HudLayout.MakeScreenGui("SkyHud", "Hud")
	bar = Instance.new("Frame")
	bar.Name = "CelestialCycle"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.BackgroundColor3 = Color3.new(1, 1, 1)
	bar.BorderSizePixel = 0
	Style.Gradient(bar, UITheme.Colors.PanelTop, UITheme.Colors.PanelBottom)
	Style.Corner(bar, 18)
	outline = Style.Stroke(bar, UITheme.Colors.Trim, 2)
	bar.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = bar

	iconLabel = Style.Label(bar, "☼", "Heavy", 21, UITheme.Colors.Gold)
	iconLabel.Name = "CelestialIcon"
	iconLabel.AnchorPoint = Vector2.new(0, 0.5)
	iconLabel.Position = UDim2.new(0, 10, 0, 21)
	iconLabel.Size = UDim2.fromOffset(31, 31)
	Style.Round(iconLabel)
	iconLabel.BackgroundTransparency = 0
	iconLabel.BackgroundColor3 = UITheme.Colors.Card

	phaseLabel = Style.Label(bar, "Daylight · Night falls in 0:00", "Heavy", 16, UITheme.Colors.Text)
	phaseLabel.Name = "Phase"
	phaseLabel.Position = UDim2.fromOffset(50, 5)
	phaseLabel.Size = UDim2.new(1, -60, 0, 23)
	phaseLabel.TextXAlignment = Enum.TextXAlignment.Left
	phaseLabel.TextTruncate = Enum.TextTruncate.AtEnd
	phaseLabel.TextWrapped = false

	detailLabel = Style.Label(bar, "Calm skies · prepare for the next constellation", "Bold", 11, UITheme.Colors.TextMuted)
	detailLabel.Name = "CelestialDetail"
	detailLabel.Position = UDim2.fromOffset(50, 27)
	detailLabel.Size = UDim2.new(1, -60, 0, 16)
	detailLabel.TextXAlignment = Enum.TextXAlignment.Left
	detailLabel.TextTruncate = Enum.TextTruncate.AtEnd
	detailLabel.TextWrapped = false

	local rail = Instance.new("Frame")
	rail.Name = "CycleProgressRail"
	rail.Position = UDim2.new(0, 12, 1, -7)
	rail.Size = UDim2.new(1, -24, 0, 3)
	rail.BorderSizePixel = 0
	rail.BackgroundColor3 = UITheme.Colors.PanelInnerLine
	rail.Parent = bar
	Style.Round(rail)

	progressFill = Instance.new("Frame")
	progressFill.Name = "CycleProgress"
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.BorderSizePixel = 0
	progressFill.BackgroundColor3 = UITheme.Colors.Gold
	progressFill.Parent = rail
	Style.Round(progressFill)

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(440, 56)
	sizeLimit.Parent = bar
	HudLayout.OnLayoutChanged(function(isPhone)
		bar.Position = UDim2.new(0.5, 0, 0, if isPhone then UITheme.Sizes.PhoneMargin else 12)
		bar.Size = UDim2.new(0.9, 0, 0, if isPhone then 54 else 56)
		sizeLimit.MaxSize = if isPhone then Vector2.new(340, 54) else Vector2.new(440, 56)
		phaseLabel.TextSize = if isPhone then 14 else 16
		detailLabel.TextSize = if isPhone then 10 else 11
	end)
end

function DayNightController:Start()
	RunService.RenderStepped:Connect(function()
		local state = Cycle.GetState()
		Lighting.ClockTime = state.ClockTime
		if os.clock() - previousText < 0.2 then
			return
		end
		previousText = os.clock()

		local constellation = state.Constellation
		local element = if constellation.Element then Elements[constellation.Element] else nil
		local accent = if element then element.Color else UITheme.Colors.Gold
		if state.IsNight then
			phaseLabel.Text = `Nightfall · {constellation.Name}`
			detailLabel.Text = `{favoredSummary(constellation)} · {formatTime(state.SecondsLeft)} remaining`
			iconLabel.Text = "☾"
			iconLabel.TextColor3 = accent
			progressFill.BackgroundColor3 = accent
		else
			phaseLabel.Text = `Daylight · Night falls in {formatTime(state.SecondsLeft)}`
			detailLabel.Text = "The stars are resting · prepare for the next constellation"
			iconLabel.Text = "☼"
			iconLabel.TextColor3 = UITheme.Colors.Gold
			progressFill.BackgroundColor3 = UITheme.Colors.Gold
		end

		local duration = if state.IsNight then DayNight.NightSeconds else DayNight.DaySeconds
		local progress = math.clamp(1 - state.SecondsLeft / duration, 0, 1)
		progressFill.Size = UDim2.new(progress, 0, 1, 0)

		if lastPhase ~= nil and lastPhase ~= state.IsNight then
			playPhaseTransition(state.IsNight, accent)
		end
		lastPhase = state.IsNight

		if not state.IsNight and state.SecondsLeft <= DayNight.DuskWarningSeconds and warnedNight ~= state.NightIndex then
			warnedNight = state.NightIndex
			NotificationController:Show(
				`Night falls in {DayNight.DuskWarningSeconds}s: {constellation.Name} rises. {duskWhere(constellation)}`,
				Color3.fromRGB(170, 220, 255)
			)
		end
	end)
end

return DayNightController
