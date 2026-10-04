--!strict
-- First-time flow, presentation only (settings Config/Onboarding, wording Text.Onboarding.Lines). Saved progress, the
-- welcome bind and the free level are server-owned (OnboardingService); this never advances a step or grants anything.
--
-- KISS: Twinkle, a little glowing guide star (client-only: a neon star with a short trail), flies ahead of the player to
-- the next target and says ONE short line in a speech bubble (title font, outlined, one big icon). The real target gets a
-- big bouncing arrow and a soft glow outline: the altar (step 1, and step 5 at night), your sanctuary + the Home button
-- (step 2), the Inventory button and then the Upgrade button (step 3, Twinkle moves onto the screen). Step 4 says
-- "Bind again tonight!" for a few seconds, then Twinkle naps until night. A small Skip button sits in the top-right corner
-- (two taps). Everything hides while a reveal / reward pop-up / the merchant dialog is up; a window hides the world guide
-- (step 3 keeps guiding inside the Inventory). Never covers the prompt (Twinkle hovers above the target), the hotbar or
-- the timers. Low effects: no trail, no light. Reduced Motion: no bobbing or bouncing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local EffectsQuality = require(script.Parent.EffectsQuality)
local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Icon = require(script.Parent.UI.Icon)
local Button = require(script.Parent.UI.Button)
local RevealGate = require(script.Parent.UI.RevealGate)
local Config = require(ReplicatedStorage.Shared.Config.Onboarding)
local Theme = require(ReplicatedStorage.Shared.Config.UITheme)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local Cycle = require(ReplicatedStorage.Shared.Cycle)

local player = Players.LocalPlayer
local controller = {}
local Steps = Config.Steps
local Lines = Text.Onboarding.Lines

local function reducedMotion(): boolean
	return player:GetAttribute("ReducedMotion") == true
end

local function altarModel(): (Instance?, BasePart?)
	for _, altar in CollectionService:GetTagged("StarAltar") do
		if (altar:GetAttribute("AreaId") or Config.StarterArea) == Config.StarterArea then
			local part = if altar:IsA("BasePart") then altar elseif altar:IsA("Model") then altar.PrimaryPart or altar:FindFirstChildWhichIsA("BasePart", true) else nil
			return altar, part :: BasePart?
		end
	end
	return nil, nil
end

local function homePlot(): Model?
	for _, plot in CollectionService:GetTagged("RoostPlot") do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

-- The top-center of a target (studs): the altar's art or the sanctuary's gate area.
local function topOf(target: Instance): Vector3?
	if target:IsA("Model") then
		local box, size = target:GetBoundingBox()
		return box.Position + Vector3.new(0, size.Y / 2, 0)
	elseif target:IsA("BasePart") then
		return target.Position + Vector3.new(0, target.Size.Y / 2, 0)
	end
	return nil
end

---------------------------------------------------------------------------------------------------------------
-- The speech bubble (one line, one big icon), used in the world and on the screen

type Bubble = { Frame: Frame, Icon: GuiObject?, IconKey: string, Label: TextLabel, Set: (Bubble, string, string) -> () }

local function newBubble(parent: Instance): Bubble
	local phone = HudLayout.IsPhone()
	local bubbleConfig = Config.Bubble
	-- the panel (violet + gold) sized from its content: the icon and the line in a row
	local frame = Instance.new("Frame")
	frame.Name = "Bubble"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.fromScale(0.5, 1)
	frame.Size = UDim2.fromOffset(10, 10)
	frame.Parent = parent
	Style.WorldPanel(frame, nil, true)
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.AutomaticSize = Enum.AutomaticSize.XY
	content.Size = UDim2.new()
	content.ZIndex = 3
	content.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, bubbleConfig.PaddingX)
	padding.PaddingRight = UDim.new(0, bubbleConfig.PaddingX)
	padding.PaddingTop = UDim.new(0, bubbleConfig.PaddingY)
	padding.PaddingBottom = UDim.new(0, bubbleConfig.PaddingY)
	padding.Parent = content
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = content
	content:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		frame.Size = UDim2.fromOffset(content.AbsoluteSize.X, content.AbsoluteSize.Y)
	end)
	local size = if phone then bubbleConfig.PhoneTextSize else bubbleConfig.TextSize
	local label = Style.Label(content, "", "Title", math.max(16, size), Theme.Colors.Text)
	label.Name = "Line"
	label.TextWrapped = false
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.new()
	label.LayoutOrder = 2
	label.ZIndex = 3
	Style.Outline(label, 2.5)
	local bubble: Bubble
	bubble = {
		Frame = frame, Icon = nil, IconKey = "", Label = label,
		Set = function(self: Bubble, text: string, iconKey: string)
			if self.Label.Text ~= text then self.Label.Text = text end
			if self.IconKey ~= iconKey then
				self.IconKey = iconKey
				if self.Icon then self.Icon:Destroy() end
				local side = math.floor(bubbleConfig.IconSize * (if phone then 0.75 else 1))
				local icon = Icon.new(self.Frame:FindFirstChild("Content") :: Frame, iconKey, Theme.Colors.Gold)
				icon.Size = UDim2.fromOffset(side, side)
				icon.LayoutOrder = 1
				icon.ZIndex = 3
				self.Icon = icon
			end
		end,
	}
	return bubble
