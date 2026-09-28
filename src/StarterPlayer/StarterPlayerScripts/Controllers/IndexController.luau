--!strict
-- Dragon Index (extends the Star Atlas): the Collection tab of the Inventory window (InventoryWindow), UI renewal part 2.
-- A header card (the Index income bonus big, "15 / 20 found", a bar to the next milestone; the rules in its tooltip),
-- a grid of every species by element and rarity (found = a card tinted in its rarity color with a big gem and the
-- name; not found = a dark cell with a faint gem and "?"; a gold ★ badge when the Starborn variant is found too),
-- and the Star Atlas as chips (constellation + times bound).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local Style = require(script.Parent.UI.Style)
local Icon = require(script.Parent.UI.Icon)
local InventoryWindow = require(script.Parent.InventoryWindow)
local Tooltip = require(script.Parent.UI.Tooltip)
local ProgressBar = require(script.Parent.UI.ProgressBar)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Constellations = require(ReplicatedStorage.Shared.Config.Constellations)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Elements = require(ReplicatedStorage.Shared.Config.Elements)
local IndexConfig = require(ReplicatedStorage.Shared.Config.Index)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local IndexController = {}

local window: InventoryWindow.Tab
local bonusLabel: TextLabel
local foundLabel: TextLabel
local bar: ProgressBar.ProgressBar
local rulesText = ""
local list: ScrollingFrame

-- Element rows in alphabetical order (stable).
local function getElementOrder(): { string }
	local order = {}
	for elementId in Elements do
		table.insert(order, elementId)
	end
	table.sort(order)
	return order
end

-- elementId -> rarityId -> speciesId
local function getGrid(): { [string]: { [string]: string } }
	local grid = {}
	for speciesId, species in Dragons do
		grid[species.Element] = grid[species.Element] or {}
		grid[species.Element][species.Rarity] = speciesId
	end
	return grid
end

local function makeCell(row: Instance, order: number, speciesId: string?, rarity: Rarities.Rarity, found: boolean, starborn: boolean)
	local theme = UITheme
	local cell = Instance.new("Frame")
	cell.Name = speciesId or "Unknown"
	cell.LayoutOrder = order
	cell.Size = UDim2.new(0.168, -6, 1, 0)
	if found then
		Style.CardLook(cell, rarity.Color)
	else
		cell.BackgroundColor3 = theme.Colors.TextStroke
		cell.BackgroundTransparency = 0.35
		Style.Corner(cell, theme.SmallCorner + 4)
		local line = Style.Stroke(cell, theme.Colors.TabTop, 1.5)
		line.Transparency = 0.2
	end
	cell.Parent = row

	local look = theme.Rarity[rarity.Id]
	local gem = Icon.new(cell, if look then look.Icon else "", rarity.Color, rarity.Id)
	gem.AnchorPoint = Vector2.new(0.5, 0)
	gem.Position = UDim2.new(0.5, 0, 0, 4)
	gem.Size = UDim2.fromOffset(42, 42)
	gem.ZIndex = 3
	if not found and gem:IsA("ImageLabel") then
		gem.ImageTransparency = 0.75
		gem.ImageColor3 = Color3.fromRGB(120, 120, 150)
	end
	local name = if speciesId and found then Dragons[speciesId].Name else "?"
	local label = Style.Label(cell, name, "Title", 15, if found then Style.Shade(rarity.Color, 0.35) else theme.Colors.TextMuted)
	label.Position = UDim2.new(0, 3, 0, 46)
	label.Size = UDim2.new(1, -6, 1, -50)
	label.TextScaled = true
	label.ZIndex = 3
	Style.Outline(label, 1.5)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 16
	limit.Parent = label
	if starborn then
		local badge = Style.Label(cell, "★", "Heavy", 16, theme.Colors.BannerStar)
		badge.Font = Enum.Font.GothamBlack
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.Position = UDim2.new(1, -8, 0, 8)
		badge.Size = UDim2.fromOffset(24, 24)
		badge.ZIndex = 4
		Style.Outline(badge, 1.5)
	end
	Tooltip.Attach(cell, function()
		if not found then
			return `Undiscovered {rarity.Name} dragon`
		end
		return `{name} · {rarity.Name}{if starborn then " · Starborn found" else ""}`
	end)
