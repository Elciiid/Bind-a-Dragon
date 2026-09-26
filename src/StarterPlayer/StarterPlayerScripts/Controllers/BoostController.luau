--!strict
-- Boosts: the "Boosts" menu tile opens a window (UI/Window) listing every potion (icon, count, effect, time left)
-- with a Use / Arm / Disarm button, and timer pills (top right; under the luck pill on phones) show active boosts
-- and the armed luck charge. The Boosts tile shows a count and pulses while there are unused potions.
-- The server checks everything (BoostService). Timers pause while offline.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Icon = require(script.Parent.UI.Icon)
local Button = require(script.Parent.UI.Button)
local Window = require(script.Parent.UI.Window)
local Tooltip = require(script.Parent.UI.Tooltip)
local Boosts = require(ReplicatedStorage.Shared.Config.Boosts)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local useBoost = ReplicatedStorage.Remotes.UseBoost :: RemoteEvent

local BoostController = {}

type Row = { Count: TextLabel, Timer: TextLabel, Button: Button.Button }

local window: Window.Window
local rows: { [string]: Row } = {}
local timerPills: { [string]: { Frame: Frame, Label: TextLabel } } = {}

local function formatTime(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- Boosts tile: a count badge and a pulsing outline while the player owns potions they haven't used.
local function updateBadge(data: any)
	local unused = 0
	for potionId, count in data.Potions do
		local potion = Boosts.ById[potionId]
		if potion and not (potion.Kind == "LuckCharge" and data.ArmedLuckPotion == potionId) then
			unused += count
		end
	end
	HudLayout.SetBadge("Boosts", unused)
	HudLayout.SetPulse("Boosts", unused > 0)
end

local function refresh()
	local data = DataController:Get()
	if data == nil then
		return
	end
	updateBadge(data)
	for _, potion in Boosts.Potions do
		local count = data.Potions[potion.Id] or 0
		local left = data.ActiveBoosts[potion.Id] or 0
		local armed = data.ArmedLuckPotion == potion.Id

		local row = rows[potion.Id]
		row.Count.Text = `x{count}`
		if potion.Kind == "LuckCharge" then
			row.Timer.Text = if armed then "Armed for your next bind" else "Arm it, then bind at night"
			row.Button:SetText(if armed then "Disarm" else "Arm")
			row.Button:SetKind(if armed then "Cancel" else "Primary")
			row.Button:SetEnabled(armed or count > 0)
		else
			row.Timer.Text = if left > 0 then `Active: {formatTime(left)} left` else `{potion.Minutes} min per potion`
			row.Button:SetText("Use")
			row.Button:SetEnabled(count > 0)
		end

		-- Timer pills: active timers and the armed charge.
		local pill = timerPills[potion.Id]
		if left > 0 then
			pill.Label.Text = formatTime(left)
			pill.Frame.Visible = true
		elseif armed then
			pill.Label.Text = "Armed"
			pill.Frame.Visible = true
		else
			pill.Frame.Visible = false
		end
	end
end

local function makeRow(list: Instance, potion: Boosts.Potion, order: number)
	local theme = UITheme
	local card = Instance.new("Frame")
	card.Name = potion.Id
	card.LayoutOrder = order
	card.Size = UDim2.new(1, -8, 0, 64)
	Style.CardLook(card, potion.Color)
	card.Parent = list

	local icon = Icon.new(card, `Potion_{potion.Id}`, potion.Color, potion.Name)
	icon.Position = UDim2.fromOffset(14, 6)
	icon.Size = UDim2.fromOffset(52, 52)

	local name = Style.Label(card, potion.Name, "Heavy", 18, potion.Color)
	name.Position = UDim2.fromOffset(74, 5)
	name.Size = UDim2.new(0.55, -74, 0, 20)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local count = Style.Label(card, "x0", "Heavy", 18)
	count.Position = UDim2.new(0.55, 0, 0, 5)
	count.Size = UDim2.new(0.12, 0, 0, 20)
	local description = Style.Label(card, potion.Description, "Body", theme.TextSizes.Small, theme.Colors.TextMuted)
	description.Position = UDim2.fromOffset(74, 26)
	description.Size = UDim2.new(0.67, -74, 0, 16)
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.TextTruncate = Enum.TextTruncate.AtEnd
	local timer = Style.Label(card, "", "Bold", theme.TextSizes.Small, theme.Colors.Info)
	timer.Position = UDim2.fromOffset(74, 43)
	timer.Size = UDim2.new(0.67, -74, 0, 16)
	timer.TextXAlignment = Enum.TextXAlignment.Left

	local button = Button.new(card, {
		Text = "Use",
		Kind = "Confirm",
		OnClick = function()
			useBoost:FireServer(potion.Id) -- the server checks the count and the 60-minute limit
		end,
	})
	button.Instance.AnchorPoint = Vector2.new(1, 0.5)
	button.Instance.Position = UDim2.new(1, -10, 0.5, 0)
	button.Instance.Size = UDim2.new(0.28, 0, 0, 40)
	Tooltip.Attach(card, function()
		return potion.Description
	end)

	rows[potion.Id] = { Count = count, Timer = timer, Button = button }
end

-- A timer pill: potion icon + time left.
local function makeTimerPill(parent: Instance, potion: Boosts.Potion, order: number)
	local pill = Instance.new("Frame")
	pill.Name = potion.Id
	pill.LayoutOrder = order
	pill.Size = UDim2.new(1, 0, 0, 26)
	pill.Visible = false
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	Style.Gradient(pill, UITheme.Colors.PanelTop, UITheme.Colors.PanelBottom)
	Style.Round(pill)
	Style.Stroke(pill, potion.Color, 2)
	pill.Parent = parent
	local icon = Icon.new(pill, `Potion_{potion.Id}`, potion.Color, potion.Name)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, -4, 0.5, 0)
	icon.Size = UDim2.fromOffset(32, 32)
	local label = Style.Label(pill, "", "Heavy", 15, potion.Color)
	label.Position = UDim2.fromOffset(30, 0)
	label.Size = UDim2.new(1, -36, 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	Tooltip.Attach(pill, function()
		return `{potion.Name}: {potion.Description}`
	end)
	timerPills[potion.Id] = { Frame = pill, Label = label }
end

function BoostController:Init()
	local open = HudLayout.AddMenuButton("Boosts")
	window = Window.new({
		Name = "Boosts",
		Title = "Boosts",
		Icon = "Menu_Boosts",
		Size = UDim2.new(0.92, 0, 0.75, 0),
		MaxSize = Vector2.new(560, 540),
	})
	local content = window.Content

	local note = Style.Label(
		content,
		`Timers pause while you're offline · up to {Boosts.MaxStoredMinutes} min per potion · Premium +{math.floor(Boosts.PremiumDurationBonus * 100)}% time`,
		"Body",
		UITheme.TextSizes.Small,
		UITheme.Colors.TextMuted
	)
	note.Size = UDim2.new(1, 0, 0, 16)
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.TextTruncate = Enum.TextTruncate.AtEnd

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(0, 22)
	list.Size = UDim2.new(1, 0, 1, -22)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = UITheme.Colors.Trim
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	Style.Pad(list, 2, 3)

	-- Timer pills: top right, below the sky bar on PC, under the luck pill on phones.
	local timersGui = HudLayout.MakeScreenGui("BoostTimers", "Cards")
	local hud = Instance.new("Frame")
	hud.Name = "Timers"
	hud.AnchorPoint = Vector2.new(1, 0)
	hud.AutomaticSize = Enum.AutomaticSize.Y
	hud.BackgroundTransparency = 1
	hud.Parent = timersGui
	local hudLayout = Instance.new("UIListLayout")
	hudLayout.Padding = UDim.new(0, 5)
	hudLayout.SortOrder = Enum.SortOrder.LayoutOrder
	hudLayout.Parent = hud
	HudLayout.OnLayoutChanged(function(isPhone)
		local sizes = UITheme.Sizes
		if isPhone then
			hud.Position = UDim2.new(1, -sizes.PhoneMargin, 0, sizes.PhoneMargin + sizes.PhonePillHeight + sizes.Gap)
			hud.Size = UDim2.fromOffset(110, 0)
		else
			hud.Position = UDim2.new(1, -sizes.Margin, 0, 70)
			hud.Size = UDim2.fromOffset(130, 0)
		end
	end)

	for index, potion in Boosts.Potions do
		makeRow(list, potion, index)
		makeTimerPill(hud, potion, index)
	end

	open.Activated:Connect(function()
		window:Toggle()
	end)
	window:OnOpen(refresh)
	for _, key in { "Potions", "ActiveBoosts", "ArmedLuckPotion" } do
		DataController:OnChanged(key, refresh)
	end
end

return BoostController