end

---------------------------------------------------------------------------------------------------------------
-- Twinkle in the world, the world arrow and glow

local world = Instance.new("Folder")
world.Name = "LocalOnboarding"

local twinkle = Instance.new("Part")
twinkle.Name = "Twinkle"
twinkle.Shape = Enum.PartType.Ball
twinkle.Size = Vector3.new(1, 1, 1)
twinkle.Material = Enum.Material.Neon
twinkle.Color = Config.Twinkle.Color
twinkle.Anchored, twinkle.CanCollide, twinkle.CanTouch, twinkle.CanQuery = true, false, false, false
twinkle.CastShadow = false
twinkle.Parent = world

local starGui = Instance.new("BillboardGui")
starGui.Name = "Star"
starGui.Size = UDim2.fromScale(Config.Twinkle.StarSize, Config.Twinkle.StarSize)
starGui.LightInfluence = 0
starGui.AlwaysOnTop = Config.Twinkle.AlwaysOnTop
starGui.Adornee = twinkle
starGui.Parent = twinkle
local starLabel = Instance.new("TextLabel")
starLabel.Size = UDim2.fromScale(1, 1)
starLabel.BackgroundTransparency = 1
starLabel.Text = "★"
starLabel.Font = Enum.Font.GothamBlack
starLabel.TextScaled = true
starLabel.TextColor3 = Config.Twinkle.Color
starLabel.Parent = starGui
local starStroke = Instance.new("UIStroke")
starStroke.Color = Theme.Colors.TrimDark
starStroke.Thickness = 2
starStroke.Parent = starLabel

local trailTop, trailBottom = Instance.new("Attachment"), Instance.new("Attachment")
trailTop.Position, trailBottom.Position = Vector3.new(0, 0.45, 0), Vector3.new(0, -0.45, 0)
trailTop.Parent, trailBottom.Parent = twinkle, twinkle
local trail = Instance.new("Trail")
trail.Attachment0, trail.Attachment1 = trailTop, trailBottom
trail.Lifetime = Config.Twinkle.TrailSeconds
trail.LightEmission = 1
trail.FaceCamera = true
trail.Color = ColorSequence.new(Config.Twinkle.Color)
trail.Transparency = NumberSequence.new(0.2, 1)
trail.Parent = twinkle
local light = Instance.new("PointLight")
light.Color = Config.Twinkle.Color
light.Range = Config.Twinkle.LightRange
light.Brightness = Config.Twinkle.LightBrightness
light.Parent = twinkle

local bubbleGui = Instance.new("BillboardGui")
bubbleGui.Name = "Speech"
bubbleGui.Size = UDim2.fromOffset(720, 140)
bubbleGui.StudsOffset = Vector3.new(0, Config.Bubble.Above, 0)
bubbleGui.SizeOffset = Vector2.new(0, 0.5) -- the bubble's bottom edge sits at the offset point, above Twinkle
bubbleGui.LightInfluence = 0
bubbleGui.AlwaysOnTop = Config.Bubble.AlwaysOnTop
bubbleGui.Adornee = twinkle
bubbleGui.Parent = twinkle
local worldBubble: Bubble? = nil

