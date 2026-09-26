--!strict
-- Dragon Index panel (extends the Star Atlas): an "Index" button opens a grid of every species by element and
-- rarity (found ones named, unknown ones "???", ★ when the Starborn variant is found too), the Index income bonus,
-- progress to the next milestone, and the Star Atlas (constellations bound). Placeholder UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Constellations = require(ReplicatedStorage.Shared.Config.Constellations)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Elements = require(ReplicatedStorage.Shared.Config.Elements)
local IndexConfig = require(ReplicatedStorage.Shared.Config.Index)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

local DARK = Color3.fromRGB(15, 15, 30)
local CARD = Color3.fromRGB(32, 32, 55)
local GREY = Color3.fromRGB(120, 120, 130)
local GOLD = Color3.fromRGB(255, 210, 70)

local IndexController = {}

local panel: Frame
local summary: TextLabel
local list: ScrollingFrame

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

local function label(parent: Instance, text: string, color: Color3, bold: boolean): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	l.Parent = parent
	return l
end

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

	local entries = DragonStats.GetIndexEntryCount(data)
	local complete, all = DragonStats.GetIndexCompletion(data)
	local nextMilestone = (data.IndexMilestones + 1) * IndexConfig.MilestoneEvery
	local speciesCount = 0
	for _ in Dragons do
		speciesCount += 1
	end
	summary.Text = `Index income {Format.Multiplier(DragonStats.GetIndexMultiplier(data))}  ·  {entries} entries`
		.. `  ·  {#complete} element{if #complete == 1 then "" else "s"} complete`
		.. (if all then "  ·  All species found!" else `  ·  Next reward at {nextMilestone}`)
		.. `\n+{math.floor(IndexConfig.IncomePerEntry * 100)}% per entry, x{IndexConfig.ElementMultiplier} per complete element,`
		.. ` x{IndexConfig.AllSpeciesMultiplier} for all {speciesCount} species. Starborn count as their own entries.`

	local grid = getGrid()
	for order, elementId in getElementOrder() do
		local row = Instance.new("Frame")
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -8, 0, 54)
		row.BackgroundTransparency = 1
		row.Parent = list
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = row

		local element = Elements[elementId]
		local isComplete = table.find(complete, elementId) ~= nil
		local head = label(row, if isComplete then `{elementId} ✓` else elementId, if element then element.Color else GREY, true)
		head.LayoutOrder = 0
		head.Size = UDim2.new(0.16, 0, 1, 0)

		for rarityOrder, rarity in Rarities do
			local speciesId = grid[elementId] and grid[elementId][rarity.Id]
			local found = speciesId ~= nil and data.Index[speciesId] ~= nil
			local starborn = speciesId ~= nil and data.Index[`{speciesId}_Starborn`] ~= nil
			local cell = Instance.new("TextLabel")
			cell.LayoutOrder = rarityOrder
			cell.Size = UDim2.new(0.168, -4, 1, 0)
			cell.BackgroundColor3 = CARD
			cell.Font = Enum.Font.GothamBold
			cell.TextScaled = true
			cell.TextColor3 = if found then rarity.Color else GREY
			local name = if speciesId and found then Dragons[speciesId].Name else "???"
			cell.Text = `{name}{if starborn then " ★" else ""}\n{rarity.Name}`
			round(cell)
			pad(cell, 5)
			if starborn then
				local stroke = Instance.new("UIStroke")
				stroke.Color = IndexConfig.StarbornColor
				stroke.Thickness = 2
				stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				stroke.Parent = cell
			end
			cell.Parent = row
		end
	end

	-- Star Atlas
	local atlasTitle = label(list, "Star Atlas", Color3.new(1, 1, 1), true)
	atlasTitle.LayoutOrder = 100
	atlasTitle.Size = UDim2.new(1, -8, 0, 24)
	atlasTitle.TextXAlignment = Enum.TextXAlignment.Left
	for order, constellation in Constellations do
		local count = data.StarAtlas[constellation.Id] or 0
		local element = constellation.Element and Elements[constellation.Element]
		local line = label(
			list,
			if count > 0 then `{constellation.Name}  ·  bound {count}x` else `{constellation.Name}  ·  not bound yet`,
			if count == 0 then GREY elseif element then element.Color else GOLD,
			false
		)
		line.LayoutOrder = 100 + order
		line.Size = UDim2.new(1, -8, 0, 20)
		line.TextXAlignment = Enum.TextXAlignment.Left
	end
end

function IndexController:Init()
	local gui = HudLayout.MakeScreenGui("Index", "Popups")
	local open = HudLayout.AddMenuButton("Index")

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.92, 0, 0.8, 0)
	panel.BackgroundColor3 = DARK
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	round(panel)
	panel.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(720, 560)
	limit.Parent = panel
	HudLayout.RegisterPopup(panel, UDim2.new(0.92, 0, 0.8, 0))

	local title = label(panel, "Dragon Index", Color3.new(1, 1, 1), true)
	title.Position = UDim2.new(0, 14, 0, 10)
	title.Size = UDim2.new(1, -70, 0, 26)
	title.TextXAlignment = Enum.TextXAlignment.Left

	summary = label(panel, "", Color3.fromRGB(190, 190, 205), false)
	summary.Position = UDim2.new(0, 14, 0, 40)
	summary.Size = UDim2.new(1, -28, 0, 34)
	summary.TextXAlignment = Enum.TextXAlignment.Left

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

	list = Instance.new("ScrollingFrame")
	list.Position = UDim2.new(0, 10, 0, 82)
	list.Size = UDim2.new(1, -20, 1, -92)
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

	open.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			redraw()
		end
	end)
	for _, key in { "Index", "StarAtlas", "IndexMilestones" } do
		DataController:OnChanged(key, function()
			if panel.Visible then
				redraw()
			end
		end)
	end
end

return IndexController
