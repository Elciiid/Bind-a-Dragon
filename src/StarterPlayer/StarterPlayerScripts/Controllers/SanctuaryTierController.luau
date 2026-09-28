--!strict
-- Sanctuaries look grander as their owner upgrades the roost, for everyone. The tier comes from the plot attributes
-- set by RoostService ("RoostSlots", "RoostIncomeLevel", "OwnerUserId"): points = extra slots bought + income levels
-- / IncomeLevelsPerPoint, one tier per PointsPerTier points (Config/WorldUI.SanctuaryTiers). The art for each tier is
-- built in Studio (ValleyBuild.BuildSanctuaryTiers) in ReplicatedStorage.Assets.SanctuaryTiers.<PlotName>.TierN, in
-- world position; this controller clones in the tiers a sanctuary has reached (locally) and removes them when the
-- owner leaves. It also switches the brazier lights by distance, shows the aurora (tier 4) only at night, turns the
-- drifting motes off with Low effects, and plays a starburst at the gate (+ a toast for the owner) on a new tier.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local AtmosphereController = require(script.Parent.AtmosphereController)
local EffectsQuality = require(script.Parent.EffectsQuality)
local Toast = require(script.Parent.UI.Toast)
local RoostConfig = require(ReplicatedStorage.Shared.Config.Roost)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local Settings = require(ReplicatedStorage.Shared.Config.WorldUI).SanctuaryTiers

local PLOT_TAG = "RoostPlot"
local SCAN_INTERVAL = 1
local UPDATE_INTERVAL = 0.5

type Sanctuary = {
	Plot: Model,
	Art: Instance, -- ReplicatedStorage.Assets.SanctuaryTiers.<PlotName>
	Shown: { [number]: Instance }, -- tier -> local clone
	Tier: number?, -- nil until first known (no burst for the tier a sanctuary already had)
	Lights: { PointLight },
	Auroras: { Beam },
	Motes: { ParticleEmitter },
}

local SanctuaryTierController = {}

local sanctuaries: { [Model]: Sanctuary } = {}
local localFolder: Folder? = nil

local function tierOf(plot: Model): number
	if plot:GetAttribute("OwnerUserId") == nil then
		return 0
	end
	local slots = plot:GetAttribute("RoostSlots")
	local income = plot:GetAttribute("RoostIncomeLevel")
	if type(slots) ~= "number" or type(income) ~= "number" then
		return 0
	end
	local points = math.max(0, slots - RoostConfig.BaseSlots) + math.floor(income / Settings.IncomeLevelsPerPoint)
	return math.clamp(math.floor(points / Settings.PointsPerTier), 0, #Settings.Names)
end

local function collect(sanctuary: Sanctuary)
	local lights, auroras, motes = {}, {}, {}
	for _, clone in sanctuary.Shown do
		for _, d in clone:GetDescendants() do
			if d:IsA("PointLight") then
				table.insert(lights, d)
			elseif d:IsA("Beam") and d.Name == "Aurora" then
				table.insert(auroras, d)
			elseif d:IsA("ParticleEmitter") and d.Name == "Motes" then
				table.insert(motes, d)
			end
		end
	end
	sanctuary.Lights, sanctuary.Auroras, sanctuary.Motes = lights, auroras, motes
end

local function burst(plot: Model, tier: number)
	local sign = plot:FindFirstChild("Sign")
	local center = plot:GetAttribute("RoamCenter")
	local at = if sign and sign:IsA("BasePart") then sign.Position elseif typeof(center) == "Vector3" then center else nil
	if at == nil or localFolder == nil then
		return
	end
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = CFrame.new(at)
	part.Parent = localFolder
	if not EffectsQuality.IsLow() then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 226, 150), Color3.fromRGB(130, 200, 255))
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new(1.2, 0)
		emitter.Lifetime = NumberRange.new(1.2, 2.2)
		emitter.Speed = NumberRange.new(10, 22)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Acceleration = Vector3.new(0, -6, 0)
		emitter.Rate = 0
		emitter.Parent = part
		emitter:Emit(Settings.BurstParticles)
	end
	local sound = Instance.new("Sound")
	sound.SoundId = Settings.BurstSound
	local volume = Players.LocalPlayer:GetAttribute("SoundVolume")
	sound.Volume = Settings.BurstVolume * (if type(volume) == "number" then volume else 1)
	sound.RollOffMaxDistance = 250
	sound.Parent = part
	sound:Play()
	task.delay(3, function()
		part:Destroy()
	end)
	if plot:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
		Toast.Show(Text.Format(Text.UpgradeStands.TierUp, { tier = Settings.Names[tier] }), "success")
	end
