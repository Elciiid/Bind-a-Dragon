--!strict
-- First-time flow, presentation only (settings Config/Onboarding, wording Text.Onboarding.Lines). Saved progress, the
-- welcome bind and the free level are server-owned (OnboardingService); this never advances a step or grants anything.
--
-- KISS: Twinkle, a little glowing guide star (client-only: a neon star with a short trail), flies ahead of the player to
-- the next target and says ONE short line: floating screen text with no box (Style.ShadowText: title font, thick outline,
-- soft shadow, one big icon), placed next to Twinkle on the first spot that covers nothing: not the target's glow, the
-- arrow or the HUD (travel row, menu, money, timers, hotbar, luck panel). The real target gets a big bouncing arrow and a
-- soft glow outline: the altar (step 1; at the Bind spot the line sits above the altar), your sanctuary + the Home button
-- (step 2), the Inventory button and then the Upgrade button (step 3: Twinkle moves onto the screen and stays inside the
-- window). Step 4 says "Bind again tonight!" for a few seconds, then Twinkle naps until night (step 5 points at the altar).
-- A small Skip text button sits in the top-right corner (two taps). Everything hides while a reveal / reward pop-up / the
-- merchant dialog is up; a window hides the world guide. Low effects: no trail, no light. Reduced Motion: no bob/bounce.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local EffectsQuality = require(script.Parent.EffectsQuality)
local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Icon = require(script.Parent.UI.Icon)
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

type Bubble = {
	Frame: Frame, Icon: GuiObject?, IconKey: string, Label: TextLabel,
	Set: (Bubble, string, string) -> (),
	Wrap: (Bubble, number?) -> (), -- wrap the line at this many pixels (nil = one line)
	NaturalWidth: (Bubble) -> number, -- the line's width on one line, icon included
}

