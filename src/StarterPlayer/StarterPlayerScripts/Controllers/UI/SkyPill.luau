--!strict
-- The day/night pill (UI renewal part 2), under the travel bar: a big painted sun / moon popping out on the left,
-- "Night in 3:31" big in the title font, at night a small second line (tonight's constellation + the favored area),
-- and a thin progress bar inside along the bottom. In the last seconds before night it glows and pulses.
-- DayNightController drives it; sizes in UITheme.Sizes (SkyPillV2 / PhoneSkyPillV2, SkyIcon), wording Text.SkyHud.
--
-- Usage: local pill = SkyPill.new(parent); pill:Set({ Night = false, Big = "Night in 3:31", Small = "", Progress = 0.4,
-- Accent = color, Dusk = false }); pill:Layout(isPhone)

local TweenService = game:GetService("TweenService")

local Style = require(script.Parent.Style)

export type State = {
	Night: boolean,
	Big: string,
	Small: string, -- "" = one line
	Progress: number, -- 0..1 through the phase
	Accent: Color3, -- progress bar / glow color
	Dusk: boolean, -- glow + pulse (night is about to fall)
}

local SkyPill = {}
SkyPill.__index = SkyPill

export type SkyPill = typeof(setmetatable({} :: {
	Instance: Frame,
	Back: Frame,
	Glow: ImageLabel,
	Icon: ImageLabel,
	Big: TextLabel,
	Small: TextLabel,
	Fill: Frame,
	Scale: UIScale,
	Phone: boolean,
	Night: boolean?,
	Dusk: boolean,
	Pulse: Tween?,
}, SkyPill))

function SkyPill.new(parent: Instance): SkyPill
	local theme = Style.Theme
	local colors = theme.Colors
	local root = Instance.new("Frame")
	root.Name = "SkyPill"
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.BackgroundTransparency = 1
	root.Parent = parent

	local glow = Style.Glow(root, colors.DuskGlow, 18, 1, -2) -- shown at dusk
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.new(1, 1, 1)
	back.ZIndex = -1
	Style.Gradient(back, colors.PanelV2Top, colors.PanelV2Bottom)
	Style.Round(back)
	Style.GoldBorder(back, 2.5)
	back.Parent = root

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Image = theme.Icons.Sky_Sun
	icon.ZIndex = 3
	icon.Parent = root

	local big = Style.Label(root, "", "Title", 22, colors.Text)
	big.Name = "Big"
	big.TextXAlignment = Enum.TextXAlignment.Left
	big.TextWrapped = false
	big.ZIndex = 2
	Style.Outline(big, 1.5)
	local small = Style.Label(root, "", "Bold", 12, colors.TextMuted)
	small.Name = "Small"
	small.TextXAlignment = Enum.TextXAlignment.Left
	small.TextWrapped = false
	small.TextTruncate = Enum.TextTruncate.AtEnd
	small.ZIndex = 2

	local rail = Instance.new("Frame")
	rail.Name = "Rail"
	rail.AnchorPoint = Vector2.new(0, 1)
	rail.BackgroundColor3 = colors.TextStroke
	rail.BackgroundTransparency = 0.3
	rail.BorderSizePixel = 0
	rail.ZIndex = 2
	Style.Round(rail)
	rail.Parent = root
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = colors.Gold
	fill.BorderSizePixel = 0
	fill.ZIndex = 2
	Style.Round(fill)
	fill.Parent = rail

	local scale = Instance.new("UIScale")
	scale.Parent = root

	local self = setmetatable({
		Instance = root,
		Back = back,
		Glow = glow,
		Icon = icon,
		Big = big,
		Small = small,
		Fill = fill,
		Scale = scale,
		Phone = false,
		Night = nil,
		Dusk = false,
		Pulse = nil,
	}, SkyPill)
	self:Layout(false)
	return self
end

-- Sizes for PC or phone, with one line (day) or two (night).
function SkyPill.Layout(self: SkyPill, phone: boolean)
	self.Phone = phone
	local sizes = Style.Theme.Sizes
	local base = if phone then sizes.PhoneSkyPillV2 else sizes.SkyPillV2
	local twoLines = self.Small.Text ~= ""
	local height = base.Y + (if twoLines then (if phone then sizes.PhoneSkyPillExtraLine else sizes.SkyPillExtraLine) else 0)
	self.Instance.Size = UDim2.fromOffset(base.X, height)
	local iconSize = if phone then sizes.PhoneSkyIcon else sizes.SkyIcon
	self.Icon.Size = UDim2.fromOffset(iconSize, iconSize)
	self.Icon.Position = UDim2.new(0, iconSize * 0.18, 0.5, 0)
	local left = math.floor(iconSize * 0.72)
	local bigSize = if phone then 17 else 24
	local smallSize = if phone then 10 else 12
	local railInset = if phone then 4 else 6
	self.Big.TextSize = bigSize
	self.Small.TextSize = smallSize
	if twoLines then
		self.Big.Position = UDim2.fromOffset(left, 2)
		self.Big.Size = UDim2.new(1, -(left + 12), 0, bigSize + 4)
		self.Small.Visible = true
		self.Small.Position = UDim2.fromOffset(left + 1, bigSize + 5)
		self.Small.Size = UDim2.new(1, -(left + 14), 0, smallSize + 2)
	else
		self.Big.Position = UDim2.fromOffset(left, 0)
		self.Big.Size = UDim2.new(1, -(left + 12), 1, -railInset)
		self.Small.Visible = false
	end
	local rail = self.Fill.Parent :: Frame
	rail.Position = UDim2.new(0, left, 1, -railInset)
	rail.Size = UDim2.new(1, -(left + 16), 0, if phone then 3 else 4)
end

function SkyPill.Set(self: SkyPill, state: State)
	local theme = Style.Theme
	local lines = self.Small.Text ~= ""
	self.Big.Text = state.Big
	self.Small.Text = state.Small
	if lines ~= (state.Small ~= "") then
		self:Layout(self.Phone)
	end
	self.Fill.BackgroundColor3 = state.Accent
	self.Fill.Size = UDim2.fromScale(math.clamp(state.Progress, 0, 1), 1)
	if self.Night ~= state.Night then
		self.Icon.Image = if state.Night then theme.Icons.Sky_Moon else theme.Icons.Sky_Sun
		if self.Night ~= nil then -- phase change: pop + swing the icon
			local seconds = theme.Motion.SkyPhaseChange
			self.Scale.Scale = 0.9
			TweenService:Create(self.Scale, TweenInfo.new(seconds * 0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			self.Icon.Rotation = if state.Night then -30 else 30
			TweenService:Create(self.Icon, TweenInfo.new(seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
		end
		self.Night = state.Night
	end
	if self.Dusk ~= state.Dusk then
		self.Dusk = state.Dusk
		if self.Pulse then
			self.Pulse:Cancel()
			self.Pulse = nil
		end
		if state.Dusk then
			self.Glow.ImageTransparency = 0.7
			local pulse = TweenService:Create(
				self.Glow,
				TweenInfo.new(theme.Motion.DuskPulse / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ ImageTransparency = 0.15 }
			)
			pulse:Play()
			self.Pulse = pulse
		else
			self.Glow.ImageTransparency = 1
		end
	end
end

return SkyPill
