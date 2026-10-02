--!strict
-- Presentation only. Saved progress / tutorial rewards are always server-owned.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Button = require(script.Parent.UI.Button)
local RevealGate = require(script.Parent.UI.RevealGate)
local Config = require(ReplicatedStorage.Shared.Config.Onboarding)
local Theme = require(ReplicatedStorage.Shared.Config.UITheme)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local Ceremony = require(ReplicatedStorage.Shared.Config.Ceremony)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local player = Players.LocalPlayer
local controller = {}
local trail = Instance.new("Folder")
trail.Name = "LocalOnboardingTrail"
local nightUntil = 0

local function altarPart(): BasePart?
	for _, altar in CollectionService:GetTagged("StarAltar") do
		if (altar:GetAttribute("AreaId") or Config.StarterArea) == Config.StarterArea then
			return (if altar:IsA("BasePart") then altar elseif altar:IsA("Model") then altar.PrimaryPart or altar:FindFirstChildWhichIsA("BasePart", true) else nil) :: BasePart?
		end
	end
	return nil
end

local function homePosition(): Vector3?
	for _, plot in CollectionService:GetTagged("RoostPlot") do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot:GetPivot().Position
		end
	end
	return nil
end

local function drawTrail(target: Vector3?)
	trail:ClearAllChildren()
	if target == nil or RevealGate.IsActive() then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then return end
	local delta = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
	if delta.Magnitude < Config.TrailStartDistance then return end
	local filter = RaycastParams.new()
	filter.FilterType = Enum.RaycastFilterType.Exclude
	filter.FilterDescendantsInstances = { character :: Model, trail }
	for index = 1, Config.TrailCount do
		local distance = Config.TrailStartDistance + (index - 1) * Config.TrailSpacing
		if distance > delta.Magnitude then break end
		local point = root.Position + delta.Unit * distance
		local hit = workspace:Raycast(point + Vector3.yAxis * Config.RayHeight, -Vector3.yAxis * Config.RayDepth, filter)
		if hit == nil then continue end
		local part = Instance.new("Part")
		part.Name = "GuideStar"
		part.Size = Theme.Onboarding.TrailSize
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
		part.Material = Enum.Material.Neon
		part.Transparency = 1
		part.Color = Theme.Colors.Gold
		part.CFrame = CFrame.new(hit.Position + Vector3.yAxis * Config.TrailGroundOffset) * CFrame.Angles(0, math.pi / 4, 0)
		part.Parent = trail
		local surface = Instance.new("SurfaceGui")
		surface.Face = Enum.NormalId.Top
		surface.CanvasSize = Theme.Onboarding.TrailPixels
		surface.LightInfluence = 0
		surface.Parent = part
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Image = Ceremony.Burst.SparkleImage
		image.ImageColor3 = Theme.Colors.Gold
		image.Size = UDim2.fromScale(1, 1)
		image.Parent = surface
	end
end

