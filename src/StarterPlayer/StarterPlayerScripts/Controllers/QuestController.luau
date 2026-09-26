--!strict
-- Quests window: the "Quests" menu tile opens the login streak (a 7-day strip with reward icons), today's daily
-- quests and this week's weekly quests (progress bars, reward icons, time until reset). Rewards are granted by the
-- server when a quest completes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local ProgressBar = require(script.Parent.UI.ProgressBar)
local RewardRow = require(script.Parent.UI.RewardRow)
local Window = require(script.Parent.UI.Window)
local Format = require(ReplicatedStorage.Shared.Format)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local QuestConfig = require(ReplicatedStorage.Shared.Config.Quests)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

local QuestController = {}

local window: Window.Window
local list: ScrollingFrame
local resetLabels: { daily: TextLabel?, weekly: TextLabel? } = {}

local questById: { [string]: QuestConfig.Quest } = {}
for _, quest in QuestConfig.DailyPool do
	questById[quest.Id] = quest
end
for _, quest in QuestConfig.WeeklyPool do
	questById[quest.Id] = quest
end

local function formatDuration(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	if s >= 86400 then
		return `{s // 86400}d {(s % 86400) // 3600}h`
	end
	return `{s // 3600}h {(s % 3600) // 60}m`
end

-- Seconds until the next UTC midnight / next Monday 00:00 UTC (same rollover as QuestService).
local function untilDailyReset(): number
	return 86400 - os.time() % 86400
end

local function untilWeeklyReset(): number
	local day = os.time() // 86400
	local daysIntoWeek = (day + 3) % 7
	return (7 - daysIntoWeek) * 86400 - os.time() % 86400
end

local function updateResetTimers()
	if resetLabels.daily then
		resetLabels.daily.Text = `Daily quests · new in {formatDuration(untilDailyReset())}`
	end
	if resetLabels.weekly then
		resetLabels.weekly.Text = `Weekly quests · new in {formatDuration(untilWeeklyReset())}`
	end
end

local function sectionTitle(order: number): TextLabel
	local label = Style.Label(list, "", "Title", 18, UITheme.Colors.Title)
	label.LayoutOrder = order
	label.Size = UDim2.new(1, -8, 0, 26)
	label.TextXAlignment = Enum.TextXAlignment.Left
	return label
end

-- The login streak: 7 day cards, claimed days checked, today highlighted.
local function addStreak(data: PlayerDataTypes.PlayerData)
	local theme = UITheme
	local days = #QuestConfig.StreakRewards
	local title = sectionTitle(-2)
	title.Text = `Login streak · day {data.LoginStreak}/{days}`

	local strip = Instance.new("Frame")
	strip.LayoutOrder = -1
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.new(1, -8, 0, 62)
	strip.Parent = list
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = strip
	for day = 1, days do
		local claimed = day <= data.LoginStreak
		local today = day == data.LoginStreak
		local card = Instance.new("Frame")
		card.LayoutOrder = day
		card.Size = UDim2.new(1 / days, -5, 1, 0)
		Style.CardLook(card)
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if today then theme.Colors.Title elseif claimed then theme.Colors.Positive else theme.Colors.PanelInnerLine
			stroke.Thickness = if today then 3 else 2
		end
		card.Parent = strip
		local label = Style.Label(card, if claimed then `✓ Day {day}` else `Day {day}`, "Heavy", 12, if claimed then theme.Colors.Positive else theme.Colors.TextMuted)
		label.Size = UDim2.new(1, 0, 0, 18)
		local rewards = RewardRow.new(card, QuestConfig.StreakRewards[day], 18) -- small: day 3 and 6 show two items
		rewards.AnchorPoint = Vector2.new(0.5, 0)
		rewards.Position = UDim2.new(0.5, 0, 0, 22)
	end
end

local function addQuest(order: number, state: PlayerDataTypes.QuestState, reward: Rewards.Reward?)
	local theme = UITheme
	local quest = questById[state.Id]
	local card = Instance.new("Frame")
	card.LayoutOrder = order
	card.Size = UDim2.new(1, -8, 0, 66)
	Style.CardLook(card, if state.Done then theme.Colors.Positive else theme.Colors.Primary)
	card.Parent = list

	local text = if quest then quest.Text:gsub("{n}", Format.Number(state.Target)) else state.Id
	local title = Style.Label(card, if state.Done then `✓ {text}` else text, "Heavy", 17, if state.Done then theme.Colors.Positive else theme.Colors.Text)
	title.Position = UDim2.fromOffset(16, 6)
	title.Size = UDim2.new(0.6, -16, 0, 22)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.TextWrapped = false

	if reward then
		local rewards = RewardRow.new(card, reward, 24)
		rewards.AnchorPoint = Vector2.new(1, 0)
		rewards.Position = UDim2.new(1, -10, 0, 5)
	end

	local bar = ProgressBar.new(card, if state.Done then theme.Colors.Positive else theme.Colors.Primary)
	bar.Instance.Position = UDim2.fromOffset(16, 36)
	bar.Instance.Size = UDim2.new(1, -28, 0, 20)
	bar:Set(state.Progress / math.max(state.Target, 1), `{Format.Number(state.Progress)} / {Format.Number(state.Target)}`)
end

local function redraw()
	local data = DataController:Get()
	if data == nil then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	addStreak(data)
	resetLabels.daily = sectionTitle(0)
	for slot, state in data.DailyQuests do
		addQuest(slot, state, QuestConfig.DailyRewards[slot])
	end
	resetLabels.weekly = sectionTitle(100)
	for slot, state in data.WeeklyQuests do
		addQuest(100 + slot, state, QuestConfig.WeeklyRewards[slot])
	end
	updateResetTimers()
end

function QuestController:Init()
	local open = HudLayout.AddMenuButton("Quests")
	window = Window.new({
		Name = "Quests",
		Title = "Quests",
		Icon = "Menu_Quests",
		Size = UDim2.new(0.92, 0, 0.8, 0),
		MaxSize = Vector2.new(600, 560),
	})

	list = Instance.new("ScrollingFrame")
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = UITheme.Colors.Trim
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = window.Content
	Style.Pad(list, 2, 3)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	open.Activated:Connect(function()
		window:Toggle()
	end)
	window:OnOpen(redraw)
	for _, key in { "DailyQuests", "WeeklyQuests", "LoginStreak" } do
		DataController:OnChanged(key, function()
			if window.IsOpen then
				redraw()
			end
		end)
	end
end

function QuestController:Start()
	while true do
		if window.IsOpen then
			updateResetTimers()
		end
		task.wait(1)
	end
end

return QuestController
