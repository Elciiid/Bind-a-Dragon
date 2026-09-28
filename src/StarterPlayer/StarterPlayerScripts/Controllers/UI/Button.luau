--!strict
-- Chunky rounded 3D button (UI renewal part 2): a bright jewel face on a darker bottom edge (UITheme.Sizes.ButtonEdge)
-- with a glossy top, the label in the title font with an outline, and an optional icon on the left. It bounces on
-- hover, squishes and drops onto its edge while pressed, and plays the click sound. Kinds (UITheme.Colors): Confirm
-- (jade = go / buy), Primary (gold = upgrade), Cancel (rose = stop / close), Neutral (blue). SetEnabled(false)
-- turns it clearly grey and ignores clicks.

local TweenService = game:GetService("TweenService")

local Style = require(script.Parent.Style)
local Icon = require(script.Parent.Icon)

export type Kind = "Confirm" | "Cancel" | "Primary" | "Neutral"
export type Props = {
	Text: string,
	Kind: Kind?,
	Icon: string?, -- UITheme.Icons key
	TextSize: number?,
	OnClick: (() -> ())?,
	Sound: string?, -- UITheme.Sounds key (default Click)
}

local Button = {}
Button.__index = Button

export type Button = typeof(setmetatable({} :: {
	Instance: TextButton,
	Kind: Kind,
	Enabled: boolean,
	Label: TextLabel,
	Gradient: UIGradient,
	Face: Frame,
	Edge: Frame,
}, Button))

local function colorFor(kind: Kind): Color3
	return (Style.Theme.Colors :: any)[kind] or Style.Theme.Colors.Primary
end

function Button.new(parent: Instance, props: Props): Button
	local theme = Style.Theme
	local edgeSize = theme.Sizes.ButtonEdge
	local radius = theme.SmallCorner + theme.Buttons.CornerExtra + 2
	local kind: Kind = props.Kind or "Primary"

	local instance = Instance.new("TextButton")
	instance.Name = props.Text
	instance.Text = ""
	instance.AutoButtonColor = false
	instance.BackgroundTransparency = 1

	local edge = Instance.new("Frame") -- the darker bottom edge the face sits on
	edge.Name = "Edge"
	edge.Size = UDim2.fromScale(1, 1)
	edge.BorderSizePixel = 0
	Style.Corner(edge, radius)
	local edgeOutline = Style.Stroke(edge, theme.Colors.TextStroke, 1.5)
	edgeOutline.Transparency = 0.35
	edge.Parent = instance

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.new(1, 0, 1, -edgeSize)
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.BorderSizePixel = 0
	Style.Corner(face, radius)
	local gradient = Style.Gradient(face, Color3.new(1, 1, 1), Color3.new(1, 1, 1))
	face.Parent = instance
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.BackgroundTransparency = 0.72
	gloss.BorderSizePixel = 0
	gloss.Position = UDim2.new(0, 5, 0, 3)
	gloss.Size = UDim2.new(1, -10, 0.4, 0)
	Style.Corner(gloss, radius - 2)
	gloss.Parent = face

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.Size = UDim2.fromScale(1, 1)
	row.BackgroundTransparency = 1
	row.ZIndex = 2
	row.Parent = face
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	if props.Icon then
		local icon = Icon.new(row, props.Icon)
		icon.LayoutOrder = 1
		icon.Size = UDim2.new(1, 0, 0.9, 0) -- a square from the face's height (constraint below), a bit big
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.DominantAxis = Enum.DominantAxis.Height
		ratio.Parent = icon
	end
	local label = Style.Label(row, props.Text, "Title", props.TextSize or theme.TextSizes.Button, theme.Colors.ButtonText)
	label.Name = "Label"
	label.LayoutOrder = 2
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	label.TextWrapped = false
	Style.Outline(label, 1.5)

	local self = setmetatable({
		Instance = instance,
		Kind = kind,
		Enabled = true,
		Label = label,
		Gradient = gradient,
		Face = face,
		Edge = edge,
	}, Button)
	self:SetKind(kind)

	-- Motion: bounce on hover, squish + drop onto the edge while pressed.
	local scale = Instance.new("UIScale")
	scale.Parent = instance
	local motion = theme.Motion
	local hovering, pressing = false, false
	local function update()
		local target = if pressing then motion.ButtonSquish.Y elseif hovering and self.Enabled then motion.ButtonBounce else 1
		TweenService:Create(scale, TweenInfo.new(if pressing then 0.06 else 0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
		face.Position = if pressing then UDim2.fromOffset(0, edgeSize - 1) else UDim2.new()
	end
	instance.MouseEnter:Connect(function()
		hovering = true
		update()
	end)
	instance.MouseLeave:Connect(function()
		hovering, pressing = false, false
		update()
	end)
	instance.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) and self.Enabled then
			pressing = true
			update()
		end
	end)
	instance.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			pressing = false
			update()
		end
	end)
	instance.Activated:Connect(function()
		if not self.Enabled then
			Style.Play("Error")
			return
		end
		Style.Play(props.Sound or "Click")
		if props.OnClick then
			props.OnClick()
		end
	end)
	instance.Parent = parent
	return self
end

function Button.SetText(self: Button, text: string)
	self.Label.Text = text
end

local function paint(self: Button)
	local shades = Style.Theme.Buttons
	local base = if self.Enabled then colorFor(self.Kind) else Style.Theme.Colors.Disabled
	self.Gradient.Color = ColorSequence.new(Style.Shade(base, shades.ShadeTop + 0.06), Style.Shade(base, shades.ShadeBottom + 0.05))
	self.Edge.BackgroundColor3 = Style.Shade(base, -0.45)
	self.Label.TextColor3 = if self.Enabled then Style.Theme.Colors.ButtonText else Style.Theme.Colors.DisabledText
	self.Label.TextTransparency = if self.Enabled then 0 else Style.Theme.Buttons.DisabledTextTransparency
end

function Button.SetKind(self: Button, kind: Kind)
	self.Kind = kind
	paint(self)
end

function Button.SetEnabled(self: Button, enabled: boolean)
	self.Enabled = enabled
	paint(self)
end

return Button