local arrowAnchor = Instance.new("Part")
arrowAnchor.Name = "ArrowAnchor"
arrowAnchor.Size = Vector3.new(0.1, 0.1, 0.1)
arrowAnchor.Transparency = 1
arrowAnchor.Anchored, arrowAnchor.CanCollide, arrowAnchor.CanTouch, arrowAnchor.CanQuery = true, false, false, false
arrowAnchor.Parent = world
local arrowGui = Instance.new("BillboardGui")
arrowGui.Name = "Arrow"
arrowGui.Size = UDim2.fromOffset(Config.Arrow.WorldSize, Config.Arrow.WorldSize)
arrowGui.LightInfluence = 0
arrowGui.AlwaysOnTop = Config.Twinkle.AlwaysOnTop
arrowGui.Adornee = arrowAnchor
arrowGui.Parent = arrowAnchor

local function arrowLabel(parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "ArrowGlyph"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "▼"
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Config.Arrow.Color
	label.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.IconLabelStroke
	stroke.Thickness = 3
	stroke.Parent = label
	return label
end
local worldArrow = arrowLabel(arrowGui)

local highlight = Instance.new("Highlight")
highlight.Name = "OnboardingGlow"
highlight.FillColor = Config.Arrow.Color
highlight.OutlineColor = Config.Arrow.Color
highlight.FillTransparency = Config.Glow.WorldFill.Max
highlight.OutlineTransparency = Config.Glow.WorldOutline
highlight.DepthMode = Enum.HighlightDepthMode.Occluded
highlight.Parent = world

---------------------------------------------------------------------------------------------------------------
-- The screen layer: arrow + glow on a HUD button, Twinkle on the screen with its bubble, the Skip button

local screen: ScreenGui
local screenGlow: Frame
local screenGlowStroke: UIStroke
local screenArrowHolder: Frame
local screenTwinkle: TextLabel
local screenBubbleHolder: Frame
local screenBubble: Bubble
local skipButton: Button.Button

local function buildScreen()
	screen = Instance.new("ScreenGui")
	screen.Name = "Onboarding"
	screen.ResetOnSpawn = false
	screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	screen.DisplayOrder = Theme.Layers.Popups + 1 -- over windows (step 3 points into the Inventory), under toasts / pop-ups
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = player:WaitForChild("PlayerGui")

	screenGlow = Instance.new("Frame")
	screenGlow.Name = "Glow"
	screenGlow.BackgroundTransparency = 1
	screenGlow.Visible = false
	screenGlow.Parent = screen
	Style.Corner(screenGlow, 14)
	screenGlowStroke = Style.Stroke(screenGlow, Config.Arrow.Color, Config.Glow.ScreenThickness, true)
	Style.Glow(screenGlow, Config.Arrow.Color, 16, 0.45, 0)

	screenArrowHolder = Instance.new("Frame")
	screenArrowHolder.Name = "Arrow"
	screenArrowHolder.BackgroundTransparency = 1
	screenArrowHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	screenArrowHolder.Visible = false
	screenArrowHolder.Parent = screen
	arrowLabel(screenArrowHolder)

	screenTwinkle = Instance.new("TextLabel")
	screenTwinkle.Name = "Twinkle"
	screenTwinkle.AnchorPoint = Vector2.new(0.5, 0.5)
	screenTwinkle.Size = UDim2.fromOffset(44, 44)
	screenTwinkle.BackgroundTransparency = 1
	screenTwinkle.Text = "★"
	screenTwinkle.Font = Enum.Font.GothamBlack
	screenTwinkle.TextScaled = true
	screenTwinkle.TextColor3 = Config.Twinkle.Color
	screenTwinkle.Visible = false
	screenTwinkle.Parent = screen
	local twinkleStroke = Instance.new("UIStroke") -- outlines the star glyph, not the box
	twinkleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	twinkleStroke.Color = Theme.Colors.TrimDark
	twinkleStroke.Thickness = 2
	twinkleStroke.Parent = screenTwinkle
	local halo = Instance.new("Frame") -- a soft round glow behind the star
	halo.Name = "Halo"
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromScale(0.5, 0.5)
	halo.Size = UDim2.fromScale(1.5, 1.5)
	halo.BackgroundColor3 = Config.Twinkle.Color
	halo.BackgroundTransparency = 0.55
	halo.ZIndex = 0
	halo.Parent = screenTwinkle
	Style.Corner(halo, 999)

	screenBubbleHolder = Instance.new("Frame")
	screenBubbleHolder.Name = "BubbleHolder"
	screenBubbleHolder.BackgroundTransparency = 1
	screenBubbleHolder.Size = UDim2.fromOffset(0, 0)
	screenBubbleHolder.Visible = false
	screenBubbleHolder.Parent = screen
	screenBubble = newBubble(screenBubbleHolder)

	-- Skip: a small button in the top-right corner, in the top bar row (clear of windows, the travel row and the timers)
	local corner = Instance.new("ScreenGui")
	corner.Name = "OnboardingSkip"
	corner.ResetOnSpawn = false
	corner.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets
	corner.DisplayOrder = Theme.Layers.Popups + 1
	corner.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	corner.Parent = screen.Parent
	screen.Destroying:Connect(function() corner:Destroy() end)
	local sure = false
	skipButton = Button.new(corner, { Text = Text.Onboarding.Skip, Kind = "Neutral", TextSize = 16, OnClick = function()
		if not sure then
			sure = true
			skipButton:SetText(Text.Onboarding.SkipSure)
			task.delay(Config.Skip.ConfirmSeconds, function()
				if sure then sure = false; skipButton:SetText(Text.Onboarding.Skip) end
			end)
			return
		end
		sure = false;
		(ReplicatedStorage.Remotes.SkipTutorial :: RemoteEvent):FireServer(true)
	end })
	skipButton.Instance.Name = "Skip"
	skipButton.Instance.AnchorPoint = Vector2.new(1, 0.5)
	skipButton.Instance.Position = UDim2.new(1, -Config.Skip.Margin, 0.5, 0)
	skipButton.Instance.Visible = false
end

-- Gamepad: the View/Select button jumps to the Skip button (then A presses it, twice).
local function bindGamepadSkip()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.ButtonSelect then return end
		if skipButton and skipButton.Instance.Visible then
			GuiService.SelectedObject = if GuiService.SelectedObject == skipButton.Instance then nil else skipButton.Instance
		end
	end)
