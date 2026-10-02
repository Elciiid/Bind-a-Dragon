--!strict
-- The Star Merchant, client side: a speech bubble ("Welcome, binder!") pops up over the NPC when you walk up, talking to it
-- (the E prompt, EconomyService) opens a dialog like other Roblox shops with four choices:
--   [Buy Stardust]  the Stardust bundle (Kyle's live price + purchase, server-validated, EconomyService)
--   [Sell Dragons]  tick the dragons to sell ("Select all Commons"), see the gold (+ Wyrm Runes / Dragonstones) they pay, confirm
--                   (Epic+ and mutated dragons need a second, warning confirm); dragons in the roost, on the hotbar, carried,
--                   locked or the champion are shown but can't be picked (SellService re-checks everything)
--   [Sell Items]    spare potions / Wyrm Runes / Dragonstones for gold
--   [Bye]           closes. The dialog also closes when you walk away or the merchant's tag goes away.
-- Prices come from the same shared functions the server uses (DragonStats.GetSellValue, Config/Economy.Selling).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local Window = require(script.Parent.UI.Window)
local Style = require(script.Parent.UI.Style)
local Button = require(script.Parent.UI.Button)
local Icon = require(script.Parent.UI.Icon)
local DragonPicture = require(script.Parent.UI.DragonPicture)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Boosts = require(ReplicatedStorage.Shared.Config.Boosts)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Mutations = require(ReplicatedStorage.Shared.Config.Mutations)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local Layout = require(ReplicatedStorage.Shared.Config.Layout)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

local words = Text.Merchant
local Selling = Economy.Selling

local MerchantController = {}

type Page = "Menu" | "Buy" | "Dragons" | "Items"

local window: Window.Window
local pages: { [string]: Frame } = {}
local currentPage: Page = "Menu"
local priceLabel: TextLabel
local buy: Button.Button
local activePrompt: ProximityPrompt? = nil

-- sell dragons page
local dragonList: ScrollingFrame
local summary: TextLabel
local sellButton: Button.Button
local confirmFrame: Frame
local confirmTitle: TextLabel
local confirmBody: TextLabel
local confirmYes: Button.Button
local selected: { [string]: boolean } = {}
local riskyStage = false -- the confirm panel is on its second (warning) step
-- sell items page
local itemList: ScrollingFrame

local dirty = false

local function validPrompt(prompt: ProximityPrompt): boolean
	if prompt.Name ~= "BuyStardustPrompt" then
		return false
	end
	for _, merchant in CollectionService:GetTagged("StarMerchant") do
		if prompt:IsDescendantOf(merchant) then
			return true
		end
	end
	return false
end

local function rarityColor(rarityId: string): Color3
	local rarity = (UITheme.Rarity :: any)[rarityId]
	return if rarity then rarity.Color else UITheme.Colors.Gold
end

local function carriedId(): string
	local id = Players.LocalPlayer:GetAttribute("CarryDragonId")
	return if type(id) == "string" then id else ""
end

local function rewardText(runes: number, stones: number): string
	local parts = {}
	if runes > 0 then
		table.insert(parts, `+{runes} Rune{if runes == 1 then "" else "s"}`)
	end
	if stones > 0 then
		table.insert(parts, `+{stones} Stone{if stones == 1 then "" else "s"}`)
	end
	return if #parts > 0 then " · " .. table.concat(parts, " ") else ""
end

---------------------------------------------------------------------------------------------------------------
-- Pages

local function showPage(page: Page)
	currentPage = page
	for name, frame in pages do
		frame.Visible = name == page
	end
	confirmFrame.Visible = false
	riskyStage = false
	dirty = true
end

-- Buy Stardust (the live price)
local function refreshBuy()
	local data = DataController:Get()
	if not data then
		buy:SetEnabled(false)
		return
	end
	local price = DragonStats.GetMerchantPrice(data, Cycle.GetState().NightIndex)
	priceLabel.Text = Text.Format(words.Bundle, { amount = Economy.Merchant.BundleSize, price = Format.Number(price) })
	buy:SetEnabled(data.Gold >= price)
end

-- Sell dragons
type Row = { Dragon: PlayerDataTypes.Dragon, Gold: number, Runes: number, Stones: number, Protection: string?, Risky: boolean }

local function collectRows(data: PlayerDataTypes.PlayerData): { Row }
	local rows: { Row } = {}
	local carried = carriedId()
	for _, dragon in data.Dragons do
		if Dragons[dragon.SpeciesId] then
			local gold, rewards = DragonStats.GetSellValue(dragon, data)
			table.insert(rows, {
				Dragon = dragon,
				Gold = gold,
				Runes = rewards.WyrmRunes,
				Stones = rewards.Dragonstones,
				Protection = DragonStats.GetSellProtection(dragon, data, carried),
				Risky = DragonStats.IsRiskySale(dragon),
			})
		end
	end
	local rank = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5 } :: { [string]: number }
	table.sort(rows, function(a, b)
		if (a.Protection ~= nil) ~= (b.Protection ~= nil) then
			return a.Protection == nil -- sellable first
		end
		local ra, rb = rank[Dragons[a.Dragon.SpeciesId].Rarity] or 9, rank[Dragons[b.Dragon.SpeciesId].Rarity] or 9
		if ra ~= rb then
			return ra < rb
		end
		if a.Dragon.Level ~= b.Dragon.Level then
			return a.Dragon.Level < b.Dragon.Level
		end
		return a.Dragon.Id < b.Dragon.Id
	end)
	return rows
