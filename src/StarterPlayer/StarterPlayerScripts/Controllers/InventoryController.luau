--!strict
-- Readable Dragons-tab cards reflow into columns without shrinking their text. Dragon art is separate from
-- Favorite, Details, Upgrade and roost touch actions; current income and power stay visible. Long names grow
-- the card height. Sorting is local only; every progression/placement/favorite request is checked by the server.
-- Upgrade hold timing remains in UITheme.Motion (Upgrade*), wording in Config/Text.Dragons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

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
local Mutations = require(ReplicatedStorage.Shared.Config.Mutations)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local BindingOdds = require(ReplicatedStorage.Shared.BindingOdds)
local OddsText = require(ReplicatedStorage.Shared.OddsText)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

local levelUpDragon = ReplicatedStorage.Remotes.LevelUpDragon :: RemoteEvent
local placeInRoost = ReplicatedStorage.Remotes.PlaceInRoost :: RemoteEvent
local returnFromRoost = ReplicatedStorage.Remotes.ReturnFromRoost :: RemoteEvent
local equipBest = ReplicatedStorage.Remotes.EquipBest :: RemoteEvent
local setDragonFavorite = ReplicatedStorage.Remotes.SetDragonFavorite :: RemoteEvent
local DragDrop = require(script.Parent.UI.DragDrop)

local REFRESH_INTERVAL = 0.25 -- seconds; while open, changed values are written into the existing cards
local mobile = UITheme.MobileUI
local CARD = mobile.DragonCard -- fixed readable cards; narrow viewports scroll, rather than scaling their text

local words = Text.Dragons
local colors = UITheme.Colors

local InventoryController = {}

local window: InventoryWindow.Tab
local list: ScrollingFrame
local gridHost: Frame
local grid: UIGridLayout
local headerText: TextLabel
local runeCount: TextLabel
local stoneCount: TextLabel
local emptyState: TextLabel
local dirty = true
local sortMode = "Income"
local layoutCards: (() -> ())? = nil

