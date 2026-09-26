--!strict
-- A currency pill: dark rounded bar with a gold trim, the currency icon on the left and the value in its color.
-- Size is set by the caller (HudLayout: bottom-left on PC, small rows top-left on phones).

local Style = require(script.Parent.Style)
local Icon = require(script.Parent.Icon)

local CurrencyPill = {}
CurrencyPill.__index = CurrencyPill

export type CurrencyPill = typeof(setmetatable({} :: {
	Instance: Frame,
	Label: TextLabel,
	Icon: GuiObject,
}, CurrencyPill))

function CurrencyPill.new(parent: Instance, icon: string, color: Color3): CurrencyPill
	local theme = Style.Theme
	local frame = Instance.new("Frame")
	frame.Name = icon
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	Style.Gradient(frame, theme.Colors.PanelTop, theme.Colors.PanelBottom)
	Style.Round(frame)
	Style.Stroke(frame, theme.Colors.TrimDark, 2)

	local image = Icon.new(frame, icon, color, icon)
	image.AnchorPoint = Vector2.new(0, 0.5)
	image.Position = UDim2.new(0, -2, 0.5, 0)
	image.Size = UDim2.fromScale(1.25, 1.25)
	image.ZIndex = 2
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Parent = image

	local label = Style.Label(frame, "", "Heavy", 18, color)
	label.Name = "Value"
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = false
	label.Parent = frame

	local self = setmetatable({ Instance = frame, Label = label, Icon = image }, CurrencyPill)
	self:Layout(false)
	frame.Parent = parent
	return self
end

function CurrencyPill.Set(self: CurrencyPill, text: string)
	self.Label.Text = text
end

-- PC: taller pill, big text. Phone: small pill that grows with its text.
function CurrencyPill.Layout(self: CurrencyPill, phone: boolean)
	local theme = Style.Theme
	local sizes = theme.Sizes
	if phone then
		self.Instance.AutomaticSize = Enum.AutomaticSize.X
		self.Instance.Size = UDim2.fromOffset(0, sizes.PhoneCurrencyRow)
		self.Label.AutomaticSize = Enum.AutomaticSize.X
		self.Label.Size = UDim2.fromScale(0, 1)
		self.Label.Position = UDim2.fromOffset(sizes.PhoneCurrencyRow + 2, 0)
		self.Label.TextSize = sizes.PhoneCurrencyTextSize
		local pad = self.Instance:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
		pad.PaddingRight = UDim.new(0, 10)
		pad.Parent = self.Instance
	else
		self.Instance.AutomaticSize = Enum.AutomaticSize.None
		self.Instance.Size = UDim2.fromOffset(sizes.Currency.X, sizes.Currency.Y)
		self.Label.AutomaticSize = Enum.AutomaticSize.None
		self.Label.Position = UDim2.fromOffset(sizes.Currency.Y + 8, 0)
		self.Label.Size = UDim2.new(1, -(sizes.Currency.Y + 14), 1, 0)
		self.Label.TextSize = 20
		local pad = self.Instance:FindFirstChildOfClass("UIPadding")
		if pad then
			pad.PaddingRight = UDim.new(0, 0)
		end
	end
end

return CurrencyPill
