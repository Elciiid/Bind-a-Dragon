--!strict
-- Presentation of a server-confirmed bind. A private viewport keeps the dragon readable and spoilers hidden
-- without taking over the player's camera. Skip, respawn, camera replacement and errors all share one cleanup.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local AltarGlowController = require(script.Parent.AltarGlowController)
local DragonRig = require(script.Parent.DragonRig)
local EffectsQuality = require(script.Parent.EffectsQuality)
local Style = require(script.Parent.UI.Style)
local Button = require(script.Parent.UI.Button)
local Icon = require(script.Parent.UI.Icon)
local Ceremony = require(ReplicatedStorage.Shared.Config.Ceremony)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Elements = require(ReplicatedStorage.Shared.Config.Elements)
local Mutations = require(ReplicatedStorage.Shared.Config.Mutations)
local RigConfig = require(ReplicatedStorage.Shared.Config.DragonRigs)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local Text = require(ReplicatedStorage.Shared.Config.Text)

export type Request = {
	SpeciesId: string, MutationId: string, BaseOneIn: number, EffectiveOneIn: number,
	OnReveal: (() -> ())?,
}

local CeremonyController = {}
local playing = false
local lastInput = os.clock()

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Only a disposable clone is sanitized. World/Studio-only models, scripts and assets are never edited.
local function sanitize(model: Model)
	for _, item in model:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("ProximityPrompt") or item:IsA("Sound")
			or item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Trail")
			or item:IsA("BillboardGui") or item:IsA("SurfaceGui") or item:IsA("Highlight") or item:IsA("Light") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = true, false, false, false
		end
	end
end

local function cloneDragon(id: string): (Model?, string)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local dragons = assets and assets:FindFirstChild("Dragons")
	if not dragons then return nil, "" end
	local art = dragons:FindFirstChild(id)
	local stageId = Ceremony.Viewport.StageFallbacks[1]
	local template: Model? = nil
	if art and art:IsA("Model") then
		template = art
	elseif art then
		for _, stage in Ceremony.Viewport.StageFallbacks do
			local found = art:FindFirstChild(stage)
			if found and found:IsA("Model") then template, stageId = found, stage; break end
		end
	end
	local placeholder = template == nil
	if placeholder then
		local fallback = dragons:FindFirstChild("Placeholder")
		if fallback and fallback:IsA("Model") then template = fallback end
	end
	if not template then return nil, stageId end
	local model = template:Clone()
	if not model then return nil, stageId end -- an unarchivable Studio-only asset may not clone
	local ok = pcall(function()
		sanitize(model)
		model:PivotTo(CFrame.identity)
		local size = model:GetExtentsSize()
		local longest = math.max(size.X, size.Y, size.Z)
		assert(longest > 0 and longest < math.huge, "Invalid reveal model bounds")
		model:ScaleTo(model:GetScale() * Ceremony.Viewport.DragonLength / longest)
		if placeholder then
			local species = Dragons[id]
			local element = species and Elements[species.Element]
			local primary = if element then element.Color else UITheme.Colors.Text
			local colors = { Primary = primary, Secondary = Style.Shade(primary, -0.45), Accent = Style.Shade(primary, 0.6) }
			for _, part in model:GetDescendants() do
				local key = part:GetAttribute("Tint")
				if part:IsA("BasePart") and type(key) == "string" and (colors :: any)[key] then part.Color = (colors :: any)[key] end
			end
		end
	end)
	-- This clone has not yet entered the main cleanup list; catch preparation errors locally to avoid an orphan.
	if not ok then model:Destroy(); return nil, stageId end
	return model, stageId
end

local function cloneAltar(altar: Instance?): Model?
	if not altar then return nil end
	-- Only the imported art branch, not scripts/glow boards/the entire streamed surroundings.
	local source = altar:FindFirstChild("Mesh") or altar:FindFirstChild("Art")
	if source == nil or not (source:IsA("Model") or source:IsA("BasePart")) then return nil end
	local parts = 0
	for _, item in source:GetDescendants() do if item:IsA("BasePart") then parts += 1 end end
	if source:IsA("BasePart") then parts += 1 end
	if parts > Ceremony.Viewport.AltarMaxParts then return nil end
	local model = Instance.new("Model")
	local clone = source:Clone()
	if not clone then model:Destroy(); return nil end
	local ok = pcall(function()
		clone.Parent = model
		sanitize(model)
		model:PivotTo(CFrame.identity)
		local _, size = model:GetBoundingBox()
		local longest = math.max(size.X, size.Y, size.Z)
		assert(longest > 0 and longest < math.huge, "Invalid altar bounds")
		model:ScaleTo(Ceremony.Viewport.AltarLength / longest)
		-- Imported art may have a world-position pivot; center the display clone by its bounding box instead.
		local box = model:GetBoundingBox()
		model:PivotTo(CFrame.new(-box.Position.X, -box.Position.Y + Ceremony.Viewport.AltarHeight, -box.Position.Z) * model:GetPivot())
	end)
	if not ok then model:Destroy(); clone:Destroy(); return nil end
	return model
