--!strict
-- Collection uses readable, reflowing species cards grouped by element. Unknown names/precise odds stay hidden.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Icon = require(script.Parent.UI.Icon)
local DragonPicture = require(script.Parent.UI.DragonPicture)
local InventoryWindow = require(script.Parent.InventoryWindow)
local Tooltip = require(script.Parent.UI.Tooltip)
local ProgressBar = require(script.Parent.UI.ProgressBar)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local Constellations = require(ReplicatedStorage.Shared.Config.Constellations)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Elements = require(ReplicatedStorage.Shared.Config.Elements)
local IndexConfig = require(ReplicatedStorage.Shared.Config.Index)
local Mutations = require(ReplicatedStorage.Shared.Config.Mutations)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local BindingOdds = require(ReplicatedStorage.Shared.BindingOdds)
local OddsText = require(ReplicatedStorage.Shared.OddsText)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local IndexController = {}
local mobile = UITheme.MobileUI
local words = Text.Collection
local window: InventoryWindow.Tab
local summary: TextButton
local bonusLabel: TextLabel
local foundLabel: TextLabel
local bar: ProgressBar.ProgressBar
local rulesText = ""
local list: ScrollingFrame

type Cell = { Name: TextLabel, Tier: TextLabel, Odds: TextLabel, Mutations: TextLabel }
type Group = { Frame: Frame, Grid: UIGridLayout, Cells: { Cell } }
local groups: { Group } = {}
local atlas: Frame?
local atlasGrid: UIGridLayout?
local atlasNames: { TextLabel } = {}

local mutationBadgeCount = 0
local rarityOrder: { [string]: number } = {}
local rarityById: { [string]: Rarities.Rarity } = {}
for _, mutation in Mutations.Mutations do
	if mutation.Id ~= Mutations.NormalId then mutationBadgeCount += 1 end
end
for order, rarity in Rarities do
	rarityOrder[rarity.Id] = order
	rarityById[rarity.Id] = rarity
end

local function measure(label: TextLabel, width: number): number
	return math.ceil(TextService:GetTextSize(label.Text, label.TextSize, label.Font, Vector2.new(math.max(1, width), math.huge)).Y)
end

