--!strict
-- Rebirth HUD icon (HudLayout: gold glow + READY! when the player can afford it, else a progress ring toward the
-- next rebirth) and a confirm window (UI/Window): a big "★ Rebirth N" heading, a cost card with the gold icon (and a
-- bar toward the cost while it's not affordable), the milestone track (Rebirth Milestone Ladder: a node per milestone,
-- reached ones lit, your title, the R12 Auto-Upgrade switch), reward chips (income bonus, level cap, a new area when this rebirth
-- unlocks one), one short line on what is kept, and big Rebirth! / Not yet buttons. Wording in Config/Text.Rebirth.
-- The server decides.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Icon = require(script.Parent.UI.Icon)
local Button = require(script.Parent.UI.Button)
local ProgressBar = require(script.Parent.UI.ProgressBar)
local Window = require(script.Parent.UI.Window)
local Tooltip = require(script.Parent.UI.Tooltip)
local RebirthMilestones = require(ReplicatedStorage.Shared.RebirthMilestones)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local Leveling = require(ReplicatedStorage.Shared.Config.Leveling)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local requestRebirth = ReplicatedStorage.Remotes.RequestRebirth :: RemoteEvent
local setAutoUpgrade = ReplicatedStorage.Remotes.SetAutoUpgrade :: RemoteEvent

local RebirthController = {}

local words = Text.Rebirth
local colors = UITheme.Colors
local Mobile = UITheme.MobileUI

local button: TextButton
local window: Window.Window
local confirmationWindow: Window.Window
local finalConfirm: Button.Button
local confirmationCost: TextLabel
local heading: TextLabel
local costCard: Frame
local costLabel: TextLabel
local haveLabel: TextLabel
local costBar: ProgressBar.ProgressBar
local chips: Frame
local keeps: TextLabel
local confirm: Button.Button
local track: Frame
local nodeRow: ScrollingFrame
local titleLabel: TextLabel
local autoButton: Button.Button
local nodes: { [string]: { Circle: Frame, Mark: TextLabel, Name: TextLabel, Level: TextLabel } } = {}

type Chip = { Frame: Frame, Value: TextLabel }
local chipByKey: { [string]: Chip } = {}

local function makeChip(key: string, order: number, icon: string, title: string, color: Color3): Chip
	local chip = Instance.new("Frame")
	chip.Name = key
	chip.LayoutOrder = order
	chip.Size = UDim2.new(1, 0, 0, Mobile.RebirthChipHeight)
	Style.CardLook(chip)
	chip.Parent = chips
	local image = Icon.new(chip, icon, color)
	image.AnchorPoint = Vector2.new(0, 0.5)
	image.Position = UDim2.new(0, Mobile.Padding, 0.5, 0)
	image.Size = UDim2.fromOffset(Mobile.Touch, Mobile.Touch)
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Parent = image
	local name = Style.Label(chip, title, "Bold", Mobile.Small, colors.TextMuted)
	name.Position = UDim2.fromOffset(Mobile.Touch + Mobile.Padding * 2, Mobile.Padding / 2)
	name.Size = UDim2.new(1, -(Mobile.Touch + Mobile.Padding * 3), 0, Mobile.Small + Mobile.Gap)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local value = Style.Label(chip, "", "Title", Mobile.Title, color)
	local valueTop = Mobile.Padding / 2 + Mobile.Small + Mobile.Gap
	value.Position = UDim2.fromOffset(Mobile.Touch + Mobile.Padding * 2, valueTop)
	value.Size = UDim2.new(1, -(Mobile.Touch + Mobile.Padding * 3), 0, Mobile.RebirthChipHeight - valueTop - Mobile.Padding)
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.TextScaled = true
	value.TextStrokeTransparency = 0
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = Mobile.Title
	limit.MinTextSize = Mobile.Body
	limit.Parent = value
	local entry = { Frame = chip, Value = value }
	chipByKey[key] = entry
	return entry
end

