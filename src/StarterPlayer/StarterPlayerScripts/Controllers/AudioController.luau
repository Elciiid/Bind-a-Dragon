--!strict
-- Area music, ambience and 3D world sounds (client only). Day and night tracks crossfade with the night blend
-- (AtmosphereController). World sources are looping 3D sounds on tagged objects (forge fire, the altar's night
-- chimes). Volumes: Config/Audio, multiplied by the player's settings (LocalPlayer attributes "MusicVolume" and
-- "SoundVolume", 0..1, set by the Settings window).

local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local AtmosphereController = require(script.Parent.AtmosphereController)
local AudioConfig = require(ReplicatedStorage.Shared.Config.Audio)
local CurrentArea = require(ReplicatedStorage.Shared.CurrentArea)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local FeedbackConfig = require(ReplicatedStorage.Shared.Config.Feedback)

type Source = { Sound: Sound, Volume: number, NightOnly: boolean }

local AudioController = {}

local musicGroup: SoundGroup
local worldGroup: SoundGroup
local dayMusic: Sound
local nightMusic: Sound
local dayAmbience: Sound
local nightAmbience: Sound
local sources: { [Instance]: Source } = {}
local retired: { Sound } = {}
local moments: { [Sound]: number } = {}
local dragonCooldowns: { [Model]: { [string]: number } } = setmetatable({}, { __mode = "k" }) :: any
local dragonSounds: { [Sound]: boolean } = {}
local loadReport: { [string]: string } = {}
local spireMusic: Sound
local areaId = ""
local climbing = false
local repeatWaiting = false
local endToken = 0

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

-- Report is populated by actual client PreloadAsync + Sound.IsLoaded checks, not metadata assumptions.
function AudioController.GetLoadReport(): { [string]: string }
	return table.clone(loadReport)
end

local function preload()
	local ids: { [string]: boolean } = {}
	local function collect(value: any)
		if type(value) == "string" and string.sub(value, 1, 13) == "rbxassetid://" then ids[value] = true
		elseif type(value) == "table" then for _, child in value do collect(child) end end
	end
	collect(AudioConfig)
	collect(FeedbackConfig.Sounds)
	for id in ids do
		loadReport[id] = "Pending"
		task.spawn(function()
			local probe = Instance.new("Sound")
			probe.SoundId = id
			probe.Parent = SoundService
			local status = "NoCallback"
			local ok, err = pcall(function()
				ContentProvider:PreloadAsync({ probe }, function(_, result) status = result.Name end)
			end)
			local loaded = ok and status == "Success" and probe.IsLoaded
			loadReport[id] = if loaded then "Loaded" else `{status}; IsLoaded={probe.IsLoaded}; {if ok then "" else tostring(err)}`
			if not loaded then warn(`[AudioController] {id}: {loadReport[id]}`) end
			probe:Destroy()
		end)
	end
end

local function oneShot(config: { Sound: string, Volume: number, Seconds: number }, parent: Instance): Sound?
	if setting("SoundVolume") <= 0 then return nil end
	local sound = Instance.new("Sound")
	sound.Name = "DragonMoment"
	sound.SoundId = config.Sound
	sound.Volume = config.Volume * setting("SoundVolume")
	sound.Parent = parent
	moments[sound] = config.Volume
	sound.Destroying:Connect(function() moments[sound] = nil; dragonSounds[sound] = nil end)
	sound:Play()
	Debris:AddItem(sound, config.Seconds)
	return sound
end

function AudioController.PlayDragonSound(kind: string, model: Model)
	local config = (AudioConfig.Dragon :: any)[kind]
	local part, camera = sourcePart(model), workspace.CurrentCamera
	if type(config) ~= "table" or not part or not camera or (part.Position - camera.CFrame.Position).Magnitude > AudioConfig.Dragon.MaxDistance then return end
	local count = 0
	for _ in dragonSounds do count += 1 end
	if count >= AudioConfig.Dragon.MaxSimultaneous then return end
	local cooldowns = dragonCooldowns[model]
	if not cooldowns then cooldowns = {}; dragonCooldowns[model] = cooldowns end
	local now = os.clock()
	if now < (cooldowns[kind] or 0) then return end
	local sound = oneShot(config, part)
	if sound then
		cooldowns[kind] = now + config.Cooldown
		sound.RollOffMinDistance = AudioConfig.Dragon.MinDistance
		sound.RollOffMaxDistance = AudioConfig.Dragon.MaxDistance
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		dragonSounds[sound] = true
	end
