--!strict
-- Title banner: a jewel ribbon with a gold border, ribbon ends behind it, a small gold star on top and the title in
-- the title font (optionally with a painted icon on the left, a bit bigger than the ribbon so it pops out). Windows
-- hang it on their top edge (UI/Window); the binding ceremony uses one for the dragon's name. Colors and sizes in
-- UITheme (Colors.Banner*, Sizes.Banner*, Motion.BannerStarSpin).
--
-- Usage: local banner = Banner.new(parent, { Text = "Quests", Icon = "Menu_Quests" })
-- banner.Holder is the frame to place (its size is set by Layout); banner:Layout(height, textSize, starSize).

local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Style = require(script.Parent.Style)
local Icon = require(script.Parent.Icon)

export type Props = {
	Text: string,
	Icon: string?, -- UITheme.Icons key
	Top: Color3?, -- ribbon colors (default: the theme's amethyst banner)
	Bottom: Color3?,
	Tail: Color3?,
	TextColor: Color3?,
}

local Banner = {}
Banner.__index = Banner

export type Banner = typeof(setmetatable({} :: {
	Holder: Frame,
	Ribbon: Frame,
	Label: TextLabel,
	Icon: GuiObject?,
	Star: TextLabel,
	Tails: { Frame },
	Height: number,
	TextSize: number,
	StarSize: number,
}, Banner))

function Banner.new(parent: Instance, props: Props): Banner
	local theme = Style.Theme
	local colors = theme.Colors
	local holder = Instance.new("Frame")
	holder.Name = "Banner"
	holder.BackgroundTransparency = 1
	holder.ZIndex = 6
	holder.Parent = parent

	-- ribbon ends: siblings drawn under the ribbon, sticking out left and right a little lower
	local tails = {}
	for side = 0, 1 do
		local tail = Instance.new("Frame")
		tail.Name = if side == 0 then "TailLeft" else "TailRight"
		tail.BackgroundColor3 = props.Tail or colors.BannerTail
		tail.ZIndex = 6
		Style.Corner(tail, 6)
		Style.GoldBorder(tail, 2)
		tail.Parent = holder
		table.insert(tails, tail)
	end

	local ribbon = Instance.new("Frame")
	ribbon.Name = "Ribbon"
	ribbon.Size = UDim2.fromScale(1, 1)
	ribbon.BackgroundColor3 = Color3.new(1, 1, 1)
	ribbon.ZIndex = 7
	Style.Gradient(ribbon, props.Top or colors.BannerTop, props.Bottom or colors.BannerBottom)
	Style.Corner(ribbon, 12)
	Style.GoldBorder(ribbon, 3)
	ribbon.Parent = holder
	local gloss = Instance.new("Frame") -- glassy light on the top half
	gloss.Name = "Gloss"
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.BackgroundTransparency = 0.82
	gloss.Position = UDim2.new(0, 5, 0, 3)
	gloss.Size = UDim2.new(1, -10, 0.42, 0)
	gloss.ZIndex = 7
	Style.Corner(gloss, 8)
	gloss.Parent = ribbon

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.ZIndex = 8
	row.Parent = ribbon
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row

	local image: GuiObject? = nil
	if props.Icon then
		local icon = Icon.new(row, props.Icon)
		icon.LayoutOrder = 1
		icon.ZIndex = 8
		image = icon
	end
	local label = Style.Label(row, props.Text, "Title", theme.TextSizes.Banner, props.TextColor or colors.Text)
	label.Name = "Title"
	label.LayoutOrder = 2
	label.TextWrapped = false
	label.ZIndex = 8
	label.TextStrokeTransparency = 1
	local outline = Instance.new("UIStroke") -- a thick dark outline reads better than TextStroke on the jewel
	outline.Color = colors.IconLabelStroke
	outline.Thickness = 2.5
	outline.Parent = label

	local star = Instance.new("TextLabel")
	star.Name = "Star"
	star.AnchorPoint = Vector2.new(0.5, 0.62)
	star.Position = UDim2.fromScale(0.5, 0)
	star.BackgroundTransparency = 1
	star.Text = "★"
	star.Font = Enum.Font.GothamBlack -- has the ★ glyph
	star.TextScaled = true
	star.TextColor3 = colors.BannerStar
	star.ZIndex = 9
	star.Parent = holder
	local starOutline = Instance.new("UIStroke")
	starOutline.Color = colors.TrimDark
	starOutline.Thickness = 2
	starOutline.Parent = star
	star.Rotation = -10
	TweenService:Create(
		star,
		TweenInfo.new(theme.Motion.BannerStarSpin / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Rotation = 10 }
	):Play()

	local self = setmetatable({
		Holder = holder,
		Ribbon = ribbon,
		Label = label,
		Icon = image,
		Star = star,
		Tails = tails,
		Height = theme.Sizes.Banner,
		TextSize = theme.TextSizes.Banner,
		StarSize = theme.Sizes.BannerStar,
	}, Banner)
	self:Layout(theme.Sizes.Banner, theme.TextSizes.Banner, theme.Sizes.BannerStar)
	return self
end

-- Sizes the banner for a height (the width follows the title).
function Banner.Layout(self: Banner, height: number, textSize: number, starSize: number)
	self.Height = height
	self.TextSize = textSize
	self.StarSize = starSize
	local padding = Style.Theme.Sizes.BannerPadding * height / Style.Theme.Sizes.Banner
	local textWidth = TextService:GetTextSize(self.Label.Text, textSize, self.Label.Font, Vector2.new(2000, 200)).X
	self.Label.TextSize = textSize
	self.Label.Size = UDim2.fromOffset(textWidth + 4, height)
	local iconWidth = 0
	if self.Icon then
		local iconSize = math.floor(height * 1.3)
		self.Icon.Size = UDim2.fromOffset(iconSize, iconSize)
		iconWidth = iconSize + 8
	end
	local width = math.floor(textWidth + iconWidth + padding * 2)
	self.Holder.Size = UDim2.fromOffset(width, height)
	local tailWidth, tailHeight = math.floor(height * 0.95), math.floor(height * 0.7)
	for index, tail in self.Tails do
		tail.Size = UDim2.fromOffset(tailWidth, tailHeight)
		tail.AnchorPoint = Vector2.new(if index == 1 then 1 else 0, 0)
		tail.Position = UDim2.new(index - 1, if index == 1 then height * 0.45 else -height * 0.45, 0, height * 0.42)
	end
	self.Star.Size = UDim2.fromOffset(starSize, starSize)
end

function Banner.SetIcon(self: Banner, key: string)
	local image = self.Icon
	local id = (Style.Theme.Icons :: any)[key]
	if image and image:IsA("ImageLabel") and type(id) == "string" then
		image.Image = id
	end
end

function Banner.SetText(self: Banner, text: string)
	self.Label.Text = text
	self:Layout(self.Height, self.TextSize, self.StarSize)
end

return Banner
