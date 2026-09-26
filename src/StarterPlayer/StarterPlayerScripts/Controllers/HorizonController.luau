--!strict
-- Horizon landmarks (client only): big silhouettes of the other areas' landmarks, shown on the horizon behind each
-- Meadow portal while the player is in an area listed in the landmark's ShowIn. Cloned from
-- ReplicatedStorage.Assets.Horizon, no collision, no shadows, never streamed. "Spinner" pieces turn slowly, "Flash"
-- parts flash like lightning; particles, beams, lights and flashes are off with Low effects. Settings: Config/Horizon.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AtmosphereController = require(script.Parent.AtmosphereController)
local EffectsQuality = require(script.Parent.EffectsQuality)
local HorizonConfig = require(ReplicatedStorage.Shared.Config.Horizon)

type Shown = {
	Config: HorizonConfig.Landmark,
	Model: Model,
	Spinner: PVInstance?,
	SpinBase: CFrame?,
	Flashes: { BasePart },
	NextFlash: number,
	FlashUntil: number,
}

local HorizonController = {}

local folder: Folder
local shown: { [number]: Shown } = {}

local function setEffects(model: Model, enabled: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Light") or d:IsA("Trail") then
			d.Enabled = enabled
		end
	end
end

local function nextFlash(config: HorizonConfig.Landmark): number
	local range = config.FlashEvery
	if range == nil then
		return math.huge
	end
	return os.clock() + range.Min + math.random() * (range.Max - range.Min)
end

local function show(index: number, config: HorizonConfig.Landmark, source: Model)
	local model = source:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
	if config.Scale ~= 1 then
		model:ScaleTo(config.Scale)
	end
	local flat = Vector3.new(config.FaceTowards.X, config.Position.Y, config.FaceTowards.Z)
	model:PivotTo(CFrame.lookAt(config.Position, flat))
	local spinner = model:FindFirstChild("Spinner", true) :: PVInstance?
	local flashes = {}
	for _, d in model:GetDescendants() do
		if d.Name == "Flash" and d:IsA("BasePart") then
			d.Transparency = 1
			table.insert(flashes, d)
		end
	end
	setEffects(model, not EffectsQuality.IsLow())
	model.Parent = folder
	shown[index] = {
		Config = config,
		Model = model,
		Spinner = spinner,
		SpinBase = spinner and spinner:GetPivot(),
		Flashes = flashes,
		NextFlash = nextFlash(config),
		FlashUntil = 0,
	}
end

local function refresh(area: string)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local library = assets and assets:FindFirstChild("Horizon")
	for index, config in HorizonConfig.Landmarks do
		local wanted = table.find(config.ShowIn, area) ~= nil
		local current = shown[index]
		if wanted and current == nil and library then
			local source = library:FindFirstChild(config.Model)
			if source and source:IsA("Model") then
				show(index, config, source)
			end
		elseif not wanted and current then
			current.Model:Destroy()
			shown[index] = nil
		end
	end
end

function HorizonController:Start()
	folder = Instance.new("Folder")
	folder.Name = "HorizonLandmarks"
	folder.Parent = workspace

	AtmosphereController.OnAreaChanged(refresh)
	EffectsQuality.OnChanged(function(isLow)
		for _, item in shown do
			setEffects(item.Model, not isLow)
		end
	end)

	local spun = 0
	RunService.Heartbeat:Connect(function(dt)
		spun += dt
		local now = os.clock()
		local low = EffectsQuality.IsLow()
		for _, item in shown do
			local speed = item.Config.SpinSpeed
			if speed and item.Spinner and item.SpinBase then
				item.Spinner:PivotTo(item.SpinBase * CFrame.Angles(0, 0, math.rad(speed * spun)))
			end
			if #item.Flashes > 0 then
				if not low and now >= item.NextFlash then
					item.FlashUntil = now + HorizonConfig.FlashSeconds
					item.NextFlash = nextFlash(item.Config)
				end
				local lit = now < item.FlashUntil
				for _, part in item.Flashes do
					part.Transparency = if lit then 1 - HorizonConfig.FlashOpacity else 1
				end
			end
		end
	end)
end

return HorizonController
