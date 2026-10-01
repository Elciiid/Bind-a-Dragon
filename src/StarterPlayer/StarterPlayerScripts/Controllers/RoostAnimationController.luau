--!strict
-- Makes roost dragons roam their pen, locally on each client (purely visual; the server only spawns them).
-- Each dragon model has attributes from its evolution stage (Config/Evolution): Movement ("Hop" | "Walk" | "Fly"),
-- MoveSpeed, FlyHeight (its own cruise height) and PerchSize. The pen comes from the plot's RoamCenter / RoamRadius
-- attributes; walkers stay in their stage's zone (model attribute "Zone", e.g. the nesting ground; Shared/RoostZones)
-- when the plot has one.
--   Hop:  wanders with little jumps, pausing now and then (Hatchlings)
--   Walk: wanders with a slight bob, pausing now and then (Drakes)
--   Fly:  circles at its FlyHeight with swoops now and then, banking into turns, nose up/down as it climbs/dives
--         (Dragons, Elders). Fliers take turns (Config/Roost.Turns): at most MaxAirborne of one pen fly at once; after
--         its flight a flier lands on a free perch (parts named "Perch" in the plot's "Perches" folder, big enough for
--         it: attribute Size >= PerchSize) or lies down on a free spot in the meadow zone, rests, and takes off again
--         when the sky has room. Each client keeps its own perch/spot reservations, so two dragons never share one on
--         a screen. Fliers of one pen steer apart when they come too close at about the same height
--         (Config/Roost.Separation).
-- Real dragon art with a bone map in Config/DragonRigs (by the model's SpeciesId/Stage attributes) also moves its
-- bones (Controllers/DragonRig): flap bursts and glides, hovering beats at take off and landing, roars in the air;
-- perched or lying down: breathing, looking around and idle actions (stretch, roar, yawn, shake, preen, tail flick)
-- picked by weight (Config/DragonRigs.Actions). Bones are animated fully near the camera, simply (wings, tail, head)
-- farther out, and not at all beyond that (Config/DragonRigs distances; shorter with Low effects).

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
local Turns = RoostConfig.Turns

local PLOT_TAG = "RoostPlot"
local SCAN_INTERVAL = 0.5 -- how often to look for new/removed dragon models
local ANIMATE_DISTANCE = 350 -- dragons farther than this from the camera are left still (saves work)
local TURN_SPEED = 3 -- how fast headings turn toward the target (higher = sharper)
local HOP_HEIGHT = 1.2
local HOP_RATE = 7 -- hops per ~second while moving
local FLY_BOB = 1.2 -- studs of up/down drift while flying
local MAX_BANK = math.rad(25)
local LAND_DISTANCE = 1.2 -- studs from the perch/spot that count as landed
local TAKEOFF_SHARE = 0.6 -- a flier counts as taking off (slow, hovering beats) below this share of its FlyHeight
local CLIMB_FOR_FULL_PITCH = 8 -- studs/s of climb (or dive) that tilt the body the full BodyPitch

type Roamer = {
	Model: Model,
	Plot: Model,
	Avoid: { Center: Vector3, Radius: number, Height: number }?, -- the centerpiece: fliers below Height steer around it
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
	-- fliers: "Fly", "Landing" (heading for a perch), "Perched", "Descending" (heading for a ground spot), "Resting"
	State: string,
	Perch: BasePart?, -- the perch it is landing on or resting on
	Spot: Vector3?, -- the ground spot it is heading for or lying on
	SpotAltitude: number,
	FlightLeft: number, -- seconds of its flying turn left
	RestLeft: number, -- seconds of its rest left
	TakingOff: boolean,
	SwoopLeft: number, -- seconds until the next swoop
	SwoopT: number, -- progress 0..1 of a swoop, -1 = none
	RoarLeft: number, -- seconds until the next roar in the air
	ActionLeft: number, -- seconds until the next idle action (perched/resting)
	ActionSeconds: number,
	LookYaw: number, -- where the head wants to look (degrees; the pose eases toward it)
	LookPitch: number,
	HoverGoal: number,
	Height: number, -- last pivot height above GroundY (for the climb rate)
	Pitch: number, -- -1..1 smoothed climb/dive
	Footprint: number, -- half its larger horizontal size (wings included), for separation and rest spots
	BodyHeight: number,
	Rig: DragonRig.Rig?,
	Pose: DragonRig.Pose,
	Moved: number, -- studs moved this frame (drives the walking gait)
	Climb: number, -- extra height while passing over a crowded neighbour (separation)
	Crowded: boolean, -- set by separation() when a lower neighbour is too close
	Frame: number,
	-- mesh detail (Config/DragonRigs LodPart / LodDistance / HideDistance / LowEffectsMaxVisible)
	Saved: { [BasePart]: number }, -- original Transparency of every part
	Body: BasePart?, -- the full-detail mesh (PrimaryPart), when the model has a LOD mesh
	Lod: BasePart?, -- the low-poly mesh
	LodBones: { [string]: Bone },
	Mode: string, -- "Full" | "Lod" | "Hidden" ("" = not set yet)
	Distance: number, -- last distance to the camera
	CapHidden: boolean, -- Low effects: not among the nearest LowEffectsMaxVisible of its sanctuary
}

local RoostAnimationController = {}

local roamers: { [Model]: Roamer } = {}
local perchTaken: { [BasePart]: Roamer } = {}
local rng = Random.new()

local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.FilterDescendantsInstances = { workspace.Terrain }

local function between(range: NumberRange): number
	return rng:NextNumber(range.Min, range.Max)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function pickTarget(roamer: Roamer): Vector3
	local angle = rng:NextNumber(0, 2 * math.pi)
	local distance = rng:NextNumber(0.2, 0.85) * roamer.Radius
	return roamer.Center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

local function isAirborne(roamer: Roamer): boolean
	return roamer.State == "Fly" or roamer.State == "Landing" or roamer.State == "Descending"
end

local function airborneCount(plot: Model): number
	local count = 0
	for _, other in roamers do
		if other.Plot == plot and other.Movement == "Fly" and isAirborne(other) then
			count += 1
		end
	end
	return count
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
	if folder == nil or roamer.PerchSize <= 0 then
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

-- A ground spot to lie down on: in the meadow zone (else the middle of the pen), clear of the nesting ground and of
-- the other resters' spots. Falls back to the roomiest spot tried.
local function restSpot(roamer: Roamer): Vector3
	local meadowCenter, meadowRadius = RoostZones.Get(roamer.Plot, "Meadow", roamer.FloorY)
	local nestCenter, nestRadius = RoostZones.Get(roamer.Plot, "Nest", roamer.FloorY)
	local best, bestGap = roamer.Center, -math.huge
	for try = 1, 24 do
		local spot = if meadowCenter and try <= 12
			then RoostZones.RandomSpot(meadowCenter, meadowRadius, 0, rng)
			else RoostZones.RandomSpot(roamer.Center, roamer.Radius * Turns.RestRadius, 0, rng)
		local gap = math.huge
		if nestCenter then
			gap = (flat(spot - nestCenter)).Magnitude - nestRadius - roamer.Footprint
		end
		for _, other in roamers do
			local otherSpot = if other ~= roamer and other.Plot == roamer.Plot then other.Spot else nil
			if otherSpot then
				gap = math.min(gap, (flat(spot - otherSpot)).Magnitude - roamer.Footprint - other.Footprint - Turns.RestSpacing)
			end
		end
		if gap >= 0 then
			return spot
		elseif gap > bestGap then
			best, bestGap = spot, gap
		end
	end
	return best
end

local function groundAltitude(roamer: Roamer, spot: Vector3): number
	local hit = workspace:Raycast(Vector3.new(spot.X, roamer.FloorY + 60, spot.Z), Vector3.new(0, -160, 0), terrainParams)
	return if hit then hit.Position.Y - roamer.GroundY else roamer.FloorY - roamer.GroundY
end

local function perchAltitude(roamer: Roamer, perch: BasePart): number
	return perch.Position.Y - roamer.FloorY
end

local function perchYaw(perch: BasePart): number
	local look = perch.CFrame.LookVector
	return math.atan2(-look.X, -look.Z)
end

local function startAction(roamer: Roamer, name: string)
	local action = RigConfig.Actions[name]
	roamer.Pose.Action = name
	roamer.Pose.ActionT = 0
	roamer.ActionSeconds = action.Seconds
end

-- An idle action for a perched ("Perch") or lying ("Rest") dragon, picked by weight. Look just turns the head.
local function idleAction(roamer: Roamer, kind: string)
	local total = 0
	for _, action in RigConfig.Actions do
		total += (action :: any)[kind]
	end
	local roll = rng:NextNumber(0, total)
	local picked = "Look"
	for name, action in RigConfig.Actions do
		roll -= (action :: any)[kind]
		if roll <= 0 then
			picked = name
			break
		end
	end
	if picked == "Look" then
		roamer.LookYaw = rng:NextNumber(-RigConfig.LookYaw, RigConfig.LookYaw)
		roamer.LookPitch = rng:NextNumber(-0.5, 1) * RigConfig.LookPitch
		roamer.ActionLeft = between(RigConfig.ActionEvery)
	else
		startAction(roamer, picked)
		roamer.ActionLeft = between(RigConfig.ActionEvery) + RigConfig.Actions[picked].Seconds
	end
end

-- End of a flying turn: head for a free perch (PerchShare of the time) or a spot on the ground.
local function startRest(roamer: Roamer)
	local perch = if rng:NextNumber() < Turns.PerchShare then freePerch(roamer) else nil
	if perch then
		perchTaken[perch] = roamer
		roamer.Perch = perch
		roamer.State = "Landing"
		roamer.Target = flat(perch.Position)
	else
		local spot = restSpot(roamer)
		roamer.Spot = spot
		roamer.SpotAltitude = groundAltitude(roamer, spot)
		roamer.State = "Descending"
		roamer.Target = flat(spot)
	end
end

local function arrive(roamer: Roamer)
	roamer.Position = flat(roamer.Target)
	roamer.State = if roamer.State == "Landing" then "Perched" else "Resting"
	roamer.RestLeft = between(Turns.RestSeconds)
	roamer.ActionLeft = between(RigConfig.ActionEvery)
	roamer.Pose.Action = nil
end

local function takeOff(roamer: Roamer)
	releasePerch(roamer)
	roamer.Spot = nil
	roamer.State = "Fly"
	roamer.FlightLeft = between(Turns.FlightSeconds)
	roamer.TakingOff = true
	roamer.Target = pickTarget(roamer)
	roamer.SwoopLeft = between(RigConfig.SwoopEvery)
	roamer.LookYaw, roamer.LookPitch = 0, 0
	roamer.Pose.Action = nil
end

-- Shows the full mesh, the LOD mesh or nothing (client-side Transparency; the server never sees it).
local function copyLodBones(roamer: Roamer)
	local rig = roamer.Rig
	if rig == nil then
		return
	end
	for name, lodBone in roamer.LodBones do
		local bone = rig.Bones[name]
		if bone then
			lodBone.Transform = bone.Transform
		end
	end
end

local function setMode(roamer: Roamer, mode: string)
	if roamer.Mode == mode then
		return
	end
	roamer.Mode = mode
	local lod, body = roamer.Lod, roamer.Body
	for part, original in roamer.Saved do
		local hide = mode == "Hidden" or (lod ~= nil and ((mode == "Lod" and part == body) or (mode ~= "Lod" and part == lod)))
		part.Transparency = if hide then 1 else original
	end
	if mode == "Lod" then
		copyLodBones(roamer)
	end
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
	local lodFound = model:FindFirstChild(RigConfig.LodPart, true)
	local lodPart = if lodFound and lodFound:IsA("MeshPart") then lodFound else nil
	local lodBones: { [string]: Bone } = {}
	local saved: { [BasePart]: number } = {}
	for _, part in parts do
		saved[part] = part.Transparency
	end
	if lodPart then
		for _, d in lodPart:GetDescendants() do
			if d:IsA("Bone") then
				d.Transform = CFrame.identity
				lodBones[d.Name] = d
			end
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
		Avoid = (function()
			local avoidCenter, avoidRadius = RoostZones.Get(plot, "Center", center.Y)
			local avoidHeight = plot:GetAttribute("CenterHeight")
			return if avoidCenter and type(avoidHeight) == "number" then { Center = avoidCenter, Radius = avoidRadius, Height = avoidHeight } else nil
		end)(),
		Parts = parts,
		Offsets = offsets,
		Center = zoneCenter or center,
		Radius = if zoneCenter then zoneRadius else radius,
		FloorY = center.Y,
		GroundY = pivot.Position.Y,
		Position = flat(pivot.Position),
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
		Spot = nil,
		SpotAltitude = 0,
		FlightLeft = 0,
		RestLeft = 0,
		TakingOff = true,
		SwoopLeft = between(RigConfig.SwoopEvery),
		SwoopT = -1,
		RoarLeft = between(RigConfig.AirRoarEvery),
		ActionLeft = between(RigConfig.ActionEvery),
		ActionSeconds = 1,
		LookYaw = 0,
		LookPitch = 0,
		HoverGoal = 0,
		Height = 0,
		Pitch = 0,
		Footprint = math.max(size.X, size.Z) / 2,
		BodyHeight = size.Y,
		Rig = if rigConfig then DragonRig.Build(model, rigConfig, lodPart) else nil,
		Pose = {
			Air = 0,
			Flap = rng:NextNumber(0, 5),
			Gait = 0,
			Walk = 0,
			Clock = rng:NextNumber(0, 10),
			Rest = 0,
			Hover = 0,
			Turn = 0,
			Pitch = 0,
			LookYaw = 0,
			LookPitch = 0,
			Action = nil,
			ActionT = 0,
			Seed = rng:NextInteger(0, 999),
		},
		Moved = 0,
		Climb = 0,
		Crowded = false,
		Frame = rng:NextInteger(0, 10),
		Saved = saved,
		Body = if lodPart then model.PrimaryPart else nil,
		Lod = lodPart,
		LodBones = lodBones,
		Mode = "",
		Distance = 0,
		CapHidden = false,
	}
	roamer.Target = pickTarget(roamer)
	if movement == "Fly" then
		if airborneCount(plot) < Turns.MaxAirborne then
			-- staggered first flights, so the turns don't all swap at once
			roamer.FlightLeft = rng:NextNumber(Turns.FlightSeconds.Min * 0.3, Turns.FlightSeconds.Max)
		else
			-- the sky is full: start out resting (on a free perch or lying on the ground)
			local perch = if rng:NextNumber() < Turns.PerchShare then freePerch(roamer) else nil
			if perch then
				perchTaken[perch] = roamer
				roamer.Perch = perch
				roamer.State = "Perched"
				roamer.Position = flat(perch.Position)
				roamer.Altitude = perchAltitude(roamer, perch)
				roamer.Yaw = perchYaw(perch)
			else
				local spot = restSpot(roamer)
				roamer.Spot = spot
				roamer.SpotAltitude = groundAltitude(roamer, spot)
				roamer.State = "Resting"
				roamer.Position = flat(spot)
				roamer.Altitude = roamer.SpotAltitude
				roamer.Pose.Rest = 1
			end
			roamer.Height = roamer.Altitude
			roamer.TakingOff = false
			roamer.RestLeft = rng:NextNumber(0.2, 1) * Turns.RestSeconds.Max
		end
	end
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
-- flags the roamer as crowded when the too-close neighbour is below it (it then climbs over, see stepFlier()).
local function separation(roamer: Roamer): Vector3
	local push = Vector3.zero
	local myHeight = roamer.Altitude
	roamer.Crowded = false
	for _, other in roamers do
		if other ~= roamer and other.Plot == roamer.Plot and other.Movement == "Fly" and isAirborne(other) then
			local dx = flat(roamer.Position - other.Position)
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
	local avoid = roamer.Avoid
	if avoid and roamer.Altitude < avoid.Height + roamer.BodyHeight / 2 then
		local dx = flat(roamer.Position - avoid.Center)
		local distance = dx.Magnitude
		local reach = avoid.Radius + roamer.Footprint * 0.5
		if distance < reach * 1.4 then
			local away = if distance > 0.01 then dx / distance else Vector3.new(math.cos(roamer.Phase), 0, math.sin(roamer.Phase))
			push += away * (1.4 - distance / reach) * Separation.CenterWeight
		end
	end
	return push
