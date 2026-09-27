--!strict
-- Makes roost dragons roam their pen, locally on each client (purely visual; the server only spawns them).
-- Each dragon model has attributes from its evolution stage (Config/Evolution): Movement ("Hop" | "Walk" | "Fly"),
-- MoveSpeed, FlyHeight and PerchSize. The pen comes from the plot's RoamCenter / RoamRadius attributes; walkers stay
-- in their stage's zone (model attribute "Zone", e.g. the nesting ground; Shared/RoostZones) when the plot has one.
--   Hop:  wanders with little jumps, pausing now and then (Hatchlings)
--   Walk: wanders with a slight bob, pausing now and then (Drakes)
--   Fly:  circles and swoops at FlyHeight, banking into turns (Dragons, Elders); now and then it flies to a free
--         perch (parts named "Perch" in the plot's "Perches" folder, big enough for it: attribute Size >= PerchSize),
--         glides down, lands facing the perch's front, rests, then takes off again (Config/Roost.Perch).
--         Each client keeps its own perch reservations, so two dragons never share a perch on one screen.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RoostZones = require(ReplicatedStorage.Shared.RoostZones)
local RoostConfig = require(ReplicatedStorage.Shared.Config.Roost)

local PerchConfig = RoostConfig.Perch

local PLOT_TAG = "RoostPlot"
local SCAN_INTERVAL = 0.5 -- how often to look for new/removed dragon models
local ANIMATE_DISTANCE = 350 -- dragons farther than this from the camera are left still (saves work)
local TURN_SPEED = 3 -- how fast headings turn toward the target (higher = sharper)
local HOP_HEIGHT = 1.2
local HOP_RATE = 7 -- hops per ~second while moving
local FLY_BOB = 1.2 -- studs of up/down drift while flying
local MAX_BANK = math.rad(25)
local LAND_DISTANCE = 1.2 -- studs from the perch point that count as landed

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

local function step(roamer: Roamer, dt: number)
	roamer.Phase += dt
	local flying = roamer.Movement == "Fly"
	local moving = true
	local perch = roamer.Perch

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
			-- Turn toward the target, then move forward along the heading (gives smooth arcs). Landing fliers slow
			-- down on the final approach.
			local turn = turnTowards(roamer, math.atan2(-toTarget.X, -toTarget.Z), dt)
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
				roamer.Position += forward * speed * dt
			end
			roamer.Turn = turn
		end
	end

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
		roamer.Altitude += (roamer.FlyHeight - roamer.Altitude) * math.min(1, dt) -- take off / settle smoothly
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
		for model, roamer in roamers do
			if model.Parent ~= nil and (roamer.Position - cameraPosition).Magnitude < ANIMATE_DISTANCE then
				step(roamer, dt)
			end
		end
	end)
end

return RoostAnimationController
