--!strict
-- Makes roost dragons roam their pen, locally on each client (purely visual; the server only spawns them).
-- Each dragon model has attributes from its evolution stage (Config/Evolution): Movement ("Hop" | "Walk" | "Fly"),
-- MoveSpeed, FlyHeight (its own cruise height) and PerchSize. The pen comes from the plot's RoamCenter / RoamRadius
-- attributes; walkers stay in their stage's zone (model attribute "Zone", e.g. the nesting ground; Shared/RoostZones)
-- when the plot has one.
--   Hop:  wanders with little jumps, pausing now and then (Hatchlings)
--   Walk: wanders with a slight bob, pausing now and then (Drakes)
--   Fly:  circles and swoops at its FlyHeight, banking into turns (Dragons, Elders); now and then it flies to a free
--         perch (parts named "Perch" in the plot's "Perches" folder, big enough for it: attribute Size >= PerchSize),
--         glides down, lands facing the perch's front, rests, then takes off again (Config/Roost.Perch).
--         Each client keeps its own perch reservations, so two dragons never share a perch on one screen.
--         Fliers of one pen steer apart when they come too close at about the same height (Config/Roost.Separation).
-- Real dragon art with a bone map in Config/DragonRigs (by the model's SpeciesId/Stage attributes) also moves its
-- bones (Controllers/DragonRig): flaps and glides in the air, folded wings when perched, legs and tail. Bones are
-- animated fully near the camera, simply (wings, tail root) farther out, and not at all beyond that
-- (Config/DragonRigs distances; shorter with Low effects).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DragonRig = require(script.Parent.DragonRig)
local EffectsQuality = require(script.Parent.EffectsQuality)
local RoostZones = require(ReplicatedStorage.Shared.RoostZones)
local RoostConfig = require(ReplicatedStorage.Shared.Config.Roost)
local RigConfig = require(ReplicatedStorage.Shared.Config.DragonRigs)

local PerchConfig = RoostConfig.Perch
local Separation = RoostConfig.Separation

local PLOT_TAG = "RoostPlot"
local SCAN_INTERVAL = 0.5 -- how often to look for new/removed dragon models
local ANIMATE_DISTANCE = 350 -- dragons farther than this from the camera are left still (saves work)
local TURN_SPEED = 3 -- how fast headings turn toward the target (higher = sharper)
local HOP_HEIGHT = 1.2
local HOP_RATE = 7 -- hops per ~second while moving
local FLY_BOB = 1.2 -- studs of up/down drift while flying
local MAX_BANK = math.rad(25)
local LAND_DISTANCE = 1.2 -- studs from the perch point that count as landed
local AIR_THRESHOLD = 4 -- studs above the ground at which a flier counts as airborne for its bone pose

type Roamer = {
	Model: Model,
	Plot: Model,
	Parts: { BasePart },
	Offsets: { CFrame },
	Center: Vector3,
	Radius: number,
	FloorY: number, -- the pen floor (RoamCenter.Y)
	GroundY: number, -- pivot height when standing on the floor
	Position: Vector3, -- current XZ position (Y ignored)
	Altitude: number, -- current height above GroundY
	Yaw: number,
	Turn: number, -- how far the heading still has to turn (for banking)
	Target: Vector3,
	Wait: number,
	Phase: number,
	Movement: string,
	Speed: number,
	FlyHeight: number,
	PerchSize: number, -- 0 = never perches
	State: string, -- fliers: "Fly", "Landing" (heading for a perch) or "Perched"
	Perch: BasePart?, -- the perch it is landing on or resting on
	Footprint: number, -- half its larger horizontal size (wings included), for separation
	BodyHeight: number,
	Rig: DragonRig.Rig?,
	Pose: DragonRig.Pose,
	Moved: number, -- studs moved this frame (drives the walking gait)
	Climb: number, -- extra height while passing over a crowded neighbour (separation)
	Crowded: boolean, -- set by separation() when a lower neighbour is too close
	Frame: number,
}

local RoostAnimationController = {}

local roamers: { [Model]: Roamer } = {}
local perchTaken: { [BasePart]: Roamer } = {}
local rng = Random.new()

local function pickTarget(roamer: Roamer): Vector3
	local angle = rng:NextNumber(0, 2 * math.pi)
	local distance = rng:NextNumber(0.2, 0.85) * roamer.Radius
	return roamer.Center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

local function releasePerch(roamer: Roamer)
	local perch = roamer.Perch
	if perch and perchTaken[perch] == roamer then
		perchTaken[perch] = nil
	end
	roamer.Perch = nil
end

-- A random free perch in the roamer's plot that is big enough for it, or nil.
local function freePerch(roamer: Roamer): BasePart?
	local folder = roamer.Plot:FindFirstChild("Perches")
	if folder == nil then
		return nil
	end
	local options = {}
	for _, perch in folder:GetChildren() do
		local size = perch:GetAttribute("Size")
		if perch:IsA("BasePart") and perch.Name == "Perch" and perchTaken[perch] == nil and type(size) == "number" and size >= roamer.PerchSize then
			table.insert(options, perch)
		end
	end
	if #options == 0 then
		return nil
	end
	return options[rng:NextInteger(1, #options)]
end

local function register(model: Model, plot: Model)
	local center = plot:GetAttribute("RoamCenter")
	local radius = plot:GetAttribute("RoamRadius")
	local movement = model:GetAttribute("Movement")
	if typeof(center) ~= "Vector3" or type(radius) ~= "number" or type(movement) ~= "string" then
		return
	end
	local pivot = model:GetPivot()
	local parts, offsets = {}, {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(parts, part)
			table.insert(offsets, pivot:ToObjectSpace(part.CFrame))
		end
	end
	local look = pivot.LookVector
	-- walkers keep to their zone (nesting ground, meadow); fliers roam the whole pen
	local zone = model:GetAttribute("Zone")
	local zoneCenter: Vector3?, zoneRadius: number = nil, 0
	if movement ~= "Fly" and type(zone) == "string" then
		zoneCenter, zoneRadius = RoostZones.Get(plot, zone, center.Y)
	end
	local perchSize = model:GetAttribute("PerchSize")
	local _, size = model:GetBoundingBox()
	local species, stage = model:GetAttribute("SpeciesId"), model:GetAttribute("Stage")
	local rigConfig = if type(species) == "string" and type(stage) == "string" then RigConfig.Rigs[`{species}/{stage}`] else nil
	local roamer: Roamer = {
		Model = model,
		Plot = plot,
		Parts = parts,
		Offsets = offsets,
		Center = zoneCenter or center,
		Radius = if zoneCenter then zoneRadius else radius,
		FloorY = center.Y,
		GroundY = pivot.Position.Y,
		Position = pivot.Position,
		Altitude = 0,
		Yaw = math.atan2(-look.X, -look.Z),
		Turn = 0,
		Target = pivot.Position,
		Wait = rng:NextNumber(0, 1.5),
		Phase = rng:NextNumber(0, 10),
		Movement = movement,
		Speed = (model:GetAttribute("MoveSpeed") :: number?) or 4,
		FlyHeight = (model:GetAttribute("FlyHeight") :: number?) or 0,
		PerchSize = if type(perchSize) == "number" then perchSize else 0,
		State = "Fly",
		Perch = nil,
		Footprint = math.max(size.X, size.Z) / 2,
		BodyHeight = size.Y,
		Rig = if rigConfig then DragonRig.Build(model, rigConfig) else nil,
		Pose = { Air = 0, Flap = rng:NextNumber(0, 5), Gait = 0, Walk = 0, Clock = rng:NextNumber(0, 10) },
		Moved = 0,
		Climb = 0,
		Crowded = false,
		Frame = rng:NextInteger(0, 10),
	}
	roamer.Target = pickTarget(roamer)
	roamers[model] = roamer
end

local function scan()
	for model, roamer in roamers do
		if model.Parent == nil then
			releasePerch(roamer)
			roamers[model] = nil
		end
	end
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		if not plot:IsA("Model") then
			continue
		end
		for _, child in plot:GetChildren() do
			if child:IsA("Model") and roamers[child] == nil and child:GetAttribute("Movement") ~= nil then
				register(child, plot)
			end
		end
	end
end

local function wrapAngle(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

local function turnTowards(roamer: Roamer, wantedYaw: number, dt: number): number
	local turn = wrapAngle(wantedYaw - roamer.Yaw)
	roamer.Yaw += turn * math.min(1, TURN_SPEED * dt)
	return turn
end

-- Sideways push away from other airborne fliers of the same pen that are too close at about the same height; also
-- flags the roamer as crowded when the too-close neighbour is below it (it then climbs over, see step()).
local function separation(roamer: Roamer): Vector3
	local push = Vector3.zero
	local myHeight = roamer.Altitude
	roamer.Crowded = false
	for _, other in roamers do
		if other ~= roamer and other.Plot == roamer.Plot and other.Movement == "Fly" and other.State ~= "Perched" then
			local dx = Vector3.new(roamer.Position.X - other.Position.X, 0, roamer.Position.Z - other.Position.Z)
			local distance = dx.Magnitude
			local minDistance = roamer.Footprint + other.Footprint + Separation.Margin
			local verticalGap = math.abs(myHeight - other.Altitude)
			if distance < minDistance and verticalGap < (roamer.BodyHeight + other.BodyHeight) / 2 then
				local away = if distance > 0.01 then dx / distance else Vector3.new(math.cos(roamer.Phase), 0, math.sin(roamer.Phase))
				push += away * (1 - distance / minDistance)
				if myHeight >= other.Altitude then
					roamer.Crowded = true
				end
			end
		end
	end
	return push
end

local function step(roamer: Roamer, dt: number)
	roamer.Phase += dt
	local flying = roamer.Movement == "Fly"
	local moving = true
	local perch = roamer.Perch
	local before = roamer.Position

	if roamer.State == "Perched" and perch then
		-- resting: face the perch's front, then take off again
		moving = false
		turnTowards(roamer, math.atan2(-perch.CFrame.LookVector.X, -perch.CFrame.LookVector.Z), dt)
		roamer.Turn = 0
		roamer.Wait -= dt
		if roamer.Wait <= 0 or perch.Parent == nil then
			releasePerch(roamer)
			roamer.State = "Fly"
			roamer.Target = pickTarget(roamer)
		end
	elseif roamer.Wait > 0 then
		roamer.Wait -= dt
		moving = false
	else
		if roamer.State == "Landing" and (perch == nil or perch.Parent == nil) then
			releasePerch(roamer)
			roamer.State = "Fly"
			roamer.Target = pickTarget(roamer)
		end
		local toTarget = roamer.Target - roamer.Position
		toTarget = Vector3.new(toTarget.X, 0, toTarget.Z)
		local distance = toTarget.Magnitude
		if roamer.State == "Landing" and distance < LAND_DISTANCE then
			roamer.State = "Perched"
			roamer.Position = Vector3.new(roamer.Target.X, roamer.Position.Y, roamer.Target.Z)
			roamer.Wait = rng:NextNumber(PerchConfig.Seconds.Min, PerchConfig.Seconds.Max)
			moving = false
		elseif roamer.State ~= "Landing" and distance < 1.5 then
			local newPerch = if flying and roamer.PerchSize > 0 and rng:NextNumber() < PerchConfig.Chance then freePerch(roamer) else nil
			if newPerch then
				perchTaken[newPerch] = roamer
				roamer.Perch = newPerch
				roamer.State = "Landing"
				roamer.Target = Vector3.new(newPerch.Position.X, 0, newPerch.Position.Z)
			else
				roamer.Target = pickTarget(roamer)
				if not flying then
					roamer.Wait = rng:NextNumber(0.8, 3) -- walkers stop and look around; fliers keep going
					moving = false
				end
			end
			toTarget = Vector3.new(roamer.Target.X - roamer.Position.X, 0, roamer.Target.Z - roamer.Position.Z)
			distance = toTarget.Magnitude
		end
		if roamer.State ~= "Perched" then
			-- Turn toward the target (steering away from fliers that are too close), then move forward along the
			-- heading (gives smooth arcs). Landing fliers slow down on the final approach and don't steer away.
			local push = Vector3.zero
			local finalApproach = roamer.State == "Landing" and distance < PerchConfig.GlideDistance
			if flying and not finalApproach then
				push = separation(roamer)
			end
			local wanted = (if distance > 0.01 then toTarget / distance else Vector3.zero) + push * Separation.TurnWeight
			local turn = turnTowards(roamer, math.atan2(-wanted.X, -wanted.Z), dt)
			if moving and roamer.State == "Landing" and distance < 5 then
				-- final approach: ease straight onto the perch point (never orbits it)
				local target = Vector3.new(roamer.Target.X, roamer.Position.Y, roamer.Target.Z)
				roamer.Position = roamer.Position:Lerp(target, math.min(1, dt * 2.5))
			elseif moving then
				local speed = roamer.Speed
				if roamer.State == "Landing" then
					speed *= math.clamp(distance / 8, 0.35, 1)
				end
				local forward = Vector3.new(-math.sin(roamer.Yaw), 0, -math.cos(roamer.Yaw))
				roamer.Position += (forward + push * Separation.Push) * speed * dt
			end
			roamer.Turn = turn
		end
	end
	roamer.Moved = Vector3.new(roamer.Position.X - before.X, 0, roamer.Position.Z - before.Z).Magnitude

	-- Height: hop arcs, a small walking bob, flight with a slow drift, or the glide down onto a perch.
	local height
	perch = roamer.Perch
	if flying and roamer.State == "Perched" and perch then
		roamer.Altitude = perch.Position.Y - roamer.FloorY
		height = roamer.Altitude
	elseif flying and roamer.State == "Landing" and perch then
		local perchAltitude = perch.Position.Y - roamer.FloorY
		local distance = Vector3.new(perch.Position.X - roamer.Position.X, 0, perch.Position.Z - roamer.Position.Z).Magnitude
		local glide = math.clamp(distance / PerchConfig.GlideDistance, 0, 1)
		local wanted = if glide >= 1
			then math.max(roamer.FlyHeight, perchAltitude + PerchConfig.ApproachHeight)
			else perchAltitude + PerchConfig.ApproachHeight * glide
		roamer.Altitude += (wanted - roamer.Altitude) * math.min(1, dt * 2.5)
		height = roamer.Altitude + math.sin(roamer.Phase * 1.3) * FLY_BOB * glide
	elseif flying then
		-- climb over a crowded lower neighbour, settle back to the cruise height afterwards
		local climbTarget = if roamer.Crowded then Separation.Climb else 0
		roamer.Climb += math.clamp(climbTarget - roamer.Climb, -Separation.ClimbRate * dt, Separation.ClimbRate * dt)
		roamer.Altitude += (roamer.FlyHeight + roamer.Climb - roamer.Altitude) * math.min(1, dt) -- take off / settle smoothly
		height = roamer.Altitude + math.sin(roamer.Phase * 1.3) * FLY_BOB
	elseif roamer.Movement == "Hop" then
		height = if moving then math.abs(math.sin(roamer.Phase * HOP_RATE)) * HOP_HEIGHT else 0
	else
		height = if moving then math.abs(math.sin(roamer.Phase * 6)) * 0.15 else 0
	end

	-- Fliers lean into their turns (not while perched).
	local bank = if flying and roamer.State ~= "Perched" then math.clamp(-roamer.Turn * 1.5, -MAX_BANK, MAX_BANK) else 0
	local pivot = CFrame.new(roamer.Position.X, roamer.GroundY + height, roamer.Position.Z)
		* CFrame.Angles(0, roamer.Yaw, 0)
		* CFrame.Angles(0, 0, bank)

	local cframes = table.create(#roamer.Parts)
	for index, offset in roamer.Offsets do
		cframes[index] = pivot * offset
	end
	workspace:BulkMoveTo(roamer.Parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Bone pose for real art: airborne blend (wings spread and flap), walking gait, clocks.
local function updatePose(roamer: Roamer, dt: number)
	local p = roamer.Pose
	local airborne = roamer.Movement == "Fly" and roamer.State ~= "Perched" and roamer.Altitude > AIR_THRESHOLD
	local blend = math.min(1, dt / RigConfig.TransitionSeconds)
	p.Air += ((if airborne then 1 else 0) - p.Air) * blend
	p.Walk += ((if roamer.Moved > 0.001 and not airborne then 1 else 0) - p.Walk) * blend
	p.Flap += dt * p.Air
	p.Gait += roamer.Moved * RigConfig.StepsPerStud
	p.Clock += dt
end

function RoostAnimationController:Start()
	local sinceScan = SCAN_INTERVAL
	RunService.Heartbeat:Connect(function(dt)
		sinceScan += dt
		if sinceScan >= SCAN_INTERVAL then
			sinceScan = 0
			scan()
		end
		local camera = workspace.CurrentCamera
		local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
		local scale = if EffectsQuality.IsLow() then RigConfig.LowEffectsScale else 1
		local fullDistance, simpleDistance = RigConfig.FullDistance * scale, RigConfig.SimpleDistance * scale
		for model, roamer in roamers do
			if model.Parent == nil then
				continue
			end
			local distance = (roamer.Position - cameraPosition).Magnitude
			if distance >= ANIMATE_DISTANCE then
				continue
			end
			step(roamer, dt)
			local rig = roamer.Rig
			if rig then
				updatePose(roamer, dt)
				roamer.Frame += 1
				if distance < fullDistance then
					DragonRig.Apply(rig, roamer.Pose, if scale < 1 then "Simple" else "Full")
				elseif distance < simpleDistance and roamer.Frame % RigConfig.SimpleEvery == 0 then
					DragonRig.Apply(rig, roamer.Pose, "Simple")
				end
			end
		end
	end)
end

return RoostAnimationController