end

-- Walkers and hoppers: wander their zone, pausing now and then. Returns the height above GroundY.
local function stepWalker(roamer: Roamer, dt: number): number
	local moving = true
	if roamer.Wait > 0 then
		roamer.Wait -= dt
		moving = false
	else
		local toTarget = flat(roamer.Target - roamer.Position)
		if toTarget.Magnitude < 1.5 then
			roamer.Target = pickTarget(roamer)
			roamer.Wait = rng:NextNumber(0.8, 3) -- stop and look around
			moving = false
			toTarget = flat(roamer.Target - roamer.Position)
		end
		roamer.Turn = turnTowards(roamer, math.atan2(-toTarget.X, -toTarget.Z), dt)
		if moving then
			roamer.Position += Vector3.new(-math.sin(roamer.Yaw), 0, -math.cos(roamer.Yaw)) * roamer.Speed * dt
		end
	end
	if roamer.Movement == "Hop" then
		return if moving then math.abs(math.sin(roamer.Phase * HOP_RATE)) * HOP_HEIGHT else 0
	end
	return if moving then math.abs(math.sin(roamer.Phase * 6)) * 0.15 else 0
end

-- Fliers: the turn-taking state machine, steering, and height. Returns the height above GroundY.
local function stepFlier(roamer: Roamer, dt: number): number
	local pose = roamer.Pose

	-- whose turn it is
	if roamer.State == "Fly" then
		roamer.FlightLeft -= dt
		if roamer.FlightLeft <= 0 and not roamer.TakingOff then
			startRest(roamer)
		end
	elseif roamer.State == "Perched" or roamer.State == "Resting" then
		roamer.RestLeft -= dt
		local perchGone = roamer.State == "Perched" and (roamer.Perch == nil or (roamer.Perch :: BasePart).Parent == nil)
		if perchGone or roamer.RestLeft <= 0 then
			if perchGone or airborneCount(roamer.Plot) < Turns.MaxAirborne then
				takeOff(roamer)
			else
				roamer.RestLeft = between(Turns.RetrySeconds)
			end
		end
	elseif roamer.State == "Landing" and (roamer.Perch == nil or (roamer.Perch :: BasePart).Parent == nil) then
		releasePerch(roamer)
		startRest(roamer) -- the perch streamed out: pick again (ground if nothing is free)
	end
	local state = roamer.State
	local landing = state == "Landing" or state == "Descending"
	local resting = state == "Perched" or state == "Resting"

	-- idle actions while perched/lying (once settled), roars and swoops in flight
	if resting then
		if pose.Air < 0.1 then
			roamer.ActionLeft -= dt
			if roamer.ActionLeft <= 0 and pose.Action == nil then
				idleAction(roamer, if state == "Perched" then "Perch" else "Rest")
			end
		end
	elseif state == "Fly" and not roamer.TakingOff then
		roamer.RoarLeft -= dt
		if roamer.RoarLeft <= 0 and pose.Action == nil then
			startAction(roamer, "Roar")
			roamer.RoarLeft = between(RigConfig.AirRoarEvery)
		end
		if roamer.SwoopT < 0 then
			roamer.SwoopLeft -= dt
			if roamer.SwoopLeft <= 0 then
				roamer.SwoopT = 0
			end
		end
	end
	if roamer.SwoopT >= 0 then
		roamer.SwoopT += dt / RigConfig.SwoopSeconds
		if roamer.SwoopT >= 1 or state ~= "Fly" then
			roamer.SwoopT = -1
			roamer.SwoopLeft = between(RigConfig.SwoopEvery)
		end
	end
	local swoop = if roamer.SwoopT >= 0 then math.sin(math.pi * roamer.SwoopT) else 0

	-- steering
	local distance = flat(roamer.Target - roamer.Position).Magnitude
	roamer.HoverGoal = 0
	if state == "Perched" then
		turnTowards(roamer, perchYaw(roamer.Perch :: BasePart), dt)
		roamer.Turn = 0
	elseif resting then
		roamer.Turn = 0
	elseif landing and distance < LAND_DISTANCE then
		arrive(roamer)
		roamer.Turn = 0
	else
		if not landing and distance < 1.5 then
			roamer.Target = pickTarget(roamer)
		end
		local toTarget = flat(roamer.Target - roamer.Position)
		distance = toTarget.Magnitude
		-- turn toward the target (steering away from fliers that are too close), then move forward along the heading
		-- (smooth arcs); landing fliers slow down on the final approach and don't steer away
		local finalApproach = landing and distance < PerchConfig.GlideDistance
		local push = if finalApproach then Vector3.zero else separation(roamer)
		local wanted = (if distance > 0.01 then toTarget / distance else Vector3.zero) + push * Separation.TurnWeight
		local turn = turnTowards(roamer, math.atan2(-wanted.X, -wanted.Z), dt)
		if landing and distance < 5 then
			-- ease straight onto the perch/spot (never orbits it)
			local goal = Vector3.new(roamer.Target.X, 0, roamer.Target.Z)
			roamer.Position = roamer.Position:Lerp(goal, math.min(1, dt * 2.5))
		else
			local speed = roamer.Speed * (1 + 0.3 * swoop)
			if landing then
				speed *= math.clamp(distance / 8, 0.35, 1)
			end
			if roamer.TakingOff then
				speed *= math.clamp(roamer.Altitude / (roamer.FlyHeight * TAKEOFF_SHARE), 0.15, 1)
			end
			local forward = Vector3.new(-math.sin(roamer.Yaw), 0, -math.cos(roamer.Yaw))
			roamer.Position += (forward + push * Separation.Push) * speed * dt
		end
		roamer.Turn = turn
		if finalApproach then
			roamer.HoverGoal = 1 - distance / PerchConfig.GlideDistance
		end
	end

	-- height: settle onto the perch/ground, glide down to it, or cruise (climbing over crowded neighbours, swooping)
	state = roamer.State
	local height
	if state == "Perched" or state == "Resting" then
		local surface = if state == "Perched" and roamer.Perch then perchAltitude(roamer, roamer.Perch) else roamer.SpotAltitude
		roamer.Altitude += (surface - roamer.Altitude) * math.min(1, dt * 4)
		height = roamer.Altitude
	elseif state == "Landing" or state == "Descending" then
		local surface = if state == "Landing" and roamer.Perch then perchAltitude(roamer, roamer.Perch) else roamer.SpotAltitude
		local glide = math.clamp(distance / PerchConfig.GlideDistance, 0, 1)
		local wanted = if glide >= 1
			then math.max(roamer.FlyHeight, surface + PerchConfig.ApproachHeight)
			else surface + PerchConfig.ApproachHeight * glide
		roamer.Altitude += (wanted - roamer.Altitude) * math.min(1, dt * 2.5)
		height = roamer.Altitude + math.sin(roamer.Phase * 1.3) * FLY_BOB * glide
	else
		local climbTarget = if roamer.Crowded then Separation.Climb else 0
		roamer.Climb += math.clamp(climbTarget - roamer.Climb, -Separation.ClimbRate * dt, Separation.ClimbRate * dt)
		local cruise = roamer.FlyHeight + roamer.Climb - RigConfig.SwoopDepth * swoop
		roamer.Altitude += (cruise - roamer.Altitude) * math.min(1, dt)
		local lift = math.clamp(roamer.Altitude / roamer.FlyHeight, 0, 1)
		if roamer.TakingOff then
			roamer.HoverGoal = 1 - math.clamp(roamer.Altitude / (roamer.FlyHeight * TAKEOFF_SHARE), 0, 1)
			if roamer.Altitude >= roamer.FlyHeight * TAKEOFF_SHARE then
				roamer.TakingOff = false
			end
		end
		height = roamer.Altitude + math.sin(roamer.Phase * 1.3) * FLY_BOB * lift
	end
	return height
