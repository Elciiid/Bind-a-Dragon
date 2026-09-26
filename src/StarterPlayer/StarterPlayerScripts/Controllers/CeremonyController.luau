--!strict
-- The binding ceremony, on the binder's client after the server's result (BindingController decides when it plays).
-- Full: the camera eases toward the altar, tonight's stars streak down into the main crystal, a burst in the rarity
-- color (particles, a ring, a flash of light), and the new dragon rises over the altar with its name and rarity.
-- Big (Legendary/Mythic/Starborn): a bigger burst, a second ring, a sky flash and a longer hold.
-- Quick ("Quick binds" setting, never for big ones): only the burst and the reveal, about a second.
-- Any key, click or tap skips it. Visual only: the dragon is already the player's. Settings: Config/Ceremony.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local AltarGlowController = require(script.Parent.AltarGlowController)
local SkyController = require(script.Parent.SkyController)
local EffectsQuality = require(script.Parent.EffectsQuality)
local Style = require(script.Parent.UI.Style)
local Ceremony = require(ReplicatedStorage.Shared.Config.Ceremony)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Elements = require(ReplicatedStorage.Shared.Config.Elements)
local Evolution = require(ReplicatedStorage.Shared.Config.Evolution)
local IndexConfig = require(ReplicatedStorage.Shared.Config.Index)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

export type Request = { SpeciesId: string, Starborn: boolean }

local CeremonyController = {}

local playing = false
local lastInput = os.clock()

