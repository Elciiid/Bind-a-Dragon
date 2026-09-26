--!strict
-- WorldBoard: a small themed sign floating over something in the world (BillboardGui): night-sky panel with gold trim,
-- an optional icon, a title line and an optional second line. Follows the world label rules (hidden past
-- UITheme.WorldLabels.MaxDistance, hidden behind terrain/buildings).
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

function WorldBoard.new(adornee: Instance, props: Props): WorldBoard
	local theme = Style.Theme
	local gui = Instance.new("BillboardGui")
	gui.Name = "WorldBoard"
	gui.Size = UDim2.fromOffset(props.Size.X, props.Size.Y)
	gui.StudsOffsetWorldSpace = Vector3.new(0, props.OffsetY or 3, 0)
	gui.MaxDistance = props.MaxDistance or theme.WorldLabels.MaxDistance
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Adornee = adornee
	gui.Parent = adornee

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	Style.Gradient(panel, theme.Colors.PanelTop, theme.Colors.PanelBottom)
	panel.BackgroundColor3 = Color3.new(1, 1, 1)
	Style.Corner(panel, theme.SmallCorner)
	Style.Stroke(panel, props.Color or theme.Colors.Trim, 2)
	panel.Parent = gui

	local textLeft = 8
	if props.Icon then
		local icon = Icon.new(panel, props.Icon)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, 6, 0.5, 0)
		icon.Size = UDim2.new(0, props.Size.Y - 10, 0, props.Size.Y - 10)
		textLeft = props.Size.Y
	end
	local title = Style.Label(panel, "", "Heavy", 16, props.Color or theme.Colors.Gold)
	title.Position = UDim2.fromOffset(textLeft, 3)
	title.Size = UDim2.new(1, -(textLeft + 6), 0.55, -3)
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	local line = Style.Label(panel, "", "Bold", 13, theme.Colors.TextMuted)
	line.Position = UDim2.new(0, textLeft, 0.55, 0)
	line.Size = UDim2.new(1, -(textLeft + 6), 0.45, -3)
	line.TextScaled = true
	line.TextXAlignment = Enum.TextXAlignment.Left

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
	self.Title.Size = if hasLine then UDim2.new(self.Title.Size.X.Scale, self.Title.Size.X.Offset, 0.55, -3)
		else UDim2.new(self.Title.Size.X.Scale, self.Title.Size.X.Offset, 1, -6)
end

function WorldBoard.SetEnabled(self: WorldBoard, enabled: boolean)
	self.Gui.Enabled = enabled
end

return WorldBoard
