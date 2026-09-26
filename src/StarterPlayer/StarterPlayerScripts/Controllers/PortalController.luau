--!strict
-- Portal look on this client. Every part tagged "AreaPortal" (the `Surface` in a builder's arch; AreaId attribute =
-- destination) gets: the destination's color as glowing Neon, a soft light, two swirl layers turning in opposite
-- directions and a few rising particles. If the local player hasn't unlocked the destination it is dim gray with no
-- light, swirl or particles, and a small lock + "Rebirth X" shows when close. The area name shows within the world
-- label distance. Looks: Config/Portals; label sizes/distances: Config/UITheme WorldLabels; wording: Config/Text.
-- Teleporting and the unlock check stay on the server (AreaService); this is only visuals.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataController = require(script.Parent.DataController)
local Style = require(script.Parent.UI.Style)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local PortalConfig = require(ReplicatedStorage.Shared.Config.Portals)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local TAG = "AreaPortal"
local WorldLabels = UITheme.WorldLabels

type Portal = {
	Surface: BasePart,
	AreaId: string,
	Color: Color3,
	Light: PointLight,
	Particles: ParticleEmitter,
	Swirls: { ImageLabel }, -- pairs per face: [1] turns forward, [2] turns back
	SwirlGuis: { SurfaceGui },
	Lock: BillboardGui,
}

local PortalController = {}

local portals: { [BasePart]: Portal } = {}
local angle = 0

local function isUnlocked(areaId: string): boolean
	local data = DataController:Get()
	return data ~= nil and DragonStats.IsAreaUnlocked(data, areaId)
end

local function makeSwirlFace(surface: BasePart, face: Enum.NormalId, color: Color3, swirls: { ImageLabel }): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Swirl" .. face.Name
	gui.Face = face
	gui.LightInfluence = 0
	gui.PixelsPerStud = PortalConfig.SwirlPixelsPerStud
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.ClipsDescendants = true
	gui.Parent = surface
	local side = math.max(surface.Size.X, surface.Size.Y) * PortalConfig.SwirlScale * PortalConfig.SwirlPixelsPerStud
	for i = 1, 2 do
		local image = Instance.new("ImageLabel")
		image.Name = "Layer" .. i
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.fromOffset(side * (if i == 1 then 1 else 0.75), side * (if i == 1 then 1 else 0.75))
		image.BackgroundTransparency = 1
		image.Image = PortalConfig.SwirlImage
		image.ImageColor3 = color:Lerp(Color3.new(1, 1, 1), 0.45)
		image.ImageTransparency = PortalConfig.SwirlTransparency + (if i == 2 then 0.15 else 0)
		image.Parent = gui
		table.insert(swirls, image)
	end
	return gui
end

