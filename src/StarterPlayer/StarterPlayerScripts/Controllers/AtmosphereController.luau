--!strict
-- Lighting per area and time of day (client only). Each area has a Day and a Night look in Config/Atmosphere
-- (ambient, haze, bloom, color correction, sun rays, a gentle far blur); they blend with the clock at dusk/dawn and
-- blend to the new area's look after a teleport. Tonight's element tints the night ambient.
-- The player's area = the nearest AreaSpawn (tag "AreaSpawn" + AreaId). Other controllers use GetArea/GetNightBlend.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EffectsQuality = require(script.Parent.EffectsQuality)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local AtmosphereConfig = require(ReplicatedStorage.Shared.Config.Atmosphere)
local Elements = require(ReplicatedStorage.Shared.Config.Elements)

type Look = AtmosphereConfig.Look

local AtmosphereController = {}

local area = AtmosphereConfig.DefaultArea
local previousLook: Look? = nil -- the look when the area last changed (blended out over AreaBlendSeconds)
local areaChangedAt = -math.huge
local nightBlend = 0
local lastLook: Look? = nil
local areaListeners: { (string) -> () } = {}

local atmosphere: Atmosphere
local bloom: BloomEffect
local color: ColorCorrectionEffect
local sunRays: SunRaysEffect
local blur: DepthOfFieldEffect

local function ensure<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		return existing :: any
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = Lighting
	return created :: any
end

local function lerpLook(a: Look, b: Look, t: number): Look
	local out: { [string]: any } = {}
	for key, value in a :: any do
		local other = (b :: any)[key]
		if typeof(value) == "number" then
			out[key] = value + (other - value) * t
		elseif typeof(value) == "Color3" then
			out[key] = (value :: Color3):Lerp(other, t)
		else
			out[key] = value
		end
	end
	return out :: any
end

local function areaLook(areaId: string, night: number): Look
	local preset = AtmosphereConfig.Areas[areaId] or AtmosphereConfig.Areas[AtmosphereConfig.DefaultArea]
	return lerpLook(preset.Day, preset.Night, night)
end

local function findArea(): string?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for _, spawnPart in CollectionService:GetTagged("AreaSpawn") do
		local areaId = spawnPart:GetAttribute("AreaId")
		if spawnPart:IsA("BasePart") and type(areaId) == "string" then
			local distance = (spawnPart.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = areaId, distance
			end
		end
	end
	return best
end

local function apply(look: Look, tintColor: Color3, tint: number)
	Lighting.Ambient = look.Ambient:Lerp(tintColor, tint)
	Lighting.OutdoorAmbient = look.OutdoorAmbient:Lerp(tintColor, tint)
	Lighting.Brightness = look.Brightness
	Lighting.ExposureCompensation = look.Exposure
	atmosphere.Density = look.Density
	atmosphere.Offset = look.Offset
	atmosphere.Color = look.HazeColor
	atmosphere.Decay = look.Decay
	atmosphere.Glare = look.Glare
	atmosphere.Haze = look.Haze
	local low = EffectsQuality.IsLow()
	bloom.Intensity = look.BloomIntensity
	bloom.Size = if low then math.min(look.BloomSize, 20) else look.BloomSize
	bloom.Threshold = look.BloomThreshold
	color.Contrast = look.Contrast
	color.Saturation = look.Saturation
	color.TintColor = look.Tint
	sunRays.Intensity = look.SunRays
	blur.Enabled = look.DepthBlur > 0 and not low
	blur.FarIntensity = look.DepthBlur
end

-- The area the player is in (AreaId).
function AtmosphereController.GetArea(): string
	return area
end

-- Calls fn(areaId) now and whenever the player changes area.
function AtmosphereController.OnAreaChanged(fn: (string) -> ())
	table.insert(areaListeners, fn)
	task.spawn(fn, area)
end

-- 0 by day, 1 at night, blended over dusk/dawn (Config/Atmosphere TransitionSeconds).
function AtmosphereController.GetNightBlend(): number
	return nightBlend
end

function AtmosphereController:Init()
	atmosphere = ensure("Atmosphere", "Atmosphere")
	bloom = ensure("BloomEffect", "Bloom")
	color = ensure("ColorCorrectionEffect", "AreaColor")
	sunRays = ensure("SunRaysEffect", "SunRays")
	blur = ensure("DepthOfFieldEffect", "DepthOfField")
	blur.FocusDistance = 80
	blur.InFocusRadius = 90
	blur.NearIntensity = 0
end

function AtmosphereController:Start()
	task.spawn(function()
		while true do
			local found = findArea()
			if found and found ~= area then
				previousLook = lastLook
				areaChangedAt = os.clock()
				area = found
				for _, fn in areaListeners do
					task.spawn(fn, area)
				end
			end
			task.wait(0.5)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local state = Cycle.GetState()
		nightBlend = Cycle.GetNightBlend(state, AtmosphereConfig.TransitionSeconds)
		local look = areaLook(area, nightBlend)
		local sinceChange = (os.clock() - areaChangedAt) / AtmosphereConfig.AreaBlendSeconds
		if previousLook and sinceChange < 1 then
			look = lerpLook(previousLook, look, math.clamp(sinceChange, 0, 1))
		end
		lastLook = look

		local constellation = state.Constellation
		local element = if constellation.Element then Elements[constellation.Element] else nil
		local tintColor = if element then element.Color else Color3.new(1, 1, 1)
		local tintStrength = if constellation.Rare then AtmosphereConfig.RareNightTint else AtmosphereConfig.NightTint
		apply(look, tintColor, tintStrength * nightBlend)
	end)
end

return AtmosphereController
