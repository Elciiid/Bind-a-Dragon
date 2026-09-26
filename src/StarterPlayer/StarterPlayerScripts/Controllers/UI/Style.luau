--!strict
-- Shared styling for the UI kit. Every look comes from Config/UITheme; components call these helpers instead of
-- setting colors/fonts themselves. (Folder "UI" is not a controller: Main.client only loads direct ModuleScripts.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

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

function Style.Play(name: string)
	local id = (UITheme.Sounds :: any)[name]
	if type(id) ~= "string" or id == "" then
		return
	end
	local sound = sounds[name]
	if sound == nil then
		local newSound = Instance.new("Sound")
		newSound.Name = `UI_{name}`
		newSound.SoundId = id
		newSound.Volume = UITheme.Sounds.Volume
		newSound.Parent = SoundService
		sounds[name] = newSound
		sound = newSound
	end
	SoundService:PlayLocalSound(sound :: Sound)
end

---------------------------------------------------------------------------------------------------------------
-- Motion

-- Hover grows, press shrinks (UIScale, so layouts aren't disturbed). Plays the click sound on activation.
function Style.AttachPress(button: GuiButton, sound: string?)
	local scale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = button
	local hovering, pressing = false, false
	local function update()
		local target = if pressing then UITheme.Motion.Press elseif hovering then UITheme.Motion.Hover else 1
		TweenService:Create(scale, TweenInfo.new(UITheme.Motion.PressTime), { Scale = target }):Play()
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
-- Dragon-theme decorations (procedural until the artist's frame art: UITheme.Art)

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

-- The night-sky panel look: gradient, gold trim, dark inner line, gold corner gems, sparkles.
function Style.PanelLook(frame: GuiObject, sparkles: number?)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 0
	Style.Gradient(frame, UITheme.Colors.PanelTop, UITheme.Colors.PanelBottom)
	Style.Corner(frame, UITheme.Corner)
	local trim = Style.Stroke(frame, UITheme.Colors.Trim, UITheme.Strokes.Trim)
	local sheen = Instance.new("UIGradient")
	sheen.Color = ColorSequence.new(UITheme.Colors.Trim, UITheme.Colors.TrimDark)
	sheen.Rotation = 90
	sheen.Parent = trim

	if UITheme.Art.PanelFrame ~= "" then
		local art = Instance.new("ImageLabel")
		art.Name = "FrameArt"
		art.Size = UDim2.fromScale(1, 1)
		art.BackgroundTransparency = 1
		art.Image = UITheme.Art.PanelFrame
		art.ScaleType = Enum.ScaleType.Slice
		art.SliceCenter = UITheme.Art.PanelFrameSlice
		art.ZIndex = 0
		art.Parent = frame
	else
		-- Inner dark line (stands in for the scale border) and gold gems on the corners.
		local inner = Instance.new("Frame")
		inner.Name = "InnerLine"
		inner.Position = UDim2.fromOffset(4, 4)
		inner.Size = UDim2.new(1, -8, 1, -8)
		inner.BackgroundTransparency = 1
		inner.ZIndex = 0
		Style.Corner(inner, UITheme.Corner - 3)
		Style.Stroke(inner, UITheme.Colors.PanelInnerLine, UITheme.Strokes.InnerLine)
		inner.Parent = frame
		for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
			local gem = Instance.new("Frame")
			gem.Name = "CornerGem"
			gem.AnchorPoint = Vector2.new(0.5, 0.5)
			gem.Position = UDim2.new(corner.X, if corner.X == 0 then 6 else -6, corner.Y, if corner.Y == 0 then 6 else -6)
			gem.Size = UDim2.fromOffset(9, 9)
			gem.Rotation = 45
			gem.BackgroundColor3 = UITheme.Colors.Trim
			gem.BorderSizePixel = 0
			gem.ZIndex = 3
			Style.Stroke(gem, UITheme.Colors.TrimDark, 1.5)
			gem.Parent = frame
		end
	end
	if UITheme.Art.PanelTexture ~= "" then
		local texture = Instance.new("ImageLabel")
		texture.Name = "Texture"
		texture.Size = UDim2.fromScale(1, 1)
		texture.BackgroundTransparency = 1
		texture.Image = UITheme.Art.PanelTexture
		texture.ScaleType = Enum.ScaleType.Tile
		texture.TileSize = UDim2.fromOffset(128, 128)
		texture.ImageTransparency = 0.85
		texture.ZIndex = 0
		texture.Parent = frame
	end
	if sparkles and sparkles > 0 then
		Style.Sparkles(frame, sparkles)
	end
end

-- A card inside a panel: darker rounded box with a colored outline and a color band on the left (element/rarity).
function Style.CardLook(frame: GuiObject, accent: Color3?)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	Style.Gradient(frame, UITheme.Colors.Card, UITheme.Colors.CardDark)
	Style.Corner(frame, UITheme.SmallCorner)
	Style.Stroke(frame, accent or UITheme.Colors.TrimDark, if accent then 2 else 1.5)
	if accent then
		local band = Instance.new("Frame")
		band.Name = "AccentBand"
		band.Size = UDim2.new(0, 5, 1, -12)
		band.Position = UDim2.fromOffset(4, 6)
		band.BackgroundColor3 = accent
		band.BorderSizePixel = 0
		Style.Round(band)
		band.Parent = frame
	end
end

return Style
