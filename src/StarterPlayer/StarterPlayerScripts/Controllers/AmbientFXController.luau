--!strict
-- World particle effects placed in the areas (ParticleEmitters tagged "AmbientFX": waterfall foam and mist, ...).
-- With Low effects they run at Config/Atmosphere AmbientFXLowRate of their normal rate. Emitters that stream in
-- later are picked up when they arrive.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EffectsQuality = require(script.Parent.EffectsQuality)
local AtmosphereConfig = require(ReplicatedStorage.Shared.Config.Atmosphere)

local TAG = "AmbientFX"

local AmbientFXController = {}

local baseRates: { [ParticleEmitter]: number } = setmetatable({}, { __mode = "k" }) :: any

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
end

return AmbientFXController
