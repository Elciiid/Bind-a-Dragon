--!strict
-- The look of a ProximityPrompt (PromptController draws every prompt with it): the in-world panel (Style.WorldPanel)
-- with a round amethyst key badge and a gold ring (the ring fills with gold while a hold prompt is held), an optional
-- icon popping out, the object name small and the action big in the title font. Look in UITheme.WorldPanel.
--
-- Usage: local pill = PromptPill.new(parent, { Key = "E", Object = "Star Altar", Action = "Bind", Icon = "Stardust", Height = 64 })
-- pill.Button fills the parent; pill:SetHold(0..1).

local Style = require(script.Parent.Style)
local Icon = require(script.Parent.Icon)

export type Props = { Key: string, Object: string, Action: string, Icon: string?, Height: number }

local PromptPill = {}
PromptPill.__index = PromptPill

export type PromptPill = typeof(setmetatable({} :: {
	Button: TextButton,
	Badge: Frame,
	Ring: UIStroke,
	Fill: Frame,
	Object: TextLabel,
	Action: TextLabel,
	BadgeSize: number,
}, PromptPill))

function PromptPill.new(parent: Instance, props: Props): PromptPill
	local theme = Style.Theme
	local world = theme.WorldPanel
	local height = props.Height

	local button = Instance.new("TextButton")
	button.Name = "Pill"
	button.Text = ""
	button.AutoButtonColor = false
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.5)
	button.Size = UDim2.new(1, -12, 1, -6)
	Style.WorldPanel(button)
	button.Parent = parent

	-- Key badge (a round jewel with a gold ring) with the hold fill
	local badgeSize = height - 8
	local badge = Instance.new("Frame")
	badge.Name = "Key"
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(0, -4, 0.5, 0)
	badge.Size = UDim2.fromOffset(badgeSize, badgeSize)
	badge.BackgroundColor3 = Color3.new(1, 1, 1)
	badge.ZIndex = 6
	Style.Gradient(badge, world.KeyBadgeTop, world.KeyBadgeBottom)
	Style.Round(badge)
	badge.Parent = button
	local ring = Style.GoldBorder(badge, 3)
	local fill = Instance.new("Frame")
	fill.Name = "Hold"
	fill.AnchorPoint = Vector2.new(0.5, 0.5)
	fill.Position = UDim2.fromScale(0.5, 0.5)
	fill.Size = UDim2.fromScale(0, 0)
	fill.BackgroundColor3 = theme.Colors.Gold
	fill.BackgroundTransparency = 0.35
	fill.ZIndex = 7
	Style.Round(fill)
	fill.Parent = badge
	local keyLabel = Style.Label(badge, props.Key, "Title", 20, theme.Colors.Text)
	keyLabel.Size = UDim2.fromScale(1, 1)
	keyLabel.TextScaled = true
	keyLabel.ZIndex = 8
	Style.Outline(keyLabel, 1.5)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.2, 0), UDim.new(0.2, 0)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.24, 0), UDim.new(0.2, 0)
	pad.Parent = keyLabel

	local left = badgeSize + 2
	if props.Icon then
		local icon = Icon.new(button, props.Icon)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, left, 0.5, 0)
		icon.Size = UDim2.fromOffset(height - 12, height - 12)
		icon.ZIndex = 3
		left += height - 8
	end
	local object = Style.Label(button, props.Object, "Bold", 13, theme.Colors.TextMuted)
	object.Position = UDim2.fromOffset(left, 5)
	object.Size = UDim2.new(1, -(left + 10), 0.34, 0)
	object.TextXAlignment = Enum.TextXAlignment.Left
	object.TextScaled = true
	object.ZIndex = 3
	local action = Style.Label(button, props.Action, "Title", 20, theme.Colors.Text)
	action.Position = UDim2.new(0, left, 0.34, 3)
	action.Size = UDim2.new(1, -(left + 10), 0.58, -6)
	action.TextXAlignment = Enum.TextXAlignment.Left
	action.TextScaled = true
	action.ZIndex = 3
	Style.Outline(action, 1.5)

	return setmetatable({
		Button = button,
		Badge = badge,
		Ring = ring,
		Fill = fill,
		Object = object,
		Action = action,
		BadgeSize = badgeSize,
	}, PromptPill)
end

-- Hold progress 0..1 (0 = not held).
function PromptPill.SetHold(self: PromptPill, t: number)
	self.Fill.Size = UDim2.fromScale(t, t)
	self.Ring.Thickness = if t > 0 then 4 else 3
end

-- A few sparkles out of the key badge (the prompt was used).
function PromptPill.Burst(self: PromptPill)
	local height = self.Button.AbsoluteSize.Y
	Style.SparkleBurst(self.Button, Vector2.new(self.BadgeSize / 2 - 4, height / 2), Style.Theme.WorldPanel.TriggerSparkles, 26)
end

return PromptPill