end

local function selectedTotals(rows: { Row }): (number, number, number, number, { Row })
	local count, gold, runes, stones = 0, 0, 0, 0
	local picked: { Row } = {}
	for _, row in rows do
		if selected[row.Dragon.Id] and row.Protection == nil then
			count += 1
			gold += row.Gold
			runes += row.Runes
			stones += row.Stones
			table.insert(picked, row)
		end
	end
	return count, gold, runes, stones, picked
end

local function updateSummary(rows: { Row })
	local count, gold, runes, stones = selectedTotals(rows)
	if count == 0 then
		summary.Text = words.NothingSelected
	else
		summary.Text = Text.Format(words.SellSummary, { count = count, gold = Format.Number(gold), extra = rewardText(runes, stones) })
	end
	sellButton:SetText(Text.Format(words.SellButton, { count = count }))
	sellButton:SetEnabled(count > 0)
end

local rebuildDragons: () -> ()

local function makeDragonRow(row: Row, order: number)
	local dragon = row.Dragon
	local species = Dragons[dragon.SpeciesId]
	local mutation = Mutations.Get(dragon.MutationId)
	local mutated = mutation.Id ~= Mutations.NormalId
	local accent = if mutated then mutation.Color else rarityColor(species.Rarity)
	local protected = row.Protection ~= nil

	local button = Instance.new("TextButton")
	button.Name = `Dragon_{dragon.Id}`
	button.LayoutOrder = order
	button.Text = ""
	button.AutoButtonColor = false
	button.Size = UDim2.new(1, -8, 0, 58)
	button.Parent = dragonList
	Style.CardLook(button, accent)
	if protected then
		button.BackgroundTransparency = 0.55
	end

	local box = Instance.new("Frame")
	box.Name = "Box"
	box.AnchorPoint = Vector2.new(0, 0.5)
	box.Position = UDim2.new(0, 10, 0.5, 0)
	box.Size = UDim2.fromOffset(26, 26)
	box.BackgroundColor3 = if selected[dragon.Id] then UITheme.Colors.Confirm else UITheme.Colors.PanelBottom
	box.ZIndex = 5
	Style.Corner(box, 6)
	Style.Stroke(box, UITheme.Colors.Trim, 2)
	box.Parent = button
	if protected then
		box.Visible = false
	end

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0, 0.5)
	holder.Position = UDim2.new(0, 44, 0.5, 0)
	holder.Size = UDim2.fromOffset(46, 46)
	holder.ZIndex = 3
	holder.Parent = button
	DragonPicture.new(holder, dragon.SpeciesId, dragon.Level)

	local name = Style.Label(button, `{if mutated then mutation.Name .. " " else ""}{species.Name}`, "Title", 18, Style.Shade(accent, 0.3))
	name.AnchorPoint = Vector2.new(0, 0)
	name.Position = UDim2.fromOffset(98, 6)
	name.Size = UDim2.new(1, -250, 0, 24)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.TextWrapped = false
	name.ZIndex = 5
	Style.Outline(name, 1.5)
	local sub = Style.Label(button, `{species.Rarity} · {Text.Format(words.Level, { level = dragon.Level })}`, "Bold", 13, UITheme.Colors.TextMuted)
	sub.Position = UDim2.fromOffset(98, 32)
	sub.Size = UDim2.new(1, -250, 0, 18)
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextWrapped = false
	sub.ZIndex = 5

	if protected then
		local tag = Style.Label(button, (words.Protected :: any)[row.Protection :: string], "Title", 15, UITheme.Colors.Text)
		tag.AnchorPoint = Vector2.new(1, 0.5)
		tag.Position = UDim2.new(1, -12, 0.5, 0)
		tag.Size = UDim2.fromOffset(104, 26)
		tag.BackgroundTransparency = 0.2
		tag.BackgroundColor3 = UITheme.Colors.Cancel
		tag.ZIndex = 6
		Style.Round(tag)
		Style.Outline(tag, 1.2)
	else
		local value = Style.Label(button, `{Format.Number(row.Gold)}`, "Title", 20, UITheme.Colors.Gold)
		value.AnchorPoint = Vector2.new(1, 0)
		value.Position = UDim2.new(1, -12, 0, 6)
		value.Size = UDim2.fromOffset(140, 24)
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.TextWrapped = false
		value.ZIndex = 5
		Style.Outline(value, 1.5)
		local extra = rewardText(row.Runes, row.Stones)
		local bonus = Style.Label(button, if extra ~= "" then string.sub(extra, 5) else "gold", "Bold", 13, UITheme.Colors.TextMuted)
		bonus.AnchorPoint = Vector2.new(1, 0)
		bonus.Position = UDim2.new(1, -12, 0, 32)
		bonus.Size = UDim2.fromOffset(140, 18)
		bonus.TextXAlignment = Enum.TextXAlignment.Right
		bonus.TextWrapped = false
		bonus.ZIndex = 5
		button.Activated:Connect(function()
			selected[dragon.Id] = if selected[dragon.Id] then nil else true
			dirty = true
		end)
	end
