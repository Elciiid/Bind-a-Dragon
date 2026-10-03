--!strict
-- Potions: the Potions tab of the Inventory window (InventoryWindow) lists every potion (icon, count, effect, time
-- left) with a Use / Arm / Disarm button. Active boosts and the armed luck charge show bottom-right as the potion
-- icons themselves with the time under each, in a horizontal row growing to the left, directly under the day/night timer
-- in the bottom-right stack (HudLayout.GetTimerStack; phones: above the jump button, at most UITheme.PhoneMaxTimers, then
-- a "+N"); tapping one opens the Potions tab. The tab (and the Inventory icon) shows a count and pulses while there
-- are unused potions. The server checks everything (BoostService). Timers pause while offline.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Icon = require(script.Parent.UI.Icon)
local Button = require(script.Parent.UI.Button)
local InventoryWindow = require(script.Parent.InventoryWindow)
local Tooltip = require(script.Parent.UI.Tooltip)
local Boosts = require(ReplicatedStorage.Shared.Config.Boosts)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local Format = require(ReplicatedStorage.Shared.Format)

local useBoost = ReplicatedStorage.Remotes.UseBoost :: RemoteEvent

local BoostController = {}

type Row = { Count: TextLabel, Timer: TextLabel, Button: Button.Button, Description: TextLabel, Name: TextLabel }

local window: InventoryWindow.Tab
local rows: { [string]: Row } = {}
local timerPills: { [string]: { Frame: GuiButton, Label: TextLabel } } = {}
local moreChip: TextButton -- phones: "+N" when more timers are running than UITheme.PhoneMaxTimers
local isPhone = false
local mobile = UITheme.MobileUI
local words = Text.Potions

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
		row.Count.Text = Text.Format(Text.Items.Count, { count = Format.Number(count) })
		if potion.Kind == "LuckCharge" then
			row.Timer.Text = if armed then words.Armed elseif count == 0 then words.Unavailable else words.NextBind
			row.Button:SetText(if armed then words.Disarm else words.Arm)
			row.Button:SetKind(if armed then "Cancel" else "Confirm")
			row.Button:SetEnabled(armed or count > 0)
		else
			local full = left >= Boosts.MaxStoredMinutes * 60
			row.Timer.Text = if full then words.Full elseif left > 0 then Text.Format(words.Active, { time = formatTime(left) }) elseif count == 0 then words.Unavailable else Text.Format(words.Duration, { minutes = potion.Minutes or 0 })
			row.Button:SetText(words.Use)
			row.Button:SetEnabled(count > 0 and not full)
		end
		row.Timer.TextColor3 = if armed or left > 0 then UITheme.Colors.Positive elseif count == 0 then UITheme.Colors.TextMuted else UITheme.Colors.Info

		-- Timer pills: active timers and the armed charge.
		local pill = timerPills[potion.Id]
		if left > 0 then
			pill.Label.Text = formatTime(left)
			pill.Frame.Visible = true
		elseif armed then
			pill.Label.Text = words.Armed
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

-- Names and full effect descriptions wrap; cards grow vertically before any text would be clipped.
local POTION_CARD = mobile.PotionCard

