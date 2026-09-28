--!strict
-- HUD icon: a big standalone icon (no tile behind it) with a soft drop shadow and a short label under it (title font,
-- white with a dark outline). Juicy: hover = bounce up + a soft glow in its color, press = squish, tap = a few
-- sparkles fly out. Optional: a red count badge, a pulsing glow (attention), "ready" mode (gold glow, hopping,
-- a turning sparkle ring and a READY! tag) and a progress ring of dots (calm mode, e.g. % to the next rebirth).
-- The image is an asset id (UITheme.Icons value) or, while the art isn't painted yet, a Glyph (an emoji).
-- Sizes/motion come from UITheme (Sizes.HudIcon..., Motion.Icon...). The caller sizes it with :Resize().
--
--   local icon = HudIcon.new(parent, { Image = id, Glyph = "🏡", Label = "Home", Color = color })
--   icon:Resize(80, 20); icon.Instance.Activated:Connect(...); icon:SetBadge(3); icon:SetReady(true); icon:SetProgress(0.4)

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Style = require(script.Parent.Style)

export type Props = {
	Image: string?, -- asset id; "" or nil = use Glyph
	Glyph: string?,
	Label: string,
	Color: Color3,
}

local HudIcon = {}
HudIcon.__index = HudIcon

export type HudIcon = typeof(setmetatable({} :: {
	Instance: TextButton,
	Holder: Frame, -- icon square (bounces)
	Scale: UIScale,
	Body: Frame, -- squishes; holds the shadow and the art
	Art: GuiObject,
	Glow: Frame,
	Label: TextLabel,
	Badge: TextLabel,
	ReadyTag: TextLabel,
	Ring: Frame,
	Dots: { Frame },
	Sparkles: Frame,
	Color: Color3,
	Hovering: boolean,
	Pulsing: boolean,
	Ready: boolean,
	IconSize: number,
}, HudIcon))

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local animated: { HudIcon } = {}
local connection: RBXScriptConnection? = nil

local function track(self: HudIcon)
	if not table.find(animated, self) then
		table.insert(animated, self)
	end
	if connection then
		return
	end
	connection = RunService.RenderStepped:Connect(function()
		local theme = Style.Theme
		local t = os.clock()
		for _, icon in animated do
			if icon.Ready then
				local hop = math.abs(math.sin(t * theme.Motion.ReadySpeed)) * theme.Motion.ReadyBounce
				icon.Holder.Position = UDim2.new(0.5, 0, 0, -hop)
				icon.Glow.BackgroundTransparency = 0.45 + 0.15 * math.sin(t * 4)
				icon.Sparkles.Rotation = (t * 40) % 360
				icon.ReadyTag.Rotation = math.sin(t * 5) * 6
			elseif icon.Pulsing then
				icon.Glow.BackgroundTransparency = 0.55 + 0.25 * math.sin(t * theme.Motion.BadgePulse)
			end
		end
	end)
end

local function untrack(self: HudIcon)
	if self.Ready or self.Pulsing then
		return
	end
	local index = table.find(animated, self)
	if index then
		table.remove(animated, index)
	end
end