local function ease(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function rarityOf(id: string): { Id: string, Name: string, Color: Color3 }?
	for _, rarity in Rarities do
		if rarity.Id == id then
			return rarity
		end
	end
	return nil
end

local function playSound(id: string?)
	if id == nil or id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	local volume = Players.LocalPlayer:GetAttribute("SoundVolume")
	sound.Volume = Ceremony.Sounds.Volume * (if type(volume) == "number" then volume else 1)
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
	task.delay(10, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

-- The dragon model a new bind shows (Hatchling art, else the species model, else the tinted placeholder).
local function dragonModel(speciesId: string, starborn: boolean): Model?
	local species = Dragons[speciesId]
	local folder = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Dragons")
	if species == nil or folder == nil then
		return nil
	end
	local stage = Evolution.Stages[1]
	local template: Instance? = nil
	local isPlaceholder = false
	local art = folder:FindFirstChild(speciesId)
	if art then
		template = art:FindFirstChild(stage.Id) or (if art:IsA("Model") then art else nil)
	end
	if template == nil then
		template = folder:FindFirstChild("Placeholder")
		isPlaceholder = true
	end
	if template == nil or not template:IsA("Model") then
		return nil
	end
	local model = template:Clone()
	if isPlaceholder then
		local element = Elements[species.Element]
		local primary = if element then element.Color else Color3.new(1, 1, 1)
		local tints = { Primary = primary, Secondary = primary:Lerp(Color3.new(0, 0, 0), 0.45), Accent = primary:Lerp(Color3.new(1, 1, 1), 0.6) }
		for _, part in model:GetDescendants() do
			local tint = part:GetAttribute("Tint")
			if part:IsA("BasePart") and type(tint) == "string" and (tints :: any)[tint] then
				part.Color = (tints :: any)[tint]
			end
		end
	end
	if starborn then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Color = part.Color:Lerp(IndexConfig.StarbornColor, IndexConfig.StarbornTint)
			end
		end
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	model:ScaleTo(model:GetScale() * Ceremony.Reveal.Scale)
	return model
end

local function effectPart(parent: Instance, position: Vector3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(position)
	part.Parent = parent
	return part
end

-- True if the player hasn't pressed anything for Config/Ceremony IdleSeconds.
function CeremonyController.IsIdle(): boolean
	return os.clock() - lastInput > Ceremony.IdleSeconds
end

function CeremonyController.IsPlaying(): boolean
	return playing
end

-- Plays the ceremony for a bind at the nearest altar. Returns false (and plays nothing) if there's no altar nearby or
-- one is already playing; onDone runs when it ends (or right away when it doesn't play).
function CeremonyController.Play(request: Request, onDone: () -> ()): boolean
	local species = Dragons[request.SpeciesId]
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if playing or species == nil or root == nil or not root:IsA("BasePart") then
		task.spawn(onDone)
		return false
	end
	local _, center = AltarGlowController.GetNearestAltar(root.Position, Ceremony.AltarRange)
	if center == nil then
		task.spawn(onDone)
		return false
	end
	local rarity = rarityOf(species.Rarity)
	local color = if request.Starborn then IndexConfig.StarbornColor elseif rarity then rarity.Color else Color3.new(1, 1, 1)
	local big = (Ceremony.FullAlways :: any)[species.Rarity] == true or (request.Starborn and Ceremony.StarbornIsBig)
	local quick = Players.LocalPlayer:GetAttribute("QuickBinds") == true and not big
	local low = EffectsQuality.IsLow()
	playing = true

	local folder = Instance.new("Folder")
	folder.Name = "Ceremony"
	folder.Parent = workspace
	local camera = workspace.CurrentCamera
	local startCFrame = camera.CFrame
	local skipped = false
	local connections: { RBXScriptConnection } = {}

	-- Overlay: flash + skip hint
	local overlay = Instance.new("ScreenGui")
	overlay.Name = "CeremonyOverlay"
	overlay.DisplayOrder = UITheme.Layers.Notifications + 5
	overlay.IgnoreGuiInset = true
	overlay.ResetOnSpawn = false
	overlay.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = overlay
	local hint = Style.Label(overlay, Ceremony.SkipHint, "Bold", 14, UITheme.Colors.TextMuted)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -24)
	hint.Size = UDim2.fromOffset(320, 20)

	table.insert(connections, UserInputService.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.Keyboard or t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
			or t == Enum.UserInputType.Gamepad1 then
			skipped = true
		end
	end))

	local function waitFor(seconds: number)
		local finish = os.clock() + seconds
		while os.clock() < finish and not skipped do
			RunService.Heartbeat:Wait()
		end
	end

	-- Camera
	local cameraTarget: CFrame? = nil
	if not quick then
		local away = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
		away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)
		local eye = center + away * Ceremony.Camera.Distance + Vector3.new(0, Ceremony.Camera.Height - 4, 0)
		cameraTarget = CFrame.lookAt(eye, center + Vector3.new(0, 3, 0))
		camera.CameraType = Enum.CameraType.Scriptable
		local started = os.clock()
		RunService:BindToRenderStep("CeremonyCamera", Enum.RenderPriority.Camera.Value + 1, function()
			local t = ease((os.clock() - started) / Ceremony.Camera.EaseSeconds)
			camera.CFrame = startCFrame:Lerp(cameraTarget :: CFrame, t)
		end)
	end

	-- Stars streaking down into the altar
	if not quick then
		playSound(Ceremony.Sounds.Pull)
		local positions = SkyController.GetStarPositions()
		if #positions == 0 then
			for i = 1, Ceremony.Stars.Count do
				local angle = i / Ceremony.Stars.Count * 2 * math.pi
				table.insert(positions, center + Vector3.new(math.cos(angle) * 60, 140, math.sin(angle) * 60))
			end
		end
		local count = math.min(Ceremony.Stars.Count, #positions)
		for i = 1, count do
			local from = positions[i]
			local control = from:Lerp(center, 0.5) + Vector3.new(0, 40, 0)
			task.delay((i - 1) * Ceremony.Stars.Stagger, function()
				if skipped then
					return
				end
				local star = effectPart(folder, from)
				local gui = Instance.new("BillboardGui")
				gui.Size = UDim2.fromScale(Ceremony.Stars.Size, Ceremony.Stars.Size)
				gui.LightInfluence = 0
				gui.Parent = star
				local image = Instance.new("ImageLabel")
				image.BackgroundTransparency = 1
				image.Size = UDim2.fromScale(1, 1)
				image.Image = Ceremony.Burst.SparkleImage
				image.ImageColor3 = color:Lerp(Color3.new(1, 1, 1), 0.5)
				image.Parent = gui
				local a0 = Instance.new("Attachment")
				a0.Position = Vector3.new(0, 0.4, 0)
				a0.Parent = star
				local a1 = Instance.new("Attachment")
				a1.Position = Vector3.new(0, -0.4, 0)
				a1.Parent = star
				local trail = Instance.new("Trail")
				trail.Attachment0 = a0
				trail.Attachment1 = a1
				trail.Lifetime = 0.35
				trail.LightEmission = 1
				trail.FaceCamera = true
				trail.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.3))
				trail.Transparency = NumberSequence.new(0, 1)
				trail.WidthScale = NumberSequence.new(1, 0)
				trail.Parent = star
				local started = os.clock()
				while not skipped do
					local t = ease((os.clock() - started) / Ceremony.Stars.FlySeconds)
					local p = from:Lerp(control, t):Lerp(control:Lerp(center, t), t) -- quadratic bezier
					star.CFrame = CFrame.new(p)
					if t >= 1 then
						break
					end
					RunService.Heartbeat:Wait()
				end
				star:Destroy()
			end)
		end
		waitFor(Ceremony.Stars.FlySeconds + Ceremony.Stars.Stagger * (count - 1))
	end

	-- Burst
	if not skipped then
		playSound((Ceremony.Sounds :: any)[species.Rarity])
		if big then
			playSound(Ceremony.Sounds.Big)
		end
		local burst = effectPart(folder, center)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = Ceremony.Burst.SparkleImage
		emitter.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.3))
		emitter.LightEmission = 1
		emitter.LightInfluence = 0
		emitter.Rate = 0
		emitter.Speed = NumberRange.new(14, if big then 38 else 26)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Drag = 3
		emitter.Lifetime = NumberRange.new(0.8, if big then 1.8 else 1.3)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
		emitter.Transparency = NumberSequence.new(0, 1)
		emitter.Parent = burst
		local particles = if big then Ceremony.Burst.BigParticles else Ceremony.Burst.Particles
		emitter:Emit(if low then math.ceil(particles / 3) else particles)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = Ceremony.Burst.LightRange
		light.Brightness = Ceremony.Burst.LightBrightness
		light.Shadows = false
		light.Parent = burst

		local rings = {}
		for wave = 1, if big then 2 else 1 do
			local ringGui = Instance.new("BillboardGui")
			ringGui.LightInfluence = 0
			ringGui.Size = UDim2.fromScale(0, 0)
			ringGui.Parent = burst
			local ringImage = Instance.new("ImageLabel")
			ringImage.BackgroundTransparency = 1
			ringImage.Size = UDim2.fromScale(1, 1)
			ringImage.Image = Ceremony.Burst.RingImage
			ringImage.ImageColor3 = color
			ringImage.Parent = ringGui
			table.insert(rings, { Gui = ringGui, Image = ringImage, Delay = (wave - 1) * 0.25 })
		end
		flash.BackgroundTransparency = if big then Ceremony.Burst.BigFlashTransparency else Ceremony.Burst.FlashTransparency
		local skyFlash: ColorCorrectionEffect? = nil
		if big and not low then
			local cc = Instance.new("ColorCorrectionEffect")
			cc.Name = "CeremonyFlash"
			cc.TintColor = color:Lerp(Color3.new(1, 1, 1), 0.6)
			cc.Brightness = Ceremony.SkyFlash.Brightness
			cc.Parent = Lighting
			skyFlash = cc
		end
		local burstStart = os.clock()
		local ringSize = if big then Ceremony.Burst.BigRingSize else Ceremony.Burst.RingSize
		table.insert(connections, RunService.RenderStepped:Connect(function()
			local elapsed = os.clock() - burstStart
			for _, ring in rings do
				local t = math.clamp((elapsed - ring.Delay) / Ceremony.Burst.RingSeconds, 0, 1)
				ring.Gui.Size = UDim2.fromScale(ringSize * ease(t), ringSize * ease(t))
				ring.Image.ImageTransparency = if t <= 0 then 1 else t
			end
			light.Brightness = Ceremony.Burst.LightBrightness * math.max(0, 1 - elapsed / 1.2)
			local base = if big then Ceremony.Burst.BigFlashTransparency else Ceremony.Burst.FlashTransparency
			flash.BackgroundTransparency = base + (1 - base) * math.clamp(elapsed / 0.5, 0, 1)
			if skyFlash then
				skyFlash.Brightness = Ceremony.SkyFlash.Brightness * math.max(0, 1 - elapsed / Ceremony.SkyFlash.Seconds)
			end
		end))
		if skyFlash then
			task.delay(Ceremony.SkyFlash.Seconds + 0.1, function()
				skyFlash:Destroy()
			end)
		end
	end

	-- Reveal
	if not skipped then
		local model = dragonModel(request.SpeciesId, request.Starborn)
		if model then
			local size = model:GetExtentsSize()
			local low0 = center - Vector3.new(0, size.Y / 2, 0)
			local high = center + Vector3.new(0, Ceremony.Reveal.RiseHeight, 0)
			model:PivotTo(CFrame.new(low0))
			model.Parent = folder
			local label = Instance.new("BillboardGui")
			label.Size = UDim2.fromOffset(260, 60)
			label.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 3, 0)
			label.LightInfluence = 0
			label.Adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
			label.Parent = model
			local title = Style.Label(label, if request.Starborn then `★ {species.Name} ★` else species.Name, "Title", 30, color)
			title.Size = UDim2.new(1, 0, 0, 34)
			title.TextStrokeTransparency = 0
			local sub = Style.Label(label, `{if request.Starborn then "STARBORN · " else ""}{species.Rarity} · {species.Element}`, "Heavy", 16, UITheme.Colors.Text)
			sub.Position = UDim2.fromOffset(0, 36)
			sub.Size = UDim2.new(1, 0, 0, 20)
			local revealStart = os.clock()
			local riseSeconds = if quick then 0.4 else Ceremony.Reveal.RiseSeconds
			table.insert(connections, RunService.RenderStepped:Connect(function()
				local elapsed = os.clock() - revealStart
				local t = ease(elapsed / riseSeconds)
				local spin = math.rad(elapsed * Ceremony.Reveal.SpinSpeed)
				model:PivotTo(CFrame.new(low0:Lerp(high, t)) * CFrame.Angles(0, spin, 0))
			end))
			local hold = if quick then Ceremony.Reveal.QuickHoldSeconds elseif big then Ceremony.Reveal.BigHoldSeconds else Ceremony.Reveal.HoldSeconds
			waitFor(riseSeconds + hold)
		end
	end

	-- Camera back
	if cameraTarget and not skipped then
		RunService:UnbindFromRenderStep("CeremonyCamera")
		local from = camera.CFrame
		local started = os.clock()
		RunService:BindToRenderStep("CeremonyCamera", Enum.RenderPriority.Camera.Value + 1, function()
			camera.CFrame = from:Lerp(startCFrame, ease((os.clock() - started) / Ceremony.Camera.ReturnSeconds))
		end)
		waitFor(Ceremony.Camera.ReturnSeconds)
	end

	-- Clean up (also after a skip)
	pcall(function()
		RunService:UnbindFromRenderStep("CeremonyCamera")
	end)
	if cameraTarget then
		camera.CameraType = Enum.CameraType.Custom
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	folder:Destroy()
	overlay:Destroy()
	local leftover = Lighting:FindFirstChild("CeremonyFlash")
	if leftover then
		leftover:Destroy()
	end
	playing = false
	task.spawn(onDone)
	return true
end

function CeremonyController:Init()
	UserInputService.InputBegan:Connect(function()
		lastInput = os.clock()
	end)
	UserInputService.InputChanged:Connect(function()
		lastInput = os.clock()
	end)
end

return CeremonyController