end

function rebuildDragons()
	local data = DataController:Get()
	if data == nil then
		return
	end
	local rows = collectRows(data)
	-- forget selections that are gone or became protected
	local valid: { [string]: Row } = {}
	for _, row in rows do
		valid[row.Dragon.Id] = row
	end
	for id in selected do
		local row = valid[id]
		if row == nil or row.Protection ~= nil then
			selected[id] = nil
		end
	end
	local keepScroll = dragonList.CanvasPosition
	for _, child in dragonList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for order, row in rows do
		makeDragonRow(row, order)
	end
	dragonList.CanvasPosition = keepScroll
	updateSummary(rows)
end

local function riskyNames(picked: { Row }): string
	local names = {}
	for _, row in picked do
		if row.Risky then
			local species = Dragons[row.Dragon.SpeciesId]
			local mutation = Mutations.Get(row.Dragon.MutationId)
			table.insert(names, `{if mutation.Id ~= Mutations.NormalId then mutation.Name .. " " else ""}{species.Name} ({species.Rarity}, Lv {row.Dragon.Level})`)
		end
	end
	return table.concat(names, ", ")
end

local function openConfirm()
	local data = DataController:Get()
	if data == nil then
		return
	end
	local rows = collectRows(data)
	local count, gold, runes, stones, picked = selectedTotals(rows)
	if count == 0 then
		return
	end
	riskyStage = false
	confirmBody.TextColor3 = UITheme.Colors.Text
	confirmTitle.Text = Text.Format(words.ConfirmTitle, { count = count })
	confirmBody.Text = Text.Format(words.ConfirmBody, { gold = Format.Number(gold), extra = rewardText(runes, stones) })
	confirmYes:SetText(Text.Format(words.SellButton, { count = count }))
	confirmFrame.Visible = true
end

local function confirmSale()
	local data = DataController:Get()
	if data == nil then
		return
	end
	local rows = collectRows(data)
	local count, _, _, _, picked = selectedTotals(rows)
	if count == 0 then
		confirmFrame.Visible = false
		return
	end
	local names = riskyNames(picked)
	if names ~= "" and not riskyStage then
		-- Epic+ / mutated: a second, warning step
		riskyStage = true
		confirmTitle.Text = words.RiskyTitle
		confirmBody.TextColor3 = UITheme.Colors.Gold
		confirmBody.Text = Text.Format(words.RiskyBody, { names = names })
		confirmYes:SetText(words.RiskyYes)
		return
	end
	local ids = {}
	for _, row in picked do
		table.insert(ids, row.Dragon.Id)
	end
	ReplicatedStorage.Remotes.SellDragons:FireServer(ids, names ~= "")
	selected = {}
	confirmFrame.Visible = false
	riskyStage = false
	dirty = true
