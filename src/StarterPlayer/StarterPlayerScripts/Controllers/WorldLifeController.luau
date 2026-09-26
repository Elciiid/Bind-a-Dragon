--!strict
-- Small life in the world (client only):
--  * Lanterns (Models tagged "Lantern" with a "Lamp" part and a PointLight): unlit glass by day, glowing at dusk with a
--    gentle flicker. Only the nearest few cast light (phone budget); the rest just glow.
--  * Drifting particles around the camera, per area and time of day (petals and fireflies in the meadow, embers at the
--    volcano, snow at the cliffs...). Fewer with Low effects.
-- Settings: Config/Atmosphere (Lanterns, DriftBox, each area's DayDrift / NightDrift).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AtmosphereController = require(script.Parent.AtmosphereController)
local EffectsQuality = require(script.Parent.EffectsQuality)
local AtmosphereConfig = require(ReplicatedStorage.Shared.Config.Atmosphere)

local LanternConfig = AtmosphereConfig.Lanterns

type Lantern = { Model: Model, Lamp: BasePart, Light: PointLight?, Seed: number }

local WorldLifeController = {}

local lanterns: { [Model]: Lantern } = {}
local lit: { [Lantern]: boolean } = {}
local dayEmitter: ParticleEmitter
local nightEmitter: ParticleEmitter
local driftPart: Part
local dayRate = 0
local nightRate = 0

local function addLantern(instance: Instance)
	if not instance:IsA("Model") or lanterns[instance] then
		return
	end
	-- the lamp can arrive a moment after the model when streaming
	local lamp = instance:FindFirstChild("Lamp") or instance:WaitForChild("Lamp", 10)
	if lamp == nil or not lamp:IsA("BasePart") or lanterns[instance] then
		return
	end
	local light = lamp:FindFirstChildOfClass("PointLight") or lamp:WaitForChild("PointLight", 5) :: PointLight?
	if light then
		light.Enabled = false
	end
	lanterns[instance] = { Model = instance, Lamp = lamp, Light = light, Seed = math.random() * 100 }
end

local function removeLantern(instance: Instance)
	local lantern = lanterns[instance :: Model]
	if lantern then
		lit[lantern] = nil
		lanterns[instance :: Model] = nil
	end
end

-- Which lanterns cast light: the nearest MaxLights within LightDistance of the camera.
local function chooseLit(eye: Vector3)
	local candidates = {}
	for _, lantern in lanterns do
		if lantern.Light and lantern.Lamp.Parent then
			local distance = (lantern.Lamp.Position - eye).Magnitude
			if distance <= LanternConfig.LightDistance then
				table.insert(candidates, { Lantern = lantern, Distance = distance })
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.Distance < b.Distance
	end)
	local max = if EffectsQuality.IsLow() then math.ceil(LanternConfig.MaxLights / 2) else LanternConfig.MaxLights
	local chosen: { [Lantern]: boolean } = {}
	for i = 1, math.min(max, #candidates) do
		chosen[candidates[i].Lantern] = true
	end
	for lantern in lit do
		if not chosen[lantern] and lantern.Light then
			lantern.Light.Enabled = false
		end
	end
	lit = chosen
end

local function makeEmitter(name: string): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.LightInfluence = 0
	emitter.Parent = driftPart
	return emitter
end

local function applyDrift(emitter: ParticleEmitter, drift: AtmosphereConfig.Drift?): number
	if drift == nil then
		emitter.Enabled = false
		return 0
	end
	emitter.Enabled = true
	emitter.Texture = drift.Texture
	emitter.Color = ColorSequence.new(drift.Color)
	emitter.LightEmission = drift.Glow
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.15, drift.Size),
		NumberSequenceKeypoint.new(0.85, drift.Size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.1),
		NumberSequenceKeypoint.new(0.8, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Speed = NumberRange.new(drift.Speed * 0.3, drift.Speed)
	emitter.Lifetime = NumberRange.new(drift.Lifetime * 0.6, drift.Lifetime)
	emitter.Acceleration = Vector3.new(0, drift.Rise, 0)
	emitter.RotSpeed = NumberRange.new(-drift.Spin, drift.Spin)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Drag = 0.5
	return drift.Rate
end

local function onArea(areaId: string)
	local preset = AtmosphereConfig.Areas[areaId] or AtmosphereConfig.Areas[AtmosphereConfig.DefaultArea]
	dayRate = applyDrift(dayEmitter, preset.DayDrift)
	nightRate = applyDrift(nightEmitter, preset.NightDrift)
end

function WorldLifeController:Start()
	CollectionService:GetInstanceAddedSignal("Lantern"):Connect(function(instance)
		task.spawn(addLantern, instance)
	end)
	CollectionService:GetInstanceRemovedSignal("Lantern"):Connect(removeLantern)
	for _, instance in CollectionService:GetTagged("Lantern") do
		task.spawn(addLantern, instance)
	end

	driftPart = Instance.new("Part")
	driftPart.Name = "DriftVolume"
	driftPart.Anchored = true
	driftPart.CanCollide = false
	driftPart.CanQuery = false
	driftPart.CanTouch = false
	driftPart.Transparency = 1
	driftPart.Size = AtmosphereConfig.DriftBox
	driftPart.Parent = workspace
	dayEmitter = makeEmitter("DayDrift")
	nightEmitter = makeEmitter("NightDrift")
	AtmosphereController.OnAreaChanged(onArea)

	local lastChoose = 0
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if camera == nil then
			return
		end
		local night = AtmosphereController.GetNightBlend()
		local now = os.clock()

		-- Lanterns
		local eye = camera.CFrame.Position
		if now - lastChoose > 0.3 then
			lastChoose = now
			chooseLit(eye)
		end
		local glassColor = LanternConfig.DayColor:Lerp(LanternConfig.NightColor, night)
		local material = if night > 0.3 then Enum.Material.Neon else Enum.Material.SmoothPlastic
		for _, lantern in lanterns do
			if lantern.Lamp.Color ~= glassColor then
				lantern.Lamp.Color = glassColor
			end
			if lantern.Lamp.Material ~= material then
				lantern.Lamp.Material = material
			end
		end
		for lantern in lit do
			local light = lantern.Light
			if light then
				local flicker = 1 + math.noise(now * LanternConfig.FlickerSpeed, lantern.Seed) * 2 * LanternConfig.Flicker
				light.Brightness = LanternConfig.Brightness * night * flicker
				light.Enabled = night > 0.05
			end
		end

		-- Drift volume follows the player (or the camera), near the ground
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local center = if root and root:IsA("BasePart") then root.Position else camera.Focus.Position
		driftPart.CFrame = CFrame.new(center + Vector3.new(0, AtmosphereConfig.DriftBox.Y / 2 - 2, 0))
		local scale = if EffectsQuality.IsLow() then AtmosphereConfig.DriftLowEffects else 1
		dayEmitter.Rate = dayRate * (1 - night) * scale
		nightEmitter.Rate = nightRate * night * scale
	end)
end

return WorldLifeController