function HudIcon.new(parent: Instance, props: Props): HudIcon
	local theme = Style.Theme
	local colors = theme.Colors

	local instance = Instance.new("TextButton")
	instance.Name = props.Label
	instance.Text = ""
	instance.AutoButtonColor = false
	instance.BackgroundTransparency = 1

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 0)
	holder.BackgroundTransparency = 1
	holder.Parent = instance
	local scale = Instance.new("UIScale")
	scale.Parent = holder

	-- soft glow disc behind the icon (hover, pulse, ready)
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(0.95, 0.95)
	glow.BackgroundColor3 = props.Color
	glow.BackgroundTransparency = 1
	glow.BorderSizePixel = 0
	glow.Parent = holder
	Style.Round(glow)

	-- progress ring of dots (calm mode)
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(1.12, 1.12)
	ring.BackgroundTransparency = 1
	ring.Visible = false
	ring.Parent = holder
	local dots = {}
	local count = theme.Motion.ProgressDots
	for i = 1, count do
		local a = (i - 1) / count * 2 * math.pi
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(0.5 + 0.5 * math.sin(a), 0.5 - 0.5 * math.cos(a)) -- clockwise from the top
		dot.Size = UDim2.fromScale(0.12, 0.12)
		dot.BackgroundColor3 = colors.ProgressDim
		dot.BorderSizePixel = 0
		dot.Parent = ring
		Style.Round(dot)
		Style.Stroke(dot, colors.IconLabelStroke, 1)
		table.insert(dots, dot)
	end

	-- turning sparkle ring (ready mode)
	local sparkles = Instance.new("Frame")
	sparkles.Name = "Sparkles"
	sparkles.AnchorPoint = Vector2.new(0.5, 0.5)
	sparkles.Position = UDim2.fromScale(0.5, 0.5)
	sparkles.Size = UDim2.fromScale(1.25, 1.25)
	sparkles.BackgroundTransparency = 1
	sparkles.Visible = false
	sparkles.Parent = holder
	for i = 1, 6 do
		local a = (i - 1) / 6 * 2 * math.pi
		local star = Instance.new("ImageLabel")
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromScale(0.5 + 0.5 * math.sin(a), 0.5 - 0.5 * math.cos(a))
		star.Size = UDim2.fromScale(if i % 2 == 0 then 0.22 else 0.3, if i % 2 == 0 then 0.22 else 0.3)
		star.BackgroundTransparency = 1
		star.Image = SPARKLE
		star.ImageColor3 = colors.Sparkle
		star.Parent = sparkles
	end

	-- the art: shadow + image (or glyph), in a body that squishes from its bottom
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.AnchorPoint = Vector2.new(0.5, 1)
	body.Position = UDim2.fromScale(0.5, 1)
	body.Size = UDim2.fromScale(1, 1)
	body.BackgroundTransparency = 1
	body.Parent = holder
	local image = props.Image or ""
	local art: GuiObject
	if image ~= "" then
		local shadow = Instance.new("ImageLabel")
		shadow.Name = "Shadow"
		shadow.BackgroundTransparency = 1
		shadow.Image = image
		shadow.ImageColor3 = colors.IconShadow
		shadow.ImageTransparency = 0.5
		shadow.Position = UDim2.new(0, 3, 0, 5)
		shadow.Size = UDim2.fromScale(1, 1)
		shadow.ScaleType = Enum.ScaleType.Fit
		shadow.Parent = body
		local img = Instance.new("ImageLabel")
		img.Name = "Art"
		img.BackgroundTransparency = 1
		img.Image = image
		img.Size = UDim2.fromScale(1, 1)
		img.ScaleType = Enum.ScaleType.Fit
		img.Parent = body
		art = img
	else
		local shadow = Instance.new("TextLabel")
		shadow.Name = "Shadow"
		shadow.BackgroundTransparency = 1
		shadow.Text = props.Glyph or "?"
		shadow.TextScaled = true
		shadow.TextColor3 = colors.IconShadow
		shadow.TextTransparency = 0.5
		shadow.Position = UDim2.new(0, 3, 0, 5)
		shadow.Size = UDim2.fromScale(1, 1)
		shadow.Parent = body
		local glyph = Instance.new("TextLabel")
		glyph.Name = "Art"
		glyph.BackgroundTransparency = 1
		glyph.Text = props.Glyph or "?"
		glyph.TextScaled = true
		glyph.TextColor3 = Color3.new(1, 1, 1)
		glyph.Size = UDim2.fromScale(1, 1)
		glyph.Parent = body
		art = glyph
	end

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.fromScale(0.5, 1)
	label.Font = theme.Fonts.Title
	label.Text = props.Label
	label.TextColor3 = colors.IconLabel
	label.TextScaled = true
	label.Parent = instance
	local labelStroke = Instance.new("UIStroke")
	labelStroke.Color = colors.IconLabelStroke
	labelStroke.Thickness = 2
	labelStroke.LineJoinMode = Enum.LineJoinMode.Round
	labelStroke.Parent = label

	local badge = Style.Label(holder, "", "Heavy", 13)
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0.88, 0.1)
	badge.Size = UDim2.fromScale(0.32, 0.32)
	badge.BackgroundTransparency = 0
	badge.BackgroundColor3 = colors.Badge
	badge.TextScaled = true
	badge.Visible = false
	badge.ZIndex = 4
	Style.Round(badge)
	Style.Stroke(badge, colors.Text, 2)
	Style.Pad(badge, 2)

	local readyTag = Instance.new("TextLabel")
	readyTag.Name = "Ready"
	readyTag.AnchorPoint = Vector2.new(0.5, 0.5)
	readyTag.Position = UDim2.fromScale(0.95, 0.2) -- a sticker on the top-right corner, clear of the icon above
	readyTag.Size = UDim2.fromScale(0.95, 0.26)
	readyTag.BackgroundColor3 = colors.Ready
	readyTag.Font = theme.Fonts.Title
	readyTag.Text = "READY!"
	readyTag.TextColor3 = Color3.new(1, 1, 1)
	readyTag.TextScaled = true
	readyTag.Visible = false
	readyTag.ZIndex = 4
	readyTag.Parent = holder
	Style.Round(readyTag)
	Style.Stroke(readyTag, colors.Trim, 2)
	Style.Pad(readyTag, 5, 1)
	local tagStroke = Instance.new("UIStroke")
	tagStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	tagStroke.Color = colors.IconLabelStroke
	tagStroke.Thickness = 1.5
	tagStroke.Parent = readyTag

	local self = setmetatable({
		Instance = instance,
		Holder = holder,
		Scale = scale,
		Body = body,
		Art = art,
		Glow = glow,
		Label = label,
		Badge = badge,
		ReadyTag = readyTag,
		Ring = ring,
		Dots = dots,
		Sparkles = sparkles,
		Color = props.Color,
		Hovering = false,
		Pulsing = false,
		Ready = false,
		IconSize = 64,
	}, HudIcon)

	local motion = theme.Motion
	local function settle()
		local info = TweenInfo.new(motion.IconHoverTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(scale, info, { Scale = if self.Hovering then motion.IconHover else 1 }):Play()
		if not (self.Ready or self.Pulsing) then
			TweenService:Create(glow, TweenInfo.new(motion.IconHoverTime), { BackgroundTransparency = if self.Hovering then 0.6 else 1 }):Play()
		end
	end
	instance.MouseEnter:Connect(function()
		self.Hovering = true
		settle()
	end)
	instance.MouseLeave:Connect(function()
		self.Hovering = false
		settle()
		TweenService:Create(body, TweenInfo.new(motion.IconSquishTime), { Size = UDim2.fromScale(1, 1) }):Play()
	end)
	instance.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(body, TweenInfo.new(motion.IconSquishTime), { Size = UDim2.fromScale(motion.IconSquish.X, motion.IconSquish.Y) }):Play()
		end
	end)
	instance.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(body, TweenInfo.new(0.35, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1, 1) }):Play()
		end
	end)
	instance.Activated:Connect(function()
		Style.Play("Click")
		self:Burst()
	end)

	instance.Parent = parent
	return self
