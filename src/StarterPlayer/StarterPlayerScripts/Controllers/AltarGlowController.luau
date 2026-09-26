--!strict
-- Star Altar night glow (client only), for every altar tagged "StarAltar": a light beam rising from the main crystal,
-- glow points on the crystal tips ("GlowAnchor" parts in the altar's "Glow" folder; only the first few cast real
-- light), rising sparkles and a faint pulsing Highlight when close. Fades with the night blend; brighter when
-- tonight's constellation favors the altar's area. Off far from the camera. Settings: Config/AltarGlow.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AtmosphereController = require(script.Parent.AtmosphereController)
local EffectsQuality = require(script.Parent.EffectsQuality)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local Luck = require(ReplicatedStorage.Shared.Luck)
local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local Elements = require(ReplicatedStorage.Shared.Config.Elements)
local Glow = require(ReplicatedStorage.Shared.Config.AltarGlow)

type Tip = { Part: BasePart, Gui: BillboardGui, Image: ImageLabel, Size: number, Light: PointLight? }
type Altar = {
	Model: Instance,
	AreaId: string,
	Center: Vector3,
	Tips: { Tip },
	Beams: { { Beam: Beam, Transparency: number } },
	Sparkles: ParticleEmitter,
	SparkleVolume: Part,
	Highlight: Highlight?,
	Effects: { Instance },
}

local AltarGlowController = {}

local altars: { [Instance]: Altar } = {}

local function altarColor(areaId: string): Color3
	local area = Areas[areaId]
	local element = area and area.Element and Elements[area.Element]
	return if element then element.Color else Glow.NoElementColor
end

local function setup(model: Instance)
	if altars[model] or not model:IsA("Model") then
		return
	end
	local folder = model:FindFirstChild("Glow") or model:WaitForChild("Glow", 10)
	if folder == nil or altars[model] or model.Parent == nil then
		return
	end
	local areaId = model:GetAttribute("AreaId")
	local color = altarColor(if type(areaId) == "string" then areaId else "")
	local effects: { Instance } = {}

	local anchors = {}
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") and part.Name == "GlowAnchor" then
			table.insert(anchors, part)
		end
	end
	table.sort(anchors, function(a, b)
		return (a:GetAttribute("Rank") or 99) < (b:GetAttribute("Rank") or 99)
	end)
	if #anchors == 0 then
		return
	end

	-- Tip glows (+ real lights on the first few)
	local tips: { Tip } = {}
	for index, part in anchors do
		local gui = Instance.new("BillboardGui")
		gui.Name = "TipGlow"
		gui.LightInfluence = 0
		gui.AlwaysOnTop = false
		local size = if index == 1 then Glow.Tips.MainSize else Glow.Tips.Size
		gui.Size = UDim2.fromScale(size, size)
		gui.Parent = part
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromScale(1, 1)
		image.Image = Glow.Tips.Image
		image.ImageColor3 = color:Lerp(Color3.new(1, 1, 1), 0.3)
		image.Parent = gui
		table.insert(effects, gui)
		local light: PointLight? = nil
		if index <= Glow.Tips.MaxLights then
			local newLight = Instance.new("PointLight")
			newLight.Color = color
			newLight.Range = Glow.Tips.LightRange
			newLight.Shadows = false
			newLight.Parent = part
			table.insert(effects, newLight)
			light = newLight
		end
		table.insert(tips, { Part = part, Gui = gui, Image = image, Size = size, Light = light })
	end

	-- Beam from the main crystal upward
	local main = anchors[1]
	local bottom = Instance.new("Attachment")
	bottom.Name = "BeamBottom"
	bottom.Parent = main
	local top = Instance.new("Attachment")
	top.Name = "BeamTop"
	top.Position = Vector3.new(0, Glow.Beam.Height, 0)
	top.Parent = main
	table.insert(effects, bottom)
	table.insert(effects, top)
	local beams = {}
	local function beam(width: number, transparency: number, texture: string?)
		local b = Instance.new("Beam")
		b.Attachment0 = bottom
		b.Attachment1 = top
		b.Width0 = width
		b.Width1 = width * 0.4
		b.FaceCamera = true
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Segments = 8
		b.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25))
		if texture then
			b.Texture = texture
			b.TextureMode = Enum.TextureMode.Wrap
			b.TextureLength = Glow.Beam.TextureLength
			b.TextureSpeed = Glow.Beam.TextureSpeed
		end
		b.Parent = main
		table.insert(effects, b)
		table.insert(beams, { Beam = b, Transparency = transparency })
	end
	beam(Glow.Beam.CoreWidth, Glow.Beam.CoreTransparency, nil)
	beam(Glow.Beam.ShellWidth, Glow.Beam.ShellTransparency, Glow.Beam.ShellTexture)

	-- Sparkles rising from a thin disk around the altar's base
	local boxCFrame, boxSize
	if model:IsA("Model") then
		boxCFrame, boxSize = model:GetBoundingBox()
	end
	local base = if boxCFrame then boxCFrame.Position - Vector3.new(0, boxSize.Y / 2 - 1, 0) else main.Position
	local volume = Instance.new("Part")
	volume.Name = "AltarSparkles"
	volume.Anchored = true
	volume.CanCollide = false
	volume.CanQuery = false
	volume.CanTouch = false
	volume.Transparency = 1
	volume.Size = Vector3.new(Glow.Sparkles.Radius * 2, 1, Glow.Sparkles.Radius * 2)
	volume.CFrame = CFrame.new(base)
	volume.Parent = workspace
	table.insert(effects, volume)
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = Glow.Tips.Image
	sparkles.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.4))
	sparkles.LightEmission = 1
	sparkles.LightInfluence = 0
	sparkles.Shape = Enum.ParticleEmitterShape.Box
	sparkles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	sparkles.EmissionDirection = Enum.NormalId.Top
	sparkles.SpreadAngle = Vector2.new(10, 10)
	sparkles.Speed = NumberRange.new(Glow.Sparkles.Speed * 0.5, Glow.Sparkles.Speed)
	sparkles.Lifetime = NumberRange.new(Glow.Sparkles.Lifetime * 0.6, Glow.Sparkles.Lifetime)
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, Glow.Sparkles.Size),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Transparency = NumberSequence.new(0.1, 1)
	sparkles.Rate = 0
	sparkles.Parent = volume

	-- Highlight
	local highlight: Highlight? = nil
	if Glow.Highlight.Enabled then
		local h = Instance.new("Highlight")
		h.Name = "AltarHighlight"
		h.FillColor = color
		h.OutlineColor = color:Lerp(Color3.new(1, 1, 1), 0.4)
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Enabled = false
		h.Adornee = model
		h.Parent = model
		table.insert(effects, h)
		highlight = h
	end

	altars[model] = {
		Model = model,
		AreaId = if type(areaId) == "string" then areaId else "",
		Center = main.Position,
		Tips = tips,
		Beams = beams,
		Sparkles = sparkles,
		SparkleVolume = volume,
		Highlight = highlight,
		Effects = effects,
	}