type Card = {
	Cell: Frame,
	Card: Frame,
	Picture: Frame,
	PictureStage: string?,
	Level: TextLabel,
	Name: TextLabel,
	Identity: TextLabel,
	Income: TextLabel,
	IncomeRow: Frame,
	Power: TextLabel,
	MeasuredWidth: number?,
	NameHeight: number,
	IdentityHeight: number,
	Upgrade: Button.Button,
	Switch: Frame,
	Knob: Frame,
	SwitchLabel: TextLabel,
	InRoost: boolean?,
	Tooltip: string,
	Details: TextButton,
	Star: TextButton, -- the Favorite toggle (a favorite can never be sold)
	Favorite: boolean?,
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

local function tutorialFreeUpgrade(data: PlayerDataTypes.PlayerData?): boolean
	return data ~= nil and data.OnboardingStep == Onboarding.Steps.Upgrade and not data.OnboardingFreeLevelUsed
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
		-- A gesture that begins as the tutorial's free upgrade is only a single activation.
		-- Do not turn that held press into paid levels when the server acknowledges the reward.
		if tutorialFreeUpgrade(DataController:Get()) then
			return
		end
		local token = holding
		local started = os.clock()
		task.delay(motion.UpgradeHoldDelay, function()
			while holding == token and button.Enabled and button.Instance.Parent ~= nil and window.IsOpen do
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
	local mutation = Mutations.Get(dragon.MutationId)
	local accent = if mutation.Id ~= Mutations.NormalId then mutation.Color else rarityColor(rarityId)

	-- The grid changes column count, never the physical text or touch-target size.
	local cell = Instance.new("Frame")
	cell.Name = `Dragon_{dragon.Id}`
	cell.BackgroundTransparency = 1
	cell.Parent = gridHost
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromScale(1, 1)
	Style.CardLook(card, accent)
	card.Parent = cell

	local picture = Instance.new("Frame")
	picture.Name = "PictureFrame"
	picture.BackgroundTransparency = 1
	picture.Position = UDim2.fromOffset(mobile.Padding, mobile.Touch)
	picture.Size = UDim2.new(1, -(mobile.Padding * 2 + mobile.Touch + mobile.Gap), 0, mobile.Touch * 2)
	picture.ZIndex = 3
	picture.Parent = card

	local rarityIcon = Icon.new(card, `Rarity_{rarityId}`, accent)
	rarityIcon.Position = UDim2.fromOffset(mobile.Padding, mobile.Padding)
	rarityIcon.Size = UDim2.fromOffset(mobile.Body * 1.5, mobile.Body * 1.5)
	rarityIcon.ZIndex = 5
	local level = Style.Label(card, "", "Heavy", mobile.Body, colors.Text)
	level.Position = UDim2.fromOffset(mobile.Padding + mobile.Body * 1.5 + mobile.Gap, mobile.Padding)
	level.Size = UDim2.new(1, -(mobile.Padding * 2 + mobile.Body * 1.5 + mobile.Touch + mobile.Gap), 0, mobile.Body * 1.5)
	level.TextXAlignment = Enum.TextXAlignment.Left
	level.ZIndex = 5
	Style.Outline(level, 1.5)

	local name = Style.Label(card, "", "Heavy", mobile.Title, colors.Text)
	name.Position = UDim2.fromOffset(mobile.Padding, mobile.Touch * 3)
	name.Size = UDim2.new(1, -mobile.Padding * 2, 0, mobile.Title * 2)
	name.TextYAlignment = Enum.TextYAlignment.Center
	name.ZIndex = 3
	Style.Outline(name, 2)
	local sub = Style.Label(card, if species then Text.Format(words.Identity, { rarity = species.Rarity, element = species.Element }) else "", "Bold", mobile.Small, accent)
	sub.Position = UDim2.fromOffset(mobile.Padding, mobile.Touch * 3 + mobile.Title * 2 + mobile.Gap / 2)
	sub.Size = UDim2.new(1, -mobile.Padding * 2, 0, mobile.Small * 1.5)
	sub.ZIndex = 3

	local incomeRow = Instance.new("Frame")
	incomeRow.BackgroundTransparency = 1
	incomeRow.Position = UDim2.fromOffset(mobile.Padding, CARD.Y - mobile.Padding - mobile.Touch * 2 - mobile.Gap - mobile.Body * 3)
	incomeRow.Size = UDim2.new(1, -mobile.Padding * 2, 0, mobile.Body * 1.5)
	incomeRow.ZIndex = 3
	incomeRow.Parent = card
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.Padding = UDim.new(0, mobile.Gap / 2)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = incomeRow
	local gold = Icon.new(incomeRow, "Gold", colors.Gold)
	gold.Size = UDim2.fromOffset(mobile.Body * 1.5, mobile.Body * 1.5)
	local income = Style.Label(incomeRow, "", "Heavy", mobile.Title, colors.Gold)
	income.LayoutOrder = 2
	income.AutomaticSize = Enum.AutomaticSize.X
	income.Size = UDim2.fromOffset(0, mobile.Body * 1.5)
	income.TextWrapped = false
	Style.Outline(income, 1.5)
	local power = Style.Label(card, "", "Bold", mobile.Body, colors.Info)
	power.Position = UDim2.fromOffset(mobile.Padding, CARD.Y - mobile.Padding - mobile.Touch * 2 - mobile.Gap - mobile.Body * 1.5)
	power.Size = UDim2.new(1, -mobile.Padding * 2, 0, mobile.Body * 1.25)
	power.ZIndex = 3

	local dragonId = dragon.Id
	local upgrade = Button.new(card, {
		Text = words.Upgrade,
		Kind = "Primary",
		Icon = "Gold",
		TextSize = mobile.Body,
		OnClick = function()
			levelUpDragon:FireServer(dragonId, 1)
		end,
	})
	upgrade.Instance.AnchorPoint = Vector2.new(0.5, 1)
	upgrade.Instance.Position = UDim2.new(0.5, 0, 1, -(mobile.Padding + mobile.Touch + mobile.Gap))
	upgrade.Instance.Size = UDim2.new(1, -mobile.Padding * 2, 0, mobile.Touch)
	upgrade.Instance.ZIndex = 3
	attachHold(upgrade, dragonId)

	-- Roost and Details are independent, full-size touch actions below the upgrade button.
	local switch = Instance.new("TextButton")
	switch.Name = "RoostSwitch"
	switch.Text = ""
	switch.AutoButtonColor = false
	switch.AnchorPoint = Vector2.new(1, 1)
	switch.Position = UDim2.new(1, -mobile.Padding, 1, -mobile.Padding)
	switch.Size = UDim2.new(0.5, -(mobile.Padding + mobile.Gap / 2), 0, mobile.Touch)
	switch.ZIndex = 3
	Style.Round(switch)
	Style.GoldBorder(switch, 1.5)
	switch.Parent = card
	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(mobile.Small / 2, mobile.Small / 2)
	knob.BackgroundColor3 = colors.TrimLight
	knob.ZIndex = 4
	Style.Round(knob)
	knob.Parent = switch
	local switchLabel = Style.Label(switch, "", "Bold", mobile.Small, colors.Text)
	switchLabel.ZIndex = 4
	Style.Outline(switchLabel, 1)
	Style.AttachPress(switch)

	local entry: Card = {
		Cell = cell,
		Card = card,
		Picture = picture,
		PictureStage = nil,
		Level = level,
		Name = name,
		Identity = sub,
		Income = income,
		IncomeRow = incomeRow,
		Power = power,
		MeasuredWidth = nil,
		NameHeight = mobile.Title * 2,
		IdentityHeight = mobile.Small * 1.5,
		Upgrade = upgrade,
		Switch = switch :: any,
		Knob = knob,
		SwitchLabel = switchLabel,
		InRoost = nil,
		Tooltip = "",
		Details = nil :: any,
		Star = nil :: any,
		Favorite = nil,
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
	local details = Instance.new("TextButton")
	details.Name = "Details"
	details.Text = words.Details
	details.Font = name.Font
	details.TextSize = mobile.Body
	details.TextColor3 = colors.Text
	details.BackgroundColor3 = colors.PanelBottom
	details.AnchorPoint = Vector2.new(0, 1)
	details.Position = UDim2.new(0, mobile.Padding, 1, -mobile.Padding)
	details.Size = UDim2.new(0.5, -(mobile.Padding + mobile.Gap / 2), 0, mobile.Touch)
	details.ZIndex = 6
	details.Parent = card
	entry.Details = details
	Style.Corner(details, 6)
	Style.Stroke(details, colors.ButtonStroke, UITheme.Strokes.Button)
	Style.AttachPress(details)
	details.Activated:Connect(function()
		Tooltip.Toggle(card, function() return entry.Tooltip end, details.AbsolutePosition + Vector2.new(0, details.AbsoluteSize.Y))
	end)
	-- Favorite has its own full touch target; the picture stops short of it.
	local star = Instance.new("TextButton")
	star.Name = "FavoriteToggle"
	star.Text = words.Favorite
	star.Font = UITheme.Fonts.Heavy
	star.TextSize = mobile.Title
	star.TextColor3 = colors.TextMuted
	star.BackgroundColor3 = colors.PanelBottom
	star.AnchorPoint = Vector2.new(1, 0)
	star.Position = UDim2.new(1, -mobile.Padding, 0, mobile.Padding)
	star.Size = UDim2.fromOffset(mobile.Touch, mobile.Touch)
	star.ZIndex = 6
	star.Parent = card
	Style.Corner(star, 8)
	Style.Stroke(star, colors.Trim, 1.25)
	Style.AttachPress(star)
	entry.Star = star
	Tooltip.Attach(star, function()
		return Text.Hotbar.FavoriteTip
	end)
	star.Activated:Connect(function()
		setDragonFavorite:FireServer(dragonId, not entry.Favorite)
	end)
	-- Drag the picture onto a hotbar slot (backpack dragons only: a dragon in the roost is not in the backpack)
	picture.Active = true
	DragDrop.Attach(picture, function()
		if entry.InRoost then
			return nil
		end
		return { DragonId = dragonId, Slot = nil, Source = "Inventory" }
	end, function(ghost)
		local data = DataController:Get()
		local current = data and data.Dragons[dragonId]
		if current then
			DragonPicture.new(ghost, current.SpeciesId, current.Level)
		end
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
	local mutation = Mutations.Get(dragon.MutationId)
	local champion = if dragon.Champion then `{Text.Milestones.ChampionPrefix} ` else ""
	local displayName = champion .. (if mutation.Id ~= Mutations.NormalId then `{mutation.Name} {name}` else name)
	if card.Name.Text ~= displayName then
		setText(card.Name, displayName)
		card.MeasuredWidth = nil
	end
	setText(card.Level, Text.Format(words.Level, { level = dragon.Level }))
	setText(card.Income, Text.Format(words.Income, { value = Format.Number(DragonStats.GetGoldPerSecond(dragon)) }))
	setText(card.Power, Text.Format(words.Power, { value = Format.Number(DragonStats.GetPower(dragon)) }))
	local trait = DragonStats.GetTrait(dragon)
	local grade = DragonStats.GetGrade(dragon)
	local baseOneIn = if species then BindingOdds.GetHomeOneIn(dragon.SpeciesId, dragon.MutationId) else nil
	card.Tooltip = Text.Format(words.Tooltip, {
		power = Format.Number(DragonStats.GetPower(dragon)),
		trait = if trait then trait.Name else words.NoTrait,
		grade = if grade then Text.Format(words.Grade, { grade = grade.Id }) else words.NoGrade,
	}) .. `\n{Text.Format(words.Stage, { stage = stage.Name, level = dragon.Level, cap = cap, mutation = mutation.Name })}\n{Text.Format(Text.Odds.Chance, { oneIn = if baseOneIn then OddsText.OneInExact(baseOneIn) else Text.Odds.Unknown })}\n{words.HomeOdds}\n{words.TooltipBaseIncome}: {Text.Format(words.Income, { value = Format.Number(if species then species.BaseGoldPerSecond else 0) })}\n{words.TooltipBasePower}: {Format.Number(if species then species.BasePower else 0)}\n{words.TooltipGold}: {Text.Format(words.Income, { value = Format.Number(DragonStats.GetGoldPerSecond(dragon)) })}\n{words.TooltipModifiers}: {Format.Multiplier(if species and species.BaseGoldPerSecond > 0 then DragonStats.GetGoldPerSecond(dragon) / species.BaseGoldPerSecond else 1)}\n{Text.Format(words.TooltipRoost, { roost = Format.Multiplier(DragonStats.GetRoostIncomeMultiplier(data)), rebirth = Format.Multiplier(DragonStats.GetRebirthBonus(data.Rebirths)), index = Format.Multiplier(DragonStats.GetIndexMultiplier(data)) })}`

	local atCap = dragon.Level >= cap
	local free = not atCap and tutorialFreeUpgrade(data)
	local cost = DragonStats.GetLevelUpCost(dragon, data.Rebirths, data.LevelingIncomeAnchor)
	local label = if atCap then words.MaxLevel elseif free then Text.Onboarding.FreeUpgrade else `{words.Upgrade}  {Format.Number(cost)}`
	if card.Upgrade.Label.Text ~= label then
		card.Upgrade:SetText(label)
	end
	local enabled = not atCap and (free or data.Gold >= cost)
	if card.Upgrade.Enabled ~= enabled then
		card.Upgrade:SetEnabled(enabled)
	end

	local favorite = dragon.Favorite == true
	if card.Favorite ~= favorite then
		card.Favorite = favorite
		card.Star.TextColor3 = if favorite then colors.Gold else colors.TextMuted
		card.Star.BackgroundColor3 = if favorite then colors.Confirm else colors.PanelBottom
	end

	if card.InRoost ~= inRoost then
		card.InRoost = inRoost
		card.Switch.BackgroundColor3 = if inRoost then colors.Confirm else colors.Disabled
		card.Knob.Position = UDim2.new(0, mobile.Padding, 0.5, 0)
		card.SwitchLabel.Text = if inRoost then words.InRoost else words.Resting
		card.SwitchLabel.Position = UDim2.fromOffset(mobile.Padding * 2, 0)
		card.SwitchLabel.Size = UDim2.new(1, -mobile.Padding * 3, 1, 0)
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
			Power = DragonStats.GetPower(dragon),
		})
	end
	-- Roost dragons first, then by income
	table.sort(entries, function(a, b)
		if a.InRoost ~= b.InRoost then
			return a.InRoost
		end
		local first = if sortMode == "Power" then a.Power elseif sortMode == "Level" then a.Dragon.Level else a.Income
		local second = if sortMode == "Power" then b.Power elseif sortMode == "Level" then b.Dragon.Level else b.Income
		if first ~= second then
			return first > second
		end
		return a.Dragon.Id < b.Dragon.Id
	end)

	local seen: { [string]: boolean } = {}
	local tutorialUpgrade: GuiObject? = nil
	local tutorialRare = false
	for index, entry in entries do
		local id = entry.Dragon.Id
		seen[id] = true
		local card = cards[id]
		if card == nil then
			card = makeCard(entry.Dragon)
			cards[id] = card
		end
		updateCard(card, entry.Dragon, data, cap, entry.InRoost, index)
		local species = Dragons[entry.Dragon.SpeciesId]
		local rare = species ~= nil and species.Rarity == Onboarding.MinimumRarity
		if entry.Dragon.Level < cap and (tutorialUpgrade == nil or (rare and not tutorialRare)) then
			tutorialUpgrade = card.Upgrade.Instance
			tutorialRare = rare
		end
	end
	HudLayout.RegisterTutorialTarget("DragonUpgrade", tutorialUpgrade)
	for id, card in cards do -- cards of dragons that are gone
		if not seen[id] then
			card.Cell:Destroy()
			cards[id] = nil
		end
	end

	setText(
		headerText,
		Text.Format(words.Header, { count = #entries, placed = #data.RoostDragonIds, slots = DragonStats.GetRoostSlots(data) })
	)
	emptyState.Visible = #entries == 0
	setText(runeCount, Format.Number(data.WyrmRunes))
	setText(stoneCount, Format.Number(data.Dragonstones))
	if layoutCards then layoutCards() end
end

function InventoryController:Init()
	window = InventoryWindow.AddTab("Dragons")
	local content = window.Content

	-- A single compact header on landscape/desktop. Only very narrow screens stack its actions.
	local header = Instance.new("Frame")
	header.Name = "Summary"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, mobile.Touch)
	header.Parent = content
	headerText = Style.Label(header, "", "Bold", mobile.Body, colors.Text)
	headerText.Size = UDim2.new(1, 0, 1, 0)
	headerText.TextXAlignment = Enum.TextXAlignment.Left
	Tooltip.Attach(headerText, function()
		return Text.Format(words.Resources, { runes = runeCount.Text, stones = stoneCount.Text })
	end)
	local resources = Instance.new("Frame")
	resources.Name = "Resources"
	resources.BackgroundTransparency = 1
	resources.Size = UDim2.fromOffset(0, mobile.Small * 1.5)
	resources.AutomaticSize = Enum.AutomaticSize.X
	resources.Parent = header
	local resourceLayout = Instance.new("UIListLayout")
	resourceLayout.FillDirection = Enum.FillDirection.Horizontal
	resourceLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	resourceLayout.Padding = UDim.new(0, mobile.Gap / 2)
	resourceLayout.SortOrder = Enum.SortOrder.LayoutOrder
	resourceLayout.Parent = resources
	local function counter(order: number, iconKey: string, color: Color3): TextLabel
		local icon = Icon.new(resources, iconKey, color)
		icon.LayoutOrder = order
		icon.Size = UDim2.fromOffset(mobile.Small * 1.5, mobile.Small * 1.5)
		local label = Style.Label(resources, "0", "Heavy", mobile.Small, color)
		label.LayoutOrder = order + 1
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.fromOffset(0, mobile.Small * 1.5)
		label.TextWrapped = false
		Style.Outline(label, 1.5)
		return label
	end
	runeCount = counter(10, "WyrmRune", colors.Constellation)
	stoneCount = counter(20, "Dragonstone", colors.Negative)

	local equip = Button.new(header, {
		Text = words.EquipBest,
		Kind = "Confirm",
		Icon = "Crown",
		TextSize = mobile.Body,
		Sound = "Confirm",
		OnClick = function()
			equipBest:FireServer()
		end,
	})
	equip.Instance.AnchorPoint = Vector2.new(1, 0)
	equip.Instance.Position = UDim2.fromScale(1, 0)
	local sortButton: Button.Button
	sortButton = Button.new(header, {
		Text = Text.Format(words.Sort, { mode = words.SortModes[sortMode] }),
		Kind = "Neutral",
		TextSize = mobile.Small,
		OnClick = function()
			sortMode = if sortMode == "Income" then "Power" elseif sortMode == "Power" then "Level" else "Income"
			sortButton:SetText(Text.Format(words.Sort, { mode = words.SortModes[sortMode] }))
			dirty = true
		end,
	})
	sortButton.Instance.AnchorPoint = Vector2.new(1, 0)

	list = Instance.new("ScrollingFrame")
	list.Name = "DragonList"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = mobile.Scrollbar
	list.ScrollBarImageColor3 = colors.Trim
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.Parent = content
	Style.Pad(list, mobile.Padding / 2, mobile.Padding / 2)
	local sections = Instance.new("UIListLayout")
	sections.Padding = UDim.new(0, mobile.Gap)
	sections.SortOrder = Enum.SortOrder.LayoutOrder
	sections.Parent = list
	gridHost = Instance.new("Frame")
	gridHost.Name = "Cards"
	gridHost.LayoutOrder = 2
	gridHost.BackgroundTransparency = 1
	gridHost.Size = UDim2.new(1, 0, 0, 0)
	gridHost.Parent = list
	DragDrop.OnDragState(function(dragging)
		list.ScrollingEnabled = not dragging -- a drag from a card must not scroll the list
	end)
	grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(mobile.Gap, mobile.Gap)
	grid.CellSize = UDim2.fromOffset(CARD.X, CARD.Y)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = gridHost
	grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		gridHost.Size = UDim2.new(1, 0, 0, grid.AbsoluteContentSize.Y)
	end)
	emptyState = Style.Label(gridHost, words.Empty, "Body", mobile.Body, colors.TextMuted)
	emptyState.Name = "EmptyState"
	emptyState.Visible = false
	emptyState.TextYAlignment = Enum.TextYAlignment.Top
	Style.Pad(emptyState, mobile.Padding)

	local function relayout()
		local width = content.AbsoluteSize.X
		if width <= 0 then return end -- AbsoluteSize is not resolved until the shared shell is parented.
		local stacked = width < mobile.Touch * 11
		local actionsTop = if stacked then mobile.Body * 1.5 + mobile.Gap else 0
		local headerHeight = actionsTop + mobile.Touch
		local scrollHeader = content.AbsoluteSize.Y < headerHeight + mobile.Gap + mobile.Touch * 2
		if scrollHeader then width -= mobile.Padding end
		header.Parent = if scrollHeader then list else content
		header.LayoutOrder = 1
		header.Position = UDim2.new()
		local usable = math.max(1, width - mobile.Padding - mobile.Gap)
		local columns = math.max(1, math.floor((usable + mobile.Gap) / (CARD.X - mobile.Padding * 2 + mobile.Gap)))
		local cellWidth = math.min(CARD.X, math.floor((usable - mobile.Gap * (columns - 1)) / columns))
		local extra = 0
		for _, card in cards do
			if card.MeasuredWidth ~= cellWidth then
				card.MeasuredWidth = cellWidth
				card.NameHeight = math.max(mobile.Title * 2, math.ceil(TextService:GetTextSize(card.Name.Text, mobile.Title, UITheme.Fonts.Heavy, Vector2.new(math.max(1, cellWidth - mobile.Padding * 2), math.huge)).Y))
				card.IdentityHeight = math.max(mobile.Small * 1.5, math.ceil(TextService:GetTextSize(card.Identity.Text, mobile.Small, UITheme.Fonts.Bold, Vector2.new(math.max(1, cellWidth - mobile.Padding * 2), math.huge)).Y))
			end
			extra = math.max(extra, card.NameHeight - mobile.Title * 2 + card.IdentityHeight - mobile.Small * 1.5)
		end
		local cardHeight = CARD.Y + extra
		grid.FillDirectionMaxCells = columns
		grid.CellSize = UDim2.fromOffset(cellWidth, cardHeight)
		for _, card in cards do
			card.Name.Size = UDim2.new(1, -mobile.Padding * 2, 0, card.NameHeight)
			card.Identity.Position = UDim2.fromOffset(mobile.Padding, mobile.Touch * 3 + card.NameHeight + mobile.Gap / 2)
			card.Identity.Size = UDim2.new(1, -mobile.Padding * 2, 0, card.IdentityHeight)
			card.IncomeRow.Position = UDim2.fromOffset(mobile.Padding, cardHeight - mobile.Padding - mobile.Touch * 2 - mobile.Gap - mobile.Body * 3)
			card.Power.Position = UDim2.fromOffset(mobile.Padding, cardHeight - mobile.Padding - mobile.Touch * 2 - mobile.Gap - mobile.Body * 1.5)
		end
		local equipWidth = mobile.Touch * 3.5
		local sortWidth = mobile.Touch * 3
		header.Size = UDim2.new(1, 0, 0, headerHeight)
		equip.Instance.Position = UDim2.new(1, 0, 0, actionsTop)
		equip.Instance.Size = UDim2.fromOffset(if stacked then math.max(mobile.Touch, (width - mobile.Gap) / 2) else equipWidth, mobile.Touch)
		sortButton.Instance.Position = if stacked then UDim2.new(0.5, -mobile.Gap / 2, 0, actionsTop) else UDim2.new(1, -(equipWidth + mobile.Gap), 0, 0)
		sortButton.Instance.Size = UDim2.fromOffset(if stacked then math.max(mobile.Touch, (width - mobile.Gap) / 2) else sortWidth, mobile.Touch)
		headerText.Size = UDim2.new(1, if stacked then 0 else -(equipWidth + sortWidth + mobile.Gap * 2), 0, if stacked then mobile.Body * 1.5 else mobile.Touch)
		resources.Visible = not stacked and width >= mobile.Touch * 16
		if resources.Visible then
			headerText.Size = UDim2.new(1, -(equipWidth + sortWidth + mobile.Gap * 2), 0, mobile.Body * 1.5)
			resources.Position = UDim2.fromOffset(0, mobile.Body * 1.5)
		end
		local listTop = if scrollHeader then 0 else headerHeight + mobile.Gap
		list.Position = UDim2.fromOffset(0, listTop)
		list.Size = UDim2.new(1, 0, 1, -listTop)
	end
	layoutCards = relayout
	HudLayout.OnLayoutChanged(relayout)
	content:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	relayout()

	window:OnOpen(function()
		dirty = true
	end)

	local function markDirty()
		dirty = true
	end
	for _, key in { "Dragons", "RoostDragonIds", "Gold", "Rebirths", "LevelingIncomeAnchor", "RoostSlotUpgrades", "RoostIncomeLevel", "Index", "WyrmRunes", "Dragonstones", "OnboardingStep", "OnboardingFreeLevelUsed" } do
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