end

local function selectCommons()
	local data = DataController:Get()
	if data == nil then
		return
	end
	for _, row in collectRows(data) do
		local species = Dragons[row.Dragon.SpeciesId]
		if row.Protection == nil and species.Rarity == "Common" and not row.Risky then
			selected[row.Dragon.Id] = true
		end
	end
	dirty = true
end

-- Sell items
local function makeItemRow(order: number, key: string, id: string, title: string, iconKey: string, color: Color3, owned: number, seconds: number, income: number, keep: number)
	local each = math.floor(income * seconds)
	local row = Instance.new("Frame")
	row.Name = key
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -8, 0, 62)
	Style.CardLook(row, color)
	row.Parent = itemList
	local icon = Icon.new(row, iconKey, color, title)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 10, 0.5, 0)
	icon.Size = UDim2.fromOffset(44, 44)
	icon.ZIndex = 4
	local name = Style.Label(row, `{title}  {Text.Format(words.Owned, { count = owned })}`, "Title", 18, Style.Shade(color, 0.3))
	name.Position = UDim2.fromOffset(62, 6)
	name.Size = UDim2.new(1, -260, 0, 24)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.TextWrapped = false
	name.ZIndex = 5
	Style.Outline(name, 1.5)
	local price = Style.Label(row, Text.Format(words.Each, { price = Format.Number(each) }), "Bold", 14, UITheme.Colors.Gold)
	price.Position = UDim2.fromOffset(62, 34)
	price.Size = UDim2.new(1, -260, 0, 20)
	price.TextXAlignment = Enum.TextXAlignment.Left
	price.TextWrapped = false
	price.ZIndex = 5
	local spare = owned - keep
	local function sell(count: number)
		ReplicatedStorage.Remotes.SellItems:FireServer(if key:find("^Potion_") then "Potion" else id, id, count)
	end
	local one = Button.new(row, { Text = words.SellOne, Kind = "Confirm", TextSize = 15, OnClick = function() sell(1) end })
	one.Instance.AnchorPoint = Vector2.new(1, 0.5)
	one.Instance.Position = UDim2.new(1, -112, 0.5, 0)
	one.Instance.Size = UDim2.fromOffset(92, 40)
	one.Instance.ZIndex = 5
	one:SetEnabled(spare >= 1 and each > 0)
	local all = Button.new(row, { Text = words.SellAllItems, Kind = "Primary", TextSize = 15, OnClick = function() sell(spare) end })
	all.Instance.AnchorPoint = Vector2.new(1, 0.5)
	all.Instance.Position = UDim2.new(1, -10, 0.5, 0)
	all.Instance.Size = UDim2.fromOffset(96, 40)
	all.Instance.ZIndex = 5
	all:SetEnabled(spare >= 1 and each > 0)
end

local function rebuildItems()
	local data = DataController:Get()
	if data == nil then
		return
	end
	local keepScroll = itemList.CanvasPosition
	for _, child in itemList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local income = DragonStats.GetRoostIncome(data)
	local order = 0
	for _, potion in Boosts.Potions do
		local owned = data.Potions[potion.Id] or 0
		local seconds = (Selling.Items.Potions :: any)[potion.Id]
		if owned > 0 and seconds then
			order += 1
			makeItemRow(order, `Potion_{potion.Id}`, potion.Id, potion.Name, `Potion_{potion.Id}`, potion.Color, owned, seconds, income, if data.ArmedLuckPotion == potion.Id then 1 else 0)
		end
	end
	if data.WyrmRunes > 0 then
		order += 1
		makeItemRow(order, "WyrmRunes", "WyrmRunes", "Wyrm Runes", "WyrmRune", UITheme.Colors.Info, data.WyrmRunes, Selling.Items.WyrmRunes, income, 0)
	end
	if data.Dragonstones > 0 then
		order += 1
		makeItemRow(order, "Dragonstones", "Dragonstones", "Dragonstones", "Dragonstone", UITheme.Colors.Gold, data.Dragonstones, Selling.Items.Dragonstones, income, 0)
	end
	if order == 0 then
		local empty = Style.Label(itemList, words.NothingToSell, "Bold", 18, UITheme.Colors.TextMuted)
		empty.Size = UDim2.new(1, 0, 0, 60)
	elseif income <= 0 then
		local hint = Style.Label(itemList, words.NeedRoost, "Bold", 14, UITheme.Colors.Cancel)
		hint.LayoutOrder = order + 1
		hint.Size = UDim2.new(1, 0, 0, 40)
	end
	itemList.CanvasPosition = keepScroll
