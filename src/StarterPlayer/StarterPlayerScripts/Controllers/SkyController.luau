--!strict
-- Tonight's constellation drawn in the sky (client only): star sprites joined by glowing lines, in the element's
-- color, fading in at dusk and out at dawn (AtmosphereController night blend). Rare constellations are bigger and
-- brighter. Now and then a shooting star crosses the sky.
-- Like a skybox, the drawing follows the camera's position (not its rotation) at Sky.Distance (far behind everything
-- in the world), so the Spire, buildings, trees, mountains and players hide it. Stars and lines are depth-tested
-- BillboardGuis (never AlwaysOnTop): pixel-sized, so the far distance doesn't shrink them, and not fogged by the
-- Atmosphere, so they stay clear through the night haze. A line is a thin frame in a billboard at its midpoint,
-- stretched and turned each frame to join its two stars on screen.
-- Drawings: Config/Constellations; look: Config/Atmosphere Sky.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AtmosphereController = require(script.Parent.AtmosphereController)
local EffectsQuality = require(script.Parent.EffectsQuality)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local AtmosphereConfig = require(ReplicatedStorage.Shared.Config.Atmosphere)
local Elements = require(ReplicatedStorage.Shared.Config.Elements)

local Sky = AtmosphereConfig.Sky

type Star = { Attachment: Attachment, Gui: BillboardGui, Image: ImageLabel, Offset: Vector2, Size: number }
type Line = { Attachment: Attachment, Gui: BillboardGui, Core: Frame, Glow: Frame?, Gradient: UIGradient? }

local SkyController = {}

local shownId: string? = nil
local stars: { Star } = {}
local lines: { { Line: Line, A: Star, B: Star } } = {}
local scale = 1
local lineColor = Sky.DefaultColor

local shooting: { Line: Line, From: Vector2, To: Vector2, Started: number }? = nil
local nextShootingStar = os.clock() + 20

local function basis(): (Vector3, Vector3, Vector3)
	local forward = Sky.Direction.Unit
	local right = forward:Cross(Vector3.yAxis).Unit
	local up = right:Cross(forward).Unit
	return forward, right, up
end

local function skyDirection(offset: Vector2): Vector3
	local forward, right, up = basis()
	return (forward + right * offset.X * Sky.Span.X * scale + up * offset.Y * Sky.Span.Y * scale).Unit
end

local function skyPoint(eye: Vector3, offset: Vector2): Vector3
	return eye + skyDirection(offset) * Sky.Distance
end

local function billboard(name: string): (Attachment, BillboardGui)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = workspace.Terrain
	local gui = Instance.new("BillboardGui")
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false -- depth-tested: anything in the world hides it
	gui.ClipsDescendants = false
	gui.Adornee = attachment
	gui.Parent = attachment
	return attachment, gui
end

local function bar(parent: Instance, color: Color3, width: number): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(0, width)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	frame.Parent = parent
	return frame
end

local function newLine(color: Color3, width: number, glowWidth: number?): Line
	local attachment, gui = billboard("SkyLine")
	local glow = if glowWidth then bar(gui, color, glowWidth) else nil
	local core = bar(gui, color, width)
	return { Attachment = attachment, Gui = gui, Core = core, Glow = glow, Gradient = nil }
end

-- Stretches a line's billboard between two world points as they appear on screen. False if off-screen behind.
local function placeLine(line: Line, camera: Camera, a: Vector3, b: Vector3): boolean
	local pa = camera:WorldToViewportPoint(a)
	local pb = camera:WorldToViewportPoint(b)
	if pa.Z <= 0 or pb.Z <= 0 then
		line.Gui.Enabled = false
		return false
	end
	line.Gui.Enabled = true
	line.Attachment.WorldPosition = (a + b) / 2
	local delta = Vector2.new(pb.X - pa.X, pb.Y - pa.Y)
	local length = delta.Magnitude
	local rotation = math.deg(math.atan2(delta.Y, delta.X))
	local glowWidth = if line.Glow then line.Glow.Size.Y.Offset else 0
	local side = length + math.max(glowWidth, line.Core.Size.Y.Offset) + 2
	line.Gui.Size = UDim2.fromOffset(side, side)
	line.Core.Size = UDim2.fromOffset(length, line.Core.Size.Y.Offset)
	line.Core.Rotation = rotation
	local glow = line.Glow
	if glow then
		glow.Size = UDim2.fromOffset(length + glowWidth, glowWidth)
		glow.Rotation = rotation
	end
	return true
