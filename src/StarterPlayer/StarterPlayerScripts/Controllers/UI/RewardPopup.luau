--!strict
-- Reward pop-up (UI renewal part 2): big moments (a new dragon, an evolution, a rebirth, a sanctuary tier, a rare
-- constellation) show a centered card instead of a toast: light rays turning behind it in the reward's color, a title
-- banner ("New dragon!"), a big picture or icon, the name big in the title font, a small tag chip, one big button, and
-- a burst of sparkles. One at a time; the rest wait in a queue. Low effects: no turning rays, fewer sparkles.
-- Sizes in UITheme.Sizes (RewardCard, RewardIcon), motion in UITheme.Motion (RewardSpin, RewardBurst).
--
-- Usage: RewardPopup.Show({ Title = "New dragon!", Name = "Solflare", Tag = "Mythic · Fire", Color = color,
--   Icon = "Rarity_Mythic", Picture = function(parent) ... end, Button = "Awesome!" })

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Style = require(script.Parent.Style)
local Icon = require(script.Parent.Icon)
local Banner = require(script.Parent.Banner)
local Button = require(script.Parent.Button)
local EffectsQuality = require(script.Parent.Parent.EffectsQuality)

export type Props = {
	Title: string, -- the banner
	Name: string, -- big line
	Tag: string?, -- small chip under the name
	Color: Color3?, -- rays / glow / name color
	Icon: string?, -- UITheme.Icons key (when there's no Picture)
	Picture: ((parent: Frame) -> ())?, -- draws a picture (e.g. a ViewportFrame of the dragon) into the given frame
	Button: string?, -- button text (default "Awesome!")
	Sound: string?, -- UITheme.Sounds key
	-- Odds layout (a new dragon): a big excitement line, chips instead of the tag, and a tap-for-details breakdown.
	Line: string?, -- e.g. "Only 1 in 8,400 binds!"
	LineColor: Color3?,
	Chips: { { Text: string, Color: Color3 } }?, -- small colored chips (rarity, element, mutation)
	Details: { Title: string, Rows: { { string } } }?, -- tap the card: rows of { name, value }
	Hint: string?, -- small text under the chips ("Tap for details")
	Seconds: number?, -- how long it stays before closing itself (default 8)
}

local EXTRA_HEIGHT = 56 -- the card grows by this much when it has a Line / Chips

local RewardPopup = {}

-- HudLayout.TopReserved (the top bar + sky pill), looked up lazily (HudLayout requires the UI kit).
local function TopReserved(): number
	local ok, value = pcall(function()
		return (require(script.Parent.Parent.HudLayout) :: any).TopReserved()
	end)
	return if ok and type(value) == "number" then value else 0
end

local queue: { Props } = {}
local showing = false
local gui: ScreenGui? = nil

local function screen(): ScreenGui
	if gui == nil then
		local newGui = Instance.new("ScreenGui")
		newGui.Name = "RewardPopup"
		newGui.DisplayOrder = Style.Theme.Layers.Popups + 1 -- above windows (the dim leaves the top bar clear)
		newGui.ScreenInsets = Enum.ScreenInsets.None
		newGui.ResetOnSpawn = false
		newGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		newGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		gui = newGui
	end
	return gui :: ScreenGui
end

-- Builds the card (rays + panel + contents) centered in `parent`; returns the root, its UIScale and the button.
function RewardPopup.Build(parent: Instance, props: Props): (Frame, UIScale, Button.Button)
	local theme = Style.Theme
	local sizes = theme.Sizes
	local color = props.Color or theme.Colors.Gold
	local card = sizes.RewardCard
	if props.Line or props.Chips then
		card = Vector2.new(card.X, card.Y + EXTRA_HEIGHT)
	end

	local root = Instance.new("Frame")
	root.Name = "Reward"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.new(0.5, 0, 0.5, math.floor(TopReserved() / 2))
	root.Size = UDim2.fromOffset(card.X, card.Y)
	root.BackgroundTransparency = 1
	root.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Parent = root

	local rays = Instance.new("ImageLabel")
	rays.Name = "Rays"
	rays.BackgroundTransparency = 1
	rays.Image = theme.Art.Rays
	rays.ImageColor3 = Style.Shade(color, 0.65) -- light, so the rays read on any background
	rays.ImageTransparency = 0
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.32)
	rays.Size = UDim2.fromOffset(card.X * 2, card.X * 2)
	rays.ZIndex = -5
	rays.Parent = root
	if not EffectsQuality.IsLow() then
		TweenService:Create(rays, TweenInfo.new(theme.Motion.RewardSpin, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 }):Play()
	end

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	Style.PanelLook(panel, 8)
	panel.Parent = root
	local banner = Banner.new(panel, { Text = props.Title })
	banner.Holder.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Holder.Position = UDim2.fromScale(0.5, 0)

	local pictureFrame = Instance.new("Frame")
	pictureFrame.Name = "Picture"
	pictureFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	pictureFrame.Position = UDim2.new(0.5, 0, 0, sizes.RewardIcon * 0.5 + 26)
	pictureFrame.Size = UDim2.fromOffset(sizes.RewardIcon, sizes.RewardIcon)
	pictureFrame.BackgroundTransparency = 1
	pictureFrame.ZIndex = 3
	pictureFrame.Parent = panel
	local halo = Style.Glow(pictureFrame, color, 26, 0.35, 2)
	halo.Size = UDim2.fromScale(0.7, 0.7) -- a soft disc behind the picture (the picture draws above it)
	if props.Picture then
		props.Picture(pictureFrame)
	elseif props.Icon then
		local image = Icon.new(pictureFrame, props.Icon, color)
		image.Size = UDim2.fromScale(1, 1)
		image.ZIndex = 3
	end

	local name = Style.Label(panel, props.Name, "Title", 36, Style.Shade(color, 0.35))
	name.Name = "Name"
	name.AnchorPoint = Vector2.new(0.5, 0)
	name.Position = UDim2.new(0.5, 0, 0, sizes.RewardIcon + 30)
	name.Size = UDim2.new(1, -40, 0, 42)
	name.TextScaled = true
	name.ZIndex = 3
	Style.Outline(name, 2.5)

	if props.Line then
		local line = Style.Label(panel, props.Line, "Title", 24, props.LineColor or theme.Colors.Gold)
		line.Name = "OddsLine"
		line.AnchorPoint = Vector2.new(0.5, 0)
		line.Position = UDim2.new(0.5, 0, 0, sizes.RewardIcon + 76)
		line.Size = UDim2.new(1, -30, 0, 30)
		line.TextScaled = true
		line.ZIndex = 3
		Style.Outline(line, 2)
	end
	if props.Chips and #props.Chips > 0 then
		local row = Instance.new("Frame")
		row.Name = "Chips"
		row.AnchorPoint = Vector2.new(0.5, 0)
		row.Position = UDim2.new(0.5, 0, 0, sizes.RewardIcon + 112)
		row.Size = UDim2.new(1, -20, 0, 26)
		row.BackgroundTransparency = 1
		row.ZIndex = 3
		row.Parent = panel
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.Padding = UDim.new(0, 6)
		list.Parent = row
		for _, chip in props.Chips do
			local label = Style.Label(row, chip.Text, "Title", 15, theme.Colors.Text)
			label.Size = UDim2.fromOffset(0, 24)
			label.AutomaticSize = Enum.AutomaticSize.X
			label.TextWrapped = false
			label.BackgroundTransparency = 0.1
			label.BackgroundColor3 = Style.Shade(chip.Color, -0.5)
			label.ZIndex = 3
			Style.Round(label)
			Style.Pad(label, 10, 0)
			local stroke = Instance.new("UIStroke")
			stroke.Color = chip.Color
			stroke.Thickness = 1.5
			stroke.Parent = label
			Style.Outline(label, 1.2)
		end
	end
	if props.Hint then
		local hint = Style.Label(panel, props.Hint, "Bold", 14, theme.Colors.TextMuted)
		hint.Name = "Hint"
		hint.AnchorPoint = Vector2.new(0.5, 0)
		hint.Position = UDim2.new(0.5, 0, 0, sizes.RewardIcon + 144)
		hint.Size = UDim2.new(1, -20, 0, 18)
		hint.ZIndex = 3
	end
	if props.Tag and props.Tag ~= "" and not props.Line then
		local tag = Style.Label(panel, props.Tag, "Title", 17, theme.Colors.Text)
		tag.Name = "Tag"
		tag.AnchorPoint = Vector2.new(0.5, 0)
		tag.Position = UDim2.new(0.5, 0, 0, sizes.RewardIcon + 76)
		tag.Size = UDim2.fromOffset(0, 26)
		tag.AutomaticSize = Enum.AutomaticSize.X
		tag.TextWrapped = false
		tag.BackgroundTransparency = 0.1
		tag.BackgroundColor3 = Style.Shade(color, -0.55)
		tag.ZIndex = 3
		Style.Round(tag)
		Style.Pad(tag, 14, 0)
		Style.GoldBorder(tag, 2)
		Style.Outline(tag, 1.5)
	end

	local button = Button.new(panel, { Text = props.Button or "Awesome!", Kind = "Confirm", TextSize = 24, Sound = "Confirm" })
	button.Instance.AnchorPoint = Vector2.new(0.5, 1)
	button.Instance.Position = UDim2.new(0.5, 0, 1, -16)
	button.Instance.Size = UDim2.fromOffset(200, 54)
	button.Instance.ZIndex = 3

	-- tap anywhere on the card (except the button) to flip between the card and the odds breakdown
	if props.Details then
		local details = Instance.new("Frame")
		details.Name = "Details"
		details.Position = UDim2.fromOffset(12, 30)
		details.Size = UDim2.new(1, -24, 1, -110)
		details.BackgroundColor3 = theme.Colors.GlassBottom
		details.BackgroundTransparency = 0
		details.Visible = false
		details.ZIndex = 6
		local detailsCorner = Instance.new("UICorner")
		detailsCorner.CornerRadius = UDim.new(0, 14)
		detailsCorner.Parent = details
		Style.GoldBorder(details, 2)
		details.Parent = panel
		local heading = Style.Label(details, props.Details.Title, "Title", 22, color)
		heading.Position = UDim2.fromOffset(8, 6)
		heading.Size = UDim2.new(1, -16, 0, 30)
		heading.ZIndex = 7
		Style.Outline(heading, 1.5)
		local rows = Instance.new("Frame")
		rows.BackgroundTransparency = 1
		rows.Position = UDim2.fromOffset(12, 42)
		rows.Size = UDim2.new(1, -24, 1, -48)
		rows.ZIndex = 7
		rows.Parent = details
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 4)
		list.Parent = rows
		for _, pair in props.Details.Rows do
			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, 26)
			row.ZIndex = 7
			row.Parent = rows
			local left = Style.Label(row, pair[1], "Bold", 16, theme.Colors.TextMuted)
			left.Size = UDim2.new(0.55, 0, 1, 0)
			left.TextXAlignment = Enum.TextXAlignment.Left
			left.ZIndex = 7
			local right = Style.Label(row, pair[2], "Title", 18, theme.Colors.Text)
			right.AnchorPoint = Vector2.new(1, 0)
			right.Position = UDim2.fromScale(1, 0)
			right.Size = UDim2.new(0.45, 0, 1, 0)
			right.TextXAlignment = Enum.TextXAlignment.Right
			right.ZIndex = 7
			Style.Outline(right, 1.2)
		end
		panel.Active = true
		panel.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				details.Visible = not details.Visible
			end
		end)
	end
	return root, scale, button
