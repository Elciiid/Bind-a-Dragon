--!strict
-- Notifications as floating text (no box): big title-font text with a thick dark outline and a soft drop shadow
-- (Style.ShadowText), colored by kind (white info, gold success / reward / announce, rose error), a small icon only when one
-- was picked for the text. Long text wraps. Fades in while rising a little (not with Low effects / Reduced Motion).
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Style = require(script.Parent.Style)
local Icon = require(script.Parent.Icon)
local EffectsQuality = require(script.Parent.Parent.EffectsQuality)
local RevealGate = require(script.Parent.RevealGate)
local Toast = {}
local container: Frame? = nil
local phone = false
local KIND_COLORS = {
	success = Style.Theme.Colors.Gold, error = Style.Theme.Colors.Negative,
	info = Style.Theme.Colors.Text, reward = Style.Theme.Colors.Gold, announce = Style.Theme.Colors.Gold,
}
function Toast.SetContainer(frame: Frame) container = frame end
function Toast.SetPhone(isPhone: boolean) phone = isPhone end

local function still(): boolean
	return EffectsQuality.IsLow() or Players.LocalPlayer:GetAttribute("ReducedMotion") == true
end

-- Returns the holder (a row in the toast column), the fading group and the line (icon + text) that rises in.
function Toast.Build(parent: Instance, text: string, kind: string?, icon: string?, color: Color3?): (Frame, CanvasGroup, Frame)
	local theme, mobile, float = Style.Theme, Style.Theme.MobileUI, Style.Theme.FloatText
	local accent = color or (KIND_COLORS :: any)[kind or "info"] or theme.Colors.Text
	local size = if phone then float.PhoneToastSize else float.ToastSize
	local iconSize = if phone then float.PhoneToastIcon else float.ToastIcon
	local holder = Instance.new("Frame")
	holder.Name = "Toast"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, size + mobile.Gap)
	holder.Parent = parent
	local group = Instance.new("CanvasGroup")
	group.Name = "Fade"
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.GroupTransparency = 1
	group.Parent = holder
	local line = Instance.new("Frame")
	line.Name = "Line"
	line.BackgroundTransparency = 1
	line.AnchorPoint = Vector2.new(0.5, 0)
	line.Position = UDim2.fromScale(0.5, 0)
	line.AutomaticSize = Enum.AutomaticSize.XY
	line.Size = UDim2.new()
	line.Parent = group
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, mobile.Gap)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = line
	local iconWidth = 0
	if icon then
		local image = Icon.new(line, icon, accent, "")
		image.Size = UDim2.fromOffset(iconSize, iconSize)
		image.LayoutOrder = 1
		iconWidth = iconSize + mobile.Gap
	end
	local width = math.max(120, (if parent:IsA("GuiObject") then parent.AbsoluteSize.X else mobile.ToastWidth) - iconWidth - mobile.Gap)
	local textHolder, label = Style.ShadowText(line, text, size, accent, width)
	textHolder.LayoutOrder = 2
	label.TextXAlignment = if icon then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
	-- the label wraps at `width`; shrink it to the text when the text is shorter, so the line stays centered
	local function fit()
		local bounds = label.TextBounds
		label.Size = UDim2.fromOffset(math.min(width, math.ceil(bounds.X) + 2), 0)
		holder.Size = UDim2.new(1, 0, 0, math.max(size, line.AbsoluteSize.Y) + mobile.Gap)
	end
	label:GetPropertyChangedSignal("TextBounds"):Connect(fit)
	line:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	label.Name = "Text"
	fit()
	return holder, group, line
end

export type Handle = { SetText: (Handle, string) -> (), Extend: (Handle) -> () }
local order = 0
function Toast.Spawn(text: string, kind: string?, icon: string?, color: Color3?, onGone: (() -> ())?): Handle
	local theme, mobile = Style.Theme, Style.Theme.MobileUI
	local parent = container
	local handle = {} :: Handle
	if not parent then
		function handle.SetText(_self: Handle, _text: string) end
		function handle.Extend(_self: Handle) end
		if onGone then task.defer(onGone) end
		return handle
	end
	local holder, group, line = Toast.Build(parent, text, kind, icon, color)
	order += 1
	holder.LayoutOrder = order
	if kind == "success" or kind == "reward" then Style.Play("Confirm") elseif kind == "error" then Style.Play("Error") end
	if not still() then
		-- rise a little while fading in
		line.Position = UDim2.new(0.5, 0, 0, theme.FloatText.Rise)
		TweenService:Create(line, TweenInfo.new(theme.Motion.ToastBounce, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0.5, 0) }):Play()
	end
	TweenService:Create(group, TweenInfo.new(theme.Motion.WindowFade), { GroupTransparency = 0 }):Play()
	local remaining = mobile.ToastDuration
	local label = line:FindFirstChild("Text", true) :: TextLabel
	function handle.SetText(_self: Handle, newText: string) label.Text = newText end
	function handle.Extend(_self: Handle) remaining = mobile.ToastDuration end
	task.spawn(function()
		while holder.Parent and remaining > 0 do
			local elapsed = task.wait(mobile.ToastPollSeconds)
			if not RevealGate.IsActive() and Players.LocalPlayer:GetAttribute("RewardPopupOpen") ~= true then remaining -= elapsed end
		end
		if holder.Parent then
			local tween = TweenService:Create(group, TweenInfo.new(theme.Motion.WindowFade), { GroupTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			holder:Destroy()
		end
		if onGone then onGone() end
	end)
	return handle
end
function Toast.Show(text: string, kind: string?, icon: string?, color: Color3?) Toast.Spawn(text, kind, icon, color) end
return Toast
