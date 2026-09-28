--!strict
-- WorldBoard: a small themed sign floating over something in the world (BillboardGui) in the window style made small
-- (Style.WorldPanel: navy glass, gold border, gold diamonds on the ends, a little star on top), with an optional icon
-- popping out on the left, a title in the title font and an optional second line. Follows the world label rules
-- (hidden past UITheme.WorldLabels.MaxDistance, hidden behind terrain/buildings).
-- Usage: local board = WorldBoard.new(part, { Size = Vector2, Icon = "Gold", OffsetY = 3 }); board:Set("Title", "Line")

local Style = require(script.Parent.Style)
local Icon = require(script.Parent.Icon)

local WorldBoard = {}
WorldBoard.__index = WorldBoard

export type Props = { Size: Vector2, Icon: string?, OffsetY: number?, MaxDistance: number?, Color: Color3? }

export type WorldBoard = typeof(setmetatable({} :: {
	Gui: BillboardGui,
	Title: TextLabel,
	Line: TextLabel,
}, WorldBoard))

local STAR_ROOM = 8 -- pixels above the panel for the star

function WorldBoard.new(adornee: Instance, props: Props): WorldBoard
	local theme = Style.Theme
	local gui = Instance.new("BillboardGui")
	gui.Name = "WorldBoard"
	gui.Size = UDim2.fromOffset(props.Size.X + 12, props.Size.Y + STAR_ROOM)
	gui.StudsOffsetWorldSpace = Vector3.new(0, props.OffsetY or 3, 0)
	gui.MaxDistance = props.MaxDistance or theme.WorldLabels.MaxDistance
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.ClipsDescendants = false
	gui.Adornee = adornee
	gui.Parent = adornee

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.fromScale(0.5, 1)
	panel.Size = UDim2.fromOffset(props.Size.X, props.Size.Y)
	Style.WorldPanel(panel, props.Color, true)
	panel.Parent = gui

	local textLeft = 10
	if props.Icon then
		local iconSize = props.Size.Y + 2 -- a bit bigger than the board, so it pops out
		local icon = Icon.new(panel, props.Icon)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, -6, 0.5, 0)
		icon.Size = UDim2.fromOffset(iconSize, iconSize)
		icon.ZIndex = 6 -- over the left end ornament
		textLeft = iconSize - 2
	end
	local title = Style.Label(panel, "", "Title", 18, props.Color or theme.Colors.Gold)
	title.Position = UDim2.fromOffset(textLeft, 4)
	title.Size = UDim2.new(1, -(textLeft + 8), 0.55, -4)
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 2
	Style.Outline(title, 1.5)
	local line = Style.Label(panel, "", "Heavy", 13, theme.Colors.Text)
	line.Position = UDim2.new(0, textLeft, 0.55, 0)
	line.Size = UDim2.new(1, -(textLeft + 8), 0.45, -4)
	line.TextScaled = true
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.ZIndex = 2

	return setmetatable({ Gui = gui, Title = title, Line = line }, WorldBoard)
end

-- Sets the texts; with no second line the title fills the board.
function WorldBoard.Set(self: WorldBoard, title: string, line: string?)
	if self.Title.Text ~= title then
		self.Title.Text = title
	end
	local hasLine = line ~= nil and line ~= ""
	self.Line.Visible = hasLine
	if hasLine and self.Line.Text ~= line then
		self.Line.Text = line :: string
	end
	self.Title.Size = if hasLine then UDim2.new(self.Title.Size.X.Scale, self.Title.Size.X.Offset, 0.55, -4)
		else UDim2.new(self.Title.Size.X.Scale, self.Title.Size.X.Offset, 1, -8)
end

function WorldBoard.SetEnabled(self: WorldBoard, enabled: boolean)
	self.Gui.Enabled = enabled
end

return WorldBoard