end

-- Bone pose for real art (also the body pitch for every flier): blends and clocks.
local function updatePose(roamer: Roamer, dt: number)
	local p = roamer.Pose
	local airborne = roamer.Movement == "Fly" and isAirborne(roamer)
	local blend = math.min(1, dt / RigConfig.TransitionSeconds)
	p.Air += ((if airborne then 1 else 0) - p.Air) * blend
	p.Rest += ((if roamer.State == "Resting" and p.Air < 0.5 then 1 else 0) - p.Rest) * blend * 0.5 -- lies down slowly
	p.Walk += ((if roamer.Moved > 0.001 and not airborne then 1 else 0) - p.Walk) * blend
	p.Hover += (roamer.HoverGoal - p.Hover) * math.min(1, dt * 3)
	p.Turn += (math.clamp(roamer.Turn / 0.8, -1, 1) - p.Turn) * math.min(1, dt * 4)
	p.Pitch = roamer.Pitch
	p.Flap += dt * p.Air
	p.Gait += roamer.Moved * RigConfig.StepsPerStud
	p.Clock += dt
	local look = math.min(1, dt * 2.5)
	p.LookYaw += (roamer.LookYaw - p.LookYaw) * look
	p.LookPitch += (roamer.LookPitch - p.LookPitch) * look
	if p.Action then
		p.ActionT += dt / math.max(roamer.ActionSeconds, 0.1)
		if p.ActionT >= 1 then
			p.Action = nil
			p.ActionT = 0
		end
	end