local function newBubble(parent: Instance): Bubble
	local phone = HudLayout.IsPhone()
	local bubbleConfig = Config.Bubble
	-- no box: the icon and the line in a row, floating text with a thick outline and a soft shadow (Style.ShadowText)
	local frame = Instance.new("Frame")
	frame.Name = "Bubble"
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.fromScale(0.5, 1)
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.Size = UDim2.new()
	frame.Parent = parent
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame
	local size = math.max(16, if phone then bubbleConfig.PhoneTextSize else bubbleConfig.TextSize)
	local textHolder, label = Style.ShadowText(frame, "", size, Theme.Colors.Text)
	textHolder.LayoutOrder = 2
	label.Name = "Line"
	local bubble: Bubble
	bubble = {
		Frame = frame, Icon = nil, IconKey = "", Label = label,
		Set = function(self: Bubble, text: string, iconKey: string)
			if self.Label.Text ~= text then self.Label.Text = text end
			-- the layout can switch (phone / PC) after the guide is built: pick the size each time
			local now = HudLayout.IsPhone()
			local wanted = math.max(16, if now then bubbleConfig.PhoneTextSize else bubbleConfig.TextSize)
			if self.Label.TextSize ~= wanted then self.Label.TextSize = wanted end
			if now ~= phone then
				phone = now
				self.IconKey = "" -- rebuild the icon at the new size
			end
			if self.IconKey ~= iconKey then
				self.IconKey = iconKey
				if self.Icon then self.Icon:Destroy() end
				local side = math.floor(bubbleConfig.IconSize * (if phone then 0.75 else 1))
				local icon = Icon.new(self.Frame, iconKey, Theme.Colors.Gold)
				icon.Size = UDim2.fromOffset(side, side)
				icon.LayoutOrder = 1
				self.Icon = icon
			end
		end,
		Wrap = function(self: Bubble, width: number?)
			local label = self.Label
			if width then
				-- AutomaticSize doesn't grow a wrapped label inside auto-sized parents: measure the wrapped height here
				local w = math.max(120, math.floor(width))
				local h = TextService:GetTextSize(label.Text, label.TextSize, label.Font, Vector2.new(w, 1000)).Y
				label.TextWrapped = true
				label.AutomaticSize = Enum.AutomaticSize.None
				label.Size = UDim2.fromOffset(w, h + 4)
			elseif label.TextWrapped then
				label.TextWrapped = false
				label.AutomaticSize = Enum.AutomaticSize.XY
				label.Size = UDim2.new()
			end
		end,
		NaturalWidth = function(self: Bubble): number
			local label = self.Label
			local text = TextService:GetTextSize(label.Text, label.TextSize, label.Font, Vector2.new(4000, 400)).X
			return text + (if self.Icon then self.Icon.AbsoluteSize.X + 10 else 0) + 8
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
local skipButton: TextButton
local skipLabel: TextLabel

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
	-- a small text button (floating text, no box) with a full touch-sized hit area; two taps
	skipButton = Instance.new("TextButton")
	skipButton.Name = "Skip"
	skipButton.Text = ""
	skipButton.BackgroundTransparency = 1
	skipButton.AnchorPoint = Vector2.new(1, 0.5)
	skipButton.Position = UDim2.new(1, -Config.Skip.Margin, 0.5, 0)
	skipButton.Visible = false
	skipButton.Parent = corner
	local skipText
	skipText, skipLabel = Style.ShadowText(skipButton, Text.Onboarding.Skip, Config.Skip.TextSize, Theme.Colors.Text)
	skipText.AnchorPoint = Vector2.new(1, 0.5)
	skipText.Position = UDim2.fromScale(1, 0.5)
	Style.AttachPress(skipButton)
	local sure = false
	skipButton.Activated:Connect(function()
		if not sure then
			sure = true
			skipLabel.Text = Text.Onboarding.SkipSure
			skipLabel.TextColor3 = Theme.Colors.Gold
			task.delay(Config.Skip.ConfirmSeconds, function()
				if sure then
					sure = false
					skipLabel.Text = Text.Onboarding.Skip
					skipLabel.TextColor3 = Theme.Colors.Text
				end
			end)
			return
		end
		sure = false;
		(ReplicatedStorage.Remotes.SkipTutorial :: RemoteEvent):FireServer(true)
	end)
end

-- Gamepad: the View/Select button jumps to the Skip button (then A presses it, twice).
local function bindGamepadSkip()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.ButtonSelect then return end
		if skipButton and skipButton.Visible then
			GuiService.SelectedObject = if GuiService.SelectedObject == skipButton then nil else skipButton
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
	AtSpot: boolean?, -- the player is at the action spot (the Bind prompt shows): the line goes above the target
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
			WorldTarget = altar, WorldSpot = part.Position, AtSpot = near, ScreenTwinkle = false }
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
-- Drawing. Twinkle's line is always screen text, placed next to Twinkle (or above the altar at the Bind spot) on the first
-- spot that keeps clear of the target's glow, the arrow and the HUD (travel row, menu, money, timers, hotbar, luck panel,
-- Skip); inside a window it stays inside the window.

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

local function rectOf(gui: GuiObject): Rect
	local base = screen.AbsolutePosition
	return Rect.new(gui.AbsolutePosition - base, gui.AbsolutePosition - base + gui.AbsoluteSize)
end

local function overlaps(a: Rect, b: Rect): boolean
	return a.Min.X < b.Max.X and a.Max.X > b.Min.X and a.Min.Y < b.Max.Y and a.Max.Y > b.Min.Y
end

-- The HUD pieces the line must never cover.
local function hudRects(): { Rect }
	local rects: { Rect } = {}
	local gui = player.PlayerGui
	local function add(path: { string })
		local node: Instance? = gui
		for _, name in path do
			node = if node then node:FindFirstChild(name) else nil
		end
		if node and node:IsA("GuiObject") and node.Visible and node.AbsoluteSize.X > 0 then
			local layer = node:FindFirstAncestorWhichIsA("ScreenGui")
			if layer == nil or layer.Enabled then
				table.insert(rects, rectOf(node))
			end
		end
	end
	add({ "TravelHud", "TravelRow" })
	add({ "Hud", "Menu" })
	add({ "Hud", "Currency" })
	add({ "Hotbar", "Hotbar" })
	add({ "Luck", "LuckPanel" })
	local stack = HudLayout.GetTimerStack()
	if stack.Visible and stack.AbsoluteSize.Y > 0 then
		table.insert(rects, rectOf(stack))
	end
	if skipButton.Visible then
		table.insert(rects, rectOf(skipButton))
	end
	return rects