-- Milestone track: reached nodes are gold, the next one is outlined, the rest grey; the title and the Auto-Upgrade switch.
local function refreshTrack(data: any)
	local words = Text.Milestones
	local nextMilestone = RebirthMilestones.Next(data.Rebirths)
	for _, milestone in RebirthMilestones.All do
		local node = nodes[milestone.Id]
		if node then
			local reached = data.Rebirths >= milestone.Rebirths
			local isNext = nextMilestone ~= nil and nextMilestone.Id == milestone.Id
			node.Circle.BackgroundColor3 = if reached then colors.Gold elseif isNext then Style.Shade(colors.Gold, -0.55) else Color3.fromRGB(60, 56, 84)
			node.Mark.Text = if reached then "★" else ""
			node.Mark.TextColor3 = if reached then Color3.fromRGB(70, 40, 10) else colors.TextMuted
			node.Name.TextColor3 = if reached then colors.Text else colors.TextMuted
			node.Level.TextColor3 = if reached then colors.Gold else colors.TextMuted
		end
	end
	local title, gold = RebirthMilestones.GetTitle(data.Rebirths)
	titleLabel.Text = if title then Text.Format(words.YourTitle, { title = title }) elseif nextMilestone then Text.Format(words.Next, { name = RebirthMilestones.NameOf(nextMilestone), n = nextMilestone.Rebirths }) else words.AllDone
	titleLabel.TextColor3 = if gold then colors.Gold else colors.TextMuted
	local hasAuto = RebirthMilestones.Has(data.Rebirths, "AutoUpgrade")
	autoButton.Instance.Visible = hasAuto
	if hasAuto then
		autoButton:SetText(`{words.AutoUpgradeLabel}: {if data.AutoUpgrade then words.AutoUpgradeOn else words.AutoUpgradeOff}`)
	end
end

local function refresh()
	local data = DataController:Get()
	if data == nil then
		return
	end
	refreshTrack(data)
	local cost = DragonStats.GetRebirthCost(data.Rebirths)
	local next = data.Rebirths + 1
	if data.Rebirths > 0 then
		HudLayout.SetMenuText("Rebirth", Text.Format(words.Heading, { n = `★{data.Rebirths}` }), `★{data.Rebirths}`)
	end

	-- HUD: "ready" (gold glow, hop, sparkles, READY!) when affordable; otherwise calm with a progress ring
	local atCap = DragonStats.IsAtRebirthCap(data)
	local ready = not atCap and data.Gold >= cost
	finalConfirm:SetEnabled(ready)
	confirmationCost.Text = Text.Format(words.Cost, { cost = Format.Number(cost) })
	HudLayout.SetReady("Rebirth", ready)
	HudLayout.SetProgress("Rebirth", if atCap or ready then nil else math.clamp(data.Gold / cost, 0, 1))

	if atCap then
		heading.Text = `★ {words.CapHeading}`
		costCard.Visible = false
		chips.Visible = false
		keeps.Text = words.CapInfo
		confirm:SetText(words.CapButton)
		confirm:SetEnabled(false)
		return
	end
	costCard.Visible = true
	chips.Visible = true

	heading.Text = "★ " .. Text.Format(words.Heading, { n = next })
	costLabel.Text = Text.Format(words.Cost, { cost = Format.Number(cost) })
	haveLabel.Text = Text.Format(words.Have, { gold = Format.Number(data.Gold) })
	local affordable = data.Gold >= cost
	costBar.Instance.Visible = not affordable
	if not affordable then
		costBar:Set(math.clamp(data.Gold / cost, 0, 1), `{math.floor(math.clamp(data.Gold / cost, 0, 1) * 100)}%`)
	end

	chipByKey.Income.Value.Text = `{Format.Multiplier(DragonStats.GetRebirthBonus(data.Rebirths))} → {Format.Multiplier(DragonStats.GetRebirthBonus(next))}`
	local capNow = DragonStats.GetLevelCap(data)
	chipByKey.LevelCap.Value.Text = `{capNow} → {capNow + Leveling.CapPerRebirth}`
	local unlocks = {}
	for _, area in Areas do
		if area.RebirthsRequired == next then
			table.insert(unlocks, area.Name)
		end
	end
	local area = chipByKey.Unlocks
	area.Frame.Visible = #unlocks > 0
	area.Value.Text = table.concat(unlocks, ", ")
	local shown = if #unlocks > 0 then 3 else 2
	chips.Size = UDim2.new(1, -Mobile.Scrollbar, 0, shown * Mobile.RebirthChipHeight + (shown - 1) * Mobile.Gap)
	keeps.Text = words.Keeps

	confirm:SetText(if affordable then words.Confirm else words.NotEnough)
	confirm:SetEnabled(affordable)
end