-- Called by BindingController's serialized BindResult flow, before its unchanged ceremony.
-- A small isolated altar viewport avoids exposing already-synced dragon names under the opaque RevealGate.
function controller.PlayFirstBind()
	local screen = Instance.new("ScreenGui")
	screen.Name = "FirstBindStar"
	screen:SetAttribute("RevealLayer", true)
	screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	screen.DisplayOrder = Theme.Layers.Notifications + Theme.Onboarding.RevealLayerOffset
	screen.ResetOnSpawn = false
	screen.Parent = player:WaitForChild("PlayerGui")
	local ok, err = xpcall(function()
		local view = Instance.new("ViewportFrame")
		view.Size = UDim2.fromScale(1, 1)
		view.BackgroundColor3 = Theme.Colors.PanelBottom
		view.Ambient = Theme.Colors.Gold
		view.LightColor = Theme.Colors.Text
		view.Parent = screen
		local camera = Instance.new("Camera")
		camera.CFrame = CFrame.lookAt(Theme.Onboarding.StarCameraPosition, Vector3.zero)
		camera.Parent = view
		view.CurrentCamera = camera
		local model = Instance.new("WorldModel")
		model.Parent = view
		local part = altarPart()
		local source = part and (if part.Parent and part.Parent:IsA("Model") then part.Parent else part)
		if source and source.Archivable then
			local clone = source:Clone()
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
		star.Size = Theme.Onboarding.FallingStarSize
		star.Anchored, star.CanCollide = true, false
		star.Material = Enum.Material.Neon
		star.Color = Theme.Colors.Gold
		local reduced = player:GetAttribute("ReducedMotion") == true or player:GetAttribute("QuickBinds") == true
		star.Position = if reduced then Vector3.zero else Vector3.yAxis * Config.StarFallHeight
		star.Parent = model
		local label = Style.Label(screen, Text.Onboarding.FallingStar, "Title", Theme.TextSizes.Title, Theme.Colors.Gold)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, Theme.Onboarding.StarLabelY)
		label.Size = UDim2.fromScale(Theme.Onboarding.HintWidth, Theme.Onboarding.StarLabelHeight)
		label.TextWrapped = true
		if reduced then task.wait(Config.ReducedStarSeconds) else
			TweenService:Create(star, TweenInfo.new(Config.StarFallSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = Vector3.zero }):Play()
			task.wait(Config.StarFallSeconds)
		end
	end, debug.traceback)
	screen:Destroy()
	if not ok then warn(`[OnboardingController] Falling star failed: {err}`) end
end