end

---------------------------------------------------------------------------------------------------------------
-- What to show for the current step

type Plan = {
	Line: string?, -- nil = nothing to say
	Icon: string,
	WorldTarget: Instance?, -- Twinkle flies there, the arrow + glow go on it
	WorldSpot: Vector3?, -- where the action happens (the altar's Bind prompt): up close the arrow points here and Twinkle waits beside it
	GuiTarget: GuiObject?, -- arrow + glow on this HUD button
	ScreenTwinkle: boolean, -- Twinkle is on the screen next to GuiTarget (step 3)
}

local function bindLine(): string
	local input = UserInputService:GetLastInputType()
	if input.Name:find("Gamepad") then return Lines.BindGamepad end
	if input == Enum.UserInputType.Touch or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) then return Lines.BindTouch end
	return Lines.BindKeyboard
end

local function visibleTarget(id: string): GuiObject?
	local target = HudLayout.GetTutorialTarget(id)
	return if target and HudLayout.GetVisibleRect(target) then target else nil
end

local waitUntil, nightUntil = 0, 0
local bindPromptShown = false -- "Hold E at the altar!" only while the Bind prompt is really on screen

local function plan(step: number, root: BasePart?): Plan
	local now = os.clock()
	local none: Plan = { Line = nil, Icon = "", ScreenTwinkle = false }
	if step == Steps.Start or (step == Steps.Complete and now < nightUntil) then
		local altar, part = altarModel()
		if altar == nil or part == nil then return none end
		local near = bindPromptShown
		local line = if step == Steps.Complete and not near then Lines.NightNow elseif near then bindLine() else Lines.Follow
		return { Line = line, Icon = if step == Steps.Complete then Config.Icons.NightNow elseif near then Config.Icons.Bind else Config.Icons.Follow,
			WorldTarget = altar, WorldSpot = part.Position, ScreenTwinkle = false }
	elseif step == Steps.Home then
		return { Line = Lines.Home, Icon = Config.Icons.Home, WorldTarget = homePlot(), GuiTarget = visibleTarget("Home"), ScreenTwinkle = false }
	elseif step == Steps.Upgrade then
		if HudLayout.HasFocus() then
			return { Line = Lines.Upgrade, Icon = Config.Icons.Upgrade, GuiTarget = visibleTarget("DragonUpgrade"), ScreenTwinkle = true }
		end
		return { Line = Lines.OpenBag, Icon = Config.Icons.OpenBag, GuiTarget = visibleTarget("Inventory"), ScreenTwinkle = true }
	elseif step == Steps.Night and now < waitUntil then
		return { Line = Lines.Night, Icon = Config.Icons.Night, ScreenTwinkle = false }
	end
	return none
