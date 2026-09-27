--!strict
-- Drives the local sky from the shared cycle (Lighting.ClockTime) and shows the day/night card at the top of the
-- screen: sun/moon icon, the phase and time left, tonight's constellation and where it gives luck, and a progress
-- bar through the phase; the card pops when night falls or day breaks. Warns DuskWarningSeconds before night.
-- Wording in Config/Text (SkyHud), sizes in UITheme.Sizes (SkyCard / PhoneSkyCard). Lighting looks (incl. the night
-- tint) are AtmosphereController. Card design by Kyle (Hakai branch).

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
local Text = require(ReplicatedStorage.Shared.Config.Text)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local Style = require(script.Parent.UI.Style)

local TEXT_INTERVAL = 0.2 -- seconds between text/progress updates (the clock itself updates every frame)

local words = Text.SkyHud

local DayNightController = {}

local card: Frame
local scale: UIScale
local outline: UIStroke
local icon: TextLabel
local title: TextLabel
local detail: TextLabel
local fill: Frame
local warnedNight: number? = nil -- NightIndex the dusk warning was last shown for
local lastIsNight: boolean? = nil
local lastText = -math.huge

type Constellation = { Name: string, Element: string?, Luck: number }

local function formatTime(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

local function favoredArea(constellation: Constellation): string?
	local favoredId = Luck.GetFavoredAreaId(constellation)
	local favored = if favoredId then Areas[favoredId] else nil
	return if favored then favored.Name else nil
end

-- "x1.5 luck at every altar · favors Storm Canyon (x1.5)", whichever parts apply.
local function whereText(constellation: Constellation): string
	local area = favoredArea(constellation)
	local everywhere = if constellation.Luck > 1
		then Text.Format(words.LuckEverywhere, { luck = Format.Multiplier(constellation.Luck) })
		else nil
	local favors = if area then Text.Format(words.Favors, { area = area, luck = Format.Multiplier(LuckConfig.FavoredAreaLuck) }) else nil
	return if everywhere and favors then `{everywhere} · {favors}` else everywhere or favors or words.NoBonus
end

local function playPhaseChange(isNight: boolean, color: Color3)
	local seconds = UITheme.Motion.SkyPhaseChange
	scale.Scale = 0.94
	TweenService:Create(scale, TweenInfo.new(seconds * 0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	outline.Color = color
	TweenService:Create(outline, TweenInfo.new(seconds, Enum.EasingStyle.Sine), { Color = UITheme.Colors.Trim }):Play()
	icon.Rotation = if isNight then -20 else 20
	TweenService:Create(icon, TweenInfo.new(seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
end

function DayNightController:Init()
	local gui = HudLayout.MakeScreenGui("SkyHud", "Hud")
	local colors = UITheme.Colors

	card = Instance.new("Frame")
	card.Name = "SkyCard"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.BorderSizePixel = 0
	card.Parent = gui
	Style.Gradient(card, colors.PanelTop, colors.PanelBottom)
	Style.Corner(card, UITheme.Corner + 6)
	outline = Style.Stroke(card, colors.Trim, 2)
	scale = Instance.new("UIScale")
	scale.Parent = card
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.Parent = card

	icon = Style.Label(card, words.DayIcon, "Heavy", 21, colors.Gold)
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.BackgroundTransparency = 0
	icon.BackgroundColor3 = colors.Card
	Style.Round(icon)

	title = Style.Label(card, "", "Heavy", 16, colors.Text)
	title.Name = "Phase"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.TextWrapped = false

	detail = Style.Label(card, "", "Bold", 11, colors.TextMuted)
	detail.Name = "Detail"
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextTruncate = Enum.TextTruncate.AtEnd
	detail.TextWrapped = false

	local rail = Instance.new("Frame")
	rail.Name = "ProgressRail"
	rail.AnchorPoint = Vector2.new(0.5, 1)
	rail.Position = UDim2.new(0.5, 0, 1, -5)
	rail.Size = UDim2.new(1, -24, 0, 3)
	rail.BorderSizePixel = 0
	rail.BackgroundColor3 = colors.PanelInnerLine
	rail.Parent = card
	Style.Round(rail)

	fill = Instance.new("Frame")
	fill.Name = "Progress"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = colors.Gold
	fill.Parent = rail
	Style.Round(fill)

	HudLayout.OnLayoutChanged(function(isPhone)
		local sizes = UITheme.Sizes
		local max = if isPhone then sizes.PhoneSkyCard else sizes.SkyCard
		card.Position = UDim2.new(0.5, 0, 0, if isPhone then sizes.PhoneMargin else 12)
		card.Size = UDim2.new(0.9, 0, 0, max.Y)
		sizeLimit.MaxSize = max
		local iconSize = if isPhone then 26 else 31
		local left = iconSize + 18
		icon.Size = UDim2.fromOffset(iconSize, iconSize)
		icon.Position = UDim2.new(0, 10, 0.5, -2)
		icon.TextSize = if isPhone then 17 else 21
		title.TextSize = if isPhone then 13 else 16
		detail.TextSize = if isPhone then 10 else 11
		title.Position = UDim2.fromOffset(left, if isPhone then 4 else 5)
		title.Size = UDim2.new(1, -(left + 10), 0, if isPhone then 18 else 22)
		detail.Position = UDim2.fromOffset(left, if isPhone then 22 else 27)
		detail.Size = UDim2.new(1, -(left + 10), 0, 14)
	end)
end

function DayNightController:Start()
	RunService.RenderStepped:Connect(function()
		local state = Cycle.GetState()
		Lighting.ClockTime = state.ClockTime
		if os.clock() - lastText < TEXT_INTERVAL then
			return
		end
		lastText = os.clock()

		local constellation = state.Constellation
		local element = if constellation.Element then Elements[constellation.Element] else nil
		local accent = if state.IsNight and element then element.Color else UITheme.Colors.Gold
		local time = formatTime(state.SecondsLeft)
		if state.IsNight then
			title.Text = Text.Format(words.NightTitle, { constellation = constellation.Name })
			detail.Text = Text.Format(words.NightDetail, { where = whereText(constellation), time = time })
			icon.Text = words.NightIcon
		else
			title.Text = Text.Format(words.DayTitle, { time = time })
			detail.Text = words.DayDetail
			icon.Text = words.DayIcon
		end
		icon.TextColor3 = accent
		fill.BackgroundColor3 = accent
		local length = if state.IsNight then DayNight.NightSeconds else DayNight.DaySeconds
		fill.Size = UDim2.fromScale(math.clamp(1 - state.SecondsLeft / length, 0, 1), 1)

		if lastIsNight ~= nil and lastIsNight ~= state.IsNight then
			playPhaseChange(state.IsNight, accent)
		end
		lastIsNight = state.IsNight

		-- Dusk warning, once per cycle, so players can walk to the altar in time.
		if not state.IsNight and state.SecondsLeft <= DayNight.DuskWarningSeconds and warnedNight ~= state.NightIndex then
			warnedNight = state.NightIndex
			local area = favoredArea(constellation)
			NotificationController:Show(
				Text.Format(words.DuskWarning, {
					seconds = DayNight.DuskWarningSeconds,
					constellation = constellation.Name,
					where = if area then Text.Format(words.DuskFavors, { area = area }) else words.DuskNoFavor,
				}),
				UITheme.Colors.Info
			)
		end
	end)
end

return DayNightController
