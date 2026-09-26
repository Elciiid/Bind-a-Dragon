--!strict
-- Window: the standard popup panel. Night-sky panel with gold trim and sparkles, a title bar with a constellation
-- motif and the title in the title font, a red X close button top-right, and a pop-in/out animation with sounds.
-- Windows register with HudLayout, so they draw above the HUD and fill the screen on phones. Only one window is open
-- at a time: opening one closes any other window or station panel (HudLayout.ClaimFocus).
--
-- Usage: local win = Window.new({ Name = "Boosts", Title = "Boosts", Icon = "Menu_Boosts", Size = UDim2..., MaxSize = Vector2... })
-- Put content in win.Content; call win:Toggle() / Open() / Close(); win:OnOpen(fn) runs each time it opens.

local TweenService = game:GetService("TweenService")

local Style = require(script.Parent.Style)
local Icon = require(script.Parent.Icon)
local HudLayout = require(script.Parent.Parent.HudLayout)

export type Props = {
	Name: string,
	Title: string,
	Icon: string?, -- UITheme.Icons key shown before the title
	Size: UDim2, -- PC size (phones: near full screen)
	MaxSize: Vector2?,
}

local Window = {}
Window.__index = Window

export type Window = typeof(setmetatable({} :: {
	Gui: ScreenGui,
	Frame: Frame,
	TitleBar: Frame,
	TitleLabel: TextLabel,
	Content: Frame,
	Scale: UIScale,
	IsOpen: boolean,
	OpenCallbacks: { () -> () },
	CloseCallbacks: { () -> () },
	Closing: boolean,
}, Window))

function Window.new(props: Props): Window
	local theme = Style.Theme
	local gui = HudLayout.MakeScreenGui(props.Name, "Popups")

	local frame = Instance.new("Frame")
	frame.Name = "Window"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = props.Size
	frame.Visible = false
	Style.PanelLook(frame, 10)
	frame.Parent = gui
	if props.MaxSize then
		local limit = Instance.new("UISizeConstraint")
		limit.MaxSize = props.MaxSize
		limit.Parent = frame
	end
	local scale = Instance.new("UIScale")
	scale.Parent = frame

	-- Title bar
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Position = UDim2.fromOffset(6, 6)
	titleBar.Size = UDim2.new(1, -12, 0, theme.Sizes.TitleBar)
	titleBar.BackgroundColor3 = theme.Colors.TitleBar
	titleBar.BackgroundTransparency = 0.25
	titleBar.ZIndex = 2
	Style.Corner(titleBar, theme.Corner - 4)
	titleBar.Parent = frame
	Style.Constellation(titleBar)

	local titleRow = Instance.new("Frame")
	titleRow.Name = "TitleRow"
	titleRow.BackgroundTransparency = 1
	titleRow.Position = UDim2.fromOffset(12, 0)
	titleRow.Size = UDim2.new(1, -70, 1, 0)
	titleRow.ZIndex = 3
	titleRow.Parent = titleBar
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = titleRow
	if props.Icon then
		local icon = Icon.new(titleRow, props.Icon)
		icon.LayoutOrder = 1
		icon.Size = UDim2.fromScale(0.85, 0.85)
		icon.ZIndex = 3
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.Parent = icon
	end
	local title = Style.Label(titleRow, props.Title, "Title", theme.TextSizes.Title, theme.Colors.Title)
	title.LayoutOrder = 2
	title.AutomaticSize = Enum.AutomaticSize.X
	title.Size = UDim2.fromScale(0, 1)
	title.TextWrapped = false
	title.TextStrokeTransparency = 0
	title.ZIndex = 3

	-- Red X close
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -6, 0.5, 0)
	close.Size = UDim2.fromOffset(theme.Sizes.Close, theme.Sizes.Close)
	close.Text = "X"
	close.AutoButtonColor = false
	close.ZIndex = 5
	Style.Text(close, "Title", 22)
	close.TextStrokeTransparency = 0
	close.Parent = titleBar
	local closeBack = Style.Backdrop(close, Style.Shade(theme.Colors.Close, 0.15), Style.Shade(theme.Colors.Close, -0.2), theme.SmallCorner)
	Style.Stroke(closeBack, theme.Colors.TextStroke, theme.Strokes.Button)
	Style.AttachPress(close, "Close")

	-- Content area
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.ZIndex = 2
	content.Parent = frame

	local self = setmetatable({
		Gui = gui,
		Frame = frame,
		TitleBar = titleBar,
		TitleLabel = title,
		Content = content,
		Scale = scale,
		IsOpen = false,
		OpenCallbacks = {},
		CloseCallbacks = {},
		Closing = false,
	}, Window)

	close.Activated:Connect(function()
		self:Close()
	end)

	HudLayout.RegisterPopup(frame, props.Size)
	HudLayout.OnLayoutChanged(function(isPhone)
		local barHeight = if isPhone then theme.Sizes.PhoneTitleBar else theme.Sizes.TitleBar
		titleBar.Size = UDim2.new(1, -12, 0, barHeight)
		title.TextSize = if isPhone then theme.TextSizes.PhoneTitle else theme.TextSizes.Title
		closeBack.Size = UDim2.fromOffset(barHeight - 8, barHeight - 8)
		content.Position = UDim2.fromOffset(12, barHeight + 12)
		content.Size = UDim2.new(1, -24, 1, -(barHeight + 22))
	end)
	return self
end

function Window.OnOpen(self: Window, fn: () -> ())
	table.insert(self.OpenCallbacks, fn)
end

function Window.OnClose(self: Window, fn: () -> ())
	table.insert(self.CloseCallbacks, fn)
end

function Window.SetTitle(self: Window, text: string)
	self.TitleLabel.Text = text
end

function Window.Open(self: Window)
	if self.IsOpen then
		return
	end
	self.IsOpen = true
	self.Closing = false
	HudLayout.ClaimFocus(self, function()
		self:Close()
	end)
	local motion = Style.Theme.Motion
	self.Scale.Scale = motion.StartScale
	self.Frame.Visible = true
	TweenService:Create(self.Scale, TweenInfo.new(motion.PopIn, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Style.Play("Open")
	for _, fn in self.OpenCallbacks do
		task.spawn(fn)
	end
end

function Window.Close(self: Window)
	if not self.IsOpen then
		return
	end
	self.IsOpen = false
	self.Closing = true
	HudLayout.ReleaseFocus(self)
	local motion = Style.Theme.Motion
	local tween = TweenService:Create(self.Scale, TweenInfo.new(motion.PopOut, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = motion.StartScale })
	tween.Completed:Connect(function()
		if self.Closing then
			self.Frame.Visible = false
			self.Closing = false
		end
	end)
	tween:Play()
	for _, fn in self.CloseCallbacks do
		task.spawn(fn)
	end
end

function Window.Toggle(self: Window)
	if self.IsOpen then
		self:Close()
	else
		self:Open()
	end
end

return Window