end

---------------------------------------------------------------------------------------------------------------
-- Drawing

local twinklePos: Vector3? = nil
local screenTwinklePos: Vector2? = nil

local function hideWorld()
	twinkle.Parent = nil
	arrowAnchor.Parent = nil
	highlight.Adornee = nil
	twinklePos = nil
end

local function hideScreen()
	screenGlow.Visible = false
	screenArrowHolder.Visible = false
	screenTwinkle.Visible = false
	screenBubbleHolder.Visible = false
	screenTwinklePos = nil
end

local function drawWorld(p: Plan, root: BasePart, dt: number)
	local target = p.WorldTarget
	local goal: Vector3
	local top = if target then topOf(target) else nil
	local still = reducedMotion()
	local bob = if still then 0 else math.sin(os.clock() * Config.Twinkle.BobSpeed) * Config.Twinkle.BobHeight
	if top and target then
		local aim = p.WorldSpot or top
		local flat = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
		local near = flat.Magnitude <= Config.Twinkle.NearDistance
		local camera = workspace.CurrentCamera
		if near and p.WorldSpot then
			-- up close: the arrow points down at the action spot; Twinkle waits at the player's side (camera right), so its
			-- bubble never covers the prompt or the travel row
			local right = if camera then camera.CFrame.RightVector else Vector3.xAxis
			goal = root.Position + Vector3.new(right.X, 0, right.Z).Unit * Config.Twinkle.SpotSide + Vector3.new(0, Config.Twinkle.SpotAbove, 0)
			arrowAnchor.Position = p.WorldSpot + Vector3.new(0, Config.Arrow.SpotAbove, 0)
		elseif near then
			goal = top + Vector3.new(0, Config.Twinkle.HoverAbove, 0) -- hover over the target
			arrowAnchor.Position = top + Vector3.new(0, Config.Arrow.WorldAbove, 0)
		else
			goal = root.Position + flat.Unit * Config.Twinkle.Ahead + Vector3.new(0, Config.Twinkle.Height, 0)
			arrowAnchor.Position = top + Vector3.new(0, Config.Arrow.WorldAbove, 0)
		end
		arrowGui.StudsOffset = Vector3.new(0, 0, 0)
		local bounce = if still then 0 else math.abs(math.sin(os.clock() * Config.Arrow.BounceSpeed)) * Config.Arrow.Bounce
		worldArrow.Position = UDim2.new(0.5, 0, 0.5, -bounce)
		arrowAnchor.Parent = world
		highlight.Adornee = target
		local fill = Config.Glow.WorldFill
		highlight.FillTransparency = if still then fill.Max else fill.Min + (fill.Max - fill.Min) * (0.5 + 0.5 * math.sin(os.clock() * Config.Glow.PulseSpeed))
	else
		-- nothing to point at (step 4): Twinkle floats beside the player
		local look = root.CFrame.LookVector
		goal = root.Position + Vector3.new(look.X, 0, look.Z).Unit * 6 + Vector3.new(0, Config.Twinkle.Height, 0)
		arrowAnchor.Parent = nil
		highlight.Adornee = nil
	end
	goal += Vector3.new(0, bob, 0)
	local current = twinklePos or (root.Position + Vector3.new(0, Config.Twinkle.Height, 0))
	twinklePos = current:Lerp(goal, 1 - math.exp(-dt * Config.Twinkle.FollowSpeed))
	twinkle.Position = twinklePos :: Vector3
	local low = EffectsQuality.IsLow()
	trail.Enabled = not low and not still
	light.Enabled = not low
	if worldBubble == nil then worldBubble = newBubble(bubbleGui) end
	(worldBubble :: Bubble):Set(p.Line or "", p.Icon)
	twinkle.Parent = world
end

