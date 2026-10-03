--!strict
-- Presentation only. Saved progress / tutorial rewards are always server-owned.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local EffectsQuality = require(script.Parent.EffectsQuality)
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
	for index = 1, (if EffectsQuality.IsLow() then Config.TrailLowCount else Config.TrailCount) do
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
		part.Position = hit.Position + Vector3.yAxis * Config.TrailGroundOffset
		part.Parent = trail
		-- A top-facing decal was hidden by grass and grazing camera angles. These bounded
		-- camera-facing stars need no asset preload and remain legible above the terrain.
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "GuideStarIcon"
		billboard.Adornee = part
		billboard.Size = UDim2.fromOffset(Theme.Onboarding.TrailPixels.X, Theme.Onboarding.TrailPixels.Y)
		billboard.AlwaysOnTop = true
		billboard.LightInfluence = 0
		billboard.MaxDistance = Config.TrailMaxDistance
		billboard.Parent = part
		local star = Style.Label(billboard, Text.Onboarding.TrailStar, "Heavy", Theme.Onboarding.TrailTextSize, Theme.Colors.Gold)
		star.Size = UDim2.fromScale(1, 1)
		star.TextScaled = true
		Style.Outline(star, Theme.Onboarding.TrailOutline)
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
		local reduced = EffectsQuality.IsLow() or player:GetAttribute("QuickBinds") == true
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
	local TutorialCard = require(script.Parent.UI.TutorialCard)
	local guide = TutorialCard.new(function()
		(ReplicatedStorage.Remotes.SkipTutorial :: RemoteEvent):FireServer(true)
	end)
	trail.Parent = workspace
	local previousStep, completedUntil = 0, 0
	local watched: { [ProximityPrompt]: RBXScriptConnection } = {}
	local function updatePrompt(prompt: ProximityPrompt)
		local data = DataController:Get()
		local first = data and data.OnboardingStep == Config.Steps.Start and not data.OnboardingFirstBindUsed
		local enabled = Cycle.GetState().IsNight or first == true
		if prompt.Enabled ~= enabled then prompt.Enabled = enabled end
	end
	DataController:OnChanged("OnboardingStep", function(step)
		if type(step) ~= "number" then return end
		if step > previousStep and previousStep > 0 then completedUntil = os.clock() + Theme.MobileUI.TutorialFeedbackSeconds end
		if step == Config.Steps.Complete and previousStep == Config.Steps.Night then nightUntil = os.clock() + Config.NightHintSeconds end
		previousStep = step
		for prompt in watched do if prompt.Parent then updatePrompt(prompt) end end
	end)
	local function freeUpgrade()
		local data = DataController:Get()
		if not data or data.OnboardingStep ~= Config.Steps.Upgrade or data.OnboardingFreeLevelUsed then return end
		local cap = DragonStats.GetLevelCap(data)
		local candidates = {}
		for id, dragon in data.Dragons do
			if dragon.Level < cap then table.insert(candidates, { Id = id, Dragon = dragon }) end
		end
		table.sort(candidates, function(a, b)
			local aSpecies, bSpecies = Dragons[a.Dragon.SpeciesId], Dragons[b.Dragon.SpeciesId]
			local aRare = aSpecies and aSpecies.Rarity == Config.MinimumRarity
			local bRare = bSpecies and bSpecies.Rarity == Config.MinimumRarity
			if aRare ~= bRare then return aRare == true end
			return a.Id < b.Id
		end)
		if candidates[1] then (ReplicatedStorage.Remotes.LevelUpDragon :: RemoteEvent):FireServer(candidates[1].Id, 1) end
	end
	local lastTrail, lastTick = -math.huge, os.clock()
	while guide.Gui.Parent do
		local now = os.clock()
		local busy = HudLayout.HasFocus() or RevealGate.IsActive() or player:GetAttribute("RewardPopupOpen") == true
		if busy and nightUntil > now then nightUntil += now - lastTick end
		lastTick = now
		local data = DataController:Get()
		local step = if data then data.OnboardingStep else 0
		local visible = step > 0 and (step < Config.Steps.Complete or now < nightUntil)
		local altar = altarPart()
		if altar then
			local prompt = altar:FindFirstChild("BindPrompt")
			if prompt and prompt:IsA("ProximityPrompt") then
				if not watched[prompt] then
					watched[prompt] = prompt:GetPropertyChangedSignal("Enabled"):Connect(function() updatePrompt(prompt) end)
					prompt.Destroying:Once(function()
						local connection = watched[prompt]
						if connection then connection:Disconnect(); watched[prompt] = nil end
					end)
				end
				updatePrompt(prompt)
			end
		end
		local targetPosition = if visible and (step == Config.Steps.Start or step == Config.Steps.Complete) then altar and altar.Position
			elseif visible and step == Config.Steps.Home then homePosition() else nil
		local guiTarget: GuiObject? = nil
		local actionText: string? = nil
		local action: (() -> ())? = nil
		local glyph = Text.Onboarding.Touch
		local inputType = UserInputService:GetLastInputType()
		if inputType.Name:find("Gamepad") then glyph = Text.Onboarding.ControllerBind
		elseif inputType == Enum.UserInputType.Keyboard or inputType.Name:find("Mouse") or not UserInputService.TouchEnabled then
			glyph = Text.Onboarding.KeyboardBind
		end
		if step == Config.Steps.Home then
			guiTarget = HudLayout.GetTutorialTarget("Home")
			actionText = Text.Onboarding.GoHome
			action = function() (ReplicatedStorage.Remotes.TravelTo :: RemoteEvent):FireServer("Home") end
		elseif step == Config.Steps.Upgrade then
			guiTarget = if HudLayout.HasFocus() then HudLayout.GetTutorialTarget("DragonUpgrade") else guide.ActionButton
			actionText = Text.Onboarding.FreeUpgrade
			action = freeUpgrade
		elseif step == Config.Steps.Night then glyph = Text.Onboarding.Wait end
		local instruction = Text.Onboarding.Steps[step] or ""
		if (step == Config.Steps.Start or step == Config.Steps.Home or step == Config.Steps.Complete) and targetPosition == nil then
			instruction = Text.Onboarding.TargetUnavailable
		end
		guide:Present({
			Number = math.max(1, step), Total = Config.Steps.Complete,
			Title = Text.Onboarding.Titles[step] or "", Instruction = instruction,
			Icon = Text.Onboarding.Icons[step] or "Stardust", Visible = visible,
			ActionText = actionText, Action = action, Glyph = glyph, GuiTarget = guiTarget,
			WorldTarget = if altar and (step == Config.Steps.Start or step == Config.Steps.Complete) then
				(if altar.Parent and altar.Parent:IsA("Model") then altar.Parent else altar) else nil,
			WorldPosition = targetPosition, Complete = now < completedUntil,
		})
		if now - lastTrail >= Config.PollSeconds or busy or not visible then
			drawTrail(if busy then nil else targetPosition)
			lastTrail = now
		end
		task.wait(Theme.MobileUI.TutorialRefresh)
	end
	for _, connection in watched do connection:Disconnect() end
	trail:Destroy()
	guide:Destroy()
end

return controller
