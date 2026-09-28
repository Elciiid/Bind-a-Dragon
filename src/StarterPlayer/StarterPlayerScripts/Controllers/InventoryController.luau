--!strict
-- Dragon inventory: the Dragons tab of the Inventory window (InventoryWindow), UI renewal part 2. A card per dragon,
-- tinted and glowing in its rarity color: a picture (UI/DragonPicture: its model, or a big rarity icon), the rarity
-- icon and level on top, the name big, "Rarity · Element" small, the income/s big, ONE "Upgrade" button with the cost
-- (tap = +1 level; hold = keeps upgrading, faster the longer it's held) and a small In roost / Resting switch.
-- Power, trait and grade are in the card's tooltip. The header shows the counts and an "Equip best" button (the
-- server fills the roost with the highest earners: RoostService EquipBest). Wording in Config/Text.Dragons; the
-- hold timing in UITheme.Motion (Upgrade*). The server checks everything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Icon = require(script.Parent.UI.Icon)
local Button = require(script.Parent.UI.Button)
local Tooltip = require(script.Parent.UI.Tooltip)
local DragonPicture = require(script.Parent.UI.DragonPicture)
local InventoryWindow = require(script.Parent.InventoryWindow)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

local levelUpDragon = ReplicatedStorage.Remotes.LevelUpDragon :: RemoteEvent
local placeInRoost = ReplicatedStorage.Remotes.PlaceInRoost :: RemoteEvent
local returnFromRoost = ReplicatedStorage.Remotes.ReturnFromRoost :: RemoteEvent
local equipBest = ReplicatedStorage.Remotes.EquipBest :: RemoteEvent

local REFRESH_INTERVAL = 0.25 -- seconds; while open, changed values are written into the existing cards
local CARD = Vector2.new(200, 246) -- design size of a card (phones scale it by UITheme.Sizes.PhoneCardScale)

local words = Text.Dragons
local colors = UITheme.Colors

local InventoryController = {}

local window: InventoryWindow.Tab
local list: ScrollingFrame
local grid: UIGridLayout
local headerText: TextLabel
local runeCount: TextLabel
local stoneCount: TextLabel
local dirty = true
local cardScale = 1

type Card = {
	Cell: Frame,
	Card: Frame,
	Scale: UIScale,
	Picture: Frame,
	PictureStage: string?,
	Level: TextLabel,
	Name: TextLabel,
	Income: TextLabel,
	Upgrade: Button.Button,
	Switch: Frame,
	Knob: Frame,
	SwitchLabel: TextLabel,
	InRoost: boolean?,
	Tooltip: string,
}

local cards: { [string]: Card } = {}

local function setText(label: TextLabel, value: string)
	if label.Text ~= value then
		label.Text = value
	end
end

local function rarityColor(rarityId: string): Color3
	local rarity = UITheme.Rarity[rarityId]
	return if rarity then rarity.Color else colors.Gold
end

-- Tap = one level; hold = keep buying, a few levels per request after a moment, more the longer it's held.
local function attachHold(button: Button.Button, dragonId: string)
	local motion = UITheme.Motion
	local holding = 0
	button.Instance.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
			return
		end
		holding += 1
		local token = holding
		local started = os.clock()
		task.delay(motion.UpgradeHoldDelay, function()
			while holding == token and button.Enabled do
				local held = os.clock() - started
				local levels = if held > motion.UpgradeRampFast then 25 elseif held > motion.UpgradeRamp then 5 else 1
				levelUpDragon:FireServer(dragonId, levels)
				task.wait(motion.UpgradeRepeat)
			end
		end)
	end)
	button.Instance.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			holding += 1 -- stops the repeat
		end
	end)
	button.Instance.MouseLeave:Connect(function()
		holding += 1
	end)
end