end

-- A world target's outline on the screen (its 8 bounding-box corners, clipped to the screen), or nil if it's behind the
-- camera.
local function screenBox(target: Instance?): Rect?
	local camera = workspace.CurrentCamera
	if target == nil or camera == nil then
		return nil
	end
	local cf: CFrame, size: Vector3
	if target:IsA("Model") then
		cf, size = target:GetBoundingBox()
	elseif target:IsA("BasePart") then
		cf, size = target.CFrame, target.Size
	else
		return nil
	end
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	local base = screen.AbsolutePosition
	for x = -1, 1, 2 do
		for y = -1, 1, 2 do
			for z = -1, 1, 2 do
				local point = camera:WorldToViewportPoint(cf:PointToWorldSpace(size * Vector3.new(x, y, z) / 2))
				if point.Z > 0 then
					local at = HudLayout.ViewportToGui(Vector2.new(point.X, point.Y)) - base
					minX, minY = math.min(minX, at.X), math.min(minY, at.Y)
					maxX, maxY = math.max(maxX, at.X), math.max(maxY, at.Y)
				end
			end
		end
	end
	if minX == math.huge then
		return nil
	end
	local view = screen.AbsoluteSize
	return Rect.new(math.max(minX, 0), math.max(minY, 0), math.min(maxX, view.X), math.min(maxY, view.Y))
end

local function worldToScreen(position: Vector3): Vector2?
	local camera = workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local point = camera:WorldToViewportPoint(position)
	if point.Z <= 0 then
		return nil
	end
	return HudLayout.ViewportToGui(Vector2.new(point.X, point.Y)) - screen.AbsolutePosition
end

type Spot = { At: Vector2, Anchor: Vector2 }

-- Places the line at the first candidate spot inside `bound` that covers nothing in `avoid`; else the first one, clamped.
local function placeLine(candidates: { Spot }, bound: Rect, avoid: { Rect }): Rect
	local size = screenBubble.Frame.AbsoluteSize
	local margin = 8
	local function rectAt(spot: Spot): Rect
		local x = math.clamp(spot.At.X - size.X * spot.Anchor.X, bound.Min.X + margin, math.max(bound.Min.X + margin, bound.Max.X - size.X - margin))
		local y = math.clamp(spot.At.Y - size.Y * spot.Anchor.Y, bound.Min.Y + margin, math.max(bound.Min.Y + margin, bound.Max.Y - size.Y - margin))
		return Rect.new(x, y, x + size.X, y + size.Y)
	end
	local chosen: Rect? = nil
	for _, spot in candidates do
		local r = rectAt(spot)
		local clear = true
		for _, a in avoid do
			if overlaps(r, a) then
				clear = false
				break
			end
		end
		if clear then
			chosen = r
			break
		end
	end
	local r = chosen or rectAt(candidates[1])
	screenBubbleHolder.Position = UDim2.fromOffset(r.Min.X, r.Min.Y)
	screenBubble.Frame.AnchorPoint = Vector2.zero
	screenBubble.Frame.Position = UDim2.new()
	screenBubbleHolder.Visible = true
	return r
end

local function aroundPoint(p: Vector2, gap: number): { Spot }
	return {
		{ At = p - Vector2.new(0, gap), Anchor = Vector2.new(0.5, 1) }, -- above
		{ At = p + Vector2.new(gap, 0), Anchor = Vector2.new(0, 0.5) }, -- right
		{ At = p - Vector2.new(gap, 0), Anchor = Vector2.new(1, 0.5) }, -- left
		{ At = p + Vector2.new(0, gap), Anchor = Vector2.new(0.5, 0) }, -- below
	}
end

