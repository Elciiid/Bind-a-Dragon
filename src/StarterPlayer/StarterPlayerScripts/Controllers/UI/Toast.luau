--!strict
-- Toasts: small night-sky cards that slide in, stay UITheme.Motion.ToastSeconds, and fade out.
-- Kinds: "success" (green stripe, confirm sound), "error" (red stripe, error sound), "info", "reward" (gold),
-- "announce" (gold, server-wide). An optional icon key shows on the left.

local TweenService = game:GetService("TweenService")

local Style = require(script.Parent.Style)
local Icon = require(script.Parent.Icon)

local Toast = {}

local container: Frame? = nil

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

function Toast.Show(text: string, kind: string?, icon: string?, color: Color3?)
	local parent = container
	if parent == nil then
		return
	end
	local theme = Style.Theme
	local accent = color or KIND_COLORS[kind or "info"] or theme.Colors.Info

	local holder = Instance.new("Frame") -- keeps the list slot while the card slides
	holder.Name = "Toast"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 38)
	holder.LayoutOrder = -math.floor(os.clock() * 1000) -- newest on top
	holder.Parent = parent

	local card = Instance.new("CanvasGroup")
	card.Size = UDim2.fromScale(1, 1)
	card.Position = UDim2.fromOffset(0, -12)
	card.GroupTransparency = 1
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	Style.Gradient(card, theme.Colors.PanelTop, theme.Colors.PanelBottom)
	Style.Corner(card, theme.SmallCorner)
	card.Parent = holder
	Style.Stroke(holder, accent, 2) -- stroke on the holder so it isn't clipped by the canvas
	Style.Corner(holder, theme.SmallCorner)

	local stripe = Instance.new("Frame")
	stripe.Size = UDim2.new(0, 6, 1, 0)
	stripe.BackgroundColor3 = accent
	stripe.BorderSizePixel = 0
	stripe.Parent = card

	local x = 14
	if icon then
		local image = Icon.new(card, icon, accent, icon)
		image.AnchorPoint = Vector2.new(0, 0.5)
		image.Position = UDim2.new(0, 12, 0.5, 0)
		image.Size = UDim2.fromOffset(28, 28)
		x = 46
	end
	local label = Style.Label(card, text, "Bold", theme.TextSizes.Body, accent)
	label.Position = UDim2.fromOffset(x, 0)
	label.Size = UDim2.new(1, -(x + 8), 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = theme.TextSizes.Body
	limit.Parent = label

	if kind == "success" or kind == "reward" then
		Style.Play("Confirm")
	elseif kind == "error" then
		Style.Play("Error")
	end

	local tweenIn = TweenInfo.new(theme.Motion.ToastIn, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(card, tweenIn, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }):Play()
	task.delay(theme.Motion.ToastSeconds, function()
		local stroke = holder:FindFirstChildOfClass("UIStroke")
		TweenService:Create(card, TweenInfo.new(0.4), { GroupTransparency = 1 }):Play()
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
		task.wait(0.4)
		holder:Destroy()
	end)
end

return Toast
