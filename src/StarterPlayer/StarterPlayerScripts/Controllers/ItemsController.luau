--!strict
-- Readable currency rows. Text determines row height; the list scrolls instead of shrinking four rows to fit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local DataController = require(script.Parent.DataController)
local InventoryWindow = require(script.Parent.InventoryWindow)
local Style = require(script.Parent.UI.Style)
local Icon = require(script.Parent.UI.Icon)
local Format = require(ReplicatedStorage.Shared.Format)
local Milestones = require(ReplicatedStorage.Shared.RebirthMilestones)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local ItemsController = {}
local mobile = UITheme.MobileUI
type Card = { DataKey: string, Count: TextLabel, Info: TextLabel, Name: TextLabel, Frame: Frame }
local cards: { Card } = {}

local ITEMS = {
	{ Key = "WyrmRunes", Icon = "WyrmRune", Color = UITheme.Colors.Constellation, Words = "WyrmRunes" },
	{ Key = "Dragonstones", Icon = "Dragonstone", Color = UITheme.Colors.Negative, Words = "Dragonstones" },
	{ Key = "Stardust", Icon = "Stardust", Color = UITheme.Colors.Stardust, Words = "Stardust" },
	{ Key = "EchoSigils", Icon = "EchoSigil", Color = UITheme.Colors.Info, Words = "EchoSigils" },
}

local function relayout()
	for _, card in cards do
		local width = math.max(mobile.Touch * 4, card.Frame.AbsoluteSize.X)
		local left = mobile.Padding + mobile.Touch + mobile.Gap
		local quantityWidth = math.max(mobile.Touch * 2, math.ceil(TextService:GetTextSize(card.Count.Text, mobile.Title, UITheme.Fonts.Heavy, Vector2.new(width, math.huge)).X))
		local stacked = width < mobile.Touch * 9 or width - left - mobile.Padding - quantityWidth - mobile.Gap < mobile.Touch * 3
		local nameWidth = width - left - mobile.Padding - (if stacked then 0 else quantityWidth + mobile.Gap)
		local nameHeight = math.ceil(TextService:GetTextSize(card.Name.Text, mobile.Title, UITheme.Fonts.Heavy, Vector2.new(math.max(1, nameWidth), math.huge)).Y)
		card.Name.Size = UDim2.fromOffset(nameWidth, nameHeight)
		local countHeight = math.max(mobile.Body * 1.5, math.ceil(TextService:GetTextSize(card.Count.Text, mobile.Title, UITheme.Fonts.Heavy, Vector2.new(if stacked then width - left - mobile.Padding else quantityWidth, math.huge)).Y))
		card.Count.AnchorPoint = if stacked then Vector2.zero else Vector2.new(1, 0)
		card.Count.Position = if stacked then UDim2.fromOffset(left, mobile.Padding + nameHeight + mobile.Gap / 2) else UDim2.new(1, -mobile.Padding, 0, mobile.Padding)
		card.Count.Size = if stacked then UDim2.new(1, -(left + mobile.Padding), 0, countHeight) else UDim2.fromOffset(quantityWidth, countHeight)
		card.Count.TextXAlignment = if stacked then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
		local infoTop = mobile.Padding + math.max(nameHeight, if stacked then 0 else countHeight) + mobile.Gap / 2 + (if stacked then countHeight + mobile.Gap / 2 else 0)
		local infoWidth = width - left - mobile.Padding
		local infoHeight = math.ceil(TextService:GetTextSize(card.Info.Text, mobile.Body, UITheme.Fonts.Body, Vector2.new(math.max(1, infoWidth), math.huge)).Y)
		card.Info.Position = UDim2.fromOffset(left, infoTop)
		card.Info.Size = UDim2.fromOffset(infoWidth, infoHeight)
		card.Frame.Size = UDim2.new(1, 0, 0, math.max(mobile.RowHeight, infoTop + infoHeight + mobile.Padding))
	end
end

local function refresh()
	local data = DataController:Get()
	if data == nil then return end
	for _, card in cards do
		card.Count.Text = Text.Format(Text.Items.Count, { count = Format.Number((data :: any)[card.DataKey] or 0) })
		local itemWords = (Text.Items :: any)[card.DataKey]
		card.Info.Text = Text.Format(itemWords.Info, { cap = Milestones.GetEchoSigilCap(data.Rebirths) })
	end
	relayout()
end

function ItemsController:Init()
	local tab = InventoryWindow.AddTab("Items")
	local list = Instance.new("ScrollingFrame")
	list.Name = "CurrencyList"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.fromScale(1, 1)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ScrollBarThickness = mobile.Scrollbar
	list.ScrollBarImageColor3 = UITheme.Colors.Trim
	list.Parent = tab.Content
	Style.Pad(list, mobile.Padding / 2, mobile.Padding / 2)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, mobile.Gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for order, item in ITEMS do
		local words = (Text.Items :: any)[item.Words]
		local frame = Instance.new("Frame")
		frame.Name = item.Key
		frame.LayoutOrder = order
		frame.Size = UDim2.new(1, 0, 0, mobile.RowHeight)
		Style.CardLook(frame, item.Color)
		frame.Parent = list
		local icon = Icon.new(frame, item.Icon, item.Color)
		icon.Position = UDim2.fromOffset(mobile.Padding, mobile.Padding)
		icon.Size = UDim2.fromOffset(mobile.Touch, mobile.Touch)
		icon.ZIndex = 3
		local name = Style.Label(frame, words.Name, "Heavy", mobile.Title, UITheme.Colors.Text)
		name.Position = UDim2.fromOffset(mobile.Padding + mobile.Touch + mobile.Gap, mobile.Padding)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextYAlignment = Enum.TextYAlignment.Top
		name.ZIndex = 3
		local count = Style.Label(frame, "", "Heavy", mobile.Title, item.Color)
		count.ZIndex = 3
		local info = Style.Label(frame, words.Info, "Body", mobile.Body, UITheme.Colors.TextMuted)
		info.TextXAlignment = Enum.TextXAlignment.Left
		info.TextYAlignment = Enum.TextYAlignment.Top
		info.ZIndex = 3
		table.insert(cards, { DataKey = item.Key, Count = count, Info = info, Name = name, Frame = frame })
	end
	tab.Content:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	tab:OnOpen(refresh)
	for _, item in ITEMS do
		DataController:OnChanged(item.Key, refresh)
	end
	DataController:OnChanged("Rebirths", refresh)
	relayout()
end

return ItemsController