function RebirthController:Init()
	button = HudLayout.AddMenuButton("Rebirth")
	window = Window.new({
		Name = "Rebirth",
		Title = words.Title,
		Icon = "Menu_Rebirth",
		Size = UDim2.new(0.9, 0, 0.9, 0), -- height scales with the screen, up to MaxSize
		MaxSize = Vector2.new(540, 570),
	})
	local content = window.Content

	local column = Instance.new("ScrollingFrame")
	column.Name = "Column"
	column.BackgroundTransparency = 1
	column.Size = UDim2.new(1, 0, 1, -(Mobile.Touch + Mobile.Gap))
	column.BorderSizePixel = 0
	column.ScrollBarThickness = Mobile.Scrollbar
	column.ScrollBarImageColor3 = colors.Trim
	column.ScrollingDirection = Enum.ScrollingDirection.Y
	column.AutomaticCanvasSize = Enum.AutomaticSize.Y
	column.CanvasSize = UDim2.new()
	column.Parent = content
	Style.Pad(column, Mobile.Padding / 2, Mobile.Padding)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, Mobile.Gap)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = column

	heading = Style.Label(column, "", "Title", Mobile.Title, colors.Title)
	heading.LayoutOrder = 1
	heading.Size = UDim2.new(1, -Mobile.Scrollbar, 0, Mobile.Touch)
	heading.TextStrokeTransparency = 0

	costCard = Instance.new("Frame")
	costCard.Name = "Cost"
	costCard.LayoutOrder = 2
	costCard.Size = UDim2.new(1, -Mobile.Scrollbar, 0, Mobile.RebirthCostHeight)
	Style.CardLook(costCard, colors.Gold)
	costCard.Parent = column
	local gold = Icon.new(costCard, "Gold", colors.Gold)
	gold.AnchorPoint = Vector2.new(0, 0.5)
	gold.Position = UDim2.new(0, Mobile.Padding, 0.5, 0)
	gold.Size = UDim2.fromOffset(Mobile.Touch, Mobile.Touch)
	costLabel = Style.Label(costCard, "", "Title", Mobile.Title, colors.Gold)
	costLabel.Position = UDim2.fromOffset(Mobile.Touch + Mobile.Padding * 2, Mobile.Padding / 2)
	costLabel.Size = UDim2.new(1, -(Mobile.Touch + Mobile.Padding * 3), 0, Mobile.Title * 2)
	costLabel.TextXAlignment = Enum.TextXAlignment.Left
	costLabel.TextStrokeTransparency = 0
	haveLabel = Style.Label(costCard, "", "Body", Mobile.Body, colors.TextMuted)
	haveLabel.Position = UDim2.fromOffset(Mobile.Touch + Mobile.Padding * 2, Mobile.Title * 2 + Mobile.Padding / 2)
	haveLabel.Size = UDim2.new(1, -(Mobile.Touch + Mobile.Padding * 3), 0, Mobile.Body + Mobile.Gap)
	haveLabel.TextXAlignment = Enum.TextXAlignment.Left
	costBar = ProgressBar.new(costCard, colors.Gold)
	costBar.Instance.Position = UDim2.fromOffset(Mobile.Touch + Mobile.Padding * 2, Mobile.RebirthCostHeight - Mobile.Body - Mobile.Padding)
	costBar.Instance.Size = UDim2.new(1, -(Mobile.Touch + Mobile.Padding * 3), 0, Mobile.Body)

	chips = Instance.new("Frame")
	chips.Name = "Rewards"
	chips.LayoutOrder = 3
	chips.BackgroundTransparency = 1
	chips.Size = UDim2.new(1, -Mobile.Scrollbar, 0, Mobile.RebirthChipHeight * 3 + Mobile.Gap * 2)
	chips.Parent = column
	local chipList = Instance.new("UIListLayout")
	chipList.FillDirection = Enum.FillDirection.Vertical
	chipList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	chipList.Padding = UDim.new(0, Mobile.Gap)
	chipList.SortOrder = Enum.SortOrder.LayoutOrder
	chipList.Parent = chips
	makeChip("Income", 1, "Gold", words.Income, colors.Positive)
	makeChip("LevelCap", 2, "Menu_Dragons", words.LevelCap, colors.Info)
	makeChip("Unlocks", 3, "Travel_Portals", words.Unlocks, colors.Title)

	track = Instance.new("Frame")
	track.Name = "Milestones"
	track.LayoutOrder = 4
	track.Size = UDim2.new(1, -Mobile.Scrollbar, 0, Mobile.RebirthTrackHeight)
	Style.CardLook(track)
	track.Parent = column
	local trackHeading = Style.Label(track, Text.Milestones.TrackHeading, "Title", Mobile.Title, colors.Title)
	trackHeading.Position = UDim2.fromOffset(Mobile.Padding, Mobile.Padding / 2)
	trackHeading.Size = UDim2.new(1, -Mobile.Padding * 2, 0, Mobile.Title + Mobile.Gap)
	trackHeading.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel = Style.Label(track, "", "Body", Mobile.Body, colors.TextMuted)
	titleLabel.Position = UDim2.fromOffset(Mobile.Padding, Mobile.Title + Mobile.Gap + Mobile.Padding / 2)
	titleLabel.Size = UDim2.new(1, -Mobile.Padding * 2, 0, Mobile.Body * 2)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextWrapped = true
	nodeRow = Instance.new("ScrollingFrame")
	nodeRow.Name = "Nodes"
	nodeRow.BackgroundTransparency = 1
	nodeRow.BorderSizePixel = 0
	nodeRow.Position = UDim2.fromOffset(Mobile.Padding, Mobile.Title + Mobile.Body * 2 + Mobile.Gap * 2)
	nodeRow.Size = UDim2.new(1, -Mobile.Padding * 2, 0, Mobile.RowHeight + Mobile.Scrollbar)
	nodeRow.AutomaticCanvasSize = Enum.AutomaticSize.X
	nodeRow.CanvasSize = UDim2.new()
	nodeRow.ScrollingDirection = Enum.ScrollingDirection.X
	nodeRow.ScrollBarThickness = Mobile.Scrollbar
	nodeRow.ScrollBarImageColor3 = colors.Trim
	nodeRow.Parent = track
	local nodeList = Instance.new("UIListLayout")
	nodeList.FillDirection = Enum.FillDirection.Horizontal
	nodeList.Padding = UDim.new(0, 8)
	nodeList.SortOrder = Enum.SortOrder.LayoutOrder
	nodeList.Parent = nodeRow
	for index, milestone in RebirthMilestones.All do
		local node = Instance.new("Frame")
		node.Name = milestone.Id
		node.LayoutOrder = index
		node.BackgroundTransparency = 1
	node.Size = UDim2.fromOffset(Mobile.StationDragonWidth / 2, Mobile.RowHeight)
		node.Parent = nodeRow
		local circle = Instance.new("Frame")
		circle.AnchorPoint = Vector2.new(0.5, 0)
		circle.Position = UDim2.fromScale(0.5, 0)
		circle.Size = UDim2.fromOffset(28, 28)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = circle
		Style.GoldBorder(circle, 1.5)
		circle.Parent = node
		local mark = Style.Label(circle, "", "Title", 16, colors.TextMuted)
		mark.Size = UDim2.fromScale(1, 1)
		local name = Style.Label(node, RebirthMilestones.NameOf(milestone), "Bold", Mobile.Small, colors.TextMuted)
		name.Position = UDim2.fromOffset(0, 29)
		name.Size = UDim2.new(1, 0, 0, Mobile.Small * 2)
		local level = Style.Label(node, Text.Format(Text.Milestones.Level, { n = milestone.Rebirths }), "Title", Mobile.Small, colors.TextMuted)
		level.Position = UDim2.fromOffset(0, Mobile.RowHeight - Mobile.Small - Mobile.Padding / 2)
		level.Size = UDim2.new(1, 0, 0, Mobile.Small)
		nodes[milestone.Id] = { Circle = circle, Mark = mark, Name = name, Level = level }
		local info = RebirthMilestones.InfoOf(milestone)
		Tooltip.Attach(node, function()
			return info
		end)
	end
	autoButton = Button.new(track, {
		Text = Text.Milestones.AutoUpgradeLabel,
		Kind = "Confirm",
		TextSize = Mobile.Body,
		OnClick = function()
			local data = DataController:Get()
			if data then
				setAutoUpgrade:FireServer(not data.AutoUpgrade)
			end
		end,
	})
	autoButton.Instance.AnchorPoint = Vector2.new(0, 1)
	autoButton.Instance.Position = UDim2.new(0, Mobile.Padding, 1, -Mobile.Padding / 2)
	autoButton.Instance.Size = UDim2.new(1, -Mobile.Padding * 2, 0, Mobile.Touch)
	autoButton.Instance.Visible = false
	Tooltip.Attach(autoButton.Instance, function()
		return Text.Milestones.AutoUpgradeInfo
	end)

	keeps = Style.Label(column, "", "Body", Mobile.Body, colors.TextMuted)
	keeps.LayoutOrder = 5
	keeps.Size = UDim2.new(1, -Mobile.Scrollbar - Mobile.Padding * 2, 0, Mobile.Touch * 2)
	keeps.TextWrapped = true

	confirm = Button.new(content, {
		Text = words.Confirm,
		Kind = "Confirm",
		Icon = "Menu_Rebirth",
		Sound = "Confirm",
		TextSize = Mobile.Title,
		OnClick = function()
			local data = DataController:Get()
			if data and not DragonStats.IsAtRebirthCap(data) and data.Gold >= DragonStats.GetRebirthCost(data.Rebirths) then
				confirmationWindow:Open()
			end
		end,
	})
	confirm.Instance.AnchorPoint = Vector2.new(0, 1)
	confirm.Instance.Position = UDim2.new(0, 0, 1, 0)
	confirm.Instance.Size = UDim2.new(0.6, -Mobile.Gap / 2, 0, Mobile.Touch)

	local cancel = Button.new(content, {
		Text = words.Cancel,
		Kind = "Cancel",
		TextSize = Mobile.Body,
		OnClick = function()
			window:Close()
		end,
	})
	cancel.Instance.AnchorPoint = Vector2.new(1, 1)
	cancel.Instance.Position = UDim2.new(1, 0, 1, 0)
	cancel.Instance.Size = UDim2.new(0.4, -Mobile.Gap / 2, 0, Mobile.Touch)

	-- Explicit confirmation: the reset warning is always visible before the server request is made.
	confirmationWindow = Window.new({
		Name = "RebirthConfirm", Title = words.ConfirmHeading, Icon = "Menu_Rebirth",
		Size = UDim2.new(0.9, 0, 0.75, 0), MaxSize = Vector2.new(Mobile.MerchantWidth, Mobile.RebirthTrackHeight + Mobile.Touch),
	})
	local confirmationBody = Instance.new("ScrollingFrame")
	confirmationBody.Name = "Warning"
	confirmationBody.BackgroundTransparency = 1
	confirmationBody.BorderSizePixel = 0
	confirmationBody.Size = UDim2.new(1, 0, 1, -(Mobile.Touch + Mobile.Gap))
	confirmationBody.ScrollBarThickness = Mobile.Scrollbar
	confirmationBody.ScrollBarImageColor3 = colors.Trim
	confirmationBody.ScrollingDirection = Enum.ScrollingDirection.Y
	confirmationBody.AutomaticCanvasSize = Enum.AutomaticSize.Y
	confirmationBody.CanvasSize = UDim2.new()
	confirmationBody.Parent = confirmationWindow.Content
	confirmationCost = Style.Label(confirmationBody, "", "Title", Mobile.Title, colors.Gold)
	confirmationCost.Size = UDim2.new(1, -Mobile.Scrollbar, 0, Mobile.Touch)
	local warning = Style.Label(confirmationBody, words.ConfirmWarning, "Body", Mobile.Body, colors.Text)
	warning.Position = UDim2.fromOffset(0, Mobile.Touch + Mobile.Gap)
	warning.Size = UDim2.new(1, -Mobile.Scrollbar, 0, 0)
	warning.AutomaticSize = Enum.AutomaticSize.Y
	warning.TextYAlignment = Enum.TextYAlignment.Top
	finalConfirm = Button.new(confirmationWindow.Content, {
		Text = words.ConfirmFinal, Kind = "Confirm", TextSize = Mobile.Body,
		OnClick = function()
			local data = DataController:Get()
			if data and not DragonStats.IsAtRebirthCap(data) and data.Gold >= DragonStats.GetRebirthCost(data.Rebirths) then
				requestRebirth:FireServer()
				confirmationWindow:Close()
			end
		end,
	})
	finalConfirm.Instance.AnchorPoint = Vector2.new(0, 1)
	finalConfirm.Instance.Position = UDim2.fromScale(0, 1)
	finalConfirm.Instance.Size = UDim2.new(0.65, -Mobile.Gap / 2, 0, Mobile.Touch)
	local back = Button.new(confirmationWindow.Content, { Text = words.Back, Kind = "Neutral", TextSize = Mobile.Body, OnClick = function()
		confirmationWindow:Close()
		window:Open()
	end })
	back.Instance.AnchorPoint = Vector2.new(1, 1)
	back.Instance.Position = UDim2.fromScale(1, 1)
	back.Instance.Size = UDim2.new(0.35, -Mobile.Gap / 2, 0, Mobile.Touch)
	window:OnOpen(refresh)
	confirmationWindow:OnOpen(refresh)

	button.Activated:Connect(function()
		refresh()
		window:Toggle()
	end)

	DataController:OnChanged("Gold", refresh)
	DataController:OnChanged("Rebirths", refresh)
	DataController:OnChanged("AutoUpgrade", refresh)
end

return RebirthController