local function aroundBox(box: Rect, gap: number): { Spot }
	local c = (box.Min + box.Max) / 2
	return {
		{ At = Vector2.new(c.X, box.Min.Y - gap), Anchor = Vector2.new(0.5, 1) }, -- above
		{ At = Vector2.new(box.Max.X + gap, c.Y), Anchor = Vector2.new(0, 0.5) }, -- right
		{ At = Vector2.new(box.Min.X - gap, c.Y), Anchor = Vector2.new(1, 0.5) }, -- left
		{ At = Vector2.new(c.X, box.Max.Y + gap), Anchor = Vector2.new(0.5, 0) }, -- below
		{ At = Vector2.new(box.Min.X + (box.Max.X - box.Min.X) * 0.2, box.Max.Y + gap), Anchor = Vector2.new(0.5, 0) }, -- below, left
		{ At = Vector2.new(box.Min.X + (box.Max.X - box.Min.X) * 0.8, box.Max.Y + gap), Anchor = Vector2.new(0.5, 0) }, -- below, right
	}
end

-- The area the line may use: the safe area under the travel row.
local function screenBound(): Rect
	local safe = HudLayout.GetUsableRect()
	local base = screen.AbsolutePosition
	return Rect.new(safe.Min.X - base.X, math.max(safe.Min.Y, HudLayout.TravelBottom()) - base.Y, safe.Max.X - base.X, safe.Max.Y - base.Y)
end

local function moveScreenTwinkle(goal: Vector2, dt: number)
	local current = screenTwinklePos or goal
	screenTwinklePos = current:Lerp(goal, 1 - math.exp(-dt * Config.Twinkle.FollowSpeed * 2))
	local at = screenTwinklePos :: Vector2
	local bob = if reducedMotion() then 0 else math.sin(os.clock() * Config.Twinkle.BobSpeed) * 4
	screenTwinkle.Position = UDim2.fromOffset(at.X, at.Y + bob)
	screenTwinkle.Visible = true
end

-- Twinkle on the screen beside the line: left of it, else right of it, else above it (whichever covers nothing).
local function placeScreenTwinkle(line: Rect, dt: number, avoid: { Rect })
	local cy = (line.Min.Y + line.Max.Y) / 2
	local spots = { Vector2.new(line.Min.X - 30, cy), Vector2.new(line.Max.X + 30, cy), Vector2.new((line.Min.X + line.Max.X) / 2, line.Min.Y - 30) }
	local goal = spots[1]
	for _, spot in spots do
		local r = Rect.new(spot - Vector2.new(26, 26), spot + Vector2.new(26, 26))
		local clear = spot.X > 26 and spot.X < screen.AbsoluteSize.X - 26
		for _, a in avoid do
			if overlaps(r, a) then
				clear = false
				break
			end
		end
		if clear then
			goal = spot
			break
		end
	end
	moveScreenTwinkle(goal, dt)
end

local function moveWorldTwinkle(goal: Vector3, root: BasePart, dt: number)
	local still = reducedMotion()
	local bob = if still then 0 else math.sin(os.clock() * Config.Twinkle.BobSpeed) * Config.Twinkle.BobHeight
	local current = twinklePos or (root.Position + Vector3.new(0, Config.Twinkle.Height, 0))
	twinklePos = current:Lerp(goal + Vector3.new(0, bob, 0), 1 - math.exp(-dt * Config.Twinkle.FollowSpeed))
	twinkle.Position = twinklePos :: Vector3
	local low = EffectsQuality.IsLow()
	trail.Enabled = not low and not still
	light.Enabled = not low
	twinkle.Parent = world
end