end

local function refresh(sanctuary: Sanctuary)
	local tier = tierOf(sanctuary.Plot)
	for i = 1, #Settings.Names do
		local shown = sanctuary.Shown[i]
		if i <= tier and shown == nil then
			local source = sanctuary.Art:FindFirstChild("Tier" .. i)
			if source then
				local clone = source:Clone()
				clone.Name = `{sanctuary.Plot.Name}_Tier{i}`
				clone.Parent = localFolder
				sanctuary.Shown[i] = clone
			end
		elseif i > tier and shown then
			shown:Destroy()
			sanctuary.Shown[i] = nil
		end
	end
	collect(sanctuary)
	if sanctuary.Tier ~= nil and tier > sanctuary.Tier then
		burst(sanctuary.Plot, tier)
	end
	sanctuary.Tier = tier
end

local function register(plot: Model)
	local root = ReplicatedStorage:FindFirstChild("Assets")
	root = root and root:FindFirstChild("SanctuaryTiers")
	local art = root and root:FindFirstChild(plot.Name)
	if art == nil then
		return
	end
	local sanctuary: Sanctuary = { Plot = plot, Art = art, Shown = {}, Tier = nil, Lights = {}, Auroras = {}, Motes = {} }
	sanctuaries[plot] = sanctuary
	for _, name in { "RoostSlots", "RoostIncomeLevel", "OwnerUserId" } do
		plot:GetAttributeChangedSignal(name):Connect(function()
			refresh(sanctuary)
		end)
	end
	refresh(sanctuary)
end

local function scan()
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		if plot:IsA("Model") and sanctuaries[plot] == nil then
			register(plot)
		end
	end
end

-- Lights near the camera only, the aurora at night only, no motes with Low effects.
local function update()
	local camera = workspace.CurrentCamera
	local from = if camera then camera.CFrame.Position else Vector3.zero
	local night = AtmosphereController.GetNightBlend() >= Settings.AuroraNightBlend
	local low = EffectsQuality.IsLow()
	for _, sanctuary in sanctuaries do
		for _, light in sanctuary.Lights do
			local parent = light.Parent
			local on = parent ~= nil and parent:IsA("BasePart") and (parent.Position - from).Magnitude < Settings.LightDistance
			if light.Enabled ~= on then
				light.Enabled = on
			end
		end
		for _, beam in sanctuary.Auroras do
			if beam.Enabled ~= night then
				beam.Enabled = night
			end
		end
		for _, emitter in sanctuary.Motes do
			if emitter.Enabled == low then
				emitter.Enabled = not low
			end
		end
	end
end

function SanctuaryTierController:Start()
	local f = Instance.new("Folder")
	f.Name = "SanctuaryTiers"
	f.Parent = workspace
	localFolder = f
	local sinceScan, sinceUpdate = SCAN_INTERVAL, UPDATE_INTERVAL
	RunService.Heartbeat:Connect(function(dt)
		sinceScan += dt
		sinceUpdate += dt
		if sinceScan >= SCAN_INTERVAL then
			sinceScan = 0
			scan()
		end
		if sinceUpdate >= UPDATE_INTERVAL then
			sinceUpdate = 0
			update()
		end
	end)
end

return SanctuaryTierController