function controller:Start()
	local screen = HudLayout.MakeScreenGui("Onboarding", "Cards")
	local rootFrame = Instance.new("Frame")
	rootFrame.Size = UDim2.fromScale(1, 1)
	rootFrame.BackgroundTransparency = 1
	rootFrame.Parent = screen
	local panel = Instance.new("Frame")
	panel.BackgroundColor3 = Theme.Colors.PanelBottom
	panel.BorderSizePixel = 0
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Parent = rootFrame
	Style.Corner(panel, Theme.SmallCorner)
	Style.Stroke(panel, Theme.Colors.Gold, Theme.Onboarding.BorderThickness)
	local label = Style.Label(panel, "", "Body", Theme.Onboarding.HintTextSize, Theme.Colors.Text)
	label.TextWrapped = true
	label.Position = UDim2.fromOffset(Theme.Onboarding.Padding, Theme.Onboarding.Padding)
	label.Size = UDim2.new(1, -Theme.Onboarding.Padding * 2, 0, Theme.Onboarding.HintLineHeight)
	local skip = Button.new(panel, { Text = Text.Onboarding.Skip, Kind = "Neutral", OnClick = function()
		(ReplicatedStorage.Remotes.SkipTutorial :: RemoteEvent):FireServer(true)
	end })
	skip.Instance.AnchorPoint = Vector2.new(0.5, 1)
	skip.Instance.Position = UDim2.new(0.5, 0, 1, -Theme.Onboarding.Padding)
	skip.Instance.Size = Theme.Onboarding.SkipSize
	local free = Button.new(panel, { Text = Text.Onboarding.FreeUpgrade, Kind = "Primary", OnClick = function()
		local data = DataController:Get()
		if data == nil or data.OnboardingStep ~= Config.Steps.Upgrade then return end
		local chosen: string? = nil
		local cap = DragonStats.GetLevelCap(data)
		for id, dragon in data.Dragons do
			if dragon.Level >= cap then continue end
			chosen = chosen or id
			if Dragons[dragon.SpeciesId] and Dragons[dragon.SpeciesId].Rarity == Config.MinimumRarity then chosen = id; break end
		end
		if chosen then (ReplicatedStorage.Remotes.LevelUpDragon :: RemoteEvent):FireServer(chosen, 1) end
	end })
	free.Instance.AnchorPoint = Vector2.new(0.5, 1)
	free.Instance.Size = Theme.Onboarding.SkipSize
	free.Instance.Position = UDim2.new(0.25, 0, 1, -Theme.Onboarding.Padding)
	local pointer = Style.Label(rootFrame, Text.Onboarding.Pointer, "Title", Theme.Onboarding.PointerSize, Theme.Colors.Gold)
	pointer.Size = Theme.Onboarding.PointerBounds
	pointer.AnchorPoint = Vector2.new(0.5, 0.5)
	pointer.Visible = false
	trail.Parent = workspace
	local previousStep = 0
	local watched: { [ProximityPrompt]: RBXScriptConnection } = {}
	local function updatePrompt(prompt: ProximityPrompt)
		local data = DataController:Get()
		local first = data and data.OnboardingStep == Config.Steps.Start and not data.OnboardingFirstBindUsed
		local enabled = Cycle.GetState().IsNight or first == true
		if prompt.Enabled ~= enabled then prompt.Enabled = enabled end
	end
	DataController:OnChanged("OnboardingStep", function(step)
		if step == Config.Steps.Complete and previousStep == Config.Steps.Night then
			nightUntil = os.clock() + Config.NightHintSeconds
		end
		previousStep = step
		for prompt in watched do updatePrompt(prompt) end
	end)
	while true do
		local data = DataController:Get()
		local step = if data then data.OnboardingStep else 0
		local visible = step > 0 and (step < Config.Steps.Complete or os.clock() < nightUntil)
		panel.Visible = visible
		free.Instance.Visible = visible and step == Config.Steps.Upgrade
		skip.Instance.Position = UDim2.new(if free.Instance.Visible then 0.75 else 0.5, 0, 1, -Theme.Onboarding.Padding)
		local bounds = HudLayout.GetUsableRect()
		local size = Theme.Onboarding.PanelSize
		local width = math.min(size.X, bounds.Width * Theme.Onboarding.HintWidth)
		panel.Size = UDim2.fromOffset(width, size.Y)
		local top = math.clamp(math.max(bounds.Min.Y, HudLayout.TopReserved()) + Theme.Onboarding.Padding, bounds.Min.Y, math.max(bounds.Min.Y, bounds.Max.Y - size.Y))
		panel.Position = UDim2.fromOffset(bounds.Min.X + bounds.Width / 2 - rootFrame.AbsolutePosition.X, top - rootFrame.AbsolutePosition.Y)
		local actionWidth = if free.Instance.Visible then math.min(Theme.Onboarding.ActionWidth, width / 2 - Theme.Onboarding.Padding * 1.5) else math.min(Theme.Onboarding.ActionWidth, width - Theme.Onboarding.Padding * 2)
		skip.Instance.Size = UDim2.fromOffset(actionWidth, Theme.Onboarding.ActionHeight)
		free.Instance.Size = skip.Instance.Size
		label.Text = Text.Onboarding.Steps[step] or ""
		pointer.Visible = false
		if visible and step == Config.Steps.Upgrade then
			local button = HudLayout.GetMenuButton("Inventory")
			if button and button.Visible then
				pointer.Visible = true
				local point = button.AbsolutePosition + Vector2.new(button.AbsoluteSize.X / 2, -Theme.Onboarding.PointerOffset)
				pointer.Position = UDim2.fromOffset(math.clamp(point.X, bounds.Min.X + pointer.AbsoluteSize.X / 2, bounds.Max.X - pointer.AbsoluteSize.X / 2) - rootFrame.AbsolutePosition.X, math.clamp(point.Y, bounds.Min.Y + pointer.AbsoluteSize.Y / 2, bounds.Max.Y - pointer.AbsoluteSize.Y / 2) - rootFrame.AbsolutePosition.Y)
			end
		end
		local altar = altarPart()
		if altar then
			local prompt = altar:FindFirstChild("BindPrompt")
			if prompt and prompt:IsA("ProximityPrompt") then
				if watched[prompt] == nil then
					watched[prompt] = prompt:GetPropertyChangedSignal("Enabled"):Connect(function() updatePrompt(prompt) end)
					prompt.Destroying:Connect(function() watched[prompt]:Disconnect(); watched[prompt] = nil end)
				end
				updatePrompt(prompt)
			end
		end
		local target = if visible and (step == Config.Steps.Start or step == Config.Steps.Complete) then (altar and altar.Position)
			elseif visible and step == Config.Steps.Home then homePosition() else nil
		drawTrail(target)
		task.wait(Config.PollSeconds)
	end
end

return controller