end

---------------------------------------------------------------------------------------------------------------
-- Build

local function newPage(name: Page): Frame
	local page = Instance.new("Frame")
	page.Name = name
	page.BackgroundTransparency = 1
	page.Size = UDim2.fromScale(1, 1)
	page.Visible = name == "Menu"
	page.Parent = window.Content
	pages[name] = page
	return page
end

local function backButton(page: Frame, width: number?): Button.Button
	local back = Button.new(page, { Text = words.Back, Kind = "Neutral", TextSize = 18, OnClick = function() showPage("Menu") end })
	back.Instance.AnchorPoint = Vector2.new(0, 1)
	back.Instance.Position = UDim2.fromScale(0, 1)
	back.Instance.Size = UDim2.new(width or 0.3, 0, 0, Layout.TouchTarget + 4)
	return back
end

function MerchantController:Init()
	window = Window.new({
		Name = "StarMerchant",
		Title = words.Title,
		Icon = "Stardust",
		Size = UDim2.fromScale(0.9, 1),
		MaxSize = Vector2.new(640, 540),
	})
	local gap = Style.Theme.Sizes.Gap
	local touch = Layout.TouchTarget + 4

	-- Menu: the merchant's line and the four choices
	local menu = newPage("Menu")
	local line = Style.Label(menu, words.MenuLine, "Title", 22, UITheme.Colors.Text)
	line.Size = UDim2.new(1, 0, 0, 56)
	line.Position = UDim2.fromOffset(0, 0)
	Style.Outline(line, 2)
	local menuList = Instance.new("Frame")
	menuList.BackgroundTransparency = 1
	menuList.Position = UDim2.fromOffset(0, 62)
	menuList.Size = UDim2.new(1, 0, 1, -62)
	menuList.Parent = menu
	local menuLayout = Instance.new("UIListLayout")
	menuLayout.Padding = UDim.new(0, gap + 4)
	menuLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	menuLayout.SortOrder = Enum.SortOrder.LayoutOrder
	menuLayout.Parent = menuList
	local choices = {
		{ words.Buy, "Confirm", "Stardust", function() showPage("Buy") end },
		{ words.SellDragons, "Primary", nil, function() showPage("Dragons") end },
		{ words.SellItems, "Primary", "Potion_GildedDraught", function() showPage("Items") end },
		{ words.Bye, "Cancel", nil, function() window:Close() end },
	}
	local menuButtons: { Button.Button } = {}
	for order, choice in choices do
		local button = Button.new(menuList, { Text = choice[1] :: string, Kind = choice[2] :: any, Icon = choice[3] :: string?, TextSize = 22, OnClick = choice[4] :: () -> () })
		button.Instance.LayoutOrder = order
		button.Instance.Size = UDim2.new(0.8, 0, 0, touch + 6)
		table.insert(menuButtons, button)
	end

	-- Buy Stardust (Kyle's page)
	local buyPage = newPage("Buy")
	local description = Style.Label(buyPage, words.Description, "Bold", Style.Theme.Sizes.MerchantText, UITheme.Colors.Text)
	description.Position = UDim2.fromOffset(0, 0)
	description.Size = UDim2.new(1, 0, 0, 70)
	priceLabel = Style.Label(buyPage, "", "Title", Style.Theme.Sizes.MerchantPriceText, UITheme.Colors.Title)
	priceLabel.Position = UDim2.fromOffset(0, 80)
	priceLabel.Size = UDim2.new(1, 0, 0, Style.Theme.Sizes.MerchantPriceText + gap * 2)
	priceLabel.TextScaled = true
	buy = Button.new(buyPage, { Text = words.Buy, Kind = "Confirm", OnClick = function()
		ReplicatedStorage.Remotes.BuyStardust:FireServer("Bundle")
	end })
	buy.Instance.AnchorPoint = Vector2.new(1, 1)
	buy.Instance.Position = UDim2.fromScale(1, 1)
	buy.Instance.Size = UDim2.new(0.66, 0, 0, touch)
	backButton(buyPage)

	-- Sell Dragons
	local sellPage = newPage("Dragons")
	local info = Style.Label(sellPage, words.SellDragonsLine, "Bold", 14, UITheme.Colors.TextMuted)
	info.Size = UDim2.new(1, 0, 0, 36)
	local commons = Button.new(sellPage, { Text = words.SelectCommons, Kind = "Primary", TextSize = 16, OnClick = selectCommons })
	commons.Instance.Position = UDim2.fromOffset(0, 40)
	commons.Instance.Size = UDim2.new(0.62, 0, 0, 40)
	local clear = Button.new(sellPage, { Text = words.ClearSelection, Kind = "Neutral", TextSize = 16, OnClick = function()
		selected = {}
		dirty = true
	end })
	clear.Instance.Position = UDim2.new(0.64, 0, 0, 40)
	clear.Instance.Size = UDim2.new(0.36, 0, 0, 40)
	dragonList = Instance.new("ScrollingFrame")
	dragonList.Name = "Dragons"
	dragonList.BackgroundTransparency = 1
	dragonList.BorderSizePixel = 0
	dragonList.ScrollBarThickness = 6
	dragonList.ScrollBarImageColor3 = UITheme.Colors.Trim
	dragonList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	dragonList.CanvasSize = UDim2.new()
	dragonList.Position = UDim2.fromOffset(0, 88)
	dragonList.Size = UDim2.new(1, 0, 1, -88 - touch - 40 - gap * 2)
	dragonList.Parent = sellPage
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = dragonList
	summary = Style.Label(sellPage, "", "Title", 17, UITheme.Colors.Gold)
	summary.AnchorPoint = Vector2.new(0, 1)
	summary.Position = UDim2.new(0, 0, 1, -touch - gap)
	summary.Size = UDim2.new(1, 0, 0, 34)
	Style.Outline(summary, 1.5)
	backButton(sellPage)
	sellButton = Button.new(sellPage, { Text = "", Kind = "Confirm", TextSize = 20, OnClick = openConfirm })
	sellButton.Instance.Name = "SellSelected"
	sellButton.Instance.AnchorPoint = Vector2.new(1, 1)
	sellButton.Instance.Position = UDim2.fromScale(1, 1)
	sellButton.Instance.Size = UDim2.new(0.66, 0, 0, touch)

	-- confirm panel (covers the page)
	confirmFrame = Instance.new("Frame")
	confirmFrame.Name = "Confirm"
	confirmFrame.Visible = false
	confirmFrame.Size = UDim2.fromScale(1, 1)
	confirmFrame.BackgroundColor3 = Color3.new(1, 1, 1)
	confirmFrame.ZIndex = 20
	Style.Gradient(confirmFrame, UITheme.Colors.PanelV2Top, UITheme.Colors.PanelV2Bottom)
	Style.Corner(confirmFrame, 12)
	Style.GoldBorder(confirmFrame, 2)
	confirmFrame.Active = true
	confirmFrame.Parent = window.Content
	confirmTitle = Style.Label(confirmFrame, "", "Title", 26, UITheme.Colors.Title)
	confirmTitle.Position = UDim2.fromOffset(12, 16)
	confirmTitle.Size = UDim2.new(1, -24, 0, 40)
	confirmTitle.ZIndex = 21
	Style.Outline(confirmTitle, 2)
	confirmBody = Style.Label(confirmFrame, "", "Bold", 22, UITheme.Colors.Text)
	confirmBody.Position = UDim2.fromOffset(16, 66)
	confirmBody.Size = UDim2.new(1, -32, 1, -66 - touch - 24)
	confirmBody.ZIndex = 21
	confirmYes = Button.new(confirmFrame, { Text = "", Kind = "Confirm", TextSize = 20, OnClick = confirmSale })
	confirmYes.Instance.Name = "ConfirmSell"
	confirmYes.Instance.AnchorPoint = Vector2.new(1, 1)
	confirmYes.Instance.Position = UDim2.new(1, -12, 1, -12)
	confirmYes.Instance.Size = UDim2.new(0.5, -18, 0, touch)
	confirmYes.Instance.ZIndex = 22
	local confirmNo = Button.new(confirmFrame, { Text = words.Cancel, Kind = "Cancel", TextSize = 20, OnClick = function()
		confirmFrame.Visible = false
		riskyStage = false
	end })
	confirmNo.Instance.AnchorPoint = Vector2.new(0, 1)
	confirmNo.Instance.Position = UDim2.new(0, 12, 1, -12)
	confirmNo.Instance.Size = UDim2.new(0.5, -18, 0, touch)
	confirmNo.Instance.ZIndex = 22

	-- Sell Items
	local itemsPage = newPage("Items")
	local itemInfo = Style.Label(itemsPage, words.SellItemsLine, "Bold", 14, UITheme.Colors.TextMuted)
	itemInfo.Size = UDim2.new(1, 0, 0, 36)
	itemList = Instance.new("ScrollingFrame")
	itemList.Name = "Items"
	itemList.BackgroundTransparency = 1
	itemList.BorderSizePixel = 0
	itemList.ScrollBarThickness = 6
	itemList.ScrollBarImageColor3 = UITheme.Colors.Trim
	itemList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	itemList.CanvasSize = UDim2.new()
	itemList.Position = UDim2.fromOffset(0, 42)
	itemList.Size = UDim2.new(1, 0, 1, -42 - touch - gap)
	itemList.Parent = itemsPage
	local itemLayout = Instance.new("UIListLayout")
	itemLayout.Padding = UDim.new(0, 6)
	itemLayout.SortOrder = Enum.SortOrder.LayoutOrder
	itemLayout.Parent = itemList
	backButton(itemsPage)

	-- Short windows (phones, about 270 px of content): the four menu buttons shrink to fit, the explanation lines drop out and the
	-- Sell Dragons summary moves up beside the Select/Clear buttons, so the lists keep room for a few rows.
	local COMPACT_BELOW = 330
	local function applyCompact()
		local height = window.Content.AbsoluteSize.Y
		if height <= 0 then
			return
		end
		local compact = height < COMPACT_BELOW
		line.Size = UDim2.new(1, 0, 0, if compact then 34 else 56)
		line.TextSize = if compact then 18 else 22
		local top = if compact then 38 else 62
		menuList.Position = UDim2.fromOffset(0, top)
		menuList.Size = UDim2.new(1, 0, 1, -top)
		local pad = gap + 4
		local buttonHeight = if compact then math.clamp(math.floor((height - top - pad * 3) / #menuButtons), 34, touch + 6) else touch + 6
		menuLayout.Padding = UDim.new(0, if compact then math.min(pad, 6) else pad)
		for _, button in menuButtons do
			button.Instance.Size = UDim2.new(0.8, 0, 0, buttonHeight)
		end
		info.Visible = not compact
		itemInfo.Visible = not compact
		if compact then
			commons.Instance.Position = UDim2.fromOffset(0, 0)
			commons.Instance.Size = UDim2.new(0.36, 0, 0, 34)
			clear.Instance.Position = UDim2.new(0.38, 0, 0, 0)
			clear.Instance.Size = UDim2.new(0.2, 0, 0, 34)
			summary.AnchorPoint = Vector2.new(1, 0)
			summary.Position = UDim2.new(1, 0, 0, 0)
			summary.Size = UDim2.new(0.4, 0, 0, 34)
			summary.TextSize = 14
			summary.TextScaled = true
			dragonList.Position = UDim2.fromOffset(0, 40)
			dragonList.Size = UDim2.new(1, 0, 1, -40 - touch - gap)
			itemList.Position = UDim2.fromOffset(0, 0)
			itemList.Size = UDim2.new(1, 0, 1, -touch - gap)
		else
			commons.Instance.Position = UDim2.fromOffset(0, 40)
			commons.Instance.Size = UDim2.new(0.62, 0, 0, 40)
			clear.Instance.Position = UDim2.new(0.64, 0, 0, 40)
			clear.Instance.Size = UDim2.new(0.36, 0, 0, 40)
			summary.AnchorPoint = Vector2.new(0, 1)
			summary.Position = UDim2.new(0, 0, 1, -touch - gap)
			summary.Size = UDim2.new(1, 0, 0, 34)
			summary.TextSize = 17
			summary.TextScaled = false
			dragonList.Position = UDim2.fromOffset(0, 88)
			dragonList.Size = UDim2.new(1, 0, 1, -88 - touch - 40 - gap * 2)
			itemList.Position = UDim2.fromOffset(0, 42)
			itemList.Size = UDim2.new(1, 0, 1, -42 - touch - gap)
		end
	end
	window.Content:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyCompact)
	task.defer(applyCompact)

	window:OnOpen(function()
		showPage("Menu")
		refreshBuy()
	end)
	window:OnClose(function()
		activePrompt = nil
		selected = {}
		confirmFrame.Visible = false
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if player ~= Players.LocalPlayer or not validPrompt(prompt) then
			return
		end
		activePrompt = prompt
		window:Open()
	end)
	DataController:OnChanged("Gold", function()
		refreshBuy()
	end)
	DataController:OnChanged("MerchantPurchases", refreshBuy)
	for _, key in { "Dragons", "RoostDragonIds", "Hotbar", "Potions", "WyrmRunes", "Dragonstones", "Rebirths", "RoostIncomeLevel", "RoostSlotUpgrades", "Index", "ArmedLuckPotion" } do
		DataController:OnChanged(key, function()
			dirty = true
		end)
	end
	Players.LocalPlayer:GetAttributeChangedSignal("CarryDragonId"):Connect(function()
		dirty = true
	end)
end

---------------------------------------------------------------------------------------------------------------
-- The speech bubble over each merchant

local bubbles: { [Instance]: BillboardGui } = {}

local function merchantAnchor(merchant: Instance): BasePart?
	if merchant:IsA("BasePart") then
		return merchant
	end
	local anchor = merchant:FindFirstChild("InteractionAnchor", true)
	if anchor and anchor:IsA("BasePart") then
		return anchor
	end
	if merchant:IsA("Model") and merchant.PrimaryPart then
		return merchant.PrimaryPart
	end
	return merchant:FindFirstChildWhichIsA("BasePart", true)
end

local function makeBubble(merchant: Instance): BillboardGui?
	local anchor = merchantAnchor(merchant)
	if anchor == nil then
		return nil
	end
	local top = anchor.Position.Y
	if merchant:IsA("Model") then
		local box, size = merchant:GetBoundingBox()
		top = box.Position.Y + size.Y / 2
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "MerchantBubble"
	gui.Adornee = anchor
	gui.Size = UDim2.fromOffset(230, 56)
	gui.StudsOffsetWorldSpace = Vector3.new(0, top - anchor.Position.Y + 2.2, 0)
	gui.SizeOffset = Vector2.new(0, Economy.Merchant.BubbleRaise) -- in bubble heights: clears the price board under it at any distance
	gui.AlwaysOnTop = false
	gui.MaxDistance = 80
	gui.Enabled = false
	gui.ResetOnSpawn = false
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(1, 1)
	Style.WorldPanel(panel, nil, true)
	panel.Parent = gui
	local label = Style.Label(panel, words.Greeting, "Title", 22, UITheme.Colors.Text)
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	Style.Pad(label, 12, 6)
	Style.Outline(label, 2)
	gui.Parent = anchor
	return gui
end

function MerchantController:Start()
	local BUBBLE_RANGE = 28 -- studs: the bubble shows while you're this close and the dialog is shut
	local seenBubble: { [Instance]: boolean } = {}
	task.spawn(function()
		while true do
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			-- bubbles for every tagged merchant
			for _, merchant in CollectionService:GetTagged("StarMerchant") do
				local gui = bubbles[merchant]
				if gui == nil or gui.Parent == nil then
					gui = makeBubble(merchant)
					if gui then
						bubbles[merchant] = gui
					end
				end
				if gui and root and root:IsA("BasePart") then
					local anchor = merchantAnchor(merchant)
					local near = anchor ~= nil and (root.Position - anchor.Position).Magnitude <= BUBBLE_RANGE
					gui.Enabled = near and not window.IsOpen
					seenBubble[merchant] = near
				end
			end
			-- the open dialog: close when walking away, or when its merchant / prompt is gone
			if window.IsOpen then
				local anchor = activePrompt and activePrompt.Parent
				local position = if anchor and anchor:IsA("BasePart") then anchor.Position elseif anchor and anchor:IsA("Attachment") then anchor.WorldPosition else nil
				if not activePrompt or not activePrompt:IsDescendantOf(workspace) or not validPrompt(activePrompt) or not root or not root:IsA("BasePart") or not position or (root.Position - position).Magnitude > Economy.Merchant.PurchaseRange then
					window:Close()
				else
					refreshBuy()
				end
			end
			task.wait(Economy.Merchant.MenuUpdateInterval)
		end
	end)
	-- list refreshes (debounced; only the visible page is rebuilt)
	task.spawn(function()
		while true do
			if dirty and window.IsOpen then
				dirty = false
				if currentPage == "Dragons" then
					rebuildDragons()
				elseif currentPage == "Items" then
					rebuildItems()
				end
			end
			task.wait(0.15)
		end
	end)
end

return MerchantController
