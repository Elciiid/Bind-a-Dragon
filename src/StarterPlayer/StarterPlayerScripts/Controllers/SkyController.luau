--!strict
-- Tonight's constellation drawn in the sky (client only): star sprites joined by glowing lines, in the element's
-- color, fading in at dusk and out at dawn (AtmosphereController night blend). Rare constellations are bigger and
-- brighter. Now and then a shooting star crosses the sky. The drawing follows the camera's position (not its
-- rotation), so it sits in the sky like the stars do. Drawings: Config/Constellations; look: Config/Atmosphere Sky.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AtmosphereController = require(script.Parent.AtmosphereController)
local EffectsQuality = require(script.Parent.EffectsQuality)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local AtmosphereConfig = require(ReplicatedStorage.Shared.Config.Atmosphere)
local Elements = require(ReplicatedStorage.Shared.Config.Elements)

local Sky = AtmosphereConfig.Sky

type Star = { Attachment: Attachment, Gui: BillboardGui, Image: ImageLabel, Offset: Vector2, Size: number }

local SkyController = {}

local shownId: string? = nil
local stars: { Star } = {}
local lines: { Beam } = {}
local scale = 1
local lineColor = Sky.DefaultColor

local shooting: { Head: Attachment, Tail: Attachment, Beam: Beam, From: Vector3, To: Vector3, Started: number }? = nil
local nextShootingStar = os.clock() + 20

local function basis(): (Vector3, Vector3, Vector3)
	local forward = Sky.Direction.Unit
	local right = forward:Cross(Vector3.yAxis).Unit
	local up = right:Cross(forward).Unit
	return forward, right, up
end

local function skyPoint(eye: Vector3, offset: Vector2): Vector3
	local forward, right, up = basis()
	local dir = forward + right * offset.X * Sky.Span.X * scale + up * offset.Y * Sky.Span.Y * scale
	return eye + dir.Unit * Sky.Distance
end

local function clear()
	for _, star in stars do
		star.Attachment:Destroy()
	end
	for _, beam in lines do
		beam:Destroy()
	end
	stars = {}
	lines = {}
end

local function build(constellation: any)
	clear()
	shownId = constellation.Id
	scale = if constellation.Rare then Sky.RareScale else 1
	local element = if constellation.Element then Elements[constellation.Element] else nil
	lineColor = if element then element.Color:Lerp(Color3.new(1, 1, 1), 0.35) else Sky.DefaultColor
	for index, point in constellation.Stars :: { Vector2 } do
		local attachment = Instance.new("Attachment")
		attachment.Name = "SkyStar"
		attachment.Parent = workspace.Terrain
		local gui = Instance.new("BillboardGui")
		gui.LightInfluence = 0
		gui.AlwaysOnTop = false
		gui.Adornee = attachment
		gui.Parent = attachment
		local size = (if index == 1 then Sky.BrightStarSize else Sky.StarSize) * scale
		gui.Size = UDim2.fromOffset(size, size)
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromScale(1, 1)
		image.Image = Sky.StarImage
		image.ImageColor3 = lineColor:Lerp(Color3.new(1, 1, 1), 0.5)
		image.Parent = gui
		table.insert(stars, { Attachment = attachment, Gui = gui, Image = image, Offset = point, Size = size })
	end
	for _, pair in constellation.Lines :: { { number } } do
		local a, b = stars[pair[1]], stars[pair[2]]
		if a and b then
			local beam = Instance.new("Beam")
			beam.Attachment0 = a.Attachment
			beam.Attachment1 = b.Attachment
			beam.Width0 = Sky.LineWidth * scale
			beam.Width1 = Sky.LineWidth * scale
			beam.FaceCamera = true
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.Segments = 1
			beam.Color = ColorSequence.new(lineColor)
			beam.Parent = workspace.Terrain
			table.insert(lines, beam)
		end
	end
end

local function updateShootingStar(eye: Vector3, night: number)
	local now = os.clock()
	if shooting == nil and night > 0.9 and now >= nextShootingStar and not EffectsQuality.IsLow() then
		local head = Instance.new("Attachment")
		head.Parent = workspace.Terrain
		local tail = Instance.new("Attachment")
		tail.Parent = workspace.Terrain
		local beam = Instance.new("Beam")
		beam.Attachment0 = head
		beam.Attachment1 = tail
		beam.Width0 = 2.5
		beam.Width1 = 0.2
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Segments = 1
		beam.Color = ColorSequence.new(Sky.ShootingStarColor)
		beam.Transparency = NumberSequence.new(0, 1)
		beam.Parent = workspace.Terrain
		local rng = Random.new()
		local startX, startY = rng:NextNumber(-1.6, 0.4), rng:NextNumber(0.6, 1.1)
		local from = Vector2.new(startX, startY)
		local to = from + Vector2.new(rng:NextNumber(0.9, 1.4), -rng:NextNumber(0.5, 0.8))
		shooting = { Head = head, Tail = tail, Beam = beam, From = Vector3.new(from.X, from.Y, 0), To = Vector3.new(to.X, to.Y, 0), Started = now }
		nextShootingStar = now + rng:NextNumber(Sky.ShootingStarEvery.Min, Sky.ShootingStarEvery.Max)
	end
	local current = shooting
	if current then
		local t = (now - current.Started) / Sky.ShootingStarSeconds
		if t >= 1 then
			current.Head:Destroy()
			current.Tail:Destroy()
			current.Beam:Destroy()
			shooting = nil
			return
		end
		local function at(u: number): Vector3
			local p = current.From:Lerp(current.To, math.clamp(u, 0, 1))
			return skyPoint(eye, Vector2.new(p.X, p.Y))
		end
		current.Head.WorldPosition = at(t)
		current.Tail.WorldPosition = at(t - 0.18)
		current.Beam.Transparency = NumberSequence.new(math.sin(t * math.pi) * -1 + 1, 1)
	end
end

function SkyController:Start()
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if camera == nil then
			return
		end
		local night = AtmosphereController.GetNightBlend()
		local state = Cycle.GetState()
		if night > 0.01 and state.Constellation.Id ~= shownId then
			build(state.Constellation)
		end
		local visible = night > 0.01
		local eye = camera.CFrame.Position
		local time = os.clock()
		for index, star in stars do
			star.Gui.Enabled = visible
			if visible then
				star.Attachment.WorldPosition = skyPoint(eye, star.Offset)
				local twinkle = 1 + math.sin(time * 1.7 + index * 2.3) * Sky.Twinkle
				local size = star.Size * twinkle
				star.Gui.Size = UDim2.fromOffset(size, size)
				star.Image.ImageTransparency = 1 - night
			end
		end
		for _, beam in lines do
			beam.Enabled = visible
			if visible then
				beam.Transparency = NumberSequence.new(1 - night * (1 - Sky.LineTransparency))
			end
		end
		updateShootingStar(eye, night)
	end)
end

return SkyController