end

local function showNext()
	local props = table.remove(queue, 1)
	if props == nil then
		showing = false
		return
	end
	showing = true
	local layer = screen()
	local theme = Style.Theme

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	-- the dim starts under the top bar + sky pill, so those stay readable
	local top = TopReserved()
	dim.Position = UDim2.fromOffset(0, top)
	dim.Size = UDim2.new(1, 0, 1, -top)
	dim.BackgroundColor3 = theme.Colors.TextStroke
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Parent = layer
	dim.ClipsDescendants = true -- the turning rays stay below the top bar too
	local root, scale, button = RewardPopup.Build(dim, props)
	root.Position = UDim2.fromScale(0.5, 0.5)
	local camera = workspace.CurrentCamera
	local short = if camera then math.min(camera.ViewportSize.X, camera.ViewportSize.Y) else 1080
	local fit = math.min(1, (short - TopReserved() - 30) / (theme.Sizes.RewardCard.Y + (if props.Line or props.Chips then EXTRA_HEIGHT else 0) + 40)) -- phones: shrink to fit
	scale.Scale = 0.2 * fit
	TweenService:Create(dim, TweenInfo.new(0.25), { BackgroundTransparency = 0.45 }):Play()
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = fit }):Play()
	Style.Play(props.Sound or "Confirm")
	task.delay(0.12, function()
		local size = root.AbsoluteSize / math.max(scale.Scale, 0.01)
		Style.SparkleBurst(root, Vector2.new(size.X / 2, theme.Sizes.RewardIcon * 0.5 + 18), theme.Motion.RewardBurst, 160)
	end)

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		TweenService:Create(dim, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
		local out = TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.3 * fit })
		out.Completed:Connect(function()
			root:Destroy()
			dim:Destroy()
			showNext()
		end)
		out:Play()
	end
	button.Instance.Activated:Connect(close)
	task.delay(props.Seconds or 8, close) -- goes away by itself too
end

-- Queues a reward pop-up (one shows at a time).
function RewardPopup.Show(props: Props)
	table.insert(queue, props)
	if not showing then
		showNext()
	end
end

return RewardPopup