end

function CeremonyController.IsIdle(): boolean
	return os.clock() - lastInput > Ceremony.IdleSeconds
end

function CeremonyController.IsPlaying(): boolean
	return playing
end

function CeremonyController.Play(request: Request, onDone: () -> ()): boolean
	local player = Players.LocalPlayer
	local species = Dragons[request.SpeciesId]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if playing or not species or not root or not root:IsA("BasePart") then
		if request.OnReveal then request.OnReveal() end
		onDone()
		return false
	end
	local altar = AltarGlowController.GetNearestAltar(root.Position, Ceremony.AltarRange)
	if not altar then
		if request.OnReveal then request.OnReveal() end
		onDone()
		return false
	end
	playing = true
	local overlay: ScreenGui? = nil
	local alive, skipped, revealed = true, false, false
	local connections: { RBXScriptConnection } = {}
	local sounds: { Sound } = {}
	local tweens: { Tween } = {}
	local clones: { Model } = {} -- includes hidden/unparented art during anticipation; cleanup cannot leak it
	local function reveal()
		if revealed then return end
		revealed = true
		if request.OnReveal then request.OnReveal() end
	end
	local function interrupted(): boolean
		return skipped or not alive or player.Character ~= character
			or player:GetAttribute("ReducedMotion") == true
	end
	local function phase(seconds: number, update: ((number) -> ())?)
		local started = os.clock()
		repeat
			if interrupted() then return end
			local t = math.clamp((os.clock() - started) / math.max(seconds, 0.001), 0, 1)
			if update then update(t) end
			if t >= 1 then return end
			RunService.RenderStepped:Wait()
		until false
	end
	local function sound(id: string?)
		if id == nil or id == "" or interrupted() then return end
		local instance = Instance.new("Sound")
		instance.SoundId = id
		local setting = player:GetAttribute("SoundVolume")
		instance.Volume = Ceremony.Sounds.Volume * (if type(setting) == "number" then math.clamp(setting, 0, 1) else 1)
		instance.Parent = SoundService
		table.insert(sounds, instance)
		instance:Play()
		task.delay(Ceremony.Sounds.CleanupSeconds, function() if instance.Parent then instance:Destroy() end end)
	end

	local ok, err = xpcall(function()
		if player:GetAttribute("ReducedMotion") == true then
			-- No workspace/viewport camera movement or animated effects. The result card is the complete fallback.
			task.wait(Ceremony.ReducedHoldSeconds)
			reveal()
			return
		end
		local profile = (Ceremony.Profiles :: any)[species.Rarity] or Ceremony.Profiles.Common
		local mutation = Mutations.Get(request.MutationId)
		if mutation.Id == "Primordial" or request.EffectiveOneIn >= Ceremony.PrestigeOneIn then profile = Ceremony.Profiles.Prestige end
		if player:GetAttribute("QuickBinds") == true then profile = Ceremony.Profiles.Quick end
		local low = EffectsQuality.IsLow()
		local rarity = UITheme.Rarity[species.Rarity]
		local color = if mutation.Id ~= Mutations.NormalId then mutation.Color elseif rarity then rarity.Color else UITheme.Colors.Gold
		local presentation = Ceremony.Presentation
		local viewportConfig = Ceremony.Viewport
		local newOverlay = Instance.new("ScreenGui")
		newOverlay.Name = "CeremonyOverlay"
		newOverlay:SetAttribute("RevealLayer", true)
		newOverlay.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		newOverlay.DisplayOrder = UITheme.Layers.Notifications + 5
		newOverlay.ResetOnSpawn = false
		newOverlay.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		newOverlay.Parent = player:WaitForChild("PlayerGui")
		overlay = newOverlay
		local canvas = Instance.new("Frame")
		canvas.Size = UDim2.fromScale(1, 1)
		canvas.BorderSizePixel = 0
		canvas.BackgroundColor3 = UITheme.Colors.PanelBottom
		canvas.Parent = newOverlay
		Style.Gradient(canvas, UITheme.Colors.GlassBottom, UITheme.Colors.PanelBottom)

		local label = Style.Label(canvas, Text.Reveal.Anticipation, "Title", UITheme.MobileUI.Title, UITheme.Colors.Text)
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.new(0.5, 0, 0, presentation.LabelTop)
		label.Size = UDim2.new(1, -UITheme.MobileUI.Padding * 2, 0, presentation.LabelHeight)
		label.ZIndex = 4
		local skip = Button.new(canvas, { Text = Text.Reveal.Skip, Kind = "Neutral", TextSize = UITheme.MobileUI.Body })
		skip.Instance.Size = UDim2.fromOffset(Ceremony.SkipButtonSize.X, Ceremony.SkipButtonSize.Y)
		skip.Instance.AnchorPoint = Vector2.new(1, 1)
		skip.Instance.Position = UDim2.new(1, -UITheme.MobileUI.Padding, 1, -Ceremony.SkipBottomMargin)
		skip.Instance.ZIndex = 5
		if UserInputService:GetLastInputType().Name:find("Gamepad") then GuiService.SelectedObject = skip.Instance end
		table.insert(connections, skip.Instance.Activated:Connect(function() skipped = true end))
		table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
			-- Movement, arbitrary taps and gamepad navigation do not accidentally dismiss a reveal.
			if input.KeyCode == Enum.KeyCode.ButtonB or (not processed and (input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Escape)) then skipped = true end
		end))
		table.insert(connections, player.CharacterRemoving:Connect(function() skipped = true end))
		table.insert(connections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() skipped = true end))
		table.insert(connections, newOverlay.AncestryChanged:Connect(function(_, parent) if not parent then skipped = true end end))

		local portal = Instance.new("ImageLabel")
		portal.Name = "StarlightPortal"
		portal.BackgroundTransparency = 1
		portal.Image = Ceremony.Burst.RingImage
		portal.ImageColor3 = color
		portal.ImageTransparency = presentation.PortalTransparency
		portal.AnchorPoint = Vector2.new(0.5, 0.5)
		portal.Position = UDim2.fromScale(0.5, presentation.PortalY)
		portal.Size = UDim2.fromScale(presentation.PortalWidthFraction, presentation.PortalHeightFraction)
		portal.ZIndex = 1
		portal.Parent = canvas

		local view = Instance.new("ViewportFrame")
		view.Name = "ConfirmedDragonStage"
		view.BackgroundTransparency = 1
		view.AnchorPoint = Vector2.new(0.5, 0.5)
		view.Position = UDim2.fromScale(0.5, presentation.StageY)
		view.Size = UDim2.fromScale(presentation.WidthFraction, presentation.HeightFraction)
		view.Ambient, view.LightColor, view.LightDirection = viewportConfig.Ambient, viewportConfig.Light, viewportConfig.LightDirection
		view.ZIndex = 2
		view.Parent = canvas
		local world = Instance.new("WorldModel")
		world.Parent = view
		local camera = Instance.new("Camera")
		camera.FieldOfView = viewportConfig.FieldOfView
		camera.Parent = view
		view.CurrentCamera = camera
		local altarClone = cloneAltar(altar)
		if altarClone then table.insert(clones, altarClone); altarClone.Parent = world end
		local model, stageId = cloneDragon(request.SpeciesId)
		local pose: DragonRig.Pose = {
			Air = 0, Flap = 0, Gait = 0, Walk = 0, Clock = 0, Rest = 0, Hover = 0,
			Turn = 0, Pitch = 0, LookYaw = 0, LookPitch = 0, Action = nil, ActionT = 0, Seed = 0,
		}
		local modelBase = CFrame.identity
		local rig: DragonRig.Rig? = nil
		local target = Vector3.zero
		local points: { Vector3 } = {}
		if model then
			table.insert(clones, model)
			model.Parent = world
			local box = model:GetBoundingBox()
			modelBase = CFrame.new(-box.Position) * model:GetPivot()
			model:PivotTo(modelBase)
			target = Vector3.zero
			local config = RigConfig.Rigs[request.SpeciesId .. "/" .. stageId]
			if config then rig = DragonRig.Build(model, config) end
			if rig then DragonRig.Apply(rig, pose, if low then "Simple" else "Full") end
			local posedBox, size = model:GetBoundingBox()
			for sx = -1, 1, 2 do
				for sy = -1, 1, 2 do
					for sz = -1, 1, 2 do
						table.insert(points, posedBox:PointToWorldSpace(Vector3.new(size.X * sx / 2, size.Y * sy / 2, size.Z * sz / 2)))
					end
				end
			end
			model.Parent = nil -- do not expose art during anticipation
		end
		local function frame(t: number)
			local ratio = view.AbsoluteSize.X / math.max(view.AbsoluteSize.Y, 1)
			local look = -viewportConfig.Direction
			local right = look:Cross(Vector3.yAxis).Unit
			local up = right:Cross(look).Unit
			local tangent = math.tan(math.rad(camera.FieldOfView / 2))
			local fitted = viewportConfig.DragonLength
			for _, point in points do
				local horizontal = math.abs(point:Dot(right)) / (tangent * math.max(ratio, 0.1))
				local vertical = math.abs(point:Dot(up)) / tangent
				fitted = math.max(fitted, math.max(horizontal, vertical) * viewportConfig.FitMargin + point:Dot(viewportConfig.Direction))
			end
			camera.CFrame = CFrame.lookAt(target + viewportConfig.Direction * fitted * (1 + viewportConfig.DollyFraction * (1 - smooth(t))), target)
		end
		frame(0)
		phase(profile.Anticipation)
		if interrupted() then return end
		label.Text = Text.Reveal.Gathering
		sound(Ceremony.Sounds.Pull)
		local stars: { ImageLabel } = {}
		local count = if low then math.min(profile.Stars, presentation.LowStars) else profile.Stars
		for index = 1, count do
			local star = Instance.new("ImageLabel")
			star.BackgroundTransparency = 1
			star.Image = Ceremony.Burst.SparkleImage
			star.ImageColor3 = UITheme.Colors.Sparkle
			star.Size = UDim2.fromOffset(presentation.StarSize, presentation.StarSize)
			star.AnchorPoint = Vector2.new(0.5, 0.5)
			star.ZIndex = 3
			star.Parent = canvas
			table.insert(stars, star)
		end
		phase(profile.Gather, function(t)
			frame(t)
			for index, star in stars do
				local angle = index / count * math.pi * 2
				local delay = (index - 1) / count * presentation.StarStaggerFraction
				local u = smooth((t - delay) / (1 - presentation.StarStaggerFraction))
				local x = math.cos(angle) * presentation.StarRadiusFraction
				local y = math.sin(angle) * presentation.StarRadiusFraction
				star.Position = UDim2.fromScale(0.5 + x * (1 - u), presentation.PortalY * u + (presentation.StageY + y) * (1 - u))
				star.ImageTransparency = u
			end
		end)
		for _, star in stars do star:Destroy() end
		if interrupted() then return end
		label.Text = Text.Reveal.Arriving
		if model then
			model.Parent = world
			model:PivotTo(CFrame.new(0, -viewportConfig.EntranceHeight, 0) * modelBase)
			view.ImageColor3 = UITheme.Colors.TextStroke -- silhouette has no name, rarity or identifying result labels
		end
		phase(profile.Silhouette)
		if interrupted() then return end
		reveal()
		view.ImageColor3 = Color3.new(1, 1, 1)
		sound((Ceremony.Sounds :: any)[species.Rarity])
		if not low then
			local burst = TweenService:Create(portal, TweenInfo.new(presentation.BurstSeconds), {
				Size = UDim2.fromScale(presentation.PortalWidthFraction * presentation.BurstSizeMultiplier, presentation.PortalHeightFraction * presentation.BurstSizeMultiplier),
				ImageTransparency = 1,
			})
			portal.ImageTransparency = presentation.BurstTransparency
			table.insert(tweens, burst)
			burst:Play()
		end
		label.Text = species.Name
		label.TextColor3 = color
		if not model then
			local fallback = Icon.new(canvas, "Rarity_" .. species.Rarity, color)
			fallback.AnchorPoint = Vector2.new(0.5, 0.5)
			fallback.Position = UDim2.fromScale(0.5, presentation.StageY)
			fallback.Size = UDim2.fromOffset(UITheme.Sizes.RewardIcon, UITheme.Sizes.RewardIcon)
			fallback.ZIndex = 4
			-- The complete result follows regardless of missing art. Keep this short header readable on a phone;
			-- appending a fallback explanation to the name can create a clipped third line.
			label.Text = species.Name
		end
		local function entrance(t: number)
			if not model then return end
			model:PivotTo(CFrame.new(0, -viewportConfig.EntranceHeight * (1 - smooth(t)), 0) * modelBase)
			if rig then DragonRig.Apply(rig, pose, if low then "Simple" else "Full") end
		end
		phase(profile.Entrance, entrance)
		if interrupted() then return end
		phase(profile.Hold, function(t)
			if rig and not low then
				pose.Clock = t * profile.Hold
				pose.Action = viewportConfig.PoseAction
				pose.ActionT = math.clamp(t * profile.Hold / viewportConfig.PoseSeconds, 0, 1)
				DragonRig.Apply(rig, pose, "Full")
			end
		end)
	end, debug.traceback)

	-- No workspace camera, player controls or Lighting state has been overwritten, so no restoration race exists.
	alive = false
	for _, connection in connections do connection:Disconnect() end
	for _, tween in tweens do tween:Cancel() end
	for _, instance in sounds do instance:Destroy() end
	for _, clone in clones do clone:Destroy() end
	if overlay then
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(overlay) then GuiService.SelectedObject = nil end
		overlay:Destroy()
	end
	playing = false
	if not ok then warn("[CeremonyController] Reveal fallback: " .. tostring(err)) end
	reveal()
	onDone()
	return true
end

function CeremonyController:Init()
	UserInputService.InputBegan:Connect(function() lastInput = os.clock() end)
	UserInputService.InputChanged:Connect(function() lastInput = os.clock() end)
end

return CeremonyController
