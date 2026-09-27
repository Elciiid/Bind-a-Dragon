--!strict
-- Right-side shortcut to inspect placed dragons and return a selected dragon to inventory.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Button = require(script.Parent.UI.Button)
local Window = require(script.Parent.UI.Window)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local returnFromRoost = ReplicatedStorage.Remotes.ReturnFromRoost :: RemoteEvent

local RoostController = {}

local window: Window.Window
local heading: TextLabel
local empty: TextLabel
local list: ScrollingFrame
local dirty = true

local function makeRow(dragonId: string, dragon: any, order: number)
	local species = Dragons[dragon.SpeciesId]
	local element = species and UITheme.Element[species.Element]
	local name = if species then species.Name else dragon.SpeciesId
	local row = Instance.new("Frame")
	row.Name = `Placed_{dragonId}`
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -8, 0, 68)
	Style.CardLook(row, if element then element.Color else nil)
	row.Parent = list

	local title = Style.Label(row, if dragon.Starborn then `★ {name}` else name, "Heavy", 17, if species and UITheme.Rarity[species.Rarity] then UITheme.Rarity[species.Rarity].Color else UITheme.Colors.Text)
	title.Position = UDim2.fromOffset(15, 8)
	title.Size = UDim2.new(1, -144, 0, 24)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.TextWrapped = false

	local stage = DragonStats.GetStage(dragon.Level)
	local detail = Style.Label(row, `{if species then species.Element else "Dragon"} · {stage.Name} · Lv {dragon.Level}`, "Bold", 13, UITheme.Colors.TextMuted)
	detail.Position = UDim2.fromOffset(15, 34)
	detail.Size = UDim2.new(1, -144, 0, 20)
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextTruncate = Enum.TextTruncate.AtEnd
	detail.TextWrapped = false

	local pickUp = Button.new(row, {
		Text = "Pick up",
		Kind = "Primary",
		TextSize = 14,
		OnClick = function()
			returnFromRoost:FireServer(dragonId)
		end,
	})
	pickUp.Instance.AnchorPoint = Vector2.new(1, 0.5)
	pickUp.Instance.Position = UDim2.new(1, -10, 0.5, 0)
	pickUp.Instance.Size = UDim2.fromOffset(108, 40)
end

local function redraw()
	local data = DataController:Get()
	if data == nil then
		return
	end

	local placed = data.RoostDragonIds or {}
	heading.Text = `Placed dragons · {#placed}/{DragonStats.GetRoostSlots(data)}`
	HudLayout.SetSideBadge("PlacedPets", #placed)
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	empty.Visible = #placed == 0
	for order, dragonId in placed do
		local dragon = data.Dragons[dragonId]
		if dragon then
			makeRow(dragonId, dragon, order)
		end
	end
end

function RoostController:Init()
	local open = HudLayout.AddSideButton("PlacedPets")
	window = Window.new({
		Name = "PlacedDragons",
		Title = "Placed Dragons",
		Icon = "Menu_PlacedPets",
		Size = UDim2.new(0.9, 0, 0.75, 0),
		MaxSize = Vector2.new(540, 430),
	})
	local content = window.Content

	heading = Style.Label(content, "Placed dragons", "Heavy", 16, UITheme.Colors.Title)
	heading.Position = UDim2.fromOffset(2, 0)
	heading.Size = UDim2.new(1, -4, 0, 24)
	heading.TextXAlignment = Enum.TextXAlignment.Left

	list = Instance.new("ScrollingFrame")
	list.Name = "PlacedDragonList"
	list.Position = UDim2.fromOffset(0, 30)
	list.Size = UDim2.new(1, 0, 1, -30)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = UITheme.Colors.Trim
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = content
	Style.Pad(list, 2, 3)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = list

	empty = Style.Label(list, "No dragons are placed yet. Place one from your Dragons inventory.", "Bold", 16, UITheme.Colors.TextMuted)
	empty.Name = "EmptyState"
	empty.Size = UDim2.new(1, -12, 0, 54)
	empty.TextWrapped = true

	open.Activated:Connect(function()
		window:Toggle()
		dirty = true
	end)

	local function markDirty()
		dirty = true
	end
	DataController:OnChanged("Dragons", markDirty)
	DataController:OnChanged("RoostDragonIds", markDirty)
end

function RoostController:Start()
	while true do
		if dirty and window.IsOpen then
			dirty = false
			redraw()
		end
		task.wait(0.3)
	end
end

return RoostController
