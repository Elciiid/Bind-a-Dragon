--!strict
-- Makes roost dragons roam their pen, locally on each client (purely visual; the server only spawns them).
-- Each dragon model has attributes from its evolution stage (Config/Evolution): Movement ("Hop" | "Walk" | "Fly"),
-- MoveSpeed and FlyHeight. The pen comes from the plot's RoamCenter / RoamRadius attributes.
--   Hop:  wanders with little jumps, pausing now and then (Hatchlings)
--   Walk: wanders with a slight bob, pausing now and then (Drakes)
--   Fly:  circles and swoops at FlyHeight without stopping, banking into turns (Dragons, Elders)

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local PLOT_TAG = "RoostPlot"
local SCAN_INTERVAL = 0.5 -- how often to look for new/removed dragon models
local ANIMATE_DISTANCE = 350 -- dragons farther than this from the camera are left still (saves work)
local TURN_SPEED = 3 -- how fast headings turn toward the target (higher = sharper)
local HOP_HEIGHT = 1.2
local HOP_RATE = 7 -- hops per ~second while moving
local FLY_BOB = 1.2 -- studs of up/down drift while flying
local MAX_BANK = math.rad(25)

type Roamer = {
	Model: Model,
	Parts: { BasePart },
	Offsets: { CFrame },
	Center: Vector3,
	Radius: number,
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
}

local RoostAnimationController = {}

local roamers: { [Model]: Roamer } = {}
local rng = Random.new()

local function pickTarget(roamer: Roamer): Vector3
	local angle = rng:NextNumber(0, 2 * math.pi)
	local distance = rng:NextNumber(0.2, 0.85) * roamer.Radius
	return roamer.Center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
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
	local roamer: Roamer = {
		Model = model,
		Parts = parts,
		Offsets = offsets,
		Center = center,
		Radius = radius,
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
	}
	roamer.Target = pickTarget(roamer)
	roamers[model] = roamer
end

local function scan()
	for model in roamers do
		if model.Parent == nil then
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

local function step(roamer: Roamer, dt: number)
	roamer.Phase += dt
	local flying = roamer.Movement == "Fly"
	local moving = true

	if roamer.Wait > 0 then
		roamer.Wait -= dt
		moving = false
	else
		local toTarget = roamer.Target - roamer.Position
		toTarget = Vector3.new(toTarget.X, 0, toTarget.Z)
		if toTarget.Magnitude < 1.5 then
			roamer.Target = pickTarget(roamer)
			if not flying then
				roamer.Wait = rng:NextNumber(0.8, 3) -- walkers stop and look around; fliers keep going
				moving = false
			end
		end
		-- Turn toward the target, then move forward along the heading (gives smooth arcs).
		local wantedYaw = math.atan2(-toTarget.X, -toTarget.Z)
		local turn = wrapAngle(wantedYaw - roamer.Yaw)
		roamer.Yaw += turn * math.min(1, TURN_SPEED * dt)
		if moving then
			local forward = Vector3.new(-math.sin(roamer.Yaw), 0, -math.cos(roamer.Yaw))
			roamer.Position += forward * roamer.Speed * dt
		end
		roamer.Turn = turn
	end

	-- Height: hop arcs, a small walking bob, or flight with a slow drift.
	local height
	if flying then
		roamer.Altitude += (roamer.FlyHeight - roamer.Altitude) * math.min(1, dt) -- take off smoothly
		height = roamer.Altitude + math.sin(roamer.Phase * 1.3) * FLY_BOB
	elseif roamer.Movement == "Hop" then
		height = if moving then math.abs(math.sin(roamer.Phase * HOP_RATE)) * HOP_HEIGHT else 0
	else
		height = if moving then math.abs(math.sin(roamer.Phase * 6)) * 0.15 else 0
	end

	-- Fliers lean into their turns.
	local bank = if flying then math.clamp(-roamer.Turn * 1.5, -MAX_BANK, MAX_BANK) else 0
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
