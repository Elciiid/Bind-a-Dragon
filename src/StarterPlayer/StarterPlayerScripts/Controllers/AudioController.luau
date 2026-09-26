--!strict
-- Music, ambience and 3D world sounds (client only). Day and night tracks crossfade with the night blend
-- (AtmosphereController). World sources are looping 3D sounds on tagged objects (forge fire, the altar's night
-- chimes). Volumes: Config/Audio, multiplied by the player's settings (LocalPlayer attributes "MusicVolume" and
-- "SoundVolume", 0..1, set by the Settings window).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local AtmosphereController = require(script.Parent.AtmosphereController)
local AudioConfig = require(ReplicatedStorage.Shared.Config.Audio)

type Source = { Sound: Sound, Volume: number, NightOnly: boolean }

local AudioController = {}

local musicGroup: SoundGroup
local worldGroup: SoundGroup
local dayMusic: Sound
local nightMusic: Sound
local dayAmbience: Sound
local nightAmbience: Sound
local sources: { [Instance]: Source } = {}

local function group(name: string): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local created = Instance.new("SoundGroup")
	created.Name = name
	created.Parent = SoundService
	return created
end

local function loop(id: string, soundGroup: SoundGroup, name: string): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	sound.SoundGroup = soundGroup
	sound.Parent = SoundService
	sound:Play()
	return sound
end

local function setting(name: string): number
	local value = Players.LocalPlayer:GetAttribute(name)
	return if type(value) == "number" then math.clamp(value, 0, 1) else 1
end

local function sourcePart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	elseif instance:IsA("Model") then
		return instance.PrimaryPart
	end
	return nil
end

local function addSource(instance: Instance, config: { Sound: string, Volume: number, MaxDistance: number, NightOnly: boolean })
	local part = sourcePart(instance)
	if part == nil or sources[instance] then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "WorldAmbience"
	sound.SoundId = config.Sound
	sound.Looped = true
	sound.Volume = 0
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = config.MaxDistance
	sound.SoundGroup = worldGroup
	sound.Parent = part
	sound:Play()
	sources[instance] = { Sound = sound, Volume = config.Volume, NightOnly = config.NightOnly }
	instance.Destroying:Connect(function()
		sources[instance] = nil
	end)
end

local function approach(sound: Sound, target: number, dt: number)
	local rate = dt / math.max(AudioConfig.CrossfadeSmoothing, 0.01)
	sound.Volume += (target - sound.Volume) * math.clamp(rate, 0, 1)
end

function AudioController:Start()
	musicGroup = group("Music")
	local ambienceGroup = group("Ambience")
	worldGroup = group("World")
	dayMusic = loop(AudioConfig.Music.Day, musicGroup, "DayMusic")
	nightMusic = loop(AudioConfig.Music.Night, musicGroup, "NightMusic")
	dayAmbience = loop(AudioConfig.Ambience.Day, ambienceGroup, "DayAmbience")
	nightAmbience = loop(AudioConfig.Ambience.Night, ambienceGroup, "NightAmbience")

	for _, config in AudioConfig.WorldSources do
		CollectionService:GetInstanceAddedSignal(config.Tag):Connect(function(instance)
			addSource(instance, config)
		end)
		for _, instance in CollectionService:GetTagged(config.Tag) do
			addSource(instance, config)
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		local night = AtmosphereController.GetNightBlend()
		local music = AudioConfig.Music.Volume * setting("MusicVolume")
		local sound = setting("SoundVolume")
		local ambience = AudioConfig.Ambience.Volume * sound
		approach(dayMusic, music * (1 - night), dt)
		approach(nightMusic, music * night, dt)
		approach(dayAmbience, ambience * (1 - night), dt)
		approach(nightAmbience, ambience * night, dt)
		for instance, source in sources do
			if source.Sound.Parent == nil then
				sources[instance] = nil
			else
				approach(source.Sound, source.Volume * sound * (if source.NightOnly then night else 1), dt)
			end
		end
	end)
end

return AudioController
