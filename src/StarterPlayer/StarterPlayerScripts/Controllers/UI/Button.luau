--!strict
-- Chunky rounded text button. Kinds (UITheme.Colors): Confirm (green), Cancel (red), Primary (gold), Neutral.
-- Optional icon on the left. Press/hover scale and click sound. SetEnabled(false) greys it out and ignores clicks.

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
}, Button))

local function colorsFor(kind: Kind): Color3
	return (Style.Theme.Colors :: any)[kind] or Style.Theme.Colors.Primary
end

function Button.new(parent: Instance, props: Props): Button
	local theme = Style.Theme
	local instance = Instance.new("TextButton")
	instance.Name = props.Text
	instance.Text = ""
	instance.AutoButtonColor = false
	instance.BackgroundColor3 = Color3.new(1, 1, 1)
	Style.Corner(instance, theme.SmallCorner)
	Style.Stroke(instance, theme.Colors.TextStroke, theme.Strokes.Button)
	local kind: Kind = props.Kind or "Primary"
	local base = colorsFor(kind)
	local gradient = Style.Gradient(instance, Style.Shade(base, 0.18), Style.Shade(base, -0.18))

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.Size = UDim2.fromScale(1, 1)
	row.BackgroundTransparency = 1
	row.Parent = instance
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
		icon.Size = UDim2.new(1, 0, 0.75, 0) -- the constraint below makes it a square from the button's height
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.DominantAxis = Enum.DominantAxis.Height
		ratio.Parent = icon
	end
	local label = Style.Label(row, props.Text, "Heavy", props.TextSize or theme.TextSizes.Button)
	label.LayoutOrder = 2
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	label.TextWrapped = false

	local self = setmetatable({
		Instance = instance,
		Kind = kind,
		Enabled = true,
		Label = label,
		Gradient = gradient,
	}, Button)
	Style.AttachPress(instance, props.Sound)
	instance.Activated:Connect(function()
		if self.Enabled and props.OnClick then
			props.OnClick()
		end
	end)
	instance.Parent = parent
	return self
end

function Button.SetText(self: Button, text: string)
	self.Label.Text = text
end

function Button.SetKind(self: Button, kind: Kind)
	self.Kind = kind
	if self.Enabled then
		local base = colorsFor(kind)
		self.Gradient.Color = ColorSequence.new(Style.Shade(base, 0.18), Style.Shade(base, -0.18))
	end
end

function Button.SetEnabled(self: Button, enabled: boolean)
	self.Enabled = enabled
	local base = if enabled then colorsFor(self.Kind) else Style.Theme.Colors.Disabled
	self.Gradient.Color = ColorSequence.new(Style.Shade(base, 0.18), Style.Shade(base, -0.18))
end

return Button
