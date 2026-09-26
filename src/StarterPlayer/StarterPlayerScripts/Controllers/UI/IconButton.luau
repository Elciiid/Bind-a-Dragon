--!strict
-- Menu tile: a rounded square in the button's color with its icon on top and a label below, a red count badge
-- (top-right) and an optional pulsing outline. Size is set by the caller (HudLayout).

local RunService = game:GetService("RunService")

local Style = require(script.Parent.Style)
local Icon = require(script.Parent.Icon)

export type Props = {
	Icon: string, -- UITheme.Icons key or asset id
	Label: string,
	Color: Color3,
}

local IconButton = {}
IconButton.__index = IconButton

export type IconButton = typeof(setmetatable({} :: {
	Instance: TextButton,
	Label: TextLabel,
	Badge: TextLabel,
	Pulse: UIStroke,
	Pulsing: boolean,
}, IconButton))

local pulsing: { IconButton } = {}
local pulseConnection: RBXScriptConnection? = nil

function IconButton.new(parent: Instance, props: Props): IconButton
	local theme = Style.Theme
	local instance = Instance.new("TextButton")
	instance.Name = props.Label
	instance.Text = ""
	instance.AutoButtonColor = false
	instance.BackgroundColor3 = Color3.new(1, 1, 1)
	Style.Gradient(instance, Style.Shade(props.Color, 0.25), Style.Shade(props.Color, -0.2))
	Style.Corner(instance, theme.SmallCorner + 2)
	Style.Stroke(instance, theme.Colors.TextStroke, theme.Strokes.Button)

	local icon = Icon.new(instance, props.Icon, props.Color, props.Label)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 3)
	icon.Size = UDim2.new(0.72, 0, 0.66, 0)
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Parent = icon

	local label = Style.Label(instance, props.Label, "Heavy", theme.Sizes.MenuLabelSize)
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -2)
	label.Size = UDim2.new(1, -4, 0.3, 0)
	label.TextWrapped = false

	local badge = Style.Label(instance, "", "Heavy", 13)
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(1, -4, 0, 4)
	badge.Size = UDim2.fromOffset(theme.Sizes.Badge, theme.Sizes.Badge)
	badge.BackgroundTransparency = 0
	badge.BackgroundColor3 = theme.Colors.Badge
	badge.TextScaled = true
	badge.Visible = false
	badge.ZIndex = 3
	Style.Round(badge)
	Style.Stroke(badge, Color3.new(1, 1, 1), 1.5)
	Style.Pad(badge, 3)

	local pulse = Style.Stroke(instance, theme.Colors.Sparkle, 0)
	pulse.Name = "Pulse"

	local self = setmetatable({ Instance = instance, Label = label, Badge = badge, Pulse = pulse, Pulsing = false }, IconButton)
	Style.AttachPress(instance)
	instance.Parent = parent
	return self
end

function IconButton.SetBadge(self: IconButton, count: number)
	self.Badge.Text = if count > 99 then "99+" else tostring(count)
	self.Badge.Visible = count > 0
end

function IconButton.SetLabel(self: IconButton, text: string)
	self.Label.Text = text
end

-- A pulsing outline that asks for attention (e.g. unused potions).
function IconButton.SetPulse(self: IconButton, on: boolean)
	if on == self.Pulsing then
		return
	end
	self.Pulsing = on
	if on then
		table.insert(pulsing, self)
	else
		local index = table.find(pulsing, self)
		if index then
			table.remove(pulsing, index)
		end
		self.Pulse.Thickness = 0
	end
	if pulseConnection == nil then
		pulseConnection = RunService.RenderStepped:Connect(function()
			local thickness = 1.5 + 1.5 * math.sin(os.clock() * Style.Theme.Motion.BadgePulse)
			for _, button in pulsing do
				button.Pulse.Thickness = thickness
			end
		end)
	end
end

return IconButton