local function relayout()
	local content = window.Content
	local width = math.max(mobile.Touch * 4, content.AbsoluteSize.X)
	local narrow = width < mobile.Touch * 9
	bonusLabel.Size = UDim2.new(if narrow then 1 else 0.52, -(mobile.Padding * 2 + mobile.Touch + mobile.Gap), 0, mobile.Title * 1.5)
	local labelWidth = (if narrow then width else width * 0.52) - (mobile.Padding * 2 + mobile.Touch + mobile.Gap)
	local bonusHeight = math.max(mobile.Title * 1.5, measure(bonusLabel, labelWidth))
	local foundHeight = math.max(mobile.Body * 1.5, measure(foundLabel, labelWidth))
	bonusLabel.Size = UDim2.new(bonusLabel.Size.X.Scale, bonusLabel.Size.X.Offset, 0, bonusHeight)
	foundLabel.Position = UDim2.fromOffset(mobile.Padding + mobile.Touch + mobile.Gap, mobile.Padding + bonusHeight)
	foundLabel.Size = UDim2.new(bonusLabel.Size.X.Scale, bonusLabel.Size.X.Offset, 0, foundHeight)
	local headerHeight = mobile.Padding * 2 + bonusHeight + foundHeight + (if narrow then mobile.Body * 1.5 + mobile.Gap else 0)
	summary.Size = UDim2.new(1, 0, 0, headerHeight)
	bar.Instance.AnchorPoint = if narrow then Vector2.new(0, 1) else Vector2.new(1, 0.5)
	bar.Instance.Position = if narrow then UDim2.new(0, mobile.Padding, 1, -mobile.Padding) else UDim2.new(1, -mobile.Padding, 0.5, 0)
	bar.Instance.Size = UDim2.new(if narrow then 1 else 0.48, -mobile.Padding * 2, 0, mobile.Body * 1.5)

	local usable = math.max(1, width - mobile.Padding - mobile.Gap)
	local columns = math.max(1, math.floor((usable + mobile.Gap) / (mobile.CollectionCard.X + mobile.Gap)))
	local cellWidth = math.floor((usable - mobile.Gap * (columns - 1)) / columns)
	for _, group in groups do
		local height = mobile.CollectionCard.Y
		for _, cell in group.Cells do
			local nameTop = mobile.Padding + mobile.Touch + mobile.Gap
			local nameHeight = math.max(mobile.Body * 2, measure(cell.Name, cellWidth - mobile.Padding * 2))
			cell.Name.Position = UDim2.fromOffset(mobile.Padding, nameTop)
			cell.Name.Size = UDim2.fromOffset(cellWidth - mobile.Padding * 2, nameHeight)
			local top = nameTop + nameHeight + mobile.Gap / 2
			cell.Tier.Position = UDim2.fromOffset(mobile.Padding, top)
			cell.Tier.Size = UDim2.new(1, -mobile.Padding * 2, 0, mobile.Small * 1.5)
			top += mobile.Small * 1.5 + mobile.Gap / 2
			local oddsHeight = math.max(mobile.Small * 1.5, measure(cell.Odds, cellWidth - mobile.Padding * 2))
			cell.Odds.Position = UDim2.fromOffset(mobile.Padding, top)
			cell.Odds.Size = UDim2.new(1, -mobile.Padding * 2, 0, oddsHeight)
			top += oddsHeight + mobile.Gap / 2
			cell.Mutations.Position = UDim2.fromOffset(mobile.Padding, top)
			cell.Mutations.Size = UDim2.new(1, -mobile.Padding * 2, 0, mobile.Small * 1.5)
			height = math.max(height, top + mobile.Small * 1.5 + mobile.Padding)
		end
		group.Grid.CellSize = UDim2.fromOffset(cellWidth, height)
		group.Grid.FillDirectionMaxCells = columns
		local rows = math.ceil(#group.Cells / columns)
		group.Frame.Size = UDim2.new(1, 0, 0, mobile.Body * 1.5 + mobile.Gap + rows * height + math.max(0, rows - 1) * mobile.Gap)
	end
	local atlasFrame, chipGrid = atlas, atlasGrid
	if atlasFrame and chipGrid then
		local height = mobile.Touch
		for _, name in atlasNames do
			height = math.max(height, measure(name, cellWidth - mobile.Padding * 2 - mobile.Touch) + mobile.Padding)
		end
		chipGrid.CellSize = UDim2.fromOffset(cellWidth, height)
		chipGrid.FillDirectionMaxCells = columns
		local rows = math.ceil(#Constellations / columns)
		atlasFrame.Size = UDim2.new(1, 0, 0, rows * height + math.max(0, rows - 1) * mobile.Gap)
	end
end

local function makeCell(parent: Instance, order: number, speciesId: string, found: boolean, mutationNames: { string }): Cell
	local species = Dragons[speciesId]
	local rarity = rarityById[species.Rarity]
	local cell = Instance.new("TextButton")
	cell.Name = if found then speciesId else "Undiscovered"
	cell.Text = ""
	cell.AutoButtonColor = false
	cell.LayoutOrder = order
	if found then
		Style.CardLook(cell, rarity.Color)
	else
		cell.BackgroundColor3 = UITheme.Colors.CardDark
		Style.Corner(cell, UITheme.SmallCorner)
		Style.Stroke(cell, UITheme.Colors.TabTop, UITheme.Strokes.Button)
	end
	cell.Parent = parent

	local portrait = Instance.new("Frame")
	portrait.Name = "Portrait"
	portrait.Position = UDim2.fromOffset(mobile.Padding, mobile.Padding)
	portrait.Size = UDim2.new(1, -mobile.Padding * 2, 0, mobile.Touch)
	portrait.BackgroundTransparency = 1
	portrait.ZIndex = 3
	portrait.Parent = cell
	if found then
		DragonPicture.new(portrait, speciesId, 1)
	else
		local gem = Icon.new(portrait, "Rarity_" .. rarity.Id, UITheme.Colors.TextMuted, words.Unknown)
		gem.AnchorPoint = Vector2.new(0.5, 0.5)
		gem.Position = UDim2.fromScale(0.5, 0.5)
		gem.Size = UDim2.fromOffset(mobile.Touch, mobile.Touch)
		if gem:IsA("ImageLabel") then gem.ImageTransparency = 0.55 end
	end
	local name = if found then species.Name else words.Unknown
	local label = Style.Label(cell, name, "Heavy", mobile.Body, UITheme.Colors.Text)
	label.ZIndex = 3
	local tier = Style.Label(cell, rarity.Name, "Bold", mobile.Small, rarity.Color)
	tier.ZIndex = 3
	local oneIn = if found then BindingOdds.GetHomeOneIn(speciesId) else nil
	local odds = Style.Label(cell, if found then Text.Format(words.NormalOdds, { oneIn = if oneIn then OddsText.OneInExact(oneIn) else Text.Odds.Unknown }) else Text.Format(Text.Odds.Undiscovered, { band = rarity.UndiscoveredOddsBand }), "Body", mobile.Small, UITheme.Colors.TextMuted)
	odds.ZIndex = 3
	local badges = Style.Label(cell, if found then Text.Format(words.MutationCount, { found = #mutationNames, total = mutationBadgeCount }) else "", "Bold", mobile.Small, UITheme.Colors.Constellation)
	badges.ZIndex = 3

	local function details(): string
		if not found then
			return Text.Format(words.Undiscovered, { rarity = rarity.Name }) .. "\n" .. Text.Format(Text.Odds.Undiscovered, { band = rarity.UndiscoveredOddsBand })
		end
		local info = name .. " · " .. rarity.Name .. " · " .. species.Element .. "\n" .. Text.Format(Text.Odds.Chance, { oneIn = if oneIn then OddsText.OneInExact(oneIn) else Text.Odds.Unknown })
		info ..= "\n" .. Text.Dragons.HomeOdds .. "\n" .. Text.Dragons.TooltipBaseIncome .. ": " .. Text.Format(Text.Dragons.Income, { value = Format.Number(species.BaseGoldPerSecond) })
		info ..= "\n" .. Text.Dragons.TooltipBasePower .. ": " .. Format.Number(species.BasePower)
		if #mutationNames > 0 then info ..= "\n" .. Text.Format(words.MutationDetails, { names = table.concat(mutationNames, ", ") }) end
		return info
	end
	Tooltip.Attach(cell, details)
	cell.Activated:Connect(function()
		Tooltip.Toggle(cell, details, cell.AbsolutePosition + Vector2.new(0, cell.AbsoluteSize.Y))
	end)
	return { Name = label, Tier = tier, Odds = odds, Mutations = badges }
end

local function redraw()
	local data = DataController:Get()
	if data == nil then return end
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") and child ~= summary then child:Destroy() end
	end
	groups = {}
	atlasNames = {}
	atlas, atlasGrid = nil, nil

	local entries = DragonStats.GetIndexEntryCount(data)
	local complete, all = DragonStats.GetIndexCompletion(data)
	local nextMilestone = (data.IndexMilestones + 1) * IndexConfig.MilestoneEvery
	local speciesCount, found = 0, 0
	local elements: { string } = {}
	local speciesByElement: { [string]: { string } } = {}
	for elementId in Elements do table.insert(elements, elementId) end
	table.sort(elements)
	for speciesId, species in Dragons do
		speciesCount += 1
		if data.Index[speciesId] ~= nil then found += 1 end
		speciesByElement[species.Element] = speciesByElement[species.Element] or {}
		table.insert(speciesByElement[species.Element], speciesId)
	end
	bonusLabel.Text = Text.Format(words.Income, { multiplier = Format.Multiplier(DragonStats.GetIndexMultiplier(data)) })
	foundLabel.Text = Text.Format(words.Found, { found = found, total = speciesCount })
	local previous = data.IndexMilestones * IndexConfig.MilestoneEvery
	bar:Set(if all then 1 else math.clamp((entries - previous) / math.max(1, nextMilestone - previous), 0, 1), if all then words.Complete else Text.Format(words.Reward, { count = nextMilestone }))
	rulesText = Text.Format(words.Rules, { entries = entries, elements = #complete, percent = IndexConfig.IncomePerEntry * 100, element = IndexConfig.ElementMultiplier, all = IndexConfig.AllSpeciesMultiplier, total = speciesCount })
	if not all then rulesText ..= "\n" .. Text.Format(words.Reward, { count = nextMilestone }) .. ": " .. Rewards.Describe(IndexConfig.MilestoneReward) end

	for order, elementId in elements do
		local speciesIds = speciesByElement[elementId] or {}
		table.sort(speciesIds, function(a, b)
			local first, second = rarityOrder[Dragons[a].Rarity] or math.huge, rarityOrder[Dragons[b].Rarity] or math.huge
			return if first == second then a < b else first < second
		end)
		local frame = Instance.new("Frame")
		frame.Name = elementId
		frame.LayoutOrder = order
		frame.BackgroundTransparency = 1
		frame.Parent = list
		local element = UITheme.Element[elementId]
		local head = Style.Label(frame, if table.find(complete, elementId) then Text.Format(words.ElementComplete, { element = elementId }) else elementId, "Heavy", mobile.Title, if element then element.Color else UITheme.Colors.Text)
		head.Size = UDim2.new(1, 0, 0, mobile.Body * 1.5)
		head.TextXAlignment = Enum.TextXAlignment.Left
		local cards = Instance.new("Frame")
		cards.Name = "Species"
		cards.Position = UDim2.fromOffset(0, mobile.Body * 1.5 + mobile.Gap)
		cards.Size = UDim2.new(1, 0, 1, -(mobile.Body * 1.5 + mobile.Gap))
		cards.BackgroundTransparency = 1
		cards.Parent = frame
		local grid = Instance.new("UIGridLayout")
		grid.CellPadding = UDim2.fromOffset(mobile.Gap, mobile.Gap)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = cards
		local group: Group = { Frame = frame, Grid = grid, Cells = {} }
		for rarityIndex, speciesId in speciesIds do
			local mutationNames = {}
			for _, mutation in Mutations.Mutations do
				if mutation.Id ~= Mutations.NormalId and (data.MutationIndex or {})[speciesId .. ":" .. mutation.Id] ~= nil then
					table.insert(mutationNames, mutation.Name)
				end
			end
			table.insert(group.Cells, makeCell(cards, rarityIndex, speciesId, data.Index[speciesId] ~= nil, mutationNames))
		end
		table.insert(groups, group)
	end

	local atlasTitle = Style.Label(list, words.Atlas, "Heavy", mobile.Title, UITheme.Colors.Title)
	atlasTitle.LayoutOrder = #elements + 1
	atlasTitle.Size = UDim2.new(1, 0, 0, mobile.Title * 1.5)
	atlasTitle.TextXAlignment = Enum.TextXAlignment.Left
	local chips = Instance.new("Frame")
	chips.Name = "StarAtlas"
	chips.LayoutOrder = #elements + 2
	chips.BackgroundTransparency = 1
	chips.Parent = list
	local chipGrid = Instance.new("UIGridLayout")
	chipGrid.CellPadding = UDim2.fromOffset(mobile.Gap, mobile.Gap)
	chipGrid.SortOrder = Enum.SortOrder.LayoutOrder
	chipGrid.Parent = chips
	atlas, atlasGrid = chips, chipGrid
	for order, constellation in Constellations do
		local count = data.StarAtlas[constellation.Id] or 0
		local element = constellation.Element and UITheme.Element[constellation.Element]
		local color = if element then element.Color else UITheme.Colors.Gold
		local chip = Instance.new("Frame")
		chip.LayoutOrder = order
		Style.CardLook(chip, if count > 0 then color else UITheme.Colors.CardDark)
		chip.Parent = chips
		local name = Style.Label(chip, constellation.Name, "Bold", mobile.Body, if count > 0 then UITheme.Colors.Text else UITheme.Colors.TextMuted)
		name.Position = UDim2.fromOffset(mobile.Padding, 0)
		name.Size = UDim2.new(1, -(mobile.Padding * 2 + mobile.Touch), 1, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.ZIndex = 3
		table.insert(atlasNames, name)
		local amount = Style.Label(chip, if count > 0 then Text.Format(words.Count, { count = Format.Number(count) }) else words.Empty, "Heavy", mobile.Small, color)
		amount.AnchorPoint = Vector2.new(1, 0)
		amount.Position = UDim2.new(1, -mobile.Padding, 0, 0)
		amount.Size = UDim2.new(0, mobile.Touch, 1, 0)
		amount.TextXAlignment = Enum.TextXAlignment.Right
		amount.ZIndex = 3
	end
	relayout()
end

function IndexController:Init()
	window = InventoryWindow.AddTab("Collection")
	local content = window.Content
	summary = Instance.new("TextButton")
	summary.Name = "Summary"
	summary.Text = ""
	summary.AutoButtonColor = false
	Style.CardLook(summary, UITheme.Colors.Gold)
	summary.Parent = content
	local icon = Icon.new(summary, "Tab_Collection")
	icon.Position = UDim2.fromOffset(mobile.Padding, mobile.Padding)
	icon.Size = UDim2.fromOffset(mobile.Touch, mobile.Touch)
	icon.ZIndex = 3
	bonusLabel = Style.Label(summary, "", "Heavy", mobile.Title, UITheme.Colors.Gold)
	bonusLabel.Position = UDim2.fromOffset(mobile.Padding + mobile.Touch + mobile.Gap, mobile.Padding)
	bonusLabel.TextXAlignment = Enum.TextXAlignment.Left
	bonusLabel.ZIndex = 3
	foundLabel = Style.Label(summary, "", "Bold", mobile.Body, UITheme.Colors.Text)
	foundLabel.Position = UDim2.fromOffset(mobile.Padding + mobile.Touch + mobile.Gap, mobile.Padding + mobile.Title * 1.5)
	foundLabel.TextXAlignment = Enum.TextXAlignment.Left
	foundLabel.ZIndex = 3
	bar = ProgressBar.new(summary, UITheme.Colors.Gold)
	bar.Instance.ZIndex = 3
	Tooltip.Attach(summary, function() return rulesText end)
	summary.Activated:Connect(function()
		Tooltip.Toggle(summary, function() return rulesText end, summary.AbsolutePosition + Vector2.new(0, summary.AbsoluteSize.Y))
	end)
	list = Instance.new("ScrollingFrame")
	list.Name = "CollectionList"
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = mobile.Scrollbar
	list.ScrollBarImageColor3 = UITheme.Colors.Trim
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.Parent = content
	summary.LayoutOrder = 0
	summary.Parent = list -- the summary scrolls away on short phones so cards keep the usable content height
	Style.Pad(list, mobile.Padding / 2, mobile.Padding / 2)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, mobile.Gap * 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	content:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	HudLayout.OnLayoutChanged(relayout)
	window:OnOpen(redraw)
	for _, key in { "Index", "MutationIndex", "StarAtlas", "IndexMilestones" } do
		DataController:OnChanged(key, function() if window.IsOpen then redraw() end end)
	end
	relayout()
end

return IndexController
