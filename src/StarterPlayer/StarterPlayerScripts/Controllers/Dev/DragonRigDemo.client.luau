--!strict
-- DEV PROTOTYPE (remove later): animates the imported Meshy dragon in the meadow by moving its bones from code.
-- Loop: walk a small circle -> take off -> fly circles above the grass -> land -> walk again. Client-only visuals,
-- no animation assets. The model is Workspace.StarterMeadow.DragonRigDemo (tag "DragonRigDemo", anchored root).
-- To remove: delete this file (Controllers/Dev) and the DragonRigDemo model. Nothing else uses it.
--
-- Bone names are Meshy smart-rig names (Bone_000 ... Bone_059). Roles below were read from the rig's rest pose;
-- a role whose bones are missing is skipped (warned once). Model axes: forward = -Z, right = +X, up = +Y.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local SETTINGS = {
	-- Walk
	WalkRadius = 7, -- studs, radius of the walking loop
	WalkSpeed = 4.5, -- studs/s
	WalkSeconds = 10,
	StepsPerSecond = 1.1, -- full gait cycles per second
	LegSwing = 26, -- degrees, hip swing forward/back
	KneeLift = 32, -- degrees, lower-leg bend while the foot swings forward
	BodyBob = 0.18, -- studs up/down, twice per gait cycle
	TailSway = 9, -- degrees per tail bone, side to side
	TailWaveSpeed = 0.8, -- tail waves per second
	NeckBob = 4, -- degrees

	-- Take off / land
	TakeoffSeconds = 2.5,
	LandSeconds = 3,
	TakeoffPitch = 14, -- degrees nose-up while climbing (nose-down on landing)

	-- Fly
	FlyHeight = 16, -- studs above the ground
	FlyRadius = 15, -- studs, radius of the flying circle
	FlySpeed = 13, -- studs/s
	FlySeconds = 14,
	BankAngle = 16, -- degrees, lean into the circle
	HoverBob = 1.2, -- studs, slow rise and fall while flying

	-- Wings (angles about the forward axis; + = wing tip up)
	WingSpread = 35, -- degrees the folded wing opens outward when flying
	FlapUp = 38,
	FlapDown = -28,
	FlapSeconds = 0.5, -- one full beat
	FlapsPerBurst = 3,
	GlideSeconds = 1.4, -- wings held between bursts
	GlideAngle = 6,
	FlapLift = 0.5, -- studs the body rises on each down-stroke
	FoldedBreath = 3, -- degrees, idle wing movement while walking

	-- Legs in flight
	LegTuck = 50, -- degrees the legs swing back
	KneeTuck = 40,
	TailTrail = 5, -- degrees per tail bone, slow up/down wave in flight
}

-- Bone roles (Meshy smart rig). Legs: {hip, knee}; chains are root -> tip.
local ROLES = {
	Spine = { "Bone_001", "Bone_003", "Bone_002", "Bone_026", "Bone_025" },
	Neck = { "Bone_037", "Bone_036", "Bone_035" },
	Tail = { "Bone_024", "Bone_023", "Bone_022", "Bone_021", "Bone_020", "Bone_019", "Bone_018", "Bone_017", "Bone_016" },
	BackRight = { "Bone_009", "Bone_007" },
	BackLeft = { "Bone_015", "Bone_013" },
	FrontRight = { "Bone_042", "Bone_041" },
	FrontLeft = { "Bone_048", "Bone_047" },
	WingRight = { "Bone_029", "Bone_027" }, -- {root, elbow}
	WingLeft = { "Bone_032", "Bone_030" },
}
-- Walk order (lateral-sequence gait): back-right, front-right, back-left, front-left, a quarter cycle apart.
local LEGS = {
	{ Role = "BackRight", Phase = 0 },
	{ Role = "FrontRight", Phase = 0.25 },
	{ Role = "BackLeft", Phase = 0.5 },
	{ Role = "FrontLeft", Phase = 0.75 },
}

