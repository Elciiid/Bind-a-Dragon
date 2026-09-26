--!strict
-- Dragon Index window (extends the Star Atlas): the "Index" menu tile opens a grid of every species by element and
-- rarity (rarity gem, name when found, "???" when not, a gold ★ outline when the Starborn variant is found too),
-- the Index income bonus, progress to the next milestone, and the Star Atlas (constellations bound).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Icon = require(script.Parent.UI.Icon)
local Window = require(script.Parent.UI.Window)
local Tooltip = require(script.Parent.UI.Tooltip)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Constellations = require(ReplicatedStorage.Shared.Config.Constellations)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Elements = require(ReplicatedStorage.Shared.Config.Elements)
local IndexConfig = require(ReplicatedStorage.Shared.Config.Index)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local IndexController = {}

local window: Window.Window
local summary: TextLabel
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
	cell.Size = UDim2.new(0.168, -5, 1, 0)
	Style.CardLook(cell)
	local stroke = cell:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if starborn then theme.Colors.Title elseif found then rarity.Color else theme.Colors.PanelInnerLine
		stroke.Thickness = if starborn then 3 else 2
	end
	cell.Parent = row

	local look = theme.Rarity[rarity.Id]
	local gem = Icon.new(cell, if look then look.Icon else "", rarity.Color, rarity.Id)
	gem.AnchorPoint = Vector2.new(0.5, 0)
	gem.Position = UDim2.new(0.5, 0, 0, 3)
	gem.Size = UDim2.new(0, 22, 0, 22)
	if not found and gem:IsA("ImageLabel") then
		gem.ImageTransparency = 0.6
	end
	local name = if speciesId and found then Dragons[speciesId].Name else "???"
	local label = Style.Label(cell, if starborn then `★ {name}` else name, "Heavy", 13, if found then rarity.Color else theme.Colors.TextMuted)
	label.Position = UDim2.new(0, 3, 0, 26)
	label.Size = UDim2.new(1, -6, 1, -28)
	label.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 14
	limit.Parent = label
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
	local speciesCount = 0
	for _ in Dragons do
		speciesCount += 1
	end
	summary.Text = `Index income {Format.Multiplier(DragonStats.GetIndexMultiplier(data))} · {entries} entries`
		.. ` · {#complete} element{if #complete == 1 then "" else "s"} complete`
		.. (if all then " · All species found!" else ` · Next reward at {nextMilestone}`)

	local rules = Style.Label(
		list,
		`+{math.floor(IndexConfig.IncomePerEntry * 100)}% per entry · x{IndexConfig.ElementMultiplier} per complete element · x{IndexConfig.AllSpeciesMultiplier} for all {speciesCount} species · Starborn count as their own entries`,
		"Body",
		theme.TextSizes.Small,
		theme.Colors.TextMuted
	)
	rules.LayoutOrder = 0
	rules.Size = UDim2.new(1, -8, 0, 30)
	rules.TextXAlignment = Enum.TextXAlignment.Left

	local grid = getGrid()
	for order, elementId in getElementOrder() do
		local row = Instance.new("Frame")
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -8, 0, 58)
		row.BackgroundTransparency = 1
		row.Parent = list
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 5)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Parent = row

		local element = theme.Element[elementId]
		local isComplete = table.find(complete, elementId) ~= nil
		local head = Style.Label(row, if isComplete then `{elementId} ✓` else elementId, "Title", 18, if element then element.Color else theme.Colors.Text)
		head.LayoutOrder = 0
		head.Size = UDim2.new(0.16, 0, 1, 0)
		head.TextScaled = true
		local headLimit = Instance.new("UITextSizeConstraint")
		headLimit.MaxTextSize = 20
		headLimit.Parent = head

		for rarityOrder, rarity in Rarities do
			local speciesId = grid[elementId] and grid[elementId][rarity.Id]
			local found = speciesId ~= nil and data.Index[speciesId] ~= nil
			local starborn = speciesId ~= nil and data.Index[`{speciesId}_Starborn`] ~= nil
			makeCell(row, rarityOrder, speciesId, rarity, found, starborn)
		end
	end

	-- Star Atlas
	local atlasTitle = Style.Label(list, "Star Atlas", "Title", 20, theme.Colors.Title)
	atlasTitle.LayoutOrder = 100
	atlasTitle.Size = UDim2.new(1, -8, 0, 28)
	atlasTitle.TextXAlignment = Enum.TextXAlignment.Left
	for order, constellation in Constellations do
		local count = data.StarAtlas[constellation.Id] or 0
		local element = constellation.Element and theme.Element[constellation.Element]
		local line = Style.Label(
			list,
			if count > 0 then `★ {constellation.Name} · bound {count}x` else `{constellation.Name} · not bound yet`,
			"Bold",
			15,
			if count == 0 then theme.Colors.TextMuted elseif element then element.Color else theme.Colors.Gold
		)
		line.LayoutOrder = 100 + order
		line.Size = UDim2.new(1, -8, 0, 20)
		line.TextXAlignment = Enum.TextXAlignment.Left
	end
end

function IndexController:Init()
	local open = HudLayout.AddMenuButton("Index")
	window = Window.new({
		Name = "Index",
		Title = "Dragon Index",
		Icon = "Menu_Index",
		Size = UDim2.new(0.92, 0, 0.8, 0),
		MaxSize = Vector2.new(720, 560),
	})
	local content = window.Content

	summary = Style.Label(content, "", "Heavy", 16, UITheme.Colors.Gold)
	summary.Size = UDim2.new(1, 0, 0, 20)
	summary.TextXAlignment = Enum.TextXAlignment.Left
	summary.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 16
	limit.Parent = summary

	list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(0, 26)
	list.Size = UDim2.new(1, 0, 1, -26)
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

	open.Activated:Connect(function()
		window:Toggle()
	end)
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