end

local function step(roamer: Roamer, dt: number)
	roamer.Phase += dt
	local flying = roamer.Movement == "Fly"
	local before = roamer.Position
	local height = if flying then stepFlier(roamer, dt) else stepWalker(roamer, dt)
	roamer.Moved = flat(roamer.Position - before).Magnitude

	-- climb rate -> nose up/down (fliers in the air)
	local climbRate = (height - roamer.Height) / math.max(dt, 1 / 240)
	roamer.Height = height
	local pitchGoal = if flying and isAirborne(roamer) then math.clamp(climbRate / CLIMB_FOR_FULL_PITCH, -1, 1) else 0
	roamer.Pitch += (pitchGoal - roamer.Pitch) * math.min(1, dt * 3)
	updatePose(roamer, dt)

	local pose = roamer.Pose
	local roll = 0
	if roamer.Rig then
		height += DragonRig.Heave(pose) - RigConfig.RestDrop * roamer.BodyHeight * pose.Rest
		if pose.Action == "Shake" then
			roll = math.rad(math.sin(pose.Clock * 30) * RigConfig.ShakeRoll * (1 - pose.ActionT))
		end
	end
	-- fliers lean into their turns and tilt with the climb (not while perched/resting)
	local bank = if flying then math.clamp(-roamer.Turn * 1.5, -MAX_BANK, MAX_BANK) * pose.Air else 0
	local pitch = if flying then math.rad(RigConfig.BodyPitch * roamer.Pitch) else 0
	local pivot = CFrame.new(roamer.Position.X, roamer.GroundY + height, roamer.Position.Z)
		* CFrame.Angles(0, roamer.Yaw, 0)
		* CFrame.Angles(pitch, 0, bank + roll)

	if roamer.Mode == "Hidden" then
		return -- not drawn: the simulation goes on (perches, turns) but the parts are not moved
	end
	local cframes = table.create(#roamer.Parts)
	for index, offset in roamer.Offsets do
		cframes[index] = pivot * offset
	end
	workspace:BulkMoveTo(roamer.Parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Low effects: only the nearest LowEffectsMaxVisible dragons of each sanctuary are drawn.
local function rankVisible()
	if not EffectsQuality.IsLow() then
		for _, roamer in roamers do
			roamer.CapHidden = false
		end
		return
	end
	local byPlot: { [Model]: { Roamer } } = {}
	for model, roamer in roamers do
		if model.Parent ~= nil then
			local list = byPlot[roamer.Plot]
			if list == nil then
				list = {}
				byPlot[roamer.Plot] = list
			end
			table.insert(list, roamer)
		end
	end
	for _, list in byPlot do
		table.sort(list, function(a, b)
			return a.Distance < b.Distance
		end)
		for rank, roamer in list do
			roamer.CapHidden = rank > RigConfig.LowEffectsMaxVisible
		end
	end
end

-- Full mesh, LOD mesh (Elders with a LodPart, beyond LodDistance) or hidden (beyond HideDistance, or over the Low-effects cap),
-- with a little hysteresis so a dragon on the border does not flicker.
local function wantedMode(roamer: Roamer, distance: number): string
	local hideAt, lodAt = RigConfig.HideDistance, RigConfig.LodDistance
	if roamer.Mode == "Hidden" then
		hideAt -= RigConfig.LodMargin
	elseif roamer.Mode == "Lod" then
		lodAt -= RigConfig.LodMargin
	end
	if roamer.CapHidden or distance >= hideAt then
		return "Hidden"
	elseif roamer.Lod ~= nil and distance >= lodAt then
		return "Lod"
	end
	return "Full"
end

function RoostAnimationController:Start()
	local sinceScan = SCAN_INTERVAL
	local sinceRank = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceScan += dt
		sinceRank += dt
		if sinceScan >= SCAN_INTERVAL then
			sinceScan = 0
			scan()
		end
		if sinceRank >= 0.3 then
			sinceRank = 0
			rankVisible()
		end
		local camera = workspace.CurrentCamera
		local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
		local scale = if EffectsQuality.IsLow() then RigConfig.LowEffectsScale else 1
		local fullDistance, simpleDistance = RigConfig.FullDistance * scale, RigConfig.SimpleDistance * scale
		for model, roamer in roamers do
			if model.Parent == nil then
				continue
			end
			local distance = (roamer.Position - flat(cameraPosition)).Magnitude
			roamer.Distance = (Vector3.new(roamer.Position.X, roamer.GroundY + roamer.Height, roamer.Position.Z) - cameraPosition).Magnitude
			setMode(roamer, wantedMode(roamer, roamer.Distance))
			if distance >= ANIMATE_DISTANCE then
				continue
			end
			step(roamer, dt)
			local rig = roamer.Rig
			if rig and roamer.Mode ~= "Hidden" then
				roamer.Frame += 1
				local applied = false
				if distance < fullDistance then
					DragonRig.Apply(rig, roamer.Pose, if scale < 1 then "Simple" else "Full")
					applied = true
				elseif distance < simpleDistance and roamer.Frame % RigConfig.SimpleEvery == 0 then
					DragonRig.Apply(rig, roamer.Pose, "Simple")
					applied = true
				end
				if applied and roamer.Mode == "Lod" then
					copyLodBones(roamer)
				end
			end
		end
	end)
end

return RoostAnimationController
