--!strict
-- Progress bar: dark rounded track with a gold rim, a glossy colored fill, the text centered in the title font.

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
	track.BackgroundColor3 = theme.Colors.TextStroke
	track.BackgroundTransparency = 0.15
	Style.Round(track)
	Style.GoldBorder(track, 2)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	local base = color or theme.Colors.Confirm
	Style.Gradient(fill, Style.Shade(base, 0.2), Style.Shade(base, -0.15))
	Style.Round(fill)
	fill.Parent = track
	local gloss = Instance.new("Frame") -- a light line along the top of the fill
	gloss.Name = "Gloss"
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.BackgroundTransparency = 0.7
	gloss.BorderSizePixel = 0
	gloss.Position = UDim2.new(0, 4, 0.12, 0)
	gloss.Size = UDim2.new(1, -8, 0.28, 0)
	Style.Round(gloss)
	gloss.Parent = fill

	local label = Style.Label(track, "", "Title", 14)
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.ZIndex = 2
	Style.Outline(label, 1.5)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.08, 0)
	pad.Parent = label
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 16
	limit.Parent = label

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
