--!strict
-- World particle effects placed in the areas (ParticleEmitters tagged "AmbientFX": waterfall foam and mist, ...).
-- With Low effects they run at Config/Atmosphere AmbientFXLowRate of their normal rate. Emitters that stream in
-- later are picked up when they arrive.
-- Beams tagged "DistanceFade" (the waterfall's water sheets) fade out between Config/Atmosphere BeamFadeStart and
-- BeamFadeEnd studs from the camera and are hidden beyond that.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EffectsQuality = require(script.Parent.EffectsQuality)
local AtmosphereConfig = require(ReplicatedStorage.Shared.Config.Atmosphere)

local TAG = "AmbientFX"
local FADE_TAG = "DistanceFade"
local FADE_INTERVAL = 0.25 -- seconds between distance checks
local FADE_STEP = 0.05 -- fade changes smaller than this are skipped (rebuilding a NumberSequence isn't free)

local AmbientFXController = {}

local baseRates: { [ParticleEmitter]: number } = setmetatable({}, { __mode = "k" }) :: any
local baseTransparency: { [Beam]: NumberSequence } = setmetatable({}, { __mode = "k" }) :: any
local fades: { [Beam]: number } = setmetatable({}, { __mode = "k" }) :: any

-- Blends a beam's own transparency toward invisible by `fade` (0 = as built, 1 = hidden).
local function setFade(beam: Beam, fade: number)
	local base = baseTransparency[beam]
	if base == nil then
		base = beam.Transparency
		baseTransparency[beam] = base
	end
	fades[beam] = fade
	beam.Enabled = fade < 1
	if fade < 1 then
		local points = {}
		for _, point in base.Keypoints do
			table.insert(points, NumberSequenceKeypoint.new(point.Time, point.Value + (1 - point.Value) * fade, point.Envelope))
		end
		beam.Transparency = NumberSequence.new(points)
	end
end

local function updateFades()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local from = camera.CFrame.Position
	local start, finish = AtmosphereConfig.BeamFadeStart, AtmosphereConfig.BeamFadeEnd
	for _, beam in CollectionService:GetTagged(FADE_TAG) do
		local anchor = if beam:IsA("Beam") then beam.Attachment0 else nil
		if anchor then
			local distance = (anchor.WorldPosition - from).Magnitude
			local fade = math.clamp((distance - start) / (finish - start), 0, 1)
			local current = fades[beam :: Beam]
			if current == nil or math.abs(fade - current) >= FADE_STEP or (fade ~= current and (fade == 0 or fade == 1)) then
				setFade(beam :: Beam, fade)
			end
		end
	end
end

local function apply(instance: Instance, low: boolean)
	if not instance:IsA("ParticleEmitter") then
		return
	end
	local base = baseRates[instance]
	if base == nil then
		base = instance.Rate
		baseRates[instance] = base
	end
	instance.Rate = if low then base * AtmosphereConfig.AmbientFXLowRate else base
end

function AmbientFXController:Start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance)
		apply(instance, EffectsQuality.IsLow())
	end)
	EffectsQuality.OnChanged(function(low)
		for _, instance in CollectionService:GetTagged(TAG) do
			apply(instance, low)
		end
	end)
	task.spawn(function()
		while true do
			updateFades()
			task.wait(FADE_INTERVAL)
		end
	end)
end

return AmbientFXController