local function drawScreenTarget(target: GuiObject?)
	if target == nil then
		screenGlow.Visible = false
		screenArrowHolder.Visible = false
		return
	end
	local still = reducedMotion()
	local pad = Config.Glow.ScreenPadding
	local base = screen.AbsolutePosition
	local pos, size = target.AbsolutePosition - base, target.AbsoluteSize
	screenGlow.Position = UDim2.fromOffset(pos.X - pad, pos.Y - pad)
	screenGlow.Size = UDim2.fromOffset(size.X + pad * 2, size.Y + pad * 2)
	screenGlowStroke.Transparency = if still then 0.1 else 0.1 + 0.3 * (0.5 + 0.5 * math.sin(os.clock() * Config.Glow.PulseSpeed))
	screenGlow.Visible = true
	-- the arrow points at the button from the side with the most room: from below for the top row (Home), else from the
	-- right when there is room for Twinkle's bubble there (the left menu column, most Upgrade buttons), else from the left
	local arrowSize = if HudLayout.IsPhone() then Config.Arrow.PhoneScreenSize else Config.Arrow.ScreenSize
	local bounce = if still then 0 else math.abs(math.sin(os.clock() * Config.Arrow.BounceSpeed)) * Config.Arrow.Bounce
	local center = pos + size / 2
	local roomRight = screen.AbsoluteSize.X - (pos.X + size.X)
	screenArrowHolder.Size = UDim2.fromOffset(arrowSize, arrowSize)
	if center.Y < screen.AbsoluteSize.Y * 0.2 then
		screenArrowHolder.Rotation = 180 -- points up, from below
		screenArrowHolder.Position = UDim2.fromOffset(center.X, pos.Y + size.Y + pad + arrowSize / 2 + bounce)
	elseif roomRight >= Config.Arrow.SideRoom then
		screenArrowHolder.Rotation = 90 -- points left, from the right side
		screenArrowHolder.Position = UDim2.fromOffset(pos.X + size.X + pad + arrowSize / 2 + bounce, center.Y)
	else
		screenArrowHolder.Rotation = -90 -- points right, from the left side
		screenArrowHolder.Position = UDim2.fromOffset(pos.X - pad - arrowSize / 2 - bounce, center.Y)
	end
	screenArrowHolder.Visible = true
end

-- Twinkle on the screen (step 3): sits past the arrow with its bubble; without a target, under the travel row.
local function drawScreenTwinkle(p: Plan, dt: number)
	local target = p.GuiTarget
	local base = screen.AbsolutePosition
	local safe = HudLayout.GetUsableRect()
	local goal: Vector2
	local anchor: Vector2
	if target then
		local pos, size = target.AbsolutePosition - base, target.AbsoluteSize
		local arrow = screenArrowHolder.AbsoluteSize
		if screenArrowHolder.Rotation == 90 then
			goal = Vector2.new(pos.X + size.X + Config.Glow.ScreenPadding + arrow.X + 34, pos.Y + size.Y / 2)
			anchor = Vector2.new(0, 0.5) -- bubble to the right of Twinkle
		elseif screenArrowHolder.Rotation == -90 then
			goal = Vector2.new(pos.X - Config.Glow.ScreenPadding - arrow.X - 34, pos.Y + size.Y / 2)
			anchor = Vector2.new(1, 0.5) -- bubble to the left of Twinkle
		else
			goal = Vector2.new(pos.X + size.X / 2, pos.Y + size.Y + Config.Glow.ScreenPadding + arrow.Y + 30)
			anchor = Vector2.new(0.5, 0) -- bubble under Twinkle
		end
	else
		goal = Vector2.new(safe.Min.X - base.X + safe.Width / 2, HudLayout.TopReserved() - base.Y + 30)
		anchor = Vector2.new(0.5, 0)
	end
	local current = screenTwinklePos or goal
	screenTwinklePos = current:Lerp(goal, 1 - math.exp(-dt * Config.Twinkle.FollowSpeed * 2))
	local at = screenTwinklePos :: Vector2
	local bob = if reducedMotion() then 0 else math.sin(os.clock() * Config.Twinkle.BobSpeed) * 4
	screenTwinkle.Position = UDim2.fromOffset(at.X, at.Y + bob)
	screenTwinkle.Visible = true
	screenBubble:Set(p.Line or "", p.Icon)
	local gap = Config.Bubble.Gap + 22
	local offset = if anchor.X == 0 then Vector2.new(gap, 0) elseif anchor.X == 1 then Vector2.new(-gap, 0) else Vector2.new(0, gap)
	-- keep the bubble on the screen
	local bubbleSize = screenBubble.Frame.AbsoluteSize
	local x = math.clamp(at.X + offset.X, safe.Min.X - base.X + bubbleSize.X * anchor.X + 8, safe.Max.X - base.X - bubbleSize.X * (1 - anchor.X) - 8)
	-- never cover the timers or the hotbar: if the bubble would, it goes above Twinkle instead (then, if still needed, up)
	local avoid: { Rect } = {}
	local stack = HudLayout.GetTimerStack()
	if stack.Visible and stack.AbsoluteSize.Y > 0 then
		table.insert(avoid, Rect.new(stack.AbsolutePosition - base, stack.AbsolutePosition - base + stack.AbsoluteSize))
	end
	local hotbar = player.PlayerGui:FindFirstChild("Hotbar")
	local bar = hotbar and hotbar:FindFirstChildWhichIsA("GuiObject")
	if hotbar and hotbar:IsA("ScreenGui") and hotbar.Enabled and bar and bar.Visible then
		table.insert(avoid, Rect.new(bar.AbsolutePosition - base, bar.AbsolutePosition - base + bar.AbsoluteSize))
	end
	local function hits(px: number, py: number, a: Vector2): Rect?
		local left, top = px - bubbleSize.X * a.X, py - bubbleSize.Y * a.Y
		for _, r in avoid do
			if left < r.Max.X and left + bubbleSize.X > r.Min.X and top < r.Max.Y and top + bubbleSize.Y > r.Min.Y then return r end
		end
		return nil
	end
	local y = at.Y + offset.Y
	if hits(x, y, anchor) then
		anchor = Vector2.new(0.5, 1)
		x = math.clamp(at.X, safe.Min.X - base.X + bubbleSize.X / 2 + 8, safe.Max.X - base.X - bubbleSize.X / 2 - 8)
		y = at.Y - gap
		local r = hits(x, y, anchor)
		if r then y = r.Min.Y - 8 end
	end
	screenBubbleHolder.Position = UDim2.fromOffset(x, y)
	screenBubble.Frame.AnchorPoint = anchor
	screenBubble.Frame.Position = UDim2.new()
	screenBubbleHolder.Visible = true