end

local function redraw()
	local data = DataController:Get()
	if data == nil then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local theme = UITheme

	local entries = DragonStats.GetIndexEntryCount(data)
	local complete, all = DragonStats.GetIndexCompletion(data)
	local nextMilestone = (data.IndexMilestones + 1) * IndexConfig.MilestoneEvery
	local speciesCount, found = 0, 0
	for speciesId in Dragons do
		speciesCount += 1
		if data.Index[speciesId] ~= nil then
			found += 1
		end
	end
	bonusLabel.Text = `{Format.Multiplier(DragonStats.GetIndexMultiplier(data))} income`
	foundLabel.Text = `{found} / {speciesCount} found`
	local previous = data.IndexMilestones * IndexConfig.MilestoneEvery
	bar:Set(
		if all then 1 else math.clamp((entries - previous) / math.max(1, nextMilestone - previous), 0, 1),
		if all then "All found!" else `Reward at {nextMilestone}`
	)
	rulesText = `{entries} entries · {#complete} element{if #complete == 1 then "" else "s"} complete · +{math.floor(IndexConfig.IncomePerEntry * 100)}% per entry · x{IndexConfig.ElementMultiplier} per complete element · x{IndexConfig.AllSpeciesMultiplier} for all {speciesCount} species · Starborn count as their own entries`

	local grid = getGrid()
	for order, elementId in getElementOrder() do
		local row = Instance.new("Frame")
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -8, 0, 78)
		row.BackgroundTransparency = 1
		row.Parent = list
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Parent = row

		local element = theme.Element[elementId]
		local isComplete = table.find(complete, elementId) ~= nil
		local head = Style.Label(row, if isComplete then `{elementId} ✓` else elementId, "Title", 20, if element then element.Color else theme.Colors.Text)
		head.LayoutOrder = 0
		head.Size = UDim2.new(0.16, 0, 1, 0)
		head.TextScaled = true
		Style.Outline(head, 1.5)
		local headLimit = Instance.new("UITextSizeConstraint")
		headLimit.MaxTextSize = 22
		headLimit.Parent = head

		for rarityOrder, rarity in Rarities do
			local speciesId = grid[elementId] and grid[elementId][rarity.Id]
			local isFound = speciesId ~= nil and data.Index[speciesId] ~= nil
			local starborn = speciesId ~= nil and data.Index[`{speciesId}_Starborn`] ~= nil
			makeCell(row, rarityOrder, speciesId, rarity, isFound, starborn)
		end
	end

	-- Star Atlas: a chip per constellation (lit when bound, with the count)
	local atlasTitle = Style.Label(list, "Star Atlas", "Title", 22, theme.Colors.Title)
	atlasTitle.LayoutOrder = 100
	atlasTitle.Size = UDim2.new(1, -8, 0, 30)
	atlasTitle.TextXAlignment = Enum.TextXAlignment.Left
	Style.Outline(atlasTitle, 2)
	local chips = Instance.new("Frame")
	chips.LayoutOrder = 101
	chips.BackgroundTransparency = 1
	chips.Size = UDim2.new(1, -8, 0, 0)
	chips.AutomaticSize = Enum.AutomaticSize.Y
	chips.Parent = list
	local chipGrid = Instance.new("UIGridLayout")
	chipGrid.CellSize = UDim2.new(1 / 3, -6, 0, 38)
	chipGrid.CellPadding = UDim2.fromOffset(8, 8)
	chipGrid.SortOrder = Enum.SortOrder.LayoutOrder
	chipGrid.Parent = chips
	for order, constellation in Constellations do
		local count = data.StarAtlas[constellation.Id] or 0
		local element = constellation.Element and theme.Element[constellation.Element]
		local color = if element then element.Color else theme.Colors.Gold
		local chip = Instance.new("Frame")
		chip.LayoutOrder = order
		if count > 0 then
			Style.CardLook(chip, color)
		else
			chip.BackgroundColor3 = theme.Colors.TextStroke
			chip.BackgroundTransparency = 0.35
			Style.Corner(chip, theme.SmallCorner + 4)
		end
		chip.Parent = chips
		local nameLabel = Style.Label(chip, `★ {constellation.Name}`, "Title", 15, if count > 0 then Style.Shade(color, 0.35) else theme.Colors.TextMuted)
		nameLabel.Position = UDim2.fromOffset(10, 0)
		nameLabel.Size = UDim2.new(1, -54, 1, 0)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextScaled = true
		nameLabel.ZIndex = 3
		Style.Outline(nameLabel, 1.5)
		local nameLimit = Instance.new("UITextSizeConstraint")
		nameLimit.MaxTextSize = 16
		nameLimit.Parent = nameLabel
		local countLabel = Style.Label(chip, if count > 0 then `x{count}` else "-", "Title", 16, theme.Colors.Text)
		countLabel.AnchorPoint = Vector2.new(1, 0)
		countLabel.Position = UDim2.new(1, -10, 0, 0)
		countLabel.Size = UDim2.new(0, 40, 1, 0)
		countLabel.TextXAlignment = Enum.TextXAlignment.Right
		countLabel.ZIndex = 3
		Style.Outline(countLabel, 1.5)
	end