-- Builds a dragon's card once; updateCard fills in the values. Cards are kept between refreshes, so buttons keep
-- their hover/press state while gold ticks up.
local function makeCard(dragon: PlayerDataTypes.Dragon): Card
	local species = Dragons[dragon.SpeciesId]
	local rarityId = if species then species.Rarity else "Common"
	local accent = if dragon.Starborn then colors.Gold else rarityColor(rarityId)

	-- the grid cell (sized by the grid) holds the card at its design size, scaled for phones
	local cell = Instance.new("Frame")
	cell.Name = `Dragon_{dragon.Id}`
	cell.BackgroundTransparency = 1
	cell.Parent = list
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(CARD.X, CARD.Y)
	Style.CardLook(card, accent)
	card.Parent = cell
	local scale = Instance.new("UIScale")
	scale.Scale = cardScale
	scale.Parent = card

	local picture = Instance.new("Frame")
	picture.Name = "PictureFrame"
	picture.BackgroundTransparency = 1
	picture.AnchorPoint = Vector2.new(0.5, 0)
	picture.Position = UDim2.new(0.5, 0, 0, 4)
	picture.Size = UDim2.new(1, -16, 0, 96)
	picture.ZIndex = 3
	picture.Parent = card

	local rarityIcon = Icon.new(card, `Rarity_{rarityId}`, accent)
	rarityIcon.Position = UDim2.fromOffset(8, 8)
	rarityIcon.Size = UDim2.fromOffset(30, 30)
	rarityIcon.ZIndex = 5
	local level = Style.Label(card, "", "Title", 17, colors.Text)
	level.AnchorPoint = Vector2.new(1, 0)
	level.Position = UDim2.new(1, -9, 0, 8)
	level.Size = UDim2.fromOffset(80, 22)
	level.TextXAlignment = Enum.TextXAlignment.Right
	level.ZIndex = 5
	Style.Outline(level, 1.5)

	local name = Style.Label(card, "", "Title", 22, Style.Shade(accent, 0.3))
	name.Position = UDim2.fromOffset(6, 100)
	name.Size = UDim2.new(1, -12, 0, 26)
	name.TextScaled = true
	name.ZIndex = 3
	Style.Outline(name, 2)
	local sizeLimit = Instance.new("UITextSizeConstraint")
	sizeLimit.MaxTextSize = 22
	sizeLimit.Parent = name
	local sub = Style.Label(card, if species then `{species.Rarity} · {species.Element}` else "", "Bold", 13, colors.TextMuted)
	sub.Position = UDim2.fromOffset(0, 125)
	sub.Size = UDim2.new(1, 0, 0, 16)
	sub.ZIndex = 3

	local incomeRow = Instance.new("Frame")
	incomeRow.BackgroundTransparency = 1
	incomeRow.Position = UDim2.fromOffset(0, 143)
	incomeRow.Size = UDim2.new(1, 0, 0, 28)
	incomeRow.ZIndex = 3
	incomeRow.Parent = card
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.Padding = UDim.new(0, 4)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = incomeRow
	local gold = Icon.new(incomeRow, "Gold", colors.Gold)
	gold.Size = UDim2.fromOffset(26, 26)
	local income = Style.Label(incomeRow, "", "Title", 22, colors.Gold)
	income.LayoutOrder = 2
	income.AutomaticSize = Enum.AutomaticSize.X
	income.Size = UDim2.fromOffset(0, 28)
	income.TextWrapped = false
	Style.Outline(income, 1.5)

	local dragonId = dragon.Id
	local upgrade = Button.new(card, {
		Text = words.Upgrade,
		Kind = "Primary",
		Icon = "Gold",
		TextSize = 17,
		OnClick = function()
			levelUpDragon:FireServer(dragonId, 1)
		end,
	})
	upgrade.Instance.AnchorPoint = Vector2.new(0.5, 1)
	upgrade.Instance.Position = UDim2.new(0.5, 0, 1, -34)
	upgrade.Instance.Size = UDim2.new(1, -16, 0, 40)
	upgrade.Instance.ZIndex = 3
	attachHold(upgrade, dragonId)

	-- small In roost / Resting switch
	local switch = Instance.new("TextButton")
	switch.Name = "RoostSwitch"
	switch.Text = ""
	switch.AutoButtonColor = false
	switch.AnchorPoint = Vector2.new(0.5, 1)
	switch.Position = UDim2.new(0.5, 0, 1, -7)
	switch.Size = UDim2.fromOffset(116, 24)
	switch.ZIndex = 3
	Style.Round(switch)
	Style.GoldBorder(switch, 1.5)
	switch.Parent = card
	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(18, 18)
	knob.BackgroundColor3 = colors.TrimLight
	knob.ZIndex = 4
	Style.Round(knob)
	knob.Parent = switch
	local switchLabel = Style.Label(switch, "", "Title", 13, colors.Text)
	switchLabel.ZIndex = 4
	Style.Outline(switchLabel, 1)
	Style.AttachPress(switch)

	local entry: Card = {
		Cell = cell,
		Card = card,
		Scale = scale,
		Picture = picture,
		PictureStage = nil,
		Level = level,
		Name = name,
		Income = income,
		Upgrade = upgrade,
		Switch = switch :: any,
		Knob = knob,
		SwitchLabel = switchLabel,
		InRoost = nil,
		Tooltip = "",
	}
	switch.Activated:Connect(function()
		if entry.InRoost then
			returnFromRoost:FireServer(dragonId)
		else
			placeInRoost:FireServer(dragonId)
		end
	end)
	Tooltip.Attach(card, function()
		return entry.Tooltip
	end)
	return entry