type Rig = {
	Model: Model,
	Root: BasePart,
	Bones: { [string]: Bone },
	Rest: { [Bone]: CFrame }, -- rest rotation relative to the root part
}

local rad = math.rad
local X_AXIS, Y_AXIS, Z_AXIS = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.FilterDescendantsInstances = { workspace.Terrain }

local function groundY(x: number, z: number, fallback: number): number
	local hit = workspace:Raycast(Vector3.new(x, fallback + 60, z), Vector3.new(0, -200, 0), terrainParams)
	return if hit then hit.Position.Y else fallback
end

-- Rotates a bone about a model-space axis (through the bone), whatever the bone's own axes are.
local function pose(rig: Rig, name: string, axis: Vector3, degrees: number)
	local bone = rig.Bones[name]
	if bone == nil then
		return
	end
	local rest = rig.Rest[bone]
	bone.Transform = rest:Inverse() * CFrame.fromAxisAngle(axis, rad(degrees)) * rest
end

local function flapAngle(t: number): number
	local s = SETTINGS
	local burst = s.FlapsPerBurst * s.FlapSeconds
	local cycle = burst + s.GlideSeconds
	local u = t % cycle
	if u < burst then
		-- cosine beat that starts and ends at the top of the stroke
		local mid = (s.FlapUp + s.FlapDown) / 2
		local amp = (s.FlapUp - s.FlapDown) / 2
		return mid + amp * math.cos(2 * math.pi * u / s.FlapSeconds)
	end
	local g = math.sin(math.pi * (u - burst) / s.GlideSeconds)
	return lerp(s.FlapUp, s.GlideAngle, g)
end

local function buildRig(model: Model): Rig?
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if root == nil then
		return nil
	end
	local bones: { [string]: Bone } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Bone") then
			d.Transform = CFrame.identity
			bones[d.Name] = d
		end
	end
	local rest: { [Bone]: CFrame } = {}
	for _, bone in bones do
		rest[bone] = root.CFrame:ToObjectSpace(bone.WorldCFrame).Rotation
	end
	local missing = {}
	for role, names in ROLES do
		for _, name in names do
			if bones[name] == nil then
				table.insert(missing, `{role}:{name}`)
			end
		end
	end
	if #missing > 0 then
		warn(`[DragonRigDemo] missing bones, those parts won't move: {table.concat(missing, ", ")}`)
	end
	return { Model = model, Root = root :: BasePart, Bones = bones, Rest = rest }
end