-- Steps with a world target (or none): Twinkle flies in the world; at the altar's Bind spot it hops onto the screen next
-- to the line, which sits above the altar (clear of its art and glow).
local function drawWorld(p: Plan, root: BasePart, dt: number, extraAvoid: { Rect })
	local target = p.WorldTarget
	local top = if target then topOf(target) else nil
	local still = reducedMotion()
	screenBubble:Set(p.Line or "", p.Icon)
	screenBubble:Wrap(nil)
	local avoid = hudRects()
	for _, r in extraAvoid do
		table.insert(avoid, r)
	end
	local box = screenBox(target)
	if box then
		table.insert(avoid, box)
	end
	local body = screenBox(root.Parent) -- never on the player's own character
	if body then
		table.insert(avoid, body)
	end
	if p.WorldSpot and p.AtSpot then
		-- the Bind prompt shows at the spot: keep its card clear (UITheme prompt size around that point)
		local spot = worldToScreen(p.WorldSpot)
		if spot then
			local half = Vector2.new(Theme.MobileUI.PromptWidth / 2 + 10, Theme.MobileUI.PromptHeight + 10)
			table.insert(avoid, Rect.new(spot - half, spot + half))
		end
	end
	if top and target then
		local aim = p.WorldSpot or top
		local flat = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
		local atSpot = p.WorldSpot ~= nil and p.AtSpot == true
		arrowAnchor.Position = if atSpot then (p.WorldSpot :: Vector3) + Vector3.new(0, Config.Arrow.SpotAbove, 0) else top + Vector3.new(0, Config.Arrow.WorldAbove, 0)
		local bounce = if still then 0 else math.abs(math.sin(os.clock() * Config.Arrow.BounceSpeed)) * Config.Arrow.Bounce
		worldArrow.Position = UDim2.new(0.5, 0, 0.5, -bounce)
		arrowAnchor.Parent = world
		highlight.Adornee = target
		local fill = Config.Glow.WorldFill
		highlight.FillTransparency = if still then fill.Max else fill.Min + (fill.Max - fill.Min) * (0.5 + 0.5 * math.sin(os.clock() * Config.Glow.PulseSpeed))
		local arrowAt = worldToScreen(arrowAnchor.Position)
		if arrowAt then
			local half = Config.Arrow.WorldSize / 2
			table.insert(avoid, Rect.new(arrowAt - Vector2.new(half, half + Config.Arrow.Bounce), arrowAt + Vector2.new(half, half)))
		end
		if atSpot and box then
			twinkle.Parent = nil
			twinklePos = nil
			local line = placeLine(aroundBox(box, Config.Bubble.Gap), screenBound(), avoid)
			placeScreenTwinkle(line, dt, avoid)
			return
		end
		local near = flat.Magnitude <= Config.Twinkle.NearDistance
		local goal = if near then top + Vector3.new(0, Config.Twinkle.HoverAbove, 0)
			else root.Position + flat.Unit * Config.Twinkle.Ahead + Vector3.new(0, Config.Twinkle.Height, 0)
		moveWorldTwinkle(goal, root, dt)
	else
		-- nothing to point at (step 4): Twinkle floats beside the player
		arrowAnchor.Parent = nil
		highlight.Adornee = nil
		local look = root.CFrame.LookVector
		moveWorldTwinkle(root.Position + Vector3.new(look.X, 0, look.Z).Unit * 6 + Vector3.new(0, Config.Twinkle.Height, 0), root, dt)
	end
	screenTwinkle.Visible = false
	screenTwinklePos = nil
	local at = worldToScreen(twinkle.Position)
	local bound = screenBound()
	local candidates = if at then aroundPoint(at, Config.Bubble.Gap + 24) else {}
	table.insert(candidates, { At = Vector2.new((bound.Min.X + bound.Max.X) / 2, bound.Min.Y + 12), Anchor = Vector2.new(0.5, 0) })
	placeLine(candidates, bound, avoid)
end

