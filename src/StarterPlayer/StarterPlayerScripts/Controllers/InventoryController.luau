--!strict
-- Dragon inventory: the "Dragons" menu tile opens a window (UI/Window) with a card per dragon: element-colored card,
-- rarity gem tag, stage, level, gold/sec, power, trait and grade, and buttons to level up (+1 / +10 / Max) or place
-- it in the roost. The header shows roost slots and Wyrm Runes / Dragonstones. The server checks everything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Icon = require(script.Parent.UI.Icon)
local Button = require(script.Parent.UI.Button)
local RarityTag = require(script.Parent.UI.RarityTag)
local Window = require(script.Parent.UI.Window)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Leveling = require(ReplicatedStorage.Shared.Config.Leveling)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

local levelUpDragon = ReplicatedStorage.Remotes.LevelUpDragon :: RemoteEvent
local placeInRoost = ReplicatedStorage.Remotes.PlaceInRoost :: RemoteEvent

local REFRESH_INTERVAL = 0.5 -- seconds; while open, changed values are written into the existing cards
local CARD_SIZE = Vector2.new(214, 172)

local InventoryController = {}

local window: Window.Window
local list: ScrollingFrame
local headerText: TextLabel
local runeCount: TextLabel
local stoneCount: TextLabel
local dirty = true

local function text(parent: Instance, value: string, kind: Style.TextKind, size: number, color: Color3?, y: number, height: number): TextLabel
	local label = Style.Label(parent, value, kind, size, color)
	label.Position = UDim2.fromOffset(14, y)
	label.Size = UDim2.new(1, -20, 0, height)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextWrapped = false
	return label
end

type Card = {
	Frame: Frame,
	Name: TextLabel,
	Stage: TextLabel,
	Income: TextLabel,
	Info: TextLabel,
	PlusOne: Button.Button,
	PlusTen: Button.Button,
	Max: Button.Button,
	RoostLabel: TextLabel,
	Place: Button.Button,
	Glow: UIStroke?,
	GlowThickness: number,
}

local cards: { [string]: Card } = {}

local function setText(label: TextLabel, value: string)
	if label.Text ~= value then
		label.Text = value
	end
end

local function setButton(button: Button.Button, value: string, enabled: boolean)
	if button.Label.Text ~= value then
		button:SetText(value)
	end
	if button.Enabled ~= enabled then
		button:SetEnabled(enabled)
	end
end

