--!strict
-- Drives the local sky from the shared cycle (Lighting.ClockTime) and shows the day/night timer: the top row of the
-- bottom-right timer stack (HudLayout.GetTimerStack, above the potion timers), same style as them (UI/TimerRow: the sun /
-- moon icon + bold italic white text with a dark outline, no background): "Night in 1m 42s" by day, "Day in 2m 10s" at
-- night. It turns gold in the last DuskWarningSeconds before night (when the dusk warning toast shows). Under it a small
-- caption shows tonight's constellation and the favored area ("The Veiled Eye · favors Eclipse Isles"). Wording in Config/Text (SkyHud Big*/Small*). Lighting looks
-- (incl. the night tint) are AtmosphereController.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NotificationController = require(script.Parent.NotificationController)
local HudLayout = require(script.Parent.HudLayout)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local Format = require(ReplicatedStorage.Shared.Format)
local Luck = require(ReplicatedStorage.Shared.Luck)
local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local DayNight = require(ReplicatedStorage.Shared.Config.DayNight)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local TimerRow = require(script.Parent.UI.TimerRow)

local TEXT_INTERVAL = 0.2 -- seconds between text/progress updates (the clock itself updates every frame)

local words = Text.SkyHud

local DayNightController = {}

local row: TimerRow.TimerRow
local caption: TimerRow.Caption -- the small line under the timer: tonight's constellation + the favored area
local warnedNight: number? = nil -- NightIndex the dusk warning was last shown for
local lastText = -math.huge

type Constellation = { Name: string, Element: string?, Luck: number }

-- "1m 42s" (under a minute: "42s")
local function formatTime(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return if s >= 60 then string.format("%dm %ds", s // 60, s % 60) else string.format("%ds", s)
end

local function favoredArea(constellation: Constellation): string?
	local favoredId = Luck.GetFavoredAreaId(constellation)
	local favored = if favoredId then Areas[favoredId] else nil
	return if favored then favored.Name else nil
end

function DayNightController:Init()
	row = TimerRow.new(HudLayout.GetTimerStack(), {
		Name = "DayNight",
		Order = 0,
		Icons = { "Sky_Sun", "Sky_Moon" },
		Color = UITheme.Colors.Gold,
		Label = "S",
	})
	caption = TimerRow.NewCaption(HudLayout.GetTimerStack(), 1)
	HudLayout.OnLayoutChanged(function(isPhone)
		row:Layout(isPhone)
		caption:Layout(isPhone)
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
		local dusk = not state.IsNight and state.SecondsLeft <= DayNight.DuskWarningSeconds
		row:ShowIcon(if state.IsNight then 2 else 1)
		row:SetText(Text.Format(if state.IsNight then words.BigNight else words.BigDay, { time = formatTime(state.SecondsLeft) }))
		row:SetColor(if dusk then UITheme.Colors.Gold else Color3.new(1, 1, 1))
		local area = favoredArea(constellation)
		local extra = if area then Text.Format(words.SmallFavors, { area = area })
			elseif constellation.Luck > 1 then Text.Format(words.SmallEverywhere, { luck = Format.Multiplier(constellation.Luck) })
			else ""
		caption:SetText(Text.Format(if state.IsNight then words.SmallNight else words.SmallDay, { constellation = constellation.Name, extra = extra }))

		-- Dusk warning, once per cycle, so players can walk to the altar in time.
		if not state.IsNight and state.SecondsLeft <= DayNight.DuskWarningSeconds and warnedNight ~= state.NightIndex then
			warnedNight = state.NightIndex
			local warnArea = favoredArea(constellation)
			NotificationController:Show(
				Text.Format(words.DuskWarning, {
					seconds = DayNight.DuskWarningSeconds,
					constellation = constellation.Name,
					where = if warnArea then Text.Format(words.DuskFavors, { area = warnArea }) else words.DuskNoFavor,
				}),
				UITheme.Colors.Info
			)
		end
	end)
end

return DayNightController