end

function IndexController:Init()
	window = InventoryWindow.AddTab("Collection")
	local content = window.Content

	-- header card: the Index icon, the income bonus big, found count, a bar to the next milestone
	local header = Instance.new("Frame")
	header.Name = "Summary"
	header.Size = UDim2.new(1, 0, 0, 58)
	Style.CardLook(header, UITheme.Colors.Gold)
	header.Parent = content
	local indexIcon = Icon.new(header, "Tab_Collection")
	indexIcon.AnchorPoint = Vector2.new(0, 0.5)
	indexIcon.Position = UDim2.new(0, 6, 0.5, 0)
	indexIcon.Size = UDim2.fromOffset(56, 56)
	indexIcon.ZIndex = 3
	bonusLabel = Style.Label(header, "", "Title", 26, UITheme.Colors.Gold)
	bonusLabel.Position = UDim2.fromOffset(68, 2)
	bonusLabel.Size = UDim2.new(0.45, -68, 0, 32)
	bonusLabel.TextXAlignment = Enum.TextXAlignment.Left
	bonusLabel.ZIndex = 3
	Style.Outline(bonusLabel, 2)
	foundLabel = Style.Label(header, "", "Title", 15, UITheme.Colors.Text)
	foundLabel.Position = UDim2.fromOffset(68, 32)
	foundLabel.Size = UDim2.new(0.45, -68, 0, 20)
	foundLabel.TextXAlignment = Enum.TextXAlignment.Left
	foundLabel.ZIndex = 3
	Style.Outline(foundLabel, 1.5)
	bar = ProgressBar.new(header, UITheme.Colors.Gold)
	bar.Instance.AnchorPoint = Vector2.new(1, 0.5)
	bar.Instance.Position = UDim2.new(1, -14, 0.5, 0)
	bar.Instance.Size = UDim2.new(0.5, -14, 0, 22)
	bar.Instance.ZIndex = 3
	Tooltip.Attach(header, function()
		return rulesText
	end)

	list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(0, 66)
	list.Size = UDim2.new(1, 0, 1, -66)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = UITheme.Colors.Trim
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = content
	Style.Pad(list, 2, 3)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	window:OnOpen(redraw)
	for _, key in { "Index", "StarAtlas", "IndexMilestones" } do
		DataController:OnChanged(key, function()
			if window.IsOpen then
				redraw()
			end
		end)
	end
end

return IndexController
