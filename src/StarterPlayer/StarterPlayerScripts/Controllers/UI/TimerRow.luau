--!strict
-- A HUD timer row for the bottom-right stack (HudLayout.GetTimerStack): the icon + bold italic white text with a dark
-- outline, no background ("[moon] Night in 1m 42s", "[potion] 26m 52s"). The day/night timer sits on top, the potion
-- timers below it. Sizes in UITheme.Sizes (TimerIcon, TimerText, Phone*), font UITheme.Fonts.Timer.
--
-- Usage: local row = TimerRow.new(stack, { Name = "Night", Order = 0, Icons = { "Sky_Sun", "Sky_Moon" }, Color = c })
-- row:SetText("Night in 1m 42s"); row:ShowIcon(2); row:SetColor(color); row:Layout(isPhone)

local Style = require(script.Parent.Style)
local Icon = require(script.Parent.Icon)

local TimerRow = {}
TimerRow.__index = TimerRow

export type Props = {
	Name: string,
	Order: number,
	Icons: { string }, -- UITheme.Icons keys; ShowIcon(i) picks one (the sun / moon swap)
	Color: Color3?, -- fallback tile color when an icon has no art
	Label: string?, -- fallback tile letter
	Clickable: boolean?, -- true = the row is a button (Activated)
}

export type TimerRow = typeof(setmetatable({} :: {
	Instance: TextButton,
	Label: TextLabel,
	Icons: { GuiObject },
	Phone: boolean,
}, TimerRow))

function TimerRow.new(parent: Instance, props: Props): TimerRow
	local colors = Style.Theme.Colors
	local root = Instance.new("TextButton")
	root.Name = props.Name
	root.LayoutOrder = props.Order
	root.Text = ""
	root.AutoButtonColor = false
	root.Active = props.Clickable == true
	root.BackgroundTransparency = 1
	root.AutomaticSize = Enum.AutomaticSize.XY
	root.Size = UDim2.fromOffset(0, 0)
	root.Parent = parent

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = root

	local icons: { GuiObject } = {}
	for index, key in props.Icons do
		local icon = Icon.new(root, key, props.Color, props.Label)
		icon.Name = `Icon{index}`
		icon.LayoutOrder = 1
		icon.Visible = index == 1
		if icon:IsA("ImageLabel") then
			icon.ImageColor3 = Color3.new(1, 1, 1)
		end
		table.insert(icons, icon)
	end

	local label = Instance.new("TextLabel")
	label.Name = "Time"
	label.LayoutOrder = 2
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	label.FontFace = Style.Theme.Fonts.Timer
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = false
	label.Text = ""
	label.Parent = root
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Outline"
	stroke.Color = colors.IconLabelStroke
	stroke.Thickness = 2
	stroke.Parent = label

	if props.Clickable then
		Style.AttachPress(root)
	end
	return setmetatable({ Instance = root, Label = label, Icons = icons, Phone = false }, TimerRow)
end

function TimerRow.SetText(self: TimerRow, text: string)
	self.Label.Text = text
end

function TimerRow.SetColor(self: TimerRow, color: Color3)
	self.Label.TextColor3 = color
end

function TimerRow.ShowIcon(self: TimerRow, index: number)
	for i, icon in self.Icons do
		icon.Visible = i == index
	end
end

function TimerRow.SetVisible(self: TimerRow, visible: boolean)
	self.Instance.Visible = visible
end

function TimerRow.Layout(self: TimerRow, phone: boolean)
	local sizes = Style.Theme.Sizes
	self.Phone = phone
	local iconSize = if phone then sizes.PhoneTimerIcon else sizes.TimerIcon
	self.Label.TextSize = if phone then sizes.PhoneTimerText else sizes.TimerText
	for _, icon in self.Icons do
		icon.Size = UDim2.fromOffset(iconSize, iconSize)
	end
end

-- A small caption line under a timer row (same font, smaller, right-aligned; e.g. tonight's constellation).
-- local caption = TimerRow.NewCaption(stack, 1); caption:SetText("The Veiled Eye"); caption:Layout(isPhone)
export type Caption = { Instance: TextLabel, SetText: (Caption, string) -> (), Layout: (Caption, boolean) -> () }

function TimerRow.NewCaption(parent: Instance, order: number): Caption
	local label = Instance.new("TextLabel")
	label.Name = "Caption"
	label.LayoutOrder = order
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	label.FontFace = Style.Theme.Fonts.Timer
	label.TextColor3 = Style.Theme.Colors.TextMuted
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.TextWrapped = false
	label.Text = ""
	label.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Outline"
	stroke.Color = Style.Theme.Colors.IconLabelStroke
	stroke.Thickness = 1.5
	stroke.Parent = label
	local caption = {} :: any
	caption.Instance = label
	function caption.SetText(_self: Caption, text: string)
		label.Text = text
		label.Visible = text ~= ""
	end
	function caption.Layout(_self: Caption, phone: boolean)
		local sizes = Style.Theme.Sizes
		label.TextSize = if phone then sizes.PhoneTimerCaptionText else sizes.TimerCaptionText
	end
	return caption :: Caption
end

return TimerRow
