--!strict
-- Items: the Items tab of the Inventory window (InventoryWindow): a big card per item with its icon, count,
-- purpose and source. Wording in Config/Text.Items.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local InventoryWindow = require(script.Parent.InventoryWindow)
local Style = require(script.Parent.UI.Style)
local Icon = require(script.Parent.UI.Icon)
local Format = require(ReplicatedStorage.Shared.Format)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local ItemsController = {}

type Card = { DataKey: string, Count: TextLabel }
local cards: { Card } = {}

local ITEMS = {
	{ Key = "WyrmRunes", Icon = "WyrmRune", Color = Color3.fromRGB(200, 160, 255), Words = "WyrmRunes" },
	{ Key = "Dragonstones", Icon = "Dragonstone", Color = Color3.fromRGB(255, 150, 120), Words = "Dragonstones" },
	{ Key = "Stardust", Icon = "Stardust", Color = UITheme.Colors.Stardust, Words = "Stardust" },
	{ Key = "EchoSigils", Icon = "Stardust", Color = Color3.fromRGB(130, 210, 255), Words = "EchoSigils" },
}

local function refresh()
	local data = DataController:Get()
	if data == nil then
		return
	end
	for _, card in cards do
		card.Count.Text = `x{Format.Number((data :: any)[card.DataKey] or 0)}`
	end
end

function ItemsController:Init()
	local tab = InventoryWindow.AddTab("Items")
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Size = UDim2.fromScale(1, 1)
	list.Parent = tab.Content
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for order, item in ITEMS do
		local words = (Text.Items :: any)[item.Words]
		local card = Instance.new("Frame")
		card.Name = item.Key
		card.LayoutOrder = order
		card.Size = UDim2.new(1, 0, 0.25, -8)
		Style.CardLook(card, item.Color)
		card.Parent = list
		local icon = Icon.new(card, item.Icon, item.Color)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, 12, 0.5, 0)
		icon.Size = UDim2.fromScale(0.8, 0.8)
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.Parent = icon
		local name = Style.Label(card, words.Name, "Title", 22, item.Color)
		name.Position = UDim2.new(0.16, 0, 0.08, 0)
		name.Size = UDim2.new(0.6, 0, 0.36, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextScaled = true
		local count = Style.Label(card, "x0", "Title", 26, UITheme.Colors.Text)
		count.AnchorPoint = Vector2.new(1, 0)
		count.Position = UDim2.new(1, -14, 0.08, 0)
		count.Size = UDim2.new(0.22, 0, 0.4, 0)
		count.TextXAlignment = Enum.TextXAlignment.Right
		count.TextScaled = true
		local info = Style.Label(card, words.Info, "Bold", 15, UITheme.Colors.TextMuted)
		info.Position = UDim2.new(0.16, 0, 0.5, 0)
		info.Size = UDim2.new(0.82, 0, 0.44, 0)
		info.TextXAlignment = Enum.TextXAlignment.Left
		info.TextYAlignment = Enum.TextYAlignment.Top
		info.TextWrapped = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 16
		limit.Parent = info
		info.TextScaled = true
		table.insert(cards, { DataKey = item.Key, Count = count })
	end

	tab:OnOpen(refresh)
	for _, item in ITEMS do
		DataController:OnChanged(item.Key, refresh)
	end
end

return ItemsController
