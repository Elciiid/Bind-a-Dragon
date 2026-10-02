--!strict
-- Local interaction menu; the server validates and prices every purchase.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataController = require(script.Parent.DataController)
local Window = require(script.Parent.UI.Window)
local Style = require(script.Parent.UI.Style)
local Button = require(script.Parent.UI.Button)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local Layout = require(ReplicatedStorage.Shared.Config.Layout)

local MerchantController = {}
local window: Window.Window
local priceLabel: TextLabel
local buy: Button.Button
local activePrompt: ProximityPrompt? = nil

local function validPrompt(prompt: ProximityPrompt): boolean
	if prompt.Name ~= "BuyStardustPrompt" then return false end
	for _, merchant in CollectionService:GetTagged("StarMerchant") do
		if prompt:IsDescendantOf(merchant) then return true end
	end
	return false
end

local function refresh()
	local data = DataController:Get()
	if not data then buy:SetEnabled(false); return end
	local price = DragonStats.GetMerchantPrice(data, Cycle.GetState().NightIndex)
	priceLabel.Text = Text.Format(Text.Merchant.Bundle, { amount = Economy.Merchant.BundleSize, price = Format.Number(price) })
	buy:SetEnabled(data.Gold >= price)
end

function MerchantController:Init()
	window = Window.new({ Name = "StarMerchant", Title = Text.Merchant.Title, Icon = "Stardust", Size = UDim2.fromScale(0.85, 1), MaxSize = Style.Theme.Sizes.MerchantWindow })
	local gap = Style.Theme.Sizes.Gap
	local buttonHeight = Layout.DetailsSize.Y
	local body = Instance.new("ScrollingFrame")
	body.Name = "MerchantInformation"
	body.Size = UDim2.new(1, 0, 1, -(buttonHeight + gap))
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = gap
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.Parent = window.Content
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, gap)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body
	local description = Style.Label(body, Text.Merchant.Description, "Bold", Style.Theme.Sizes.MerchantText, Style.Theme.Colors.Text)
	description.LayoutOrder = 1
	description.Size = UDim2.new(1, -gap * 2, 0, 0)
	description.AutomaticSize = Enum.AutomaticSize.Y
	description.TextWrapped = true
	priceLabel = Style.Label(body, "", "Title", Style.Theme.Sizes.MerchantPriceText, Style.Theme.Colors.Title)
	priceLabel.LayoutOrder = 2
	priceLabel.Size = UDim2.new(1, -gap * 2, 0, Style.Theme.Sizes.MerchantPriceText + gap * 2)
	priceLabel.TextScaled = true
	buy = Button.new(window.Content, { Text = Text.Merchant.Buy, Kind = "Confirm", OnClick = function()
		ReplicatedStorage.Remotes.BuyStardust:FireServer("Bundle")
	end })
	buy.Instance.AnchorPoint = Vector2.new(0, 1)
	buy.Instance.Position = UDim2.fromScale(0.04, 1)
	buy.Instance.Size = UDim2.new(0.56, 0, 0, buttonHeight)
	local exit = Button.new(window.Content, { Text = Text.Merchant.Exit, Kind = "Cancel", OnClick = function() window:Close() end })
	exit.Instance.AnchorPoint = Vector2.new(0, 1)
	exit.Instance.Position = UDim2.fromScale(0.64, 1)
	exit.Instance.Size = UDim2.new(0.32, 0, 0, buttonHeight)
	window:OnOpen(refresh)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if player ~= Players.LocalPlayer or not validPrompt(prompt) then return end
		activePrompt = prompt
		window:Open()
	end)
	DataController:OnChanged("Gold", refresh)
	DataController:OnChanged("MerchantPurchases", refresh)
end

function MerchantController:Start()
	while true do
		if window.IsOpen then
			local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			local anchor = activePrompt and activePrompt.Parent
			local position = if anchor and anchor:IsA("BasePart") then anchor.Position elseif anchor and anchor:IsA("Attachment") then anchor.WorldPosition else nil
			if not activePrompt or not activePrompt:IsDescendantOf(workspace) or not validPrompt(activePrompt) or not root or not root:IsA("BasePart") or not position or (root.Position - position).Magnitude > Economy.Merchant.PurchaseRange then
				window:Close()
			else refresh() end
		end
		task.wait(Economy.Merchant.MenuUpdateInterval)
	end
end
return MerchantController
