--!strict
-- Potions: the Potions tab of the Inventory window (InventoryWindow) lists every potion (icon, count, effect, time
-- left) with a Use / Arm / Disarm button. Active boosts and the armed luck charge show bottom-right as the potion
-- icons themselves with the time under each (phones: above the jump button, at most UITheme.PhoneMaxTimers, then a
-- "+N"); tapping one opens the Potions tab. The tab (and the Inventory icon) shows a count and pulses while there
-- are unused potions. The server checks everything (BoostService). Timers pause while offline.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Icon = require(script.Parent.UI.Icon)
local Button = require(script.Parent.UI.Button)
local InventoryWindow = require(script.Parent.InventoryWindow)
local Tooltip = require(script.Parent.UI.Tooltip)
local Boosts = require(ReplicatedStorage.Shared.Config.Boosts)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local useBoost = ReplicatedStorage.Remotes.UseBoost :: RemoteEvent

local BoostController = {}

type Row = { Count: TextLabel, Timer: TextLabel, Button: Button.Button }

local window: InventoryWindow.Tab
local rows: { [string]: Row } = {}
local timerPills: { [string]: { Frame: GuiButton, Label: TextLabel } } = {}
local moreChip: TextButton -- phones: "+N" when more timers are running than UITheme.PhoneMaxTimers
local isPhone = false

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
	window:SetBadge(unused)
	window:SetPulse(unused > 0)
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

	-- Phones: only the first few pills, then a "+N" chip.
	local shown = 0
	local hidden = 0
	for _, potion in Boosts.Potions do
		local pill = timerPills[potion.Id]
		if pill.Frame.Visible then
			if isPhone and shown >= UITheme.PhoneMaxTimers then
				pill.Frame.Visible = false
				hidden += 1
			else
				shown += 1
			end
		end
	end
	moreChip.Text = `+{hidden}`
	moreChip.Visible = hidden > 0
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

-- A potion timer: the potion icon itself (drop shadow, no background) with the time under it; tap = Potions tab.
local function makeTimerPill(parent: Instance, potion: Boosts.Potion, order: number)
	local colors = UITheme.Colors
	local button = Instance.new("TextButton")
	button.Name = potion.Id
	button.LayoutOrder = order
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.Visible = false
	button.Parent = parent
	local shadow = Icon.new(button, `Potion_{potion.Id}`, potion.Color, potion.Name)
	shadow.Name = "Shadow"
	if shadow:IsA("ImageLabel") then
		shadow.ImageColor3 = colors.IconShadow
		shadow.ImageTransparency = 0.5
	end
	local icon = Icon.new(button, `Potion_{potion.Id}`, potion.Color, potion.Name)
	for _, art in { shadow, icon } do
		art.AnchorPoint = Vector2.new(0.5, 0)
		art.Size = UDim2.new(1, 0, 0.72, 0)
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.Parent = art
	end
	icon.Position = UDim2.fromScale(0.5, 0)
	shadow.Position = UDim2.new(0.5, 2, 0, 3)
	local label = Instance.new("TextLabel")
	label.Name = "Time"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.fromScale(0.5, 1)
	label.Size = UDim2.new(1, 16, 0.3, 0)
	label.Font = UITheme.Fonts.Title
	label.TextScaled = true
	label.TextColor3 = colors.IconLabel
	label.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = colors.IconLabelStroke
	stroke.Thickness = 1.5
	stroke.Parent = label
	Style.AttachPress(button)
	button.Activated:Connect(function()
		window:Open()
	end)
	Tooltip.Attach(button, function()
		return `{potion.Name}: {potion.Description}`
	end)
	timerPills[potion.Id] = { Frame = button, Label = label }
end

function BoostController:Init()
	window = InventoryWindow.AddTab("Potions")
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

	-- Potion timers: bottom-right, in a row growing to the left (phones: above the jump button).
	local timersGui = HudLayout.MakeScreenGui("BoostTimers", "Cards")
	local hud = Instance.new("Frame")
	hud.Name = "Timers"
	hud.AnchorPoint = Vector2.new(1, 1)
	hud.AutomaticSize = Enum.AutomaticSize.X
	hud.BackgroundTransparency = 1
	hud.Parent = timersGui
	local hudLayout = Instance.new("UIListLayout")
	hudLayout.FillDirection = Enum.FillDirection.Horizontal
	hudLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	hudLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	hudLayout.Padding = UDim.new(0, 10)
	hudLayout.SortOrder = Enum.SortOrder.LayoutOrder
	hudLayout.Parent = hud
	-- "+N" after the icons (phones only); tapping it opens the Potions tab.
	moreChip = Instance.new("TextButton")
	moreChip.Name = "More"
	moreChip.LayoutOrder = #Boosts.Potions + 1
	moreChip.AutoButtonColor = false
	moreChip.BackgroundColor3 = UITheme.Colors.PanelBottom
	moreChip.BackgroundTransparency = 0.25
	moreChip.Font = UITheme.Fonts.Title
	moreChip.TextColor3 = UITheme.Colors.Gold
	moreChip.TextScaled = true
	moreChip.Visible = false
	moreChip.Parent = hud
	Style.Round(moreChip)
	Style.Stroke(moreChip, UITheme.Colors.Trim, 2)
	Style.Pad(moreChip, 4)
	Style.AttachPress(moreChip)
	moreChip.Activated:Connect(function()
		window:Open()
	end)

	HudLayout.OnLayoutChanged(function(phone)
		isPhone = phone
		if next(rows) ~= nil then -- the first call runs before the rows exist
			refresh()
		end
		local sizes = UITheme.Sizes
		local size = if phone then sizes.PhonePotionTimer else sizes.PotionTimer
		if phone then
			hud.Position = UDim2.new(1, -sizes.PhoneMargin, 1, -sizes.PhoneTimersBottom)
		else
			hud.Position = UDim2.new(1, -sizes.Margin, 1, -sizes.Margin)
		end
		hud.Size = UDim2.fromOffset(0, math.floor(size * 1.4))
		for _, pill in timerPills do
			pill.Frame.Size = UDim2.fromOffset(size, math.floor(size * 1.4))
		end
		moreChip.Size = UDim2.fromOffset(math.floor(size * 0.8), math.floor(size * 0.6))
	end)

	for index, potion in Boosts.Potions do
		makeRow(list, potion, index)
		makeTimerPill(hud, potion, index)
	end
	-- size the icons made after the first layout call
	local size = if isPhone then UITheme.Sizes.PhonePotionTimer else UITheme.Sizes.PotionTimer
	for _, pill in timerPills do
		pill.Frame.Size = UDim2.fromOffset(size, math.floor(size * 1.4))
	end

	window:OnOpen(refresh)
	for _, key in { "Potions", "ActiveBoosts", "ArmedLuckPotion" } do
		DataController:OnChanged(key, refresh)
	end
end

return BoostController
