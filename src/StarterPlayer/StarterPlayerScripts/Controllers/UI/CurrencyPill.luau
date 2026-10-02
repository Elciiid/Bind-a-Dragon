--!strict
-- A currency pill in the HUD icon style: an indigo -> violet bar with a gold border and a soft gloss, the currency icon big
-- and standalone over its left end (with a drop shadow), and the value in the title font in the currency's color
-- with a dark outline. Size is set by the caller (HudLayout: bottom-left on PC, one small row top-left on phones).

local Style = require(script.Parent.Style)
local Icon = require(script.Parent.Icon)

local CurrencyPill = {}
CurrencyPill.__index = CurrencyPill

export type CurrencyPill = typeof(setmetatable({} :: {
	Instance: Frame,
	Label: TextLabel,
	Icon: GuiObject,
	Shadow: GuiObject,
}, CurrencyPill))

function CurrencyPill.new(parent: Instance, icon: string, color: Color3): CurrencyPill
	local theme = Style.Theme
	local frame = Instance.new("Frame")
	frame.Name = icon
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 0.12
	Style.Gradient(frame, theme.Colors.PanelV2Top, theme.Colors.PanelV2Bottom)
	Style.Round(frame)
	Style.GoldBorder(frame, 2)
	local gloss = Instance.new("Frame") -- a soft light along the top
	gloss.Name = "Gloss"
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.BackgroundTransparency = 0.85
	gloss.BorderSizePixel = 0
	gloss.Position = UDim2.new(0, 6, 0, 2)
	gloss.Size = UDim2.new(1, -12, 0.4, 0)
	Style.Round(gloss)
	gloss.Parent = frame

	local shadow = Icon.new(frame, icon, color, icon)
	shadow.Name = "Shadow"
	shadow.AnchorPoint = Vector2.new(0, 0.5)
	shadow.ZIndex = 2
	if shadow:IsA("ImageLabel") then
		shadow.ImageColor3 = theme.Colors.IconShadow
		shadow.ImageTransparency = 0.5
	end
	local image = Icon.new(frame, icon, color, icon)
	image.AnchorPoint = Vector2.new(0, 0.5)
	image.ZIndex = 3
	for _, art in { shadow, image } do
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.Parent = art
	end

	local label = Instance.new("TextLabel")
	label.Name = "Value"
	label.BackgroundTransparency = 1
	label.Font = theme.Fonts.Title
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = false
	label.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = theme.Colors.IconLabelStroke
	stroke.Thickness = 2
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label

	local self = setmetatable({ Instance = frame, Label = label, Icon = image, Shadow = shadow }, CurrencyPill)
	self:Layout(false)
	frame.Parent = parent
	return self
end

function CurrencyPill.Set(self: CurrencyPill, text: string)
	self.Label.Text = text
end

-- PC: a tall pill with big text. Phone: a small pill that grows with its text.
function CurrencyPill.Layout(self: CurrencyPill, phone: boolean)
	local sizes = Style.Theme.Sizes
	local height = if phone then sizes.PhoneCurrencyRow else sizes.Currency.Y
	local iconSize = math.floor(height * 1.45)
	self.Icon.Size = UDim2.fromOffset(iconSize, iconSize)
	self.Icon.Position = UDim2.new(0, -math.floor(iconSize * 0.3), 0.5, 0)
	self.Shadow.Size = self.Icon.Size
	self.Shadow.Position = self.Icon.Position + UDim2.fromOffset(2, 3)
	local left = math.floor(iconSize * 0.72)
	local pad = self.Instance:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	pad.Parent = self.Instance
	-- the same stacked pill on PC and phone (phones just scale it down)
	local width = if phone then sizes.PhoneCurrency.X else sizes.Currency.X
	self.Instance.AutomaticSize = Enum.AutomaticSize.None
	self.Instance.Size = UDim2.fromOffset(width, height)
	self.Label.AutomaticSize = Enum.AutomaticSize.None
	self.Label.Position = UDim2.fromOffset(left, 0)
	self.Label.Size = UDim2.new(1, -(left + 8), 1, 0)
	self.Label.TextSize = if phone then sizes.PhoneCurrencyTextSize else 22
	pad.PaddingRight = UDim.new(0, 0)
	self.Label:FindFirstChildOfClass("UIStroke").Thickness = if phone then 1.5 else 2
end

return CurrencyPill
