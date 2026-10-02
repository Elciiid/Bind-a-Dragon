--!strict
-- Drives the local sky from the shared cycle (Lighting.ClockTime) and shows the day/night pill (UI/SkyPill) under the
-- travel buttons with a gap (HudLayout.SkyPillTop): a big sun / moon, "Night in 3:31" big, at night a small second
-- line (tonight's constellation + the favored area) and a thin progress bar; it pops when night falls or day breaks
-- and glows/pulses in the last DuskWarningSeconds before night (when the dusk warning toast shows). Wording in
-- Config/Text (SkyHud Big*/Small*). Lighting looks (incl. the night tint) are AtmosphereController.

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
local Elements = require(ReplicatedStorage.Shared.Config.Elements)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local SkyPill = require(script.Parent.UI.SkyPill)

local TEXT_INTERVAL = 0.2 -- seconds between text/progress updates (the clock itself updates every frame)

local words = Text.SkyHud

local DayNightController = {}

local pill: SkyPill.SkyPill
local warnedNight: number? = nil -- NightIndex the dusk warning was last shown for
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

function DayNightController:Init()
	local gui = HudLayout.MakeScreenGui("SkyHud", "Hud")
	HudLayout.HideWithPopups(gui)
	pill = SkyPill.new(gui)
	HudLayout.OnLayoutChanged(function(isPhone)
		pill.Instance.Position = UDim2.new(0.5, 0, 0, HudLayout.SkyPillTop())
		pill:Layout(isPhone)
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
		local small = ""
		if state.IsNight then
			local area = favoredArea(constellation)
			local extra = if area then Text.Format(words.SmallFavors, { area = area })
				elseif constellation.Luck > 1 then Text.Format(words.SmallEverywhere, { luck = Format.Multiplier(constellation.Luck) })
				else ""
			small = Text.Format(words.SmallNight, { constellation = constellation.Name, extra = extra })
		end
		local length = if state.IsNight then DayNight.NightSeconds else DayNight.DaySeconds
		pill:Set({
			Night = state.IsNight,
			Big = Text.Format(if state.IsNight then words.BigNight else words.BigDay, { time = time }),
			Small = small,
			Progress = 1 - state.SecondsLeft / length,
			Accent = accent,
			Dusk = not state.IsNight and state.SecondsLeft <= DayNight.DuskWarningSeconds,
		})

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