-- Builds a dragon's card once; updateCard fills in the values. Cards are kept between refreshes, so buttons keep
-- their hover/press state while gold ticks up.
local function makeCard(dragon: PlayerDataTypes.Dragon): Card
	local theme = UITheme
	local species = Dragons[dragon.SpeciesId]
	local rarity = species and DragonStats.GetRarity(species.Rarity)
	local element = species and theme.Element[species.Element]

	local card = Instance.new("Frame")
	card.Name = `Dragon_{dragon.Id}`
	Style.CardLook(card, if element then element.Color else nil)
	card.Parent = list

	local name = text(card, "", "Heavy", 18, if rarity then rarity.Color else theme.Colors.Text, 5, 22)

	-- Rarity gem + element + stage
	local tagRow = Instance.new("Frame")
	tagRow.BackgroundTransparency = 1
	tagRow.Position = UDim2.fromOffset(14, 28)
	tagRow.Size = UDim2.new(1, -20, 0, 18)
	tagRow.Parent = card
	local tagLayout = Instance.new("UIListLayout")
	tagLayout.FillDirection = Enum.FillDirection.Horizontal
	tagLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	tagLayout.Padding = UDim.new(0, 6)
	tagLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tagLayout.Parent = tagRow
	if species then
		local tag = RarityTag.new(tagRow, species.Rarity, 18)
		tag.LayoutOrder = 1
	end
	local stageLabel = Style.Label(tagRow, "", "Bold", 13, if element then element.Color else theme.Colors.TextMuted)
	stageLabel.LayoutOrder = 2
	stageLabel.AutomaticSize = Enum.AutomaticSize.X
	stageLabel.Size = UDim2.fromOffset(0, 18)
	stageLabel.TextWrapped = false

	-- Level and income
	local incomeRow = Instance.new("Frame")
	incomeRow.BackgroundTransparency = 1
	incomeRow.Position = UDim2.fromOffset(14, 50)
	incomeRow.Size = UDim2.new(1, -20, 0, 18)
	incomeRow.Parent = card
	local gold = Icon.new(incomeRow, "Gold", theme.Colors.Gold)
	gold.Size = UDim2.fromOffset(18, 18)
	local income = Style.Label(incomeRow, "", "Heavy", 15, theme.Colors.Gold)
	income.Position = UDim2.fromOffset(22, 0)
	income.Size = UDim2.new(1, -22, 1, 0)
	income.TextXAlignment = Enum.TextXAlignment.Left

	local info = text(card, "", "Body", 13, theme.Colors.TextMuted, 70, 16)

	-- Level buttons: two lines ("+1" / cost) so they stay readable on phones.
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(12, 90)
	row.Size = UDim2.new(1, -18, 0, 38)
	row.Parent = card
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	local dragonId = dragon.Id
	local plusOne = Button.new(row, {
		Text = "+1",
		Kind = "Primary",
		TextSize = 13,
		OnClick = function()
			levelUpDragon:FireServer(dragonId, 1)
		end,
	})
	plusOne.Instance.LayoutOrder = 1
	plusOne.Instance.Size = UDim2.new(0.38, -4, 1, 0)
	local plusTen = Button.new(row, {
		Text = "+10",
		Kind = "Primary",
		TextSize = 13,
		OnClick = function()
			levelUpDragon:FireServer(dragonId, 10) -- server buys as many of the 10 as the player can afford
		end,
	})
	plusTen.Instance.LayoutOrder = 2
	plusTen.Instance.Size = UDim2.new(0.36, -4, 1, 0)
	local max = Button.new(row, {
		Text = "Max",
		Kind = "Primary",
		TextSize = 15,
		OnClick = function()
			levelUpDragon:FireServer(dragonId, Leveling.MaxLevelsPerRequest)
		end,
	})
	max.Instance.LayoutOrder = 3
	max.Instance.Size = UDim2.new(0.26, -2, 1, 0)

	-- Roost: a label when placed, a button otherwise (only one shows)
	local roostLabel = text(card, "✓ In roost", "Heavy", 16, theme.Colors.Positive, 136, 26)
	roostLabel.TextXAlignment = Enum.TextXAlignment.Center
	local place = Button.new(card, {
		Text = "Place in roost",
		Kind = "Confirm",
		TextSize = 15,
		OnClick = function()
			placeInRoost:FireServer(dragonId)
		end,
	})
	place.Instance.Position = UDim2.fromOffset(12, 134)
	place.Instance.Size = UDim2.new(1, -18, 0, 30)

	local glow = card:FindFirstChildOfClass("UIStroke")
	return {
		Frame = card,
		Name = name,
		Stage = stageLabel,
		Income = income,
		Info = info,
		PlusOne = plusOne,
		PlusTen = plusTen,
		Max = max,
		RoostLabel = roostLabel,
		Place = place,
		Glow = glow,
		GlowThickness = if glow then glow.Thickness else 0,
	}
end

-- Writes the current values into a card; only properties that changed are touched.
local function updateCard(card: Card, dragon: PlayerDataTypes.Dragon, data: PlayerDataTypes.PlayerData, cap: number, inRoost: boolean, order: number)
	local species = Dragons[dragon.SpeciesId]
	local stage = DragonStats.GetStage(dragon.Level)
	if card.Frame.LayoutOrder ~= order then
		card.Frame.LayoutOrder = order
	end
	local name = if species then species.Name else dragon.SpeciesId
	setText(card.Name, if dragon.Starborn then `★ {name}` else name)
	setText(card.Stage, if species then `{species.Element} · {stage.Name}` else stage.Name)
	setText(card.Income, `{Format.Number(DragonStats.GetGoldPerSecond(dragon))}/s   Lv {dragon.Level}/{cap}`)
	local trait = DragonStats.GetTrait(dragon)
	local grade = DragonStats.GetGrade(dragon)
	setText(
		card.Info,
		`Power {Format.Number(DragonStats.GetPower(dragon))} · {if trait then trait.Name else "No trait"} · {if grade then "Grade " .. grade.Id else "No grade"}`
	)

	local atCap = dragon.Level >= cap
	local oneCost = DragonStats.GetLevelUpCost(dragon, data.Rebirths)
	local tenLevels, tenCost = DragonStats.GetBulkLevelCost(dragon, 10, cap, data.Rebirths)
	local canAfford = not atCap and data.Gold >= oneCost
	setButton(card.PlusOne, if atCap then "Max level" else `+1\n{Format.Number(oneCost)}`, canAfford)
	setButton(card.PlusTen, `+{math.max(tenLevels, 1)}\n{Format.Number(tenCost)}`, tenLevels > 0 and data.Gold >= oneCost)
	setButton(card.Max, "Max", canAfford)

	if card.RoostLabel.Visible ~= inRoost then
		card.RoostLabel.Visible = inRoost
		card.Place.Instance.Visible = not inRoost
	end
	if card.Glow then
		local thickness = if inRoost then 3 else card.GlowThickness
		if card.Glow.Thickness ~= thickness then
			card.Glow.Thickness = thickness
		end
	end