end

---------------------------------------------------------------------------------------------------------------
-- The falling star before the welcome bind's reveal (BindingController calls it inside its serialized reveal queue).
-- A small isolated altar viewport avoids exposing already-synced dragon names under the opaque RevealGate.

function controller.PlayFirstBind()
	local fall = Config.FallingStar
	local gui = Instance.new("ScreenGui")
	gui.Name = "FirstBindStar"
	gui:SetAttribute("RevealLayer", true)
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder = Theme.Layers.Notifications + fall.LayerOffset
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local ok, err = xpcall(function()
		local view = Instance.new("ViewportFrame")
		view.Size = UDim2.fromScale(1, 1)
		view.BackgroundColor3 = Theme.Colors.PanelBottom
		view.Ambient = Theme.Colors.Gold
		view.LightColor = Theme.Colors.Text
		view.Parent = gui
		local camera = Instance.new("Camera")
		camera.CFrame = CFrame.lookAt(fall.CameraPosition, Vector3.zero)
		camera.Parent = view
		view.CurrentCamera = camera
		local model = Instance.new("WorldModel")
		model.Parent = view
		local altar = altarModel()
		if altar and altar.Archivable then
			local clone = altar:Clone()
			if clone then
				for _, child in clone:GetDescendants() do
					if child:IsA("LuaSourceContainer") or child:IsA("ProximityPrompt") or child:IsA("LayerCollector") then child:Destroy() end
				end
				if clone:IsA("Model") then clone:PivotTo(CFrame.new()) elseif clone:IsA("BasePart") then clone.CFrame = CFrame.new() end
				clone.Parent = model
			end
		end
		local star = Instance.new("Part")
		star.Shape = Enum.PartType.Ball
		star.Size = fall.Size
		star.Anchored, star.CanCollide = true, false
		star.Material = Enum.Material.Neon
		star.Color = Theme.Colors.Gold
		local quick = EffectsQuality.IsLow() or reducedMotion() or player:GetAttribute("QuickBinds") == true
		star.Position = if quick then Vector3.zero else Vector3.yAxis * Config.StarFallHeight
		star.Parent = model
		local label = Style.Label(gui, Text.Onboarding.FallingStar, "Title", Theme.TextSizes.Title, Theme.Colors.Gold)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, fall.LabelY)
		label.Size = UDim2.fromScale(fall.LabelWidth, fall.LabelHeight)
		label.TextWrapped = true
		Style.Outline(label, 2)
		if quick then task.wait(Config.ReducedStarSeconds) else
			TweenService:Create(star, TweenInfo.new(Config.StarFallSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = Vector3.zero }):Play()
			task.wait(Config.StarFallSeconds)
		end
	end, debug.traceback)
	gui:Destroy()
	if not ok then warn(`[OnboardingController] Falling star failed: {err}`) end