-- The arrow + glow on a HUD button. `bound` = where the arrow may go (the window it's in, else the screen).
local function drawScreenTarget(target: GuiObject?, bound: Rect): Rect?
	if target == nil then
		screenGlow.Visible = false
		screenArrowHolder.Visible = false
		return nil
	end
	local still = reducedMotion()
	local pad = Config.Glow.ScreenPadding
	local r = rectOf(target)
	local pos, size = r.Min, r.Max - r.Min
	screenGlow.Position = UDim2.fromOffset(pos.X - pad, pos.Y - pad)
	screenGlow.Size = UDim2.fromOffset(size.X + pad * 2, size.Y + pad * 2)
	screenGlowStroke.Transparency = if still then 0.1 else 0.1 + 0.3 * (0.5 + 0.5 * math.sin(os.clock() * Config.Glow.PulseSpeed))
	screenGlow.Visible = true
	-- the arrow points at the button from the side with the most room: from below for the top row (Home), else from the
	-- right when there is room for Twinkle's line there (the left menu column, most Upgrade buttons), else from the left
	local arrowSize = if HudLayout.IsPhone() then Config.Arrow.PhoneScreenSize else Config.Arrow.ScreenSize
	local bounce = if still then 0 else math.abs(math.sin(os.clock() * Config.Arrow.BounceSpeed)) * Config.Arrow.Bounce
	local center = pos + size / 2
	local reach = pad + arrowSize + Config.Arrow.Bounce
	screenArrowHolder.Size = UDim2.fromOffset(arrowSize, arrowSize)
	local arrowRect: Rect
	if center.Y < screen.AbsoluteSize.Y * 0.2 then
		screenArrowHolder.Rotation = 180 -- points up, from below
		screenArrowHolder.Position = UDim2.fromOffset(center.X, pos.Y + size.Y + pad + arrowSize / 2 + bounce)
		arrowRect = Rect.new(center.X - arrowSize / 2, pos.Y + size.Y, center.X + arrowSize / 2, pos.Y + size.Y + reach)
	elseif bound.Max.X - (pos.X + size.X) >= Config.Arrow.SideRoom then
		screenArrowHolder.Rotation = 90 -- points left, from the right side
		screenArrowHolder.Position = UDim2.fromOffset(pos.X + size.X + pad + arrowSize / 2 + bounce, center.Y)
		arrowRect = Rect.new(pos.X + size.X, center.Y - arrowSize / 2, pos.X + size.X + reach, center.Y + arrowSize / 2)
	else
		screenArrowHolder.Rotation = -90 -- points right, from the left side
		screenArrowHolder.Position = UDim2.fromOffset(pos.X - pad - arrowSize / 2 - bounce, center.Y)
		arrowRect = Rect.new(pos.X - reach, center.Y - arrowSize / 2, pos.X, center.Y + arrowSize / 2)
	end
	screenArrowHolder.Visible = true
	return arrowRect
end

-- Right after the window opens (Config.Bubble.ScrollSeconds): keep the list scrolled so the whole card around the target
-- (e.g. the dragon card with Free!) shows. After that the player's own scrolling wins.
local scrollUntil = 0
local scrollTarget: GuiObject? = nil
local function scrollCardIntoView(target: GuiObject)
	if scrollTarget ~= target then
		scrollTarget = target
		scrollUntil = os.clock() + Config.Bubble.ScrollSeconds
	end
	if os.clock() > scrollUntil then
		return
	end
	local card = target:FindFirstAncestor("Card")
	local list = target:FindFirstAncestorWhichIsA("ScrollingFrame")
	if card == nil or not card:IsA("GuiObject") or list == nil then
		return
	end
	local pad = Config.Bubble.Gap
	local top, bottom = card.AbsolutePosition.Y, card.AbsolutePosition.Y + card.AbsoluteSize.Y
	local viewTop, viewBottom = list.AbsolutePosition.Y, list.AbsolutePosition.Y + list.AbsoluteSize.Y
	local delta = 0
	if bottom + pad > viewBottom then
		delta = bottom + pad - viewBottom
	end
	if top - delta - pad < viewTop then
		delta = top - pad - viewTop
	end
	if math.abs(delta) >= 1 then
		list.CanvasPosition = Vector2.new(list.CanvasPosition.X, math.max(0, list.CanvasPosition.Y + delta))
	end
end

-- Twinkle on the screen (step 3): past the arrow, with the line beside it; inside the window when the target is in one.
local function drawScreenTwinkle(p: Plan, dt: number)
	screenBubble:Set(p.Line or "", p.Icon)
	local target = p.GuiTarget
	local window = if target then target:FindFirstAncestor("Window") else nil
	local bound = if window and window:IsA("GuiObject") then rectOf(window) else screenBound()
	if window then
		-- stay well inside the window (clear of its gold border, banner and close button)
		local inset = Config.Bubble.WindowInset
		bound = Rect.new(bound.Min + Vector2.new(inset, inset + Config.Bubble.WindowTop), bound.Max - Vector2.new(inset, inset))
	end
	local avoid = if window then {} else hudRects()
	if window and target then
		scrollCardIntoView(target)
		local card = target:FindFirstAncestor("Card")
		if card and card:IsA("GuiObject") then
			table.insert(avoid, rectOf(card)) -- the line never covers the card it points into
		end
	elseif not window then
		scrollTarget = nil
	end
	local arrowRect = drawScreenTarget(target, bound)
	if target and arrowRect then
		table.insert(avoid, rectOf(target))
		table.insert(avoid, arrowRect)
		-- Twinkle sits just past the arrow; the line goes beside Twinkle
		local tip: Vector2
		if screenArrowHolder.Rotation == 90 then
			tip = Vector2.new(arrowRect.Max.X + 26, (arrowRect.Min.Y + arrowRect.Max.Y) / 2)
		elseif screenArrowHolder.Rotation == -90 then
			tip = Vector2.new(arrowRect.Min.X - 26, (arrowRect.Min.Y + arrowRect.Max.Y) / 2)
		else
			tip = Vector2.new((arrowRect.Min.X + arrowRect.Max.X) / 2, arrowRect.Max.Y + 26)
		end
		tip = Vector2.new(math.clamp(tip.X, bound.Min.X + 24, bound.Max.X - 24), math.clamp(tip.Y, bound.Min.Y + 24, bound.Max.Y - 24))
		table.insert(avoid, Rect.new(tip - Vector2.new(24, 24), tip + Vector2.new(24, 24)))
		moveScreenTwinkle(tip, dt)
		local gap = Config.Bubble.Gap + 22
		local iconWidth = if screenBubble.Icon then screenBubble.Icon.AbsoluteSize.X + 10 else 0
		local candidates: { Spot } = {}
		local card = target:FindFirstAncestor("Card")
		if window and card and card:IsA("GuiObject") then
			-- inside a window: the line goes in the free column beside the card (above Twinkle, else below), wrapped to fit it
			local c = rectOf(card)
			local left = c.Min.X - bound.Min.X >= bound.Max.X - c.Max.X
			local colMin = if left then bound.Min.X + 8 else c.Max.X + Config.Bubble.Gap
			local colMax = if left then c.Min.X - Config.Bubble.Gap else bound.Max.X - 8
			local width = colMax - colMin
			screenBubble:Wrap(if screenBubble:NaturalWidth() > width then width - iconWidth else nil)
			local mid = (colMin + colMax) / 2
			table.insert(candidates, { At = Vector2.new(mid, tip.Y - 34), Anchor = Vector2.new(0.5, 1) })
			table.insert(candidates, { At = Vector2.new(mid, tip.Y + 34), Anchor = Vector2.new(0.5, 0) })
		else
			screenBubble:Wrap(nil)
			table.insert(candidates, if screenArrowHolder.Rotation == 90 then { At = tip + Vector2.new(gap, 0), Anchor = Vector2.new(0, 0.5) }
				elseif screenArrowHolder.Rotation == -90 then { At = tip - Vector2.new(gap, 0), Anchor = Vector2.new(1, 0.5) }
				else { At = tip + Vector2.new(0, gap), Anchor = Vector2.new(0.5, 0) })
		end
		for _, spot in aroundPoint(tip, gap) do
			table.insert(candidates, spot)
		end
		placeLine(candidates, bound, avoid)
	else
		screenBubble:Wrap(nil)
		local line = placeLine({ { At = Vector2.new((bound.Min.X + bound.Max.X) / 2, bound.Min.Y + 12), Anchor = Vector2.new(0.5, 0) } }, bound, avoid)
		placeScreenTwinkle(line, dt, avoid)
	end
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
		-- the hit area: the text's width (at least a touch target) x a touch-sized height
		local skipSize = if HudLayout.IsPhone() then Config.Skip.PhoneSize else Config.Skip.Size
		skipButton.Size = UDim2.fromOffset(math.max(skipSize.X, skipLabel.TextBounds.X + 16), skipSize.Y)

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
		skipButton.Visible = active and step < Steps.Complete and not busy
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
			drawScreenTwinkle(p, dt)
		else
			if HudLayout.HasFocus() then
				hideWorld() -- a window is open: the world guide waits
				hideScreen()
				return
			end
			-- the Home button's arrow + glow (step 2) are kept clear by the line too
			local extra: { Rect } = {}
			local arrowRect = drawScreenTarget(p.GuiTarget, screenBound())
			if p.GuiTarget and arrowRect then
				table.insert(extra, arrowRect)
				table.insert(extra, rectOf(p.GuiTarget))
			end
			drawWorld(p, root :: BasePart, dt, extra)
		end
	end)
end

return controller
