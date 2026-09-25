--!strict
-- Shop: a "Shop" button (left button column) opens the game passes and developer products from Config/Products with a Buy
-- button each (Roblox's purchase prompt). Owned passes show "Owned" (Player attribute "Pass_<Key>", set by the
-- server). Items whose Id is still 0 show "Coming soon". Granting happens on the server. Placeholder UI.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local Products = require(ReplicatedStorage.Shared.Config.Products)

local DARK = Color3.fromRGB(15, 15, 30)
local CARD = Color3.fromRGB(32, 32, 55)
local GREY = Color3.fromRGB(120, 120, 130)
local GOLD = Color3.fromRGB(255, 210, 70)
local GREEN = Color3.fromRGB(130, 230, 140)

local ShopController = {}

local player = Players.LocalPlayer
local refreshers: { () -> () } = {}

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

local function label(parent: Instance, text: string, color: Color3, bold: boolean, position: UDim2, size: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = position
	l.Size = size
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = color
	l.Text = text
	l.Parent = parent
	return l
end

local function makeCard(list: Instance, key: string, order: number)
	local pass = Products.Passes[key]
	local product = Products.Products[key]
	local item = pass or product
	if item == nil then
		warn(`[ShopController] Unknown shop item {key}`)
		return
	end

	local card = Instance.new("Frame")
	card.LayoutOrder = order
	card.Size = UDim2.new(1, -8, 0, 62)
	card.BackgroundColor3 = CARD
	round(card)
	card.Parent = list

	label(card, item.Name, GOLD, true, UDim2.new(0, 10, 0, 6), UDim2.new(0.68, -10, 0, 22))
	local detail = label(card, item.Description, Color3.fromRGB(200, 200, 215), false, UDim2.new(0, 10, 0, 32), UDim2.new(0.68, -10, 0, 22))
	detail.TextWrapped = true

	local buy = Instance.new("TextButton")
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.new(1, -10, 0.5, 0)
	buy.Size = UDim2.new(0.3, 0, 0, 38)
	buy.TextColor3 = DARK
	buy.Font = Enum.Font.GothamBold
	buy.TextScaled = true
	round(buy)
	pad(buy, 6)
	buy.Parent = card

	local function refresh()
		local ownsPass = pass ~= nil and player:GetAttribute(`Pass_{key}`) == true
		if item.Id == 0 then
			buy.Text, buy.BackgroundColor3, buy.AutoButtonColor = "Coming soon", GREY, false
		elseif ownsPass then
			buy.Text, buy.BackgroundColor3, buy.AutoButtonColor = "Owned", GREEN, false
		else
			buy.Text, buy.BackgroundColor3, buy.AutoButtonColor = `R$ {item.Robux}`, GOLD, true
		end
		if key == "ElevatorSkip" then
			local data = DataController:Get()
			detail.Text = `{item.Description}  ·  you have {if data then data.ElevatorSkips else 0}`
		end
	end
	table.insert(refreshers, refresh)
	refresh()
	if pass then
		player:GetAttributeChangedSignal(`Pass_{key}`):Connect(refresh)
	end

	buy.Activated:Connect(function()
		if item.Id == 0 or (pass and player:GetAttribute(`Pass_{key}`) == true) then
			return
		end
		if pass then
			MarketplaceService:PromptGamePassPurchase(player, item.Id)
		else
			MarketplaceService:PromptProductPurchase(player, item.Id)
		end
	end)
end

function ShopController:Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Shop"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local open = Instance.new("TextButton")
	open.AnchorPoint = Vector2.new(0, 1)
	open.Position = UDim2.new(0, 16, 1, -352) -- above the Quests button (top left is Roblox's chat)
	open.Size = UDim2.new(0, 160, 0, 40)
	open.BackgroundColor3 = GOLD
	open.TextColor3 = DARK
	open.Font = Enum.Font.GothamBold
	open.TextScaled = true
	open.Text = "Shop"
	round(open)
	pad(open, 6)
	open.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.92, 0, 0.7, 0)
	panel.BackgroundColor3 = DARK
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	round(panel)
	panel.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(520, 420)
	limit.Parent = panel

	label(panel, "Shop", Color3.new(1, 1, 1), true, UDim2.new(0, 14, 0, 10), UDim2.new(1, -70, 0, 26))

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

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.new(0, 10, 0, 46)
	list.Size = UDim2.new(1, -20, 1, -56)
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

	for order, key in Products.ShopOrder do
		makeCard(list, key, order)
	end

	open.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
	DataController:OnChanged("ElevatorSkips", function()
		for _, refresh in refreshers do
			refresh()
		end
	end)
end

return ShopController