end

-- Sizes the icon (pixels) and its label (text height).
function HudIcon.Resize(self: HudIcon, iconSize: number, labelSize: number)
	self.IconSize = iconSize
	self.Instance.Size = UDim2.fromOffset(math.max(iconSize, labelSize * 5), iconSize + labelSize + 2)
	self.Holder.Size = UDim2.fromOffset(iconSize, iconSize)
	self.Label.Size = UDim2.new(1, 8, 0, labelSize)
	local stroke = self.Label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Thickness = if labelSize >= 16 then 2 else 1.5
	end
end

function HudIcon.SetLabel(self: HudIcon, text: string)
	self.Label.Text = text
end

function HudIcon.SetBadge(self: HudIcon, count: number)
	self.Badge.Text = if count > 99 then "99+" else tostring(count)
	self.Badge.Visible = count > 0
end

-- A softly pulsing glow that asks for attention.
function HudIcon.SetPulse(self: HudIcon, on: boolean)
	if on == self.Pulsing then
		return
	end
	self.Pulsing = on
	if on then
		track(self)
	else
		untrack(self)
		if not self.Ready then
			self.Glow.BackgroundTransparency = if self.Hovering then 0.6 else 1
		end
	end
end

-- Ready: gold glow, hopping, turning sparkles and a READY! tag. Off: calm (the progress ring can show instead).
function HudIcon.SetReady(self: HudIcon, on: boolean)
	if on == self.Ready then
		return
	end
	self.Ready = on
	self.ReadyTag.Visible = on
	self.Sparkles.Visible = on
	self.Glow.BackgroundColor3 = if on then Style.Theme.Colors.Gold else self.Color
	if on then
		self.Ring.Visible = false
		track(self)
	else
		untrack(self)
		self.Holder.Position = UDim2.new(0.5, 0, 0, 0)
		self.Glow.BackgroundTransparency = if self.Pulsing then 0.6 elseif self.Hovering then 0.6 else 1
	end
end

-- Progress ring (0..1) around a calm icon; nil hides it.
function HudIcon.SetProgress(self: HudIcon, progress: number?)
	if progress == nil or self.Ready then
		self.Ring.Visible = false
		return
	end
	self.Ring.Visible = true
	local lit = math.floor(math.clamp(progress, 0, 1) * #self.Dots + 0.0001)
	local colors = Style.Theme.Colors
	for i, dot in self.Dots do
		dot.BackgroundColor3 = if i <= lit then colors.Gold else colors.ProgressDim
	end
end

-- A few sparkles fly out from the icon (on tap).
function HudIcon.Burst(self: HudIcon)
	local count = Style.Theme.Motion.IconSparkles
	for i = 1, count do
		local a = (i - 1) / count * 2 * math.pi + math.random() * 0.5
		local star = Instance.new("ImageLabel")
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromScale(0.5, 0.5)
		star.Size = UDim2.fromScale(0.2, 0.2)
		star.BackgroundTransparency = 1
		star.Image = SPARKLE
		star.ImageColor3 = Style.Theme.Colors.Sparkle
		star.ZIndex = 5
		star.Parent = self.Holder
		local tween = TweenService:Create(star, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5 + math.sin(a) * 0.75, 0.5 - math.cos(a) * 0.75),
			Size = UDim2.fromScale(0.08, 0.08),
			ImageTransparency = 1,
		})
		tween.Completed:Connect(function()
			star:Destroy()
		end)
		tween:Play()
	end
end

return HudIcon
