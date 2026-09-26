--!strict
-- Progress bar: dark rounded track, colored fill with a light-to-dark gradient, centered text.

local TweenService = game:GetService("TweenService")

local Style = require(script.Parent.Style)

local ProgressBar = {}
ProgressBar.__index = ProgressBar

export type ProgressBar = typeof(setmetatable({} :: {
	Instance: Frame,
	Fill: Frame,
	Label: TextLabel,
}, ProgressBar))

function ProgressBar.new(parent: Instance, color: Color3?): ProgressBar
	local theme = Style.Theme
	local track = Instance.new("Frame")
	track.Name = "ProgressBar"
	track.BackgroundColor3 = theme.Colors.PanelInnerLine
	Style.Round(track)
	Style.Stroke(track, theme.Colors.TextStroke, 1.5)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	local base = color or theme.Colors.Confirm
	Style.Gradient(fill, Style.Shade(base, 0.2), Style.Shade(base, -0.15))
	Style.Round(fill)
	fill.Parent = track

	local label = Style.Label(track, "", "Heavy", 13)
	label.Size = UDim2.fromScale(1, 1)
	label.ZIndex = 2

	track.Parent = parent
	return setmetatable({ Instance = track, Fill = fill, Label = label }, ProgressBar)
end

function ProgressBar.Set(self: ProgressBar, fraction: number, text: string?, animate: boolean?)
	local goal = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	if animate then
		TweenService:Create(self.Fill, TweenInfo.new(0.25), { Size = goal }):Play()
	else
		self.Fill.Size = goal
	end
	self.Label.Text = text or ""
end

return ProgressBar