end

local function remove(model: Instance)
	local altar = altars[model]
	if altar then
		for _, effect in altar.Effects do
			effect:Destroy()
		end
		altars[model] = nil
	end
end

-- The main crystal's position of the altar nearest to `position` within `range` (for the binding ceremony).
function AltarGlowController.GetNearestAltar(position: Vector3, range: number): (Instance?, Vector3?)
	local best, bestCenter, bestDistance = nil, nil, range
	for model, altar in altars do
		local distance = (altar.Center - position).Magnitude
		if distance <= bestDistance then
			best, bestCenter, bestDistance = model, altar.Center, distance
		end
	end
	return best, bestCenter
end

function AltarGlowController:Start()
	CollectionService:GetInstanceAddedSignal("StarAltar"):Connect(function(model)
		task.spawn(setup, model)
	end)
	CollectionService:GetInstanceRemovedSignal("StarAltar"):Connect(remove)
	for _, model in CollectionService:GetTagged("StarAltar") do
		task.spawn(setup, model)
	end

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if camera == nil then
			return
		end
		local eye = camera.CFrame.Position
		local night = AtmosphereController.GetNightBlend()
		local constellation = Cycle.GetState().Constellation
		local low = EffectsQuality.IsLow()
		local breath = 1 + math.sin(os.clock() * 2 * math.pi / Glow.BreathSeconds) * Glow.BreathAmount
		for model, altar in altars do
			if model.Parent == nil then
				remove(model)
				continue
			end
			local distance = (altar.Center - eye).Magnitude
			local active = night > 0.01 and distance <= Glow.FarDistance
			local favored = altar.AreaId ~= "" and Luck.IsFavored(altar.AreaId, constellation)
			local strength = night * (if favored then Glow.FavoredBoost else 1) * breath
			local fade = math.min(strength, 1)

			for _, entry in altar.Beams do
				entry.Beam.Enabled = active
				if active then
					local t = 1 - (1 - entry.Transparency) * fade
					entry.Beam.Transparency = NumberSequence.new(t, 1)
				end
			end
			for _, tip in altar.Tips do
				tip.Gui.Enabled = active
				if active then
					tip.Image.ImageTransparency = 1 - fade
					local size = tip.Size * math.max(strength, 0.4)
					tip.Gui.Size = UDim2.fromScale(size, size)
				end
				if tip.Light then
					tip.Light.Enabled = active
					tip.Light.Brightness = Glow.Tips.LightBrightness * strength
				end
			end
			altar.Sparkles.Rate = if active then Glow.Sparkles.Rate * strength * (if low then 0.35 else 1) else 0
			local highlight = altar.Highlight
			if highlight then
				local show = active and not low and night > 0.3 and distance <= Glow.Highlight.Distance
				highlight.Enabled = show
				if show then
					local pulse = (math.sin(os.clock() * 2 * math.pi / Glow.Highlight.PulseSeconds) + 1) / 2
					highlight.FillTransparency = 1 - (1 - Glow.Highlight.FillTransparency) * pulse * fade
					highlight.OutlineTransparency = 1 - (1 - Glow.Highlight.OutlineTransparency) * fade
				end
			end
		end
	end)
end

return AltarGlowController
