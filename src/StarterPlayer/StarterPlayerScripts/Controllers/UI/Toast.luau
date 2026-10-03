--!strict
-- Bounded notifications: wrap/scroll long text, never shrink the whole pill on phones.
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local Players = game:GetService("Players")
local Style = require(script.Parent.Style)
local Icon = require(script.Parent.Icon)
local EffectsQuality = require(script.Parent.Parent.EffectsQuality)
local RevealGate = require(script.Parent.RevealGate)
local Toast = {}
local container: Frame? = nil
local KIND_COLORS = {
	success = Style.Theme.Colors.Positive, error = Style.Theme.Colors.Negative,
	info = Style.Theme.Colors.Info, reward = Style.Theme.Colors.Gold, announce = Style.Theme.Colors.Title,
}
function Toast.SetContainer(frame: Frame) container = frame end
function Toast.SetPhone(_phone: boolean) end -- Compatibility; fonts retain physical sizes.

function Toast.Build(parent: Instance, text: string, kind: string?, icon: string?, color: Color3?): (Frame, CanvasGroup, Frame)
	local theme, mobile = Style.Theme, Style.Theme.MobileUI
	local accent = color or (KIND_COLORS :: any)[kind or "info"] or theme.Colors.Info
	local holder = Instance.new("Frame")
	holder.Name = "Toast"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, mobile.ToastHeight + mobile.Gap)
	holder.Parent = parent
	local group = Instance.new("CanvasGroup")
	group.Name = "Fade"
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.GroupTransparency = 1
	group.Parent = holder
	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.Position = UDim2.fromOffset(mobile.Gap / 2, mobile.Gap / 2)
	pill.Size = UDim2.new(1, -mobile.Gap, 1, -mobile.Gap)
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	Style.Gradient(pill, theme.Colors.GlassTop, theme.Colors.GlassBottom)
	Style.Corner(pill, mobile.Padding)
	Style.Stroke(pill, accent, mobile.CardBorder)
	pill.Parent = group
	local image = Icon.new(pill, icon or "Stardust", accent, "★")
	image.AnchorPoint = Vector2.new(0, 0.5)
	image.Position = UDim2.new(0, mobile.Padding, 0.5, 0)
	image.Size = UDim2.fromOffset(mobile.ToastIcon, mobile.ToastIcon)
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.CanvasSize = UDim2.new()
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.ScrollBarImageColor3 = accent
	body.Position = UDim2.fromOffset(mobile.Padding * 2 + mobile.ToastIcon, mobile.Padding)
	body.Size = UDim2.new(1, -(mobile.Padding * 3 + mobile.ToastIcon), 1, -mobile.Padding * 2)
	body.Parent = pill
	local label = Style.Label(body, text, "Bold", mobile.Body, theme.Colors.Text)
	label.Name = "Text"
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	local function fit()
		local width = math.max(1, holder.AbsoluteSize.X - mobile.Gap - mobile.Padding * 3 - mobile.ToastIcon - mobile.Scrollbar)
		local measured = TextService:GetTextSize(label.Text, mobile.Body, label.Font, Vector2.new(width, 100000))
		local height = math.max(mobile.ToastHeight, math.min(mobile.ToastMaxHeight, measured.Y + mobile.Padding * 2))
		holder.Size = UDim2.new(1, 0, 0, height + mobile.Gap)
		label.Size = UDim2.new(1, -mobile.Scrollbar, 0, measured.Y + 2)
		body.CanvasSize = UDim2.fromOffset(0, measured.Y + 2)
		body.ScrollBarThickness = if measured.Y > height - mobile.Padding * 2 then mobile.Scrollbar else 0
	end
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	label:GetPropertyChangedSignal("Text"):Connect(fit)
	fit()
	return holder, group, pill
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
	local holder, group, pill = Toast.Build(parent, text, kind, icon, color)
	order += 1
	holder.LayoutOrder = order
	if kind == "success" or kind == "reward" then Style.Play("Confirm") elseif kind == "error" then Style.Play("Error") end
	local pop = Instance.new("UIScale")
	pop.Scale = if EffectsQuality.IsLow() then 1 else theme.Motion.StartScale
	pop.Parent = pill
	TweenService:Create(pop, TweenInfo.new(theme.Motion.ToastBounce, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
	TweenService:Create(group, TweenInfo.new(theme.Motion.WindowFade), { GroupTransparency = 0 }):Play()
	local remaining = mobile.ToastDuration
	local label = pill:FindFirstChild("Text", true) :: TextLabel
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