end

function AudioController:Start()
	musicGroup = group("Music")
	local ambienceGroup = group("Ambience")
	worldGroup = group("World")
	dayMusic = loop(AudioConfig.Music.Day, musicGroup, "DayMusic")
	nightMusic = loop(AudioConfig.Music.Night, musicGroup, "NightMusic")
	dayAmbience = loop(AudioConfig.Ambience.Day, ambienceGroup, "DayAmbience")
	nightAmbience = loop(AudioConfig.Ambience.Night, ambienceGroup, "NightAmbience")
	spireMusic = loop(AudioConfig.Spire.Sound, musicGroup, "SpireMusic")
	preload()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local bindResult = remotes:WaitForChild("BindResult") :: RemoteEvent
	local spireUpdate = remotes:WaitForChild("SpireUpdate") :: RemoteEvent
	bindResult.OnClientEvent:Connect(function(result)
		if type(result) ~= "table" then return end
		local species = Dragons[result.SpeciesId]
		local key = if result.MutationId == "Primordial" then "Primordial" elseif species then species.Rarity else "Common"
		local config = (AudioConfig.Bind :: any)[key]
		if config then oneShot(config, SoundService) end
	end)
	spireUpdate.OnClientEvent:Connect(function(update)
		if type(update) ~= "table" then return end
		if update.Phase == "Fight" then endToken += 1; climbing = true; repeatWaiting = false
		elseif update.Phase == "Ended" then
			endToken += 1
			local token = endToken
			if update.Result == "Top" and update.AutoRepeat == true then
				repeatWaiting = true
				task.delay(AudioConfig.Spire.RepeatEndGraceSeconds, function() if token == endToken then climbing = false; repeatWaiting = false end end)
			else climbing = false; repeatWaiting = false end
		elseif update.Phase == "State" and update.AutoRepeat == false then
			if repeatWaiting then endToken += 1; climbing = false; repeatWaiting = false end
		end
	end)

	for _, config in AudioConfig.WorldSources do
		CollectionService:GetInstanceAddedSignal(config.Tag):Connect(function(instance)
			addSource(instance, config)
		end)
		CollectionService:GetInstanceRemovedSignal(config.Tag):Connect(function(instance)
			local source = sources[instance]
			if source then source.Sound:Destroy(); sources[instance] = nil end
		end)
		for _, instance in CollectionService:GetTagged(config.Tag) do
			addSource(instance, config)
		end
	end

	local sinceArea = AudioConfig.AreaPollSeconds
	RunService.Heartbeat:Connect(function(dt)
		sinceArea += dt
		if sinceArea >= AudioConfig.AreaPollSeconds then
			sinceArea = 0
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local wanted = if root and root:IsA("BasePart") then CurrentArea.At(root.Position) else nil
			if not wanted or not (AudioConfig.Areas :: any)[wanted] then wanted = AudioConfig.DefaultArea end
			if wanted ~= areaId then
				areaId = wanted :: string
				for _, old in { dayMusic, nightMusic, dayAmbience, nightAmbience } do table.insert(retired, old) end
				local config = (AudioConfig.Areas :: any)[areaId]
				dayMusic = loop(config.DayMusic, musicGroup, "DayMusic")
				nightMusic = loop(config.NightMusic, musicGroup, "NightMusic")
				dayAmbience = loop(config.DayAmbience, ambienceGroup, "DayAmbience")
				nightAmbience = loop(config.NightAmbience, ambienceGroup, "NightAmbience")
			end
		end
		local night = AtmosphereController.GetNightBlend()
		local music = AudioConfig.Music.Volume * setting("MusicVolume") * (if climbing then 0 else 1)
		local sound = setting("SoundVolume")
		local ambience = AudioConfig.Ambience.Volume * sound
		approach(dayMusic, music * (1 - night), dt)
		approach(nightMusic, music * night, dt)
		approach(dayAmbience, ambience * (1 - night), dt)
		approach(nightAmbience, ambience * night, dt)
		approach(spireMusic, AudioConfig.Spire.Volume * setting("MusicVolume") * (if climbing then 1 else 0), dt)
		for index = #retired, 1, -1 do
			local old = retired[index]
			approach(old, 0, dt)
			if old.Volume < 0.001 then old:Destroy(); table.remove(retired, index) end
		end
		for moment, gain in moments do moment.Volume = gain * sound end
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