local function makeLabel(surface: BasePart, name: string, size: Vector2, offsetY: number, maxDistance: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.fromOffset(size.X, size.Y)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = maxDistance
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Parent = surface
	return gui
end

-- A small drawn padlock (no image asset needed) with "Rebirth X" next to it.
local function makeLock(surface: BasePart, rebirths: number): BillboardGui
	local gui = makeLabel(surface, "PortalLock", WorldLabels.PortalLock, 0, PortalConfig.LockShowDistance)
	local lock = Instance.new("Frame")
	lock.Name = "Padlock"
	lock.BackgroundTransparency = 1
	lock.Size = UDim2.fromOffset(22, 26)
	lock.Position = UDim2.new(0, 4, 0.5, -13)
	lock.Parent = gui
	local shackle = Instance.new("Frame")
	shackle.BackgroundTransparency = 1
	shackle.Size = UDim2.fromOffset(14, 16)
	shackle.Position = UDim2.fromOffset(4, 0)
	Style.Round(shackle)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = UITheme.Colors.Gold
	stroke.Parent = shackle
	shackle.Parent = lock
	local body = Instance.new("Frame")
	body.BackgroundColor3 = UITheme.Colors.Gold
	body.Size = UDim2.fromOffset(22, 15)
	body.Position = UDim2.fromOffset(0, 11)
	Style.Corner(body, 4)
	body.Parent = lock
	local label = Style.Label(gui, Text.Format(Text.PortalLocked, { rebirths = rebirths }), "Heavy", 16, UITheme.Colors.Text)
	label.Position = UDim2.fromOffset(30, 0)
	label.Size = UDim2.new(1, -30, 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	return gui
end

local function apply(portal: Portal)
	local unlocked = isUnlocked(portal.AreaId)
	local surface = portal.Surface
	surface.Material = Enum.Material.Neon
	surface.Color = if unlocked then portal.Color else PortalConfig.LockedColor
	surface.Transparency = if unlocked then PortalConfig.SurfaceTransparency else PortalConfig.LockedTransparency
	portal.Light.Enabled = unlocked
	portal.Particles.Enabled = unlocked
	for _, gui in portal.SwirlGuis do
		gui.Enabled = unlocked and PortalConfig.SwirlImage ~= ""
	end
	portal.Lock.Enabled = not unlocked
end

local function setup(instance: Instance)
	if not instance:IsA("BasePart") or portals[instance] then
		return
	end
	local areaId = instance:GetAttribute("AreaId")
	if type(areaId) ~= "string" then
		return
	end
	local area = Areas[areaId]
	local color = PortalConfig.Colors[areaId] or PortalConfig.DefaultColor

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = PortalConfig.LightBrightness
	light.Range = PortalConfig.LightRange
	light.Shadows = false
	light.Parent = instance

	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Color = ColorSequence.new(color)
	particles.LightEmission = 1
	particles.Rate = PortalConfig.ParticleRate
	particles.Speed = NumberRange.new(PortalConfig.ParticleSpeed * 0.6, PortalConfig.ParticleSpeed)
	particles.Lifetime = NumberRange.new(PortalConfig.ParticleLifetime * 0.7, PortalConfig.ParticleLifetime)
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, PortalConfig.ParticleSize),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Transparency = NumberSequence.new(0.2, 1)
	particles.EmissionDirection = Enum.NormalId.Top
	particles.SpreadAngle = Vector2.new(15, 15)
	particles.Acceleration = Vector3.new(0, 0.5, 0)
	particles.Parent = instance

	local swirls = {}
	local guis = {}
	if PortalConfig.SwirlImage ~= "" then
		table.insert(guis, makeSwirlFace(instance, Enum.NormalId.Front, color, swirls))
		table.insert(guis, makeSwirlFace(instance, Enum.NormalId.Back, color, swirls))
	end

	-- area name above the opening
	local nameGui = makeLabel(instance, "PortalName", WorldLabels.PortalName, instance.Size.Y / 2 + 2, WorldLabels.MaxDistance)
	Style.Label(nameGui, if area then area.Name else areaId, "Title", 20, UITheme.Colors.Title).Size = UDim2.fromScale(1, 1)

	local portal: Portal = {
		Surface = instance,
		AreaId = areaId,
		Color = color,
		Light = light,
		Particles = particles,
		Swirls = swirls,
		SwirlGuis = guis,
		Lock = makeLock(instance, if area then area.RebirthsRequired else 0),
	}
	portals[instance] = portal
	apply(portal)
	instance.Destroying:Connect(function()
		portals[instance] = nil
	end)
end

local function refreshAll()
	for _, portal in portals do
		apply(portal)
	end
end

function PortalController:Start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(setup)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
		if instance:IsA("BasePart") then
			portals[instance] = nil
		end
	end)
	for _, instance in CollectionService:GetTagged(TAG) do
		setup(instance)
	end
	DataController:OnChanged("Rebirths", refreshAll)
	task.spawn(function()
		DataController:WaitForData()
		refreshAll()
	end)

	RunService.RenderStepped:Connect(function(dt)
		angle = (angle + PortalConfig.SwirlSpeed * dt) % 360
		local camera = workspace.CurrentCamera
		if camera == nil then
			return
		end
		local eye = camera.CFrame.Position
		for surface, portal in portals do
			if portal.Particles.Enabled and (surface.Position - eye).Magnitude <= PortalConfig.AnimateWithin then
				for i, image in portal.Swirls do
					image.Rotation = if i % 2 == 1 then angle else -angle * PortalConfig.SwirlCounterRatio
				end
			end
		end
	end)
end

return PortalController