end

local function redraw()
	local data = DataController:Get()
	if data == nil then
		return
	end

	local cap = DragonStats.GetLevelCap(data)
	local entries = {}
	for _, dragon in data.Dragons do
		table.insert(entries, {
			Dragon = dragon,
			InRoost = table.find(data.RoostDragonIds, dragon.Id) ~= nil,
			Income = DragonStats.GetGoldPerSecond(dragon),
		})
	end
	-- Roost dragons first, then by income
	table.sort(entries, function(a, b)
		if a.InRoost ~= b.InRoost then
			return a.InRoost
		end
		return a.Income > b.Income
	end)

	local seen: { [string]: boolean } = {}
	for index, entry in entries do
		local id = entry.Dragon.Id
		seen[id] = true
		local card = cards[id]
		if card == nil then
			card = makeCard(entry.Dragon)
			cards[id] = card
		end
		updateCard(card, entry.Dragon, data, cap, entry.InRoost, index)
	end
	-- cards of dragons that are gone
	for id, card in cards do
		if not seen[id] then
			card.Frame:Destroy()
			cards[id] = nil
		end
	end

	setText(
		headerText,
		`{#entries} dragons · Roost {#data.RoostDragonIds}/{DragonStats.GetRoostSlots(data)}`
			.. (if #entries == 0 then " · Bind at a Star Altar at night!" else "")
	)
	setText(runeCount, tostring(data.WyrmRunes))
	setText(stoneCount, tostring(data.Dragonstones))
end

function InventoryController:Init()
	local open = HudLayout.AddMenuButton("Dragons")
	window = Window.new({
		Name = "Inventory",
		Title = "Dragons",
		Icon = "Menu_Dragons",
		Size = UDim2.new(0.92, 0, 0.78, 0),
		MaxSize = Vector2.new(720, 540),
	})
	local content = window.Content

	-- Header: counts, then Wyrm Runes and Dragonstones with their icons.
	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 22)
	header.Parent = content
	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	headerLayout.Padding = UDim.new(0, 6)
	headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	headerLayout.Parent = header
	headerText = Style.Label(header, "", "Heavy", 16)
	headerText.LayoutOrder = 1
	headerText.AutomaticSize = Enum.AutomaticSize.X
	headerText.Size = UDim2.fromOffset(0, 22)
	headerText.TextWrapped = false
	local function counter(order: number, iconKey: string, color: Color3): TextLabel
		local icon = Icon.new(header, iconKey, color)
		icon.LayoutOrder = order
		icon.Size = UDim2.fromOffset(24, 24)
		local label = Style.Label(header, "0", "Heavy", 16, color)
		label.LayoutOrder = order + 1
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.fromOffset(0, 22)
		label.TextWrapped = false
		return label
	end
	runeCount = counter(10, "WyrmRune", Color3.fromRGB(200, 160, 255))
	stoneCount = counter(20, "Dragonstone", Color3.fromRGB(255, 150, 120))

	list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(0, 28)
	list.Size = UDim2.new(1, 0, 1, -28)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = UITheme.Colors.Trim
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = content
	Style.Pad(list, 2, 3)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = list

	open.Activated:Connect(function()
		window:Toggle()
		dirty = true
	end)

	local function markDirty()
		dirty = true
	end
	for _, key in { "Dragons", "RoostDragonIds", "Gold", "Rebirths", "RoostSlotUpgrades", "WyrmRunes", "Dragonstones" } do
		DataController:OnChanged(key, markDirty)
	end
end

function InventoryController:Start()
	while true do
		if dirty and window.IsOpen then
			dirty = false
			redraw()
		end
		task.wait(REFRESH_INTERVAL)
	end
end

return InventoryController
