--!strict
-- Window: the standard popup panel (UI renewal part 2). An indigo -> violet panel with a sparkle pattern, a soft glow
-- and a gold ornamental border (Style.PanelLook), a jewel title banner with a star hanging on the top edge
-- (UI/Banner), a big round 3D rose close button on the top-right corner, and a pop-in (scale + fade) with sounds and
-- a sparkle burst out of the banner. HudLayout places windows below the travel row.
-- Windows register with HudLayout, so they draw above the HUD and fill the screen on phones. Only one window is open
-- at a time: opening one closes any other window or station panel (HudLayout.ClaimFocus).
--
-- Usage: local win = Window.new({ Name = "Boosts", Title = "Boosts", Icon = "Menu_Boosts", Size = UDim2..., MaxSize = Vector2... })
-- Put content in win.Content; call win:Toggle() / Open() / Close(); win:OnOpen(fn) runs each time it opens.

local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Style = require(script.Parent.Style)
local Banner = require(script.Parent.Banner)
local HudLayout = require(script.Parent.Parent.HudLayout)
local EffectsQuality = require(script.Parent.Parent.EffectsQuality)

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
	Fader: CanvasGroup,
	Frame: Frame,
	TitleBar: Frame, -- the banner's holder
	Banner: Banner.Banner,
	TitleLabel: TextLabel,
	Content: Frame,
	CloseButton: TextButton,
	Scale: UIScale,
	IsOpen: boolean,
	OpenCallbacks: { () -> () },
	CloseCallbacks: { () -> () },
	Closing: boolean,
	FadeTween: Tween?,
	ScaleTween: Tween?,
	Epoch: number,
	PreviousSelection: GuiObject?,
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

	-- Title banner, hanging on the top edge
	local banner = Banner.new(frame, { Text = props.Title, Icon = props.Icon })
	banner.Holder.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Holder.Position = UDim2.fromScale(0.5, 0)

	-- Big round 3D close button on the top-right corner: a rose face on a darker edge, dropping onto it when pressed
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(0.5, 0.5)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Text = ""
	close.AutoButtonColor = false
	close.Selectable = true
	close.BackgroundTransparency = 1
	close.ZIndex = 10
	close.Parent = frame
	local closeEdge = Instance.new("Frame")
	closeEdge.Name = "Edge"
	closeEdge.Size = UDim2.fromScale(1, 1)
	closeEdge.BackgroundColor3 = Style.Shade(theme.Colors.CloseBottom, -0.4)
	closeEdge.ZIndex = 10
	Style.Round(closeEdge)
	closeEdge.Parent = close
	local closeFace = Instance.new("Frame")
	closeFace.Name = "Face"
	closeFace.Size = UDim2.new(1, 0, 1, -theme.Sizes.ButtonEdge)
	closeFace.BackgroundColor3 = Color3.new(1, 1, 1)
	closeFace.ZIndex = 10
	Style.Gradient(closeFace, theme.Colors.CloseTop, theme.Colors.CloseBottom)
	Style.Round(closeFace)
	Style.GoldBorder(closeFace, 3)
	closeFace.Parent = close
	close.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			closeFace.Position = UDim2.fromOffset(0, theme.Sizes.ButtonEdge - 1)
		end
	end)
	close.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			closeFace.Position = UDim2.new()
		end
	end)
	local closeGloss = Instance.new("Frame")
	closeGloss.Name = "Gloss"
	closeGloss.AnchorPoint = Vector2.new(0.5, 0)
	closeGloss.Position = UDim2.fromScale(0.5, 0.08)
	closeGloss.Size = UDim2.fromScale(0.62, 0.36)
	closeGloss.BackgroundColor3 = Color3.new(1, 1, 1)
	closeGloss.BackgroundTransparency = 0.78
	closeGloss.ZIndex = 10
	Style.Round(closeGloss)
	closeGloss.Parent = closeFace
	local cross = Style.Label(closeFace, "X", "Title", 26)
	cross.Name = "Cross"
	cross.AnchorPoint = Vector2.new(0.5, 0.5)
	cross.Position = UDim2.fromScale(0.5, 0.54)
	cross.Size = UDim2.fromScale(1, 1)
	cross.ZIndex = 11
	cross.TextStrokeTransparency = 1
	local crossOutline = Instance.new("UIStroke")
	crossOutline.Color = theme.Colors.IconLabelStroke
	crossOutline.Thickness = 2
	crossOutline.Parent = cross
	Style.AttachPress(close, "Close")
	local turn = TweenInfo.new(theme.Motion.IconHoverTime, Enum.EasingStyle.Back)
	close.MouseEnter:Connect(function()
		if not EffectsQuality.IsLow() then TweenService:Create(cross, turn, { Rotation = theme.Motion.CloseHoverTurn }):Play() end
	end)
	close.MouseLeave:Connect(function()
		TweenService:Create(cross, turn, { Rotation = 0 }):Play()
	end)

	-- Content area
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.ZIndex = 2
	content.ClipsDescendants = true
	content.Parent = frame

	-- while fading in/out the window sits in this CanvasGroup (it covers the screen, so the layout doesn't change)
	local fader = Instance.new("CanvasGroup")
	fader.Name = "Fader"
	fader.Size = UDim2.fromScale(1, 1)
	fader.BackgroundTransparency = 1
	fader.Visible = false
	fader.Parent = gui

	local self = setmetatable({
		Gui = gui,
		Fader = fader,
		Frame = frame,
		TitleBar = banner.Holder,
		Banner = banner,
		TitleLabel = banner.Label,
		Content = content,
		CloseButton = close,
		Scale = scale,
		IsOpen = false,
		OpenCallbacks = {},
		CloseCallbacks = {},
		Closing = false,
		Epoch = 0,
	}, Window)

	close.Activated:Connect(function()
		self:Close()
	end)
	local backConnection = UserInputService.InputBegan:Connect(function(input, processed)
		local player = Players.LocalPlayer
		if self.IsOpen and self.Gui.Enabled and player:GetAttribute("RewardPopupOpen") ~= true and player:GetAttribute("BindRevealActive") ~= true
			and (input.KeyCode == Enum.KeyCode.ButtonB or (input.KeyCode == Enum.KeyCode.Escape and not processed)) then self:Close() end
	end)

	HudLayout.RegisterPopup(frame, props.Size)
	local unlayout = HudLayout.OnLayoutChanged(function(isPhone)
		local sizes = theme.Sizes
		local bannerHeight = if isPhone then sizes.PhoneBanner else sizes.Banner
		local closeSize = if isPhone then sizes.PhoneCloseButton else sizes.CloseButton
		banner:Layout(
			bannerHeight,
			if isPhone then theme.TextSizes.PhoneBanner else theme.TextSizes.Banner,
			if isPhone then sizes.PhoneBannerStar else sizes.BannerStar,
			math.max(theme.MobileUI.Touch, frame.Size.X.Offset - closeSize * 2 - theme.MobileUI.Padding)
		)
		close.Size = UDim2.fromOffset(closeSize, closeSize)
		cross.TextSize = math.floor(closeSize * 0.5)
		local pad = if isPhone then theme.MobileUI.Padding else sizes.WindowPadding
		local top = math.max(math.floor(bannerHeight / 2) + theme.MobileUI.Gap, closeSize / 2 + theme.MobileUI.Gap)
		content.Position = UDim2.fromOffset(pad, top)
		content.Size = UDim2.new(1, -pad * 2, 1, -(top + pad))
	end)
	gui.Destroying:Connect(function()
		unlayout()
		backConnection:Disconnect()
		if self.FadeTween then self.FadeTween:Cancel() end
		if self.ScaleTween then self.ScaleTween:Cancel() end
		HudLayout.ReleaseFocus(self)
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
	self.Banner:SetText(text)
end

-- Changes the banner icon (a UITheme.Icons key; the window must have been made with an Icon).
function Window.SetIcon(self: Window, key: string)
	self.Banner:SetIcon(key)
end

-- Fades the window in or out: it moves into the screen-sized CanvasGroup for the fade and back out after it (a
-- CanvasGroup the size of the window would clip the banner, the close button and the glow).
local function fade(self: Window, show: boolean)
	if self.FadeTween then self.FadeTween:Cancel() end
	local fader = self.Fader
	self.Frame.Parent = fader
	fader.GroupTransparency = if show then 1 else 0
	fader.Visible = true
	local tween = TweenService:Create(fader, TweenInfo.new(Style.Theme.Motion.WindowFade), { GroupTransparency = if show then 0 else 1 })
	self.FadeTween = tween
	tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and self.IsOpen == show then
			self.Frame.Parent = self.Gui
			fader.Visible = false
		end
	end)
	tween:Play()
end

function Window.Open(self: Window)
	if self.IsOpen then
		return
	end
	self.IsOpen = true
	self.Epoch += 1
	self.Closing = false
	if self.ScaleTween then self.ScaleTween:Cancel() end
	self.PreviousSelection = GuiService.SelectedObject
	HudLayout.ClaimFocus(self, function()
		self:Close()
	end)
	local motion = Style.Theme.Motion
	self.Scale.Scale = if EffectsQuality.IsLow() then 1 else motion.StartScale
	self.Frame.Visible = true
	fade(self, true)
	self.ScaleTween = TweenService:Create(self.Scale, TweenInfo.new(motion.PopIn, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
	self.ScaleTween:Play()
	Style.Play("Open")
	local width = self.Frame.AbsoluteSize.X / math.max(self.Scale.Scale, 0.01)
	Style.SparkleBurst(self.Frame, Vector2.new(width / 2, 0), motion.OpenSparkles, 60)
	for _, fn in self.OpenCallbacks do
		task.spawn(fn)
	end
	if UserInputService.GamepadEnabled then task.defer(function()
		if not self.IsOpen then return end
		for _, child in self.Content:GetDescendants() do
			if child:IsA("GuiButton") and child.Selectable and HudLayout.GetVisibleRect(child) then
				GuiService.SelectedObject = child
				return
			end
		end
		GuiService.SelectedObject = self.CloseButton -- informational/empty windows still have an accessible action
	end) end
end

function Window.Close(self: Window)
	if not self.IsOpen then
		return
	end
	self.IsOpen = false
	self.Epoch += 1
	local epoch = self.Epoch
	self.Closing = true
	if self.ScaleTween then self.ScaleTween:Cancel() end
	HudLayout.ReleaseFocus(self)
	local motion = Style.Theme.Motion
	fade(self, false)
	local tween = TweenService:Create(self.Scale, TweenInfo.new(motion.PopOut, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = if EffectsQuality.IsLow() then 1 else motion.StartScale })
	self.ScaleTween = tween
	tween.Completed:Once(function(state)
		if self.Closing and self.Epoch == epoch and state == Enum.PlaybackState.Completed then
			self.Frame.Visible = false
			self.Closing = false
		end
	end)
	tween:Play()
	if self.PreviousSelection and HudLayout.GetVisibleRect(self.PreviousSelection) then
		GuiService.SelectedObject = self.PreviousSelection
	elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.Frame) then
		GuiService.SelectedObject = nil
	end
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
