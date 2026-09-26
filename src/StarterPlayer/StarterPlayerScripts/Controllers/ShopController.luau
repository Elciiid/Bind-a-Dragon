--!strict
-- Shop window: the "Shop" menu tile opens the game passes and developer products from Config/Products, each as a
-- card with its icon (UITheme.ShopIcons), what it does, and a green Robux buy button (Roblox's purchase prompt).
-- Owned passes show "Owned" (Player attribute "Pass_<Key>", set by the server). Items whose Id is still 0 show
-- "Coming soon". Granting happens on the server.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Icon = require(script.Parent.UI.Icon)
local Button = require(script.Parent.UI.Button)
local Window = require(script.Parent.UI.Window)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local ShopController = {}

local player = Players.LocalPlayer
local refreshers: { () -> () } = {}

local function makeCard(list: Instance, key: string, order: number)
	local theme = UITheme
	local pass = Products.Passes[key]
	local product = Products.Products[key]
	local item = pass or product
	if item == nil then
		warn(`[ShopController] Unknown shop item {key}`)
		return
	end

	local card = Instance.new("Frame")
	card.Name = key
	card.LayoutOrder = order
	card.Size = UDim2.new(1, -8, 0, 84)
	Style.CardLook(card, theme.Colors.Primary)
	card.Parent = list

	local icon = Icon.new(card, theme.ShopIcons[key] or "", theme.Colors.Neutral, item.Name)
	icon.Position = UDim2.fromOffset(14, 12)
	icon.Size = UDim2.fromOffset(60, 60)

	local name = Style.Label(card, item.Name, "Heavy", 18, theme.Colors.Gold)
	name.Position = UDim2.fromOffset(84, 6)
	name.Size = UDim2.new(0.68, -84, 0, 22)
	name.TextXAlignment = Enum.TextXAlignment.Left
	-- Descriptions say exactly what a pass does, so they wrap at a fixed readable size instead of shrinking.
	local detail = Style.Label(card, item.Description, "Body", 13, theme.Colors.TextMuted)
	detail.Position = UDim2.fromOffset(84, 30)
	detail.Size = UDim2.new(0.68, -84, 0, 48)
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextYAlignment = Enum.TextYAlignment.Top

	local buy = Button.new(card, {
		Text = `R$ {item.Robux}`,
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
	buy.Instance.AnchorPoint = Vector2.new(1, 0.5)
	buy.Instance.Position = UDim2.new(1, -12, 0.5, 0)
	buy.Instance.Size = UDim2.new(0.26, 0, 0, 44)

	local function refresh()
		local ownsPass = pass ~= nil and player:GetAttribute(`Pass_{key}`) == true
		if item.Id == 0 then
			buy:SetText("Coming soon")
			buy:SetEnabled(false)
		elseif ownsPass then
			buy:SetText("Owned")
			buy:SetEnabled(false)
		else
			buy:SetText(`R$ {item.Robux}`)
			buy:SetEnabled(true)
		end
		if key == "ElevatorSkip" then
			local data = DataController:Get()
			detail.Text = `{item.Description} · you have {if data then data.ElevatorSkips else 0}`
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
		MaxSize = Vector2.new(580, 460),
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
	Style.Pad(list, 2, 3)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

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
