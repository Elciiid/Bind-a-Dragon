--!strict
-- Quests panel: a "Quests" button opens today's daily quests and this week's weekly quests (progress bars, rewards,
-- time until reset) and the login streak. Rewards are granted by the server when a quest completes. Placeholder UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local Format = require(ReplicatedStorage.Shared.Format)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local QuestConfig = require(ReplicatedStorage.Shared.Config.Quests)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

local DARK = Color3.fromRGB(15, 15, 30)
local CARD = Color3.fromRGB(32, 32, 55)
local GOLD = Color3.fromRGB(255, 210, 70)
local GREEN = Color3.fromRGB(130, 230, 140)
local QUEST_COLOR = Color3.fromRGB(130, 230, 140)

local QuestController = {}

local panel: Frame
local streakLabel: TextLabel
local list: ScrollingFrame
local resetLabels: { daily: TextLabel?, weekly: TextLabel? } = {}

local questById: { [string]: QuestConfig.Quest } = {}
for _, quest in QuestConfig.DailyPool do
	questById[quest.Id] = quest
end
for _, quest in QuestConfig.WeeklyPool do
	questById[quest.Id] = quest
end

local function round(instance: GuiObject)
	Instance.new("UICorner").Parent = instance
end

local function pad(instance: GuiObject, amount: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, amount)
	p.PaddingBottom = UDim.new(0, amount)
	p.PaddingLeft = UDim.new(0, amount)
	p.PaddingRight = UDim.new(0, amount)
	p.Parent = instance
end

local function label(parent: Instance, text: string, color: Color3, bold: boolean): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = color
	l.Text = text
	l.Parent = parent
	return l
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

local function addQuest(order: number, state: PlayerDataTypes.QuestState, reward: Rewards.Reward?)
	local quest = questById[state.Id]
	local card = Instance.new("Frame")
	card.LayoutOrder = order
	card.Size = UDim2.new(1, -8, 0, 56)
	card.BackgroundColor3 = CARD
	round(card)
	card.Parent = list

	local text = if quest then quest.Text:gsub("{n}", Format.Number(state.Target)) else state.Id
	local title = label(card, if state.Done then `✓ {text}` else text, if state.Done then GREEN else Color3.new(1, 1, 1), true)
	title.Position = UDim2.new(0, 10, 0, 6)
	title.Size = UDim2.new(0.65, -10, 0, 20)

	local rewardText = label(card, if reward then Rewards.Describe(reward) else "", GOLD, false)
	rewardText.Position = UDim2.new(0.65, 0, 0, 6)
	rewardText.Size = UDim2.new(0.35, -10, 0, 18)
	rewardText.TextXAlignment = Enum.TextXAlignment.Right

	local bar = Instance.new("Frame")
	bar.Position = UDim2.new(0, 10, 0, 32)
	bar.Size = UDim2.new(1, -20, 0, 16)
	bar.BackgroundColor3 = DARK
	round(bar)
	bar.Parent = card
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(math.clamp(state.Progress / math.max(state.Target, 1), 0, 1), 0, 1, 0)
	fill.BackgroundColor3 = if state.Done then GREEN else QUEST_COLOR:Lerp(DARK, 0.3)
	round(fill)
	fill.Parent = bar
	local count = label(bar, `{Format.Number(state.Progress)} / {Format.Number(state.Target)}`, Color3.new(1, 1, 1), true)
	count.Size = UDim2.fromScale(1, 1)
	count.TextXAlignment = Enum.TextXAlignment.Center
	count.ZIndex = 2
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

	local days = #QuestConfig.StreakRewards
	local nextDay = if data.LoginStreak >= days then 1 else data.LoginStreak + 1
	streakLabel.Text = `Login streak: day {data.LoginStreak}/{days}  ·  tomorrow: {Rewards.Describe(QuestConfig.StreakRewards[nextDay])}`
		.. (if nextDay ~= days then `  ·  day {days}: {Rewards.Describe(QuestConfig.StreakRewards[days])}` else "")

	local daily = label(list, "", Color3.new(1, 1, 1), true)
	daily.LayoutOrder = 0
	daily.Size = UDim2.new(1, -8, 0, 22)
	resetLabels.daily = daily
	for slot, state in data.DailyQuests do
		addQuest(slot, state, QuestConfig.DailyRewards[slot])
	end

	local weekly = label(list, "", Color3.new(1, 1, 1), true)
	weekly.LayoutOrder = 100
	weekly.Size = UDim2.new(1, -8, 0, 22)
	resetLabels.weekly = weekly
	for slot, state in data.WeeklyQuests do
		addQuest(100 + slot, state, QuestConfig.WeeklyRewards[slot])
	end
	updateResetTimers()
end

function QuestController:Init()
	local gui = HudLayout.MakeScreenGui("Quests", "Popups")
	local open = HudLayout.AddMenuButton("Quests")

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.92, 0, 0.75, 0)
	panel.BackgroundColor3 = DARK
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	round(panel)
	panel.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 520)
	limit.Parent = panel
	HudLayout.RegisterPopup(panel, UDim2.new(0.92, 0, 0.75, 0))

	local title = label(panel, "Quests", Color3.new(1, 1, 1), true)
	title.Position = UDim2.new(0, 14, 0, 10)
	title.Size = UDim2.new(1, -70, 0, 26)

	streakLabel = label(panel, "", GOLD, false)
	streakLabel.Position = UDim2.new(0, 14, 0, 40)
	streakLabel.Size = UDim2.new(1, -28, 0, 16)

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 8)
	close.Size = UDim2.new(0, 36, 0, 30)
	close.BackgroundColor3 = GOLD
	close.TextColor3 = DARK
	close.Font = Enum.Font.GothamBold
	close.TextScaled = true
	close.Text = "X"
	round(close)
	pad(close, 4)
	close.Parent = panel
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	list = Instance.new("ScrollingFrame")
	list.Position = UDim2.new(0, 10, 0, 64)
	list.Size = UDim2.new(1, -20, 1, -74)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	open.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			redraw()
		end
	end)
	for _, key in { "DailyQuests", "WeeklyQuests", "LoginStreak" } do
		DataController:OnChanged(key, function()
			if panel.Visible then
				redraw()
			end
		end)
	end
end

function QuestController:Start()
	while true do
		if panel.Visible then
			updateResetTimers()
		end
		task.wait(1)
	end
end

return QuestController
