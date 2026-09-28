--!strict
-- Toasts (UI renewal part 2): a short pill with a big icon popping out on the left and one line in the title font,
-- bouncing in and fading out after UITheme.Motion.ToastSeconds. The pill has a gold border and a soft glow in the
-- kind's color. Kinds: "success" (jade, confirm sound), "error" (rose, error sound), "info" (blue), "reward" (gold),
-- "announce" (gold, server-wide). An optional icon key; without one the kind shows a small star.

local TweenService = game:GetService("TweenService")

local Style = require(script.Parent.Style)
local Icon = require(script.Parent.Icon)

local Toast = {}

local container: Frame? = nil
local phone = false

local KIND_COLORS: { [string]: Color3 } = {
	success = Style.Theme.Colors.Positive,
	error = Style.Theme.Colors.Negative,
	info = Style.Theme.Colors.Info,
	reward = Style.Theme.Colors.Gold,
	announce = Style.Theme.Colors.Title,
}

-- The frame toasts stack in (NotificationController owns and positions it).
function Toast.SetContainer(frame: Frame)
	container = frame
end

-- Phones use the smaller pill (NotificationController calls this on layout changes).
function Toast.SetPhone(isPhone: boolean)
	phone = isPhone
end

-- Builds a toast pill in `parent` (also used by the style-sheet mockup). Returns the holder and the fading group.
function Toast.Build(parent: Instance, text: string, kind: string?, icon: string?, color: Color3?): (Frame, CanvasGroup, Frame)
	local theme = Style.Theme
	local sizes = theme.Sizes
	local accent = color or KIND_COLORS[kind or "info"] or theme.Colors.Info
	local height = if phone then sizes.PhoneToastPill else sizes.ToastPill
	local iconSize = if phone then sizes.PhoneToastIcon else sizes.ToastIcon

	local holder = Instance.new("Frame") -- keeps the list slot while the pill animates
	holder.Name = "Toast"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, height + 10)
	holder.Parent = parent

	local group = Instance.new("CanvasGroup") -- fades the whole toast (sized to the holder, so nothing is clipped)
	group.Name = "Fade"
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.GroupTransparency = 1
	group.Parent = holder

	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.fromScale(0.5, 0.5)
	pill.Size = UDim2.fromOffset(0, height)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	Style.Gradient(pill, theme.Colors.PanelV2Top, theme.Colors.PanelV2Bottom)
	Style.Round(pill)
	Style.GoldBorder(pill, 2.5)
	pill.Parent = group
	local tint = Style.Glow(pill, accent, 8, 0.6, 0) -- the kind's color glowing through
	tint.Name = "Tint"
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, math.floor(iconSize * 0.95) + 4) -- room for the icon
	pad.PaddingRight = UDim.new(0, math.floor(height * 0.45))
	pad.Parent = pill

	local image: GuiObject
	if icon then
		image = Icon.new(pill, icon, accent, icon)
	else
		local star = Instance.new("TextLabel")
		star.BackgroundTransparency = 1
		star.Text = "★"
		star.Font = Enum.Font.GothamBlack
		star.TextScaled = true
		star.TextColor3 = accent
		Style.Outline(star, 2)
		star.Parent = pill
		image = star
	end
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.new(0, -math.floor(iconSize * 0.5) - 4, 0.5, 0) -- in the left padding, popping out
	image.Size = UDim2.fromOffset(iconSize, iconSize)
	image.ZIndex = 3

	local label = Style.Label(pill, text, "Title", if phone then 15 else 20, theme.Colors.Text)
	label.Name = "Text"
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	label.TextWrapped = false
	label.ZIndex = 2
	Style.Outline(label, 1.5)
	return holder, group, pill
end

export type Handle = {
	SetText: (Handle, string) -> (),
	Extend: (Handle) -> (), -- restart its time on screen (and a little pop), e.g. when the same message comes again
}

local order = 0

-- Shows one toast in the container; onGone runs after it has faded out. NotificationController queues these (at most
-- a few at once, repeats merged into "x2"); other code should call NotificationController:Show instead.
function Toast.Spawn(text: string, kind: string?, icon: string?, color: Color3?, onGone: (() -> ())?): Handle
	local theme = Style.Theme
	local parent = container
	local handle = {} :: Handle
	if parent == nil then
		function handle.SetText(_self: Handle, _text: string) end
		function handle.Extend(_self: Handle) end
		if onGone then
			task.defer(onGone)
		end
		return handle
	end
	local holder, group, pill = Toast.Build(parent, text, kind, icon, color)
	order += 1
	holder.LayoutOrder = order -- oldest on top, new ones below

	if kind == "success" or kind == "reward" then
		Style.Play("Confirm")
	elseif kind == "error" then
		Style.Play("Error")
	end

	local pop = Instance.new("UIScale")
	pop.Scale = 0.5
	pop.Parent = pill
	TweenService:Create(pop, TweenInfo.new(theme.Motion.ToastBounce, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(group, TweenInfo.new(0.15), { GroupTransparency = 0 }):Play()

	local deadline = os.clock() + theme.Motion.ToastSeconds
	local label = pill:FindFirstChild("Text") :: TextLabel
	function handle.SetText(_self: Handle, newText: string)
		label.Text = newText
	end
	function handle.Extend(_self: Handle)
		deadline = os.clock() + theme.Motion.ToastSeconds
		pop.Scale = 1.15
		TweenService:Create(pop, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	task.spawn(function()
		while os.clock() < deadline do
			task.wait(deadline - os.clock())
		end
		TweenService:Create(group, TweenInfo.new(0.3), { GroupTransparency = 1 }):Play()
		TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.85 }):Play()
		task.wait(0.3)
		holder:Destroy()
		if onGone then
			onGone()
		end
	end)
	return handle
end

-- A toast without the queue (kept for older callers).
function Toast.Show(text: string, kind: string?, icon: string?, color: Color3?)
	Toast.Spawn(text, kind, icon, color)
end

return Toast