end

---------------------------------------------------------------------------------------------------------------

function controller:Start()
	buildScreen()
	bindGamepadSkip()
	local ProximityPromptService = game:GetService("ProximityPromptService")
	ProximityPromptService.PromptShown:Connect(function(prompt)
		if prompt.Name == "BindPrompt" then bindPromptShown = true end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		if prompt.Name == "BindPrompt" then bindPromptShown = false end
	end)
	world.Parent = workspace
	hideWorld()
	hideScreen()

	-- the daylight Bind prompt shows only for a player who still has the welcome bind
	local watched: { [ProximityPrompt]: boolean } = {}
	local function updatePrompt(prompt: ProximityPrompt)
		local data = DataController:Get()
		local welcome = data ~= nil and data.OnboardingStep == Steps.Start and not data.OnboardingFirstBindUsed
		local enabled = Cycle.GetState().IsNight or welcome
		if prompt.Enabled ~= enabled then prompt.Enabled = enabled end
	end
	local previous = 0
	DataController:OnChanged("OnboardingStep", function(step)
		if type(step) ~= "number" then return end
		if step == Steps.Night and previous ~= Steps.Night then waitUntil = os.clock() + Config.WaitHintSeconds end
		if step == Steps.Complete and previous == Steps.Night then nightUntil = os.clock() + Config.NightHintSeconds end
		previous = step
		for prompt in watched do if prompt.Parent then updatePrompt(prompt) end end
	end)

	local lastBusy = os.clock()
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local data = DataController:Get()
		local step = if data then data.OnboardingStep else 0
		local active = step > 0 and (step < Steps.Complete or now < nightUntil)
		local skipSize = if HudLayout.IsPhone() then Config.Skip.PhoneSize else Config.Skip.Size
		local asking = skipButton.Label.Text == Text.Onboarding.SkipSure
		skipButton.Instance.Size = UDim2.fromOffset(if asking then skipSize.X * 1.8 else skipSize.X, skipSize.Y)

		-- keep the altar's daylight Bind prompt right for this player
		local _, altarPart = altarModel()
		local prompt = altarPart and altarPart:FindFirstChild("BindPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			if not watched[prompt] then
				watched[prompt] = true
				prompt:GetPropertyChangedSignal("Enabled"):Connect(function() updatePrompt(prompt) end)
				prompt.Destroying:Once(function() watched[prompt] = nil end)
			end
			updatePrompt(prompt)
		end

		local busy = RevealGate.IsActive() or player:GetAttribute("RewardPopupOpen") == true
			or player:GetAttribute("BindRevealActive") == true or player:GetAttribute("MerchantDialog") == true
		if busy then
			-- timed lines wait while something else has the screen
			waitUntil += now - lastBusy
			nightUntil += now - lastBusy
		end
		lastBusy = now
		skipButton.Instance.Visible = active and step < Steps.Complete and not busy
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		root = if root and root:IsA("BasePart") then root else nil
		if not active or busy or root == nil then
			hideWorld()
			hideScreen()
			return
		end
		local p = plan(step, root :: BasePart)
		if p.Line == nil then
			hideWorld()
			hideScreen()
			return
		end
		if p.ScreenTwinkle then
			hideWorld()
			drawScreenTarget(p.GuiTarget)
			drawScreenTwinkle(p, dt)
		else
			if HudLayout.HasFocus() then
				hideWorld() -- a window is open: the world guide waits
				hideScreen()
				return
			end
			screenTwinkle.Visible, screenBubbleHolder.Visible = false, false
			drawScreenTarget(p.GuiTarget)
			drawWorld(p, root :: BasePart, dt)
		end
	end)
end

return controller