end

local function clear()
	for _, star in stars do
		star.Attachment:Destroy()
	end
	for _, entry in lines do
		entry.Line.Attachment:Destroy()
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
		local attachment, gui = billboard("SkyStar")
		local size = (if index == 1 then Sky.BrightStarSize else Sky.StarSize) * scale
		gui.Size = UDim2.fromOffset(size, size)
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromScale(1, 1)
		image.Image = Sky.StarImage
		image.ImageColor3 = lineColor:Lerp(Color3.new(1, 1, 1), 0.5)
		image.ZIndex = 2
		image.Parent = gui
		table.insert(stars, { Attachment = attachment, Gui = gui, Image = image, Offset = point, Size = size })
	end
	for _, pair in constellation.Lines :: { { number } } do
		local a, b = stars[pair[1]], stars[pair[2]]
		if a and b then
			local line = newLine(lineColor, Sky.LineWidth * scale, Sky.LineGlowWidth * scale)
			table.insert(lines, { Line = line, A = a, B = b })
		end
	end
end

local function updateShootingStar(camera: Camera, eye: Vector3, night: number)
	local now = os.clock()
	if shooting == nil and night > 0.9 and now >= nextShootingStar and not EffectsQuality.IsLow() then
		local line = newLine(Sky.ShootingStarColor, Sky.ShootingStarWidth, nil)
		local gradient = Instance.new("UIGradient") -- fades from the head (right end) to the tail
		gradient.Transparency = NumberSequence.new(1, 0)
		gradient.Parent = line.Core
		line.Gradient = gradient
		local rng = Random.new()
		local from = Vector2.new(rng:NextNumber(-1.6, 0.4), rng:NextNumber(0.6, 1.1))
		local to = from + Vector2.new(rng:NextNumber(0.9, 1.4), -rng:NextNumber(0.5, 0.8))
		shooting = { Line = line, From = from, To = to, Started = now }
		nextShootingStar = now + rng:NextNumber(Sky.ShootingStarEvery.Min, Sky.ShootingStarEvery.Max)
	end
	local current = shooting
	if current then
		local t = (now - current.Started) / Sky.ShootingStarSeconds
		if t >= 1 then
			current.Line.Attachment:Destroy()
			shooting = nil
			return
		end
		local function at(u: number): Vector3
			return skyPoint(eye, current.From:Lerp(current.To, math.clamp(u, 0, 1)))
		end
		if placeLine(current.Line, camera, at(t - 0.18), at(t)) then
			current.Line.Core.BackgroundTransparency = 1 - math.sin(t * math.pi) * night
		end
	end
end

-- Where tonight's drawn stars appear (empty by day), CeremonyDistance from the camera in the same directions. The
-- binding ceremony pulls these down into the altar.
function SkyController.GetStarPositions(): { Vector3 }
	local positions = {}
	local camera = workspace.CurrentCamera
	if camera == nil then
		return positions
	end
	local eye = camera.CFrame.Position
	for _, star in stars do
		if star.Gui.Enabled then
			table.insert(positions, eye + skyDirection(star.Offset) * Sky.CeremonyDistance)
		end
	end
	return positions
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
		for _, entry in lines do
			local line = entry.Line
			if not visible then
				line.Gui.Enabled = false
			elseif placeLine(line, camera, entry.A.Attachment.WorldPosition, entry.B.Attachment.WorldPosition) then
				line.Core.BackgroundTransparency = 1 - night * (1 - Sky.LineTransparency)
				if line.Glow then
					line.Glow.BackgroundTransparency = 1 - night * (1 - Sky.LineGlowTransparency)
				end
			end
		end
		updateShootingStar(camera, eye, night)
	end)
end

return SkyController