local function run(model: Model)
	local rig = buildRig(model)
	if rig == nil then
		return
	end
	local s = SETTINGS
	local start = model:GetPivot()
	local center = start.Position - Vector3.new(s.WalkRadius, 0, 0)
	local halfHeight = rig.Root.Size.Y / 2
	local baseGround = start.Position.Y - halfHeight

	local angle = 0 -- position on the circle
	local stateTime = 0
	local state = "Walk"
	local clock = 0
	local gait = 0
	local flapClock = 0

	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt: number)
		if model.Parent == nil then
			connection:Disconnect()
			return
		end
		clock += dt
		stateTime += dt

		-- state machine: Walk -> Takeoff -> Fly -> Land -> Walk
		local air = 0 -- 0 = on the ground, 1 = flying
		local climb = 0 -- +1 climbing, -1 descending (for pitch)
		if state == "Walk" then
			if stateTime >= s.WalkSeconds then
				state, stateTime = "Takeoff", 0
				flapClock = 0
			end
		elseif state == "Takeoff" then
			local t = stateTime / s.TakeoffSeconds
			air = smooth(t)
			climb = math.sin(math.pi * math.clamp(t, 0, 1))
			if t >= 1 then
				state, stateTime = "Fly", 0
			end
		elseif state == "Fly" then
			air = 1
			if stateTime >= s.FlySeconds then
				state, stateTime = "Land", 0
			end
		elseif state == "Land" then
			local t = stateTime / s.LandSeconds
			air = 1 - smooth(t)
			climb = -math.sin(math.pi * math.clamp(t, 0, 1))
			if t >= 1 then
				state, stateTime = "Walk", 0
				air = 0
			end
		end
		local ground = 1 - air

		-- body path
		local radius = lerp(s.WalkRadius, s.FlyRadius, air)
		local speed = lerp(s.WalkSpeed, s.FlySpeed, air)
		angle += speed / radius * dt
		local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local x, z = center.X + offset.X, center.Z + offset.Z
		local floorY = groundY(x, z, baseGround)

		gait += dt * s.StepsPerSecond * lerp(1, 0.2, air)
		flapClock += dt * air
		local flap = flapAngle(flapClock)
		local bob = math.sin(gait * 4 * math.pi) * s.BodyBob * ground
		local hover = (math.sin(clock * 0.9) * s.HoverBob + math.max(0, -math.sin(2 * math.pi * flapClock / s.FlapSeconds)) * s.FlapLift) * air
		local height = s.FlyHeight * air + hover + bob
		local position = Vector3.new(x, floorY + halfHeight + height, z)
		local cf = CFrame.lookAt(position, position + tangent)
			* CFrame.Angles(rad(s.TakeoffPitch * climb), 0, rad(-s.BankAngle * air))
		model:PivotTo(cf)

		-- legs: gait on the ground, tucked back in the air
		for _, leg in LEGS do
			local names = (ROLES :: any)[leg.Role] :: { string }
			local p = 2 * math.pi * (gait + leg.Phase)
			local swing = math.sin(p) * s.LegSwing
			local lift = math.max(0, math.cos(p)) * s.KneeLift
			pose(rig, names[1], X_AXIS, swing * ground - s.LegTuck * air)
			pose(rig, names[2], X_AXIS, -lift * ground - s.KneeTuck * air)
		end

		-- wings: folded with a small breath on the ground, spread and flapping in the air
		local breath = math.sin(clock * 1.5) * s.FoldedBreath
		local wing = breath * ground + flap * air
		pose(rig, ROLES.WingRight[1], Z_AXIS, wing)
		pose(rig, ROLES.WingLeft[1], Z_AXIS, -wing)
		pose(rig, ROLES.WingRight[2], Z_AXIS, -s.WingSpread * air)
		pose(rig, ROLES.WingLeft[2], Z_AXIS, s.WingSpread * air)

		-- tail: side sway while walking, trailing wave while flying
		for i, name in ROLES.Tail do
			local wave = 2 * math.pi * s.TailWaveSpeed * clock - i * 0.55
			local sway = math.sin(wave) * s.TailSway * ground
			local trail = math.sin(wave * 0.6) * s.TailTrail * air
			local bone = rig.Bones[name]
			if bone then
				local rest = rig.Rest[bone]
				bone.Transform = rest:Inverse()
					* CFrame.fromAxisAngle(Y_AXIS, rad(sway))
					* CFrame.fromAxisAngle(X_AXIS, rad(trail))
					* rest
			end
		end

		-- neck follows the steps; spine sways a little
		for i, name in ROLES.Neck do
			pose(rig, name, X_AXIS, math.sin(gait * 4 * math.pi + i * 0.4) * s.NeckBob * ground - 4 * air)
		end
		for i, name in ROLES.Spine do
			pose(rig, name, Y_AXIS, math.sin(2 * math.pi * gait + i * 0.5) * 2 * ground)
		end
	end)
end

local function track(instance: Instance)
	if instance:IsA("Model") then
		task.spawn(run, instance)
	end
end

CollectionService:GetInstanceAddedSignal("DragonRigDemo"):Connect(track)
for _, instance in CollectionService:GetTagged("DragonRigDemo") do
	track(instance)
end
