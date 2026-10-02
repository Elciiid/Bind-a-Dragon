--!strict
-- Shop window: the "Shop" menu icon opens the game passes and developer products from Config/Products as big cards in
-- a grid (UI renewal part 2): the icon big (UITheme.ShopIcons), the name, one short line (Config/Text.Shop.Short; the
-- full description is in the tooltip) and a big jade Robux button (Roblox's purchase prompt).
-- Owned passes show "Owned" (Player attribute "Pass_<Key>", set by the server). Items whose Id is still 0 show
-- "Coming soon". Granting happens on the server.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Icon = require(script.Parent.UI.Icon)
local Tooltip = require(script.Parent.UI.Tooltip)
local Button = require(script.Parent.UI.Button)
local Window = require(script.Parent.UI.Window)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local ShopController = {}

local player = Players.LocalPlayer
local refreshers: { () -> () } = {}

local function makeCard(list: Instance, key: string, order: number)
	local theme = UITheme
	local pass = Products.Passes[key]
	local product = Products.Products[key]
	local item = pass or product
	if item == nil or item.Disabled then
		warn(`[ShopController] Unknown shop item {key}`)
		return
	end

	local card = Instance.new("Frame")
	card.Name = key
	card.LayoutOrder = order
	Style.CardLook(card, theme.Colors.Gold)
	card.Parent = list

	local icon = Icon.new(card, theme.ShopIcons[key] or "", theme.Colors.Neutral, item.Name)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 8, 0.5, 0)
	icon.Size = UDim2.fromOffset(96, 96)
	icon.ZIndex = 3

	local name = Style.Label(card, item.Name, "Title", 21, theme.Colors.Gold)
	name.Position = UDim2.fromOffset(110, 12)
	name.Size = UDim2.new(1, -120, 0, 26)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextScaled = true
	name.ZIndex = 3
	Style.Outline(name, 2)
	local nameLimit = Instance.new("UITextSizeConstraint")
	nameLimit.MaxTextSize = 22
	nameLimit.Parent = name
	local detail = Style.Label(card, Text.Shop.Short[key] or item.Description, "Bold", 14, theme.Colors.Text)
	detail.Position = UDim2.fromOffset(110, 40)
	detail.Size = UDim2.new(1, -120, 0, 36)
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextYAlignment = Enum.TextYAlignment.Top
	detail.ZIndex = 3
	Tooltip.Attach(card, function()
		return item.Description
	end)

	local buy = Button.new(card, {
		Text = `R$ {item.Robux}`,
		TextSize = 20,
		Kind = "Confirm",
		Sound = "Click",
		OnClick = function()
			if item.Id == 0 or (pass and player:GetAttribute(`Pass_{key}`) == true) then
				return
			end
			if pass then
				MarketplaceService:PromptGamePassPurchase(player, item.Id)
			else
				MarketplaceService:PromptProductPurchase(player, item.Id)
			end
		end,
	})
	buy.Instance.AnchorPoint = Vector2.new(0, 1)
	buy.Instance.Position = UDim2.new(0, 110, 1, -12)
	buy.Instance.Size = UDim2.new(1, -122, 0, 44)
	buy.Instance.ZIndex = 3

	local function refresh()
		local ownsPass = pass ~= nil and player:GetAttribute(`Pass_{key}`) == true
		if item.Id == 0 then
			buy:SetText(Text.Shop.ComingSoon)
			buy:SetEnabled(false)
		elseif ownsPass then
			buy:SetText(Text.Shop.Owned)
			buy:SetEnabled(false)
		else
			buy:SetText(`R$ {item.Robux}`)
			buy:SetEnabled(true)
		end
		if key == "ElevatorSkip" then
			local data = DataController:Get()
			detail.Text = `{Text.Shop.Short[key] or ""} · {Text.Format(Text.Shop.SkipsOwned, { n = if data then data.ElevatorSkips else 0 })}`
		end
	end
	table.insert(refreshers, refresh)
	refresh()
	if pass then
		player:GetAttributeChangedSignal(`Pass_{key}`):Connect(refresh)
	end
end

function ShopController:Init()
	local open = HudLayout.AddMenuButton("Shop")
	local window = Window.new({
		Name = "Shop",
		Title = "Shop",
		Icon = "Menu_Shop",
		Size = UDim2.new(0.92, 0, 0.72, 0),
		MaxSize = Vector2.new(700, 372),
	})

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = UITheme.Colors.Trim
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = window.Content
	Style.Pad(list, 6, 6)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -6, 0, 132)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list
	HudLayout.OnLayoutChanged(function(phone)
		grid.CellSize = UDim2.new(0.5, -6, 0, if phone then 118 else 132)
	end)

	for order, key in Products.ShopOrder do
		makeCard(list, key, order)
	end

	open.Activated:Connect(function()
		window:Toggle()
	end)
	DataController:OnChanged("ElevatorSkips", function()
		for _, refresh in refreshers do
			refresh()
		end
	end)
end

return ShopController