end

-- Writes the current values into a card; only properties that changed are touched.
local function updateCard(card: Card, dragon: PlayerDataTypes.Dragon, data: PlayerDataTypes.PlayerData, cap: number, inRoost: boolean, order: number)
	local species = Dragons[dragon.SpeciesId]
	local stage = DragonStats.GetStage(dragon.Level)
	if card.Cell.LayoutOrder ~= order then
		card.Cell.LayoutOrder = order
	end
	if card.PictureStage ~= stage.Id then -- (re)draw the picture when the dragon evolves
		card.PictureStage = stage.Id
		for _, child in card.Picture:GetChildren() do
			child:Destroy()
		end
		DragonPicture.new(card.Picture, dragon.SpeciesId, dragon.Level)
	end
	local name = if species then species.Name else dragon.SpeciesId
	setText(card.Name, if dragon.Starborn then `★ {name}` else name)
	setText(card.Level, `Lv {dragon.Level}`)
	setText(card.Income, `{Format.Number(DragonStats.GetGoldPerSecond(dragon))}/s`)
	local trait = DragonStats.GetTrait(dragon)
	local grade = DragonStats.GetGrade(dragon)
	card.Tooltip = Text.Format(words.Tooltip, {
		power = Format.Number(DragonStats.GetPower(dragon)),
		trait = if trait then trait.Name else words.NoTrait,
		grade = if grade then `Grade {grade.Id}` else words.NoGrade,
	}) .. ` · {stage.Name} · Lv {dragon.Level}/{cap}`

	local atCap = dragon.Level >= cap
	local cost = DragonStats.GetLevelUpCost(dragon, data.Rebirths)
	local label = if atCap then words.MaxLevel else `{words.Upgrade}  {Format.Number(cost)}`
	if card.Upgrade.Label.Text ~= label then
		card.Upgrade:SetText(label)
	end
	local enabled = not atCap and data.Gold >= cost
	if card.Upgrade.Enabled ~= enabled then
		card.Upgrade:SetEnabled(enabled)
	end

	if card.InRoost ~= inRoost then
		card.InRoost = inRoost
		card.Switch.BackgroundColor3 = if inRoost then colors.Confirm else colors.Disabled
		card.Knob.Position = if inRoost then UDim2.new(1, -12, 0.5, 0) else UDim2.new(0, 12, 0.5, 0)
		card.SwitchLabel.Text = if inRoost then words.InRoost else words.Resting
		card.SwitchLabel.Position = if inRoost then UDim2.fromOffset(8, 0) else UDim2.fromOffset(24, 0)
		card.SwitchLabel.Size = UDim2.new(1, -32, 1, 0)
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
		if a.Income ~= b.Income then
			return a.Income > b.Income
		end
		return a.Dragon.Id < b.Dragon.Id
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
	for id, card in cards do -- cards of dragons that are gone
		if not seen[id] then
			card.Cell:Destroy()
			cards[id] = nil
		end
	end

	setText(
		headerText,
		if #entries == 0
			then words.Empty
			else Text.Format(words.Header, { count = #entries, placed = #data.RoostDragonIds, slots = DragonStats.GetRoostSlots(data) })
	)
	setText(runeCount, Format.Number(data.WyrmRunes))
	setText(stoneCount, Format.Number(data.Dragonstones))
end

function InventoryController:Init()
	window = InventoryWindow.AddTab("Dragons")
	local content = window.Content

	-- Header: counts + Wyrm Runes / Dragonstones on the left, Equip best on the right.
	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, -170, 0, 40)
	header.Parent = content
	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	headerLayout.Padding = UDim.new(0, 6)
	headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	headerLayout.Parent = header
	headerText = Style.Label(header, "", "Title", 17, colors.TextMuted)
	headerText.LayoutOrder = 1
	headerText.AutomaticSize = Enum.AutomaticSize.X
	headerText.Size = UDim2.fromOffset(0, 26)
	headerText.TextWrapped = false
	Style.Outline(headerText, 1.5)
	local function counter(order: number, iconKey: string, color: Color3): TextLabel
		local icon = Icon.new(header, iconKey, color)
		icon.LayoutOrder = order
		icon.Size = UDim2.fromOffset(28, 28)
		local label = Style.Label(header, "0", "Title", 17, color)
		label.LayoutOrder = order + 1
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.fromOffset(0, 26)
		label.TextWrapped = false
		Style.Outline(label, 1.5)
		return label
	end
	runeCount = counter(10, "WyrmRune", Color3.fromRGB(200, 160, 255))
	stoneCount = counter(20, "Dragonstone", Color3.fromRGB(255, 150, 120))

	local equip = Button.new(content, {
		Text = words.EquipBest,
		Kind = "Confirm",
		Icon = "Menu_Dragons",
		TextSize = 18,
		Sound = "Confirm",
		OnClick = function()
			equipBest:FireServer()
		end,
	})
	equip.Instance.AnchorPoint = Vector2.new(1, 0)
	equip.Instance.Position = UDim2.fromScale(1, 0)
	equip.Instance.Size = UDim2.fromOffset(164, 40)

	list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(0, 48)
	list.Size = UDim2.new(1, 0, 1, -48)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = colors.Trim
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = content
	Style.Pad(list, 6, 6)
	grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = list

	HudLayout.OnLayoutChanged(function(phone)
		cardScale = if phone then UITheme.Sizes.PhoneCardScale else 1
		grid.CellSize = UDim2.fromOffset(math.floor(CARD.X * cardScale), math.floor(CARD.Y * cardScale))
		for _, card in cards do
			card.Scale.Scale = cardScale
		end
		equip.Instance.Size = UDim2.fromOffset(if phone then 120 else 164, if phone then 28 else 40)
		headerText.TextSize = if phone then 13 else 17
		runeCount.TextSize = headerText.TextSize
		stoneCount.TextSize = headerText.TextSize
		list.Position = UDim2.fromOffset(0, if phone then 32 else 48)
		list.Size = UDim2.new(1, 0, 1, if phone then -32 else -48)
	end)

	window:OnOpen(function()
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