local function makeRow(list: Instance, potion: Boosts.Potion, order: number)
	local theme = UITheme
	local cell = Instance.new("Frame")
	cell.Name = potion.Id
	cell.LayoutOrder = order
	cell.BackgroundTransparency = 1
	cell.Parent = list
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromScale(1, 1)
	Style.CardLook(card, potion.Color)
	card.Parent = cell
	local details = Instance.new("TextButton")
	details.Name = "PotionDetails"
	details.Text = ""
	details.BackgroundTransparency = 1
	details.Size = UDim2.fromOffset(mobile.Touch, mobile.Touch)
	details.Position = UDim2.fromOffset(mobile.Padding, mobile.Padding)
	details.Parent = card
	local icon = Icon.new(details, `Potion_{potion.Id}`, potion.Color, potion.Name)
	icon.Size = UDim2.fromScale(1, 1)
	icon.ZIndex = 3
	local count = Style.Label(card, Text.Format(Text.Items.Count, { count = 0 }), "Heavy", mobile.Small, theme.Colors.Text)
	count.AnchorPoint = Vector2.new(0.5, 1)
	count.Position = UDim2.fromOffset(mobile.Padding + mobile.Touch / 2, mobile.Padding + mobile.Touch)
	count.Size = UDim2.fromOffset(0, mobile.Small * 1.5)
	count.AutomaticSize = Enum.AutomaticSize.X
	count.TextWrapped = false
	count.BackgroundTransparency = 0.1
	count.BackgroundColor3 = Style.Shade(potion.Color, -0.55)
	count.ZIndex = 4
	Style.Round(count)
	Style.Pad(count, mobile.Padding / 2, 0)
	Style.GoldBorder(count, 1.5)
	Style.Outline(count, 1.5)

	local name = Style.Label(card, potion.Name, "Heavy", mobile.Body, theme.Colors.Text)
	name.Position = UDim2.fromOffset(mobile.Padding + mobile.Touch + mobile.Gap, mobile.Padding)
	name.Size = UDim2.new(1, -(mobile.Padding * 2 + mobile.Touch + mobile.Gap), 0, mobile.Touch)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.ZIndex = 3
	Style.Outline(name, 2)
	local description = Style.Label(card, potion.Description, "Body", mobile.Body, theme.Colors.TextMuted)
	description.Position = UDim2.fromOffset(mobile.Padding, mobile.Padding + mobile.Touch + mobile.Gap)
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.TextYAlignment = Enum.TextYAlignment.Top
	description.ZIndex = 3
	local timer = Style.Label(card, "", "Bold", mobile.Small, theme.Colors.Info)
	timer.AnchorPoint = Vector2.new(0, 1)
	timer.Position = UDim2.new(0, mobile.Padding, 1, -(mobile.Padding + mobile.Touch + mobile.Gap))
	timer.Size = UDim2.new(1, -mobile.Padding * 2, 0, mobile.Small * 1.5)
	timer.ZIndex = 3
	Style.Outline(timer, 1.2)

	local button = Button.new(card, {
		Text = words.Use,
		Kind = "Confirm",
		TextSize = mobile.Body,
		OnClick = function()
			useBoost:FireServer(potion.Id) -- the server checks the count and the 60-minute limit
		end,
	})
	button.Instance.AnchorPoint = Vector2.new(0.5, 1)
	button.Instance.Position = UDim2.new(0.5, 0, 1, -mobile.Padding)
	button.Instance.Size = UDim2.new(1, -mobile.Padding * 2, 0, mobile.Touch)
	button.Instance.ZIndex = 3
	local function getDetails(): string
		return Text.Format(words.Tooltip, { name = potion.Name, description = potion.Description, minutes = Boosts.MaxStoredMinutes, bonus = math.floor(Boosts.PremiumDurationBonus * 100) })
	end
	Tooltip.Attach(card, getDetails)
	details.Activated:Connect(function()
		Tooltip.Toggle(card, getDetails, details.AbsolutePosition + Vector2.new(0, details.AbsoluteSize.Y))
	end)
	rows[potion.Id] = { Count = count, Timer = timer, Button = button, Description = description, Name = name }
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
	label.FontFace = UITheme.Fonts.Timer -- the same bold italic white as the day/night timer
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
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

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = mobile.Scrollbar
	list.ScrollBarImageColor3 = UITheme.Colors.Trim
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.Parent = content
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(mobile.Gap, mobile.Gap)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = list
	Style.Pad(list, mobile.Padding / 2, mobile.Padding / 2)

	-- Potion timers: a horizontal row (growing to the left) under the day/night timer in the bottom-right stack.
	local hud = Instance.new("Frame")
	hud.Name = "Timers"
	hud.LayoutOrder = 2 -- after the day/night timer (0) and its caption (1)
	hud.AutomaticSize = Enum.AutomaticSize.X
	hud.BackgroundTransparency = 1
	hud.Parent = HudLayout.GetTimerStack()
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
	moreChip.BackgroundColor3 = UITheme.Colors.PanelV2Top
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

	local function layoutCards()
		if content.AbsoluteSize.X <= 0 then return end
		local usable = math.max(1, content.AbsoluteSize.X - mobile.Padding - mobile.Gap)
		local columns = math.max(1, math.floor((usable + mobile.Gap) / (POTION_CARD.X - mobile.Padding * 2 + mobile.Gap)))
		local width = math.min(POTION_CARD.X, math.floor((usable - mobile.Gap * (columns - 1)) / columns))
		local descriptionHeight = 0
		local headerHeight = mobile.Touch
		for _, row in rows do
			local measure = TextService:GetTextSize(row.Description.Text, mobile.Body, UITheme.Fonts.Body, Vector2.new(width - mobile.Padding * 2, math.huge))
			descriptionHeight = math.max(descriptionHeight, math.ceil(measure.Y))
			headerHeight = math.max(headerHeight, math.ceil(TextService:GetTextSize(row.Name.Text, mobile.Body, UITheme.Fonts.Heavy, Vector2.new(math.max(1, width - mobile.Padding * 2 - mobile.Touch - mobile.Gap), math.huge)).Y))
		end
		local height = math.max(POTION_CARD.Y, mobile.Padding * 2 + headerHeight + mobile.Touch + mobile.Gap * 3 + mobile.Small * 1.5 + descriptionHeight)
		grid.CellSize = UDim2.fromOffset(width, height)
		grid.FillDirectionMaxCells = columns
		for _, row in rows do
			row.Name.Size = UDim2.new(1, -(mobile.Padding * 2 + mobile.Touch + mobile.Gap), 0, headerHeight)
			row.Description.Position = UDim2.fromOffset(mobile.Padding, mobile.Padding + headerHeight + mobile.Gap)
			row.Description.Size = UDim2.new(1, -mobile.Padding * 2, 0, descriptionHeight)
		end
	end
	HudLayout.OnLayoutChanged(function(phone)
		isPhone = phone
		if next(rows) ~= nil then -- the first call runs before the rows exist
			refresh()
		end
		local sizes = UITheme.Sizes
		layoutCards()
		local size = math.max(mobile.Touch, if phone then sizes.PhonePotionTimer else sizes.PotionTimer)
		hud.Size = UDim2.fromOffset(0, math.floor(size * 1.4))
		for _, pill in timerPills do
			pill.Frame.Size = UDim2.fromOffset(size, math.floor(size * 1.4))
		end
		moreChip.Size = UDim2.fromOffset(mobile.Touch, mobile.Touch)
	end)

	for index, potion in Boosts.Potions do
		makeRow(list, potion, index)
		makeTimerPill(hud, potion, index)
	end
	-- size the icons and cards made after the first layout call
	content:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutCards)
	layoutCards()
	local size = math.max(mobile.Touch, if isPhone then UITheme.Sizes.PhonePotionTimer else UITheme.Sizes.PotionTimer)
	for _, pill in timerPills do
		pill.Frame.Size = UDim2.fromOffset(size, math.floor(size * 1.4))
	end

	window:OnOpen(refresh)
	for _, key in { "Potions", "ActiveBoosts", "ArmedLuckPotion" } do
		DataController:OnChanged(key, refresh)
	end
end

return BoostController
