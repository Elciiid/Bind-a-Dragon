--!strict
-- Shared styling for the UI kit. Every look comes from Config/UITheme; components call these helpers instead of
-- setting colors/fonts themselves. (Folder "UI" is not a controller: Main.client only loads direct ModuleScripts.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local EffectsQuality = require(script.Parent.Parent.EffectsQuality)

local Style = {}
Style.Theme = UITheme

function Style.Corner(instance: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or UITheme.SmallCorner)
	corner.Parent = instance
	return corner
end

function Style.Round(instance: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = instance
	return corner
end

function Style.Pad(instance: GuiObject, x: number, y: number?)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, x)
	pad.PaddingRight = UDim.new(0, x)
	pad.PaddingTop = UDim.new(0, y or x)
	pad.PaddingBottom = UDim.new(0, y or x)
	pad.Parent = instance
	return pad
end

function Style.Stroke(instance: GuiObject, color: Color3, thickness: number, border: boolean?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = if border == false then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = instance
	return stroke
end

-- Vertical gradient from top to bottom color (on a white background it shows the colors exactly).
function Style.Gradient(instance: GuiObject, top: Color3, bottom: Color3): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = 90
	gradient.Parent = instance
	return gradient
end

-- A gradient box holding a text object: UIGradient on a TextLabel/TextButton would tint its text too (and a child
-- would draw over the text), so the gradient goes on this frame and the text object fills it, transparent.
-- The caller positions/sizes the returned frame instead of the text object.
function Style.Backdrop(instance: GuiObject, top: Color3, bottom: Color3, radius: number?): Frame
	local backdrop = Instance.new("Frame")
	backdrop.Name = instance.Name .. "Backdrop"
	backdrop.BackgroundColor3 = Color3.new(1, 1, 1)
	backdrop.AnchorPoint = instance.AnchorPoint
	backdrop.Position = instance.Position
	backdrop.Size = instance.Size
	backdrop.ZIndex = instance.ZIndex
	Style.Gradient(backdrop, top, bottom)
	if radius then
		Style.Corner(backdrop, radius)
	else
		Style.Round(backdrop)
	end
	backdrop.Parent = instance.Parent
	instance.AnchorPoint = Vector2.zero
	instance.Position = UDim2.new()
	instance.Size = UDim2.fromScale(1, 1)
	instance.BackgroundTransparency = 1
	instance.Parent = backdrop
	return backdrop
end

-- Standard text look: white with a dark outline (readable on any background).
export type TextKind = "Title" | "Body" | "Bold" | "Heavy"
function Style.Text(label: TextLabel | TextButton, kind: TextKind, size: number?, color: Color3?)
	label.Font = (UITheme.Fonts :: any)[kind] or UITheme.Fonts.Body
	label.TextColor3 = color or UITheme.Colors.Text
	label.TextStrokeColor3 = UITheme.Colors.TextStroke
	label.TextStrokeTransparency = if kind == "Body" then 1 else UITheme.Strokes.TextStroke
	label.BackgroundTransparency = 1
	if size then
		label.TextScaled = false
		label.TextSize = size
	end
end

-- A plain text label in the theme.
function Style.Label(parent: Instance, text: string, kind: TextKind, size: number, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.Text = text
	label.TextWrapped = true
	Style.Text(label, kind, size, color)
	label.Parent = parent
	return label
end

-- Lighter/darker version of a color (amount -1..1).
function Style.Shade(color: Color3, amount: number): Color3
	return if amount >= 0 then color:Lerp(Color3.new(1, 1, 1), amount) else color:Lerp(Color3.new(0, 0, 0), -amount)
end

---------------------------------------------------------------------------------------------------------------
-- Sounds

local sounds: { [string]: Sound } = {}
local lastFeedbackSound = -math.huge
local FEEDBACK_WINDOW = 0.35 -- seconds; matches Config/Feedback ToastSoundWindow

-- FeedbackController calls this when it plays a palette sound, so the toast chime right after it is skipped.
function Style.MarkFeedbackSound()
	lastFeedbackSound = os.clock()
end

function Style.Play(name: string)
	local id = (UITheme.Sounds :: any)[name]
	if type(id) ~= "string" or id == "" then
		return
	end
	if name == "Confirm" and os.clock() - lastFeedbackSound < FEEDBACK_WINDOW then
		return
	end
	local volumeSetting = game:GetService("Players").LocalPlayer:GetAttribute("SoundVolume")
	local volume = UITheme.Sounds.Volume * (if type(volumeSetting) == "number" then math.clamp(volumeSetting, 0, 1) else 1)
	local sound = sounds[name]
	if sound == nil then
		local newSound = Instance.new("Sound")
		newSound.Name = `UI_{name}`
		newSound.SoundId = id
		newSound.Parent = SoundService
		sounds[name] = newSound
		sound = newSound
	end
	(sound :: Sound).Volume = volume
	SoundService:PlayLocalSound(sound :: Sound)
end

---------------------------------------------------------------------------------------------------------------
-- Motion

-- Hover grows, press shrinks (UIScale, so layouts aren't disturbed); on hover the outline turns gold and thickens.
-- Plays the click sound on activation.
function Style.AttachPress(button: GuiButton, sound: string?)
	local scale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = button
	local outline = button:FindFirstChildOfClass("UIStroke")
	local outlineColor = if outline then outline.Color else nil
	local outlineThickness = if outline then outline.Thickness else nil
	local hovering, pressing = false, false
	local function update()
		local target = if EffectsQuality.IsLow() then 1 elseif pressing then UITheme.Motion.Press elseif hovering then UITheme.Motion.Hover else 1
		local info = TweenInfo.new(UITheme.Motion.PressTime)
		TweenService:Create(scale, info, { Scale = target }):Play()
		if outline and outlineColor and outlineThickness then
			local lit = hovering and not pressing
			TweenService:Create(outline, info, {
				Color = if lit then UITheme.Colors.Trim else outlineColor,
				Thickness = if lit then outlineThickness + UITheme.Strokes.HoverGrow else outlineThickness,
			}):Play()
		end
	end
	button.MouseEnter:Connect(function()
		hovering = true
		update()
	end)
	button.MouseLeave:Connect(function()
		hovering, pressing = false, false
		update()
	end)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pressing = true
			update()
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pressing = false
			update()
		end
	end)
	button.Activated:Connect(function()
		Style.Play(sound or "Click")
	end)
end

---------------------------------------------------------------------------------------------------------------
-- Dragon-theme decorations (procedural; an artist's frame art in UITheme.Art replaces the border ornaments)

-- Small twinkling four-point stars scattered inside a frame.
function Style.Sparkles(frame: GuiObject, count: number)
	local rng = Random.new(#frame:GetFullName())
	for _ = 1, count do
		local size = rng:NextInteger(4, 8)
		local star = Instance.new("Frame")
		star.Name = "Sparkle"
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromScale(rng:NextNumber(0.05, 0.95), rng:NextNumber(0.08, 0.95))
		star.Size = UDim2.fromOffset(size, size)
		star.Rotation = 45
		star.BackgroundColor3 = UITheme.Colors.Sparkle
		star.BackgroundTransparency = 0.6
		star.BorderSizePixel = 0
		star.ZIndex = 0
		star.Parent = frame
		local tween = TweenService:Create(
			star,
			TweenInfo.new(UITheme.Motion.SparkleTwinkle, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, rng:NextNumber(0, 1.5)),
			{ BackgroundTransparency = 0.95 }
		)
		tween:Play()
	end
end

-- A faint constellation (dots joined by lines) in a title bar, on the right side.
function Style.Constellation(frame: GuiObject)
	local points = { Vector2.new(0.62, 0.62), Vector2.new(0.70, 0.30), Vector2.new(0.78, 0.55), Vector2.new(0.86, 0.25), Vector2.new(0.93, 0.60) }
	local holder = Instance.new("Frame")
	holder.Name = "Constellation"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 1
	holder.Parent = frame
	local function line(a: Vector2, b: Vector2)
		-- Positions in scale; drawn after the holder has a size.
		local l = Instance.new("Frame")
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.BorderSizePixel = 0
		l.BackgroundColor3 = UITheme.Colors.Constellation
		l.BackgroundTransparency = 0.7
		l.ZIndex = 1
		l.Parent = holder
		local function place()
			local size = holder.AbsoluteSize
			local pa, pb = a * size, b * size
			local mid = (pa + pb) / 2
			local delta = pb - pa
			l.Position = UDim2.fromOffset(mid.X, mid.Y)
			l.Size = UDim2.fromOffset(delta.Magnitude, 1.5)
			l.Rotation = math.deg(math.atan2(delta.Y, delta.X))
		end
		holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
		place()
	end
	for index = 1, #points - 1 do
		line(points[index], points[index + 1])
	end
	for _, point in points do
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(point.X, point.Y)
		dot.Size = UDim2.fromOffset(5, 5)
		dot.BackgroundColor3 = UITheme.Colors.Sparkle
		dot.BackgroundTransparency = 0.3
		dot.ZIndex = 1
		Style.Round(dot)
		dot.Parent = holder
	end
end

-- A gold border: a stroke shaded from light gold at the top to antique gold at the bottom.
function Style.GoldBorder(instance: GuiObject, thickness: number): UIStroke
	local stroke = Style.Stroke(instance, Color3.new(1, 1, 1), thickness)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, UITheme.Colors.TrimLight),
		ColorSequenceKeypoint.new(0.45, UITheme.Colors.Trim),
		ColorSequenceKeypoint.new(1, UITheme.Colors.TrimDark),
	})
	gradient.Rotation = 90
	gradient.Parent = stroke
	return stroke
end

-- A gold diamond with a jewel in it (window corners, dividers).
function Style.Ornament(parent: GuiObject, size: number, jewel: Color3?): Frame
	local gem = Instance.new("Frame")
	gem.Name = "Ornament"
	gem.AnchorPoint = Vector2.new(0.5, 0.5)
	gem.Size = UDim2.fromOffset(size, size)
	gem.Rotation = 45
	gem.BackgroundColor3 = Color3.new(1, 1, 1)
	gem.BorderSizePixel = 0
	gem.ZIndex = 4
	Style.Gradient(gem, UITheme.Colors.TrimLight, UITheme.Colors.TrimDark)
	Style.Corner(gem, 3)
	Style.Stroke(gem, UITheme.Colors.TextStroke, 1.5)
	gem.Parent = parent
	local stone = Instance.new("Frame")
	stone.Name = "Jewel"
	stone.AnchorPoint = Vector2.new(0.5, 0.5)
	stone.Position = UDim2.fromScale(0.5, 0.5)
	stone.Size = UDim2.fromScale(0.46, 0.46)
	stone.BackgroundColor3 = Color3.new(1, 1, 1)
	stone.BorderSizePixel = 0
	stone.ZIndex = 5
	local color = jewel or UITheme.Colors.CornerJewel
	Style.Gradient(stone, Style.Shade(color, 0.45), Style.Shade(color, -0.25))
	Style.Corner(stone, 2)
	stone.Parent = gem
	return gem
end

-- Sparkles burst out of a point (e.g. a window's title banner when it opens) and fade. `layer` is a frame covering
-- the area (the sparkles are drawn in it); `at` is the burst center in that frame's pixels.
function Style.SparkleBurst(layer: GuiObject, at: Vector2, count: number, reach: number?)
	if EffectsQuality.IsLow() then
		count = math.ceil(count / 3) -- Low effects: a few sparkles only
	end
	local rng = Random.new()
	for _ = 1, count do
		local size = rng:NextInteger(6, 11)
		local star = Instance.new("Frame")
		star.Name = "BurstSparkle"
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromOffset(at.X, at.Y)
		star.Size = UDim2.fromOffset(size, size)
		star.Rotation = 45
		star.BackgroundColor3 = if rng:NextNumber() < 0.5 then UITheme.Colors.Sparkle else UITheme.Colors.Trim
		star.BorderSizePixel = 0
		star.ZIndex = 20
		star.Parent = layer
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = (reach or 70) * rng:NextNumber(0.6, 1.2)
		local target = at + Vector2.new(math.cos(angle) * distance * 1.6, math.sin(angle) * distance)
		local time = rng:NextNumber(0.45, 0.75)
		TweenService:Create(star, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(target.X, target.Y),
			Size = UDim2.fromOffset(2, 2),
			BackgroundTransparency = 1,
			Rotation = 45 + rng:NextInteger(-90, 90),
		}):Play()
		task.delay(time, function()
			star:Destroy()
		end)
	end
end

-- A soft glow (UITheme.Art.Glow, 9-sliced) around a frame, reaching `spread` pixels out. It is a child, so it draws
-- over its parent's own background: give the parent a transparent background (PanelLook does) or keep it faint.
function Style.Glow(parent: GuiObject, color: Color3, spread: number, transparency: number, zIndex: number?): ImageLabel
	local art = UITheme.Art
	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow"
	glow.BackgroundTransparency = 1
	glow.Image = art.Glow
	glow.ImageColor3 = color
	glow.ImageTransparency = transparency
	glow.ScaleType = Enum.ScaleType.Slice
	glow.SliceCenter = art.GlowSlice
	glow.SliceScale = spread / art.GlowBody -- the glow's solid body lines up with the frame's edge
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.new(1, spread * 2, 1, spread * 2)
	glow.ZIndex = zIndex or -3
	glow.Parent = parent
	return glow
end

-- The faint sparkle pattern (UITheme.Art.PanelPattern) filling a frame.
function Style.Pattern(parent: GuiObject, radius: number?, zIndex: number?): ImageLabel?
	local art = UITheme.Art
	if art.PanelPattern == "" then
		return nil
	end
	local pattern = Instance.new("ImageLabel")
	pattern.Name = "Pattern"
	pattern.BackgroundTransparency = 1
	pattern.Size = UDim2.fromScale(1, 1)
	pattern.Image = art.PanelPattern
	pattern.ImageColor3 = UITheme.Colors.PatternTint
	pattern.ImageTransparency = Style.Theme.MobileUI.PatternTransparency
	pattern.ScaleType = Enum.ScaleType.Tile
	pattern.TileSize = UDim2.fromOffset(art.PatternTile, art.PatternTile)
	pattern.ZIndex = zIndex or -2
	Style.Corner(pattern, radius or UITheme.Corner)
	pattern.Parent = parent
	return pattern
end

-- The window/panel look (UI renewal part 2): a deep indigo -> violet panel with a faint sparkle pattern, a soft light
-- across the top, a soft outer glow, a gold border with a thin gold line inside, gold corner gems with a jewel and
-- gold beads, a small gem mid-bottom and twinkling sparkles. The frame itself stays transparent (so the glow can sit
-- behind the panel); the panel is its "Back" child. Content goes in the frame as before (ZIndex 1+).
function Style.PanelLook(frame: GuiObject, sparkles: number?)
	local sizes = UITheme.Sizes
	local colors = UITheme.Colors
	frame.BackgroundTransparency = 1
	Style.Glow(frame, colors.PanelGlow, UITheme.Art.GlowSpread, UITheme.MobileUI.PanelGlowTransparency, -3)

	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.new(1, 1, 1)
	back.BorderSizePixel = 0
	back.ZIndex = -2
	Style.Gradient(back, colors.GlassTop, colors.GlassBottom)
	Style.Corner(back, UITheme.Corner)
	Style.GoldBorder(back, sizes.Border)
	back.Parent = frame
	Style.Pattern(back, UITheme.Corner, -2)

	if UITheme.Art.PanelFrame ~= "" then
		local art = Instance.new("ImageLabel")
		art.Name = "FrameArt"
		art.Size = UDim2.fromScale(1, 1)
		art.BackgroundTransparency = 1
		art.Image = UITheme.Art.PanelFrame
		art.ScaleType = Enum.ScaleType.Slice
		art.SliceCenter = UITheme.Art.PanelFrameSlice
		art.ZIndex = -1
		art.Parent = frame
	else
		local sheen = Instance.new("Frame") -- light across the top
		sheen.Name = "Sheen"
		sheen.BackgroundColor3 = colors.GlassSheen
		sheen.BorderSizePixel = 0
		sheen.Position = UDim2.fromOffset(sizes.Border, sizes.Border)
		sheen.Size = UDim2.new(1, -sizes.Border * 2, 0.3, 0)
		sheen.ZIndex = -1
		Style.Corner(sheen, UITheme.Corner - 2)
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new(0.8, 1)
		fade.Parent = sheen
		sheen.Parent = frame

		local inset = sizes.InnerBorderInset
		local inner = Instance.new("Frame")
		inner.Name = "InnerLine"
		inner.Position = UDim2.fromOffset(inset, inset)
		inner.Size = UDim2.new(1, -inset * 2, 1, -inset * 2)
		inner.BackgroundTransparency = 1
		inner.ZIndex = -1
		Style.Corner(inner, UITheme.Corner - inset + 2)
		local line = Style.Stroke(inner, colors.Trim, 1.5)
		line.Transparency = 0.55
		inner.Parent = frame

		local size = sizes.CornerOrnament
		for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
			local cx = if corner.X == 0 then 5 else -5
			local cy = if corner.Y == 0 then 5 else -5
			local gem = Style.Ornament(frame, size)
			gem.Name = "CornerOrnament"
			gem.Position = UDim2.new(corner.X, cx, corner.Y, cy)
			for step = 1, 2 do
				for _, along in { Vector2.new(1, 0), Vector2.new(0, 1) } do
					local offset = size * 0.35 + step * 9
					local bead = Instance.new("Frame")
					bead.Name = "Bead"
					bead.AnchorPoint = Vector2.new(0.5, 0.5)
					bead.Position = UDim2.new(
						corner.X,
						cx + along.X * offset * (if corner.X == 0 then 1 else -1),
						corner.Y,
						cy + along.Y * offset * (if corner.Y == 0 then 1 else -1)
					)
					bead.Size = UDim2.fromOffset(6 - step, 6 - step)
					bead.BackgroundColor3 = colors.Trim
					bead.BorderSizePixel = 0
					bead.ZIndex = 3
					Style.Round(bead)
					bead.Parent = frame
				end
			end
		end
		local bottom = Style.Ornament(frame, math.floor(size * 0.7), colors.BannerTop)
		bottom.Name = "BottomOrnament"
		bottom.Position = UDim2.new(0.5, 0, 1, 0)
	end
	if sparkles and sparkles > 0 then
		Style.Sparkles(frame, sparkles)
	end
end

-- The in-world look (prompts, boards, banners over things): the window style made small. Indigo -> violet with the
-- faint sparkle pattern, a gold border,
-- a small gold diamond on each end and (optionally) a little gold star on top. `accent` tints the inner line.
function Style.WorldPanel(frame: GuiObject, accent: Color3?, star: boolean?)
	local world = UITheme.WorldPanel
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = world.Transparency
	Style.Gradient(frame, UITheme.Colors.PanelV2Top, UITheme.Colors.PanelV2Bottom)
	Style.Corner(frame, world.Corner)
	Style.GoldBorder(frame, world.Border)
	Style.Pattern(frame, world.Corner, 0) -- the panels' faint sparkles, under the content
	if accent then
		local inner = Instance.new("Frame")
		inner.Name = "AccentLine"
		inner.Position = UDim2.fromOffset(4, 4)
		inner.Size = UDim2.new(1, -8, 1, -8)
		inner.BackgroundTransparency = 1
		inner.ZIndex = 0
		Style.Corner(inner, world.Corner - 3)
		local line = Style.Stroke(inner, accent, 1.5)
		line.Transparency = 0.35
		inner.Parent = frame
	end
	for _, x in { 0, 1 } do
		local gem = Style.Ornament(frame, world.EndOrnament)
		gem.Name = "EndOrnament"
		gem.Position = UDim2.fromScale(x, 0.5)
	end
	if star then
		local mark = Instance.new("TextLabel")
		mark.Name = "Star"
		mark.AnchorPoint = Vector2.new(0.5, 0.6)
		mark.Position = UDim2.fromScale(0.5, 0)
		mark.Size = UDim2.fromOffset(world.Star, world.Star)
		mark.BackgroundTransparency = 1
		mark.Text = "★"
		mark.Font = Enum.Font.GothamBlack
		mark.TextScaled = true
		mark.TextColor3 = UITheme.Colors.BannerStar
		mark.ZIndex = 6
		local outline = Instance.new("UIStroke")
		outline.Color = UITheme.Colors.TrimDark
		outline.Thickness = 1.5
		outline.Parent = mark
		mark.Parent = frame
	end
end

-- Title-font text with a thick dark outline (world labels, big numbers): reads on any background.
function Style.Outline(label: TextLabel | TextButton, thickness: number?)
	label.TextStrokeTransparency = 1
	local existing = label:FindFirstChild("Outline")
	local outline = if existing and existing:IsA("UIStroke") then existing else Instance.new("UIStroke")
	outline.Name = "Outline" -- a named stroke, so a border stroke on the same label is left alone
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	outline.Color = UITheme.Colors.IconLabelStroke
	outline.Thickness = thickness or 2
	outline.Parent = label
end

-- A card inside a panel (UI renewal part 2): tinted by its accent (rarity / element / kind) with a soft glow in that
-- color and a bright outline; without an accent it's a plain lighter panel with a soft gold outline.
function Style.CardLook(frame: GuiObject, accent: Color3?)
	local colors = UITheme.Colors
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 0.04
	local top = if accent then colors.CardTop:Lerp(accent, UITheme.MobileUI.CardAccentMix) else colors.CardTop
	local bottom = colors.CardBottom
	Style.Gradient(frame, top, bottom)
	Style.Corner(frame, UITheme.SmallCorner + 4)
	local stroke = Style.Stroke(frame, if accent then Style.Shade(accent, 0.25) else colors.Trim, UITheme.MobileUI.CardBorder)
	if accent then
		stroke.Transparency = 0.2 -- reserve the strongest glow for reveal/ready states, not every card
	else
		stroke.Transparency = 0.45
	end
end

-- A tab (e.g. the Inventory tabs): chunky, the open one is a raised gold-rimmed jewel, the others calm glass.
-- `back` is the tab's frame (with a UIGradient and UIStroke from TabLookSetup); call again when selection changes.
function Style.TabLook(back: GuiObject, selected: boolean, color: Color3?)
	local colors = UITheme.Colors
	local gradient = back:FindFirstChildOfClass("UIGradient")
	local stroke = back:FindFirstChildOfClass("UIStroke")
	local base = color or colors.BannerTop
	if gradient then
		gradient.Color = if selected
			then ColorSequence.new(Style.Shade(base, 0.2), Style.Shade(base, -0.25))
			else ColorSequence.new(colors.TabTop, colors.TabBottom)
	end
	if stroke then
		stroke.Color = if selected then colors.Trim else colors.ButtonStroke
		stroke.Thickness = if selected then 3 else 1.5
		stroke.Transparency = if selected then 0 else 0.3
	end
end

return Style
