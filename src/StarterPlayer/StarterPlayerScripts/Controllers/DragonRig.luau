--!strict
-- Poses a real dragon model's bones from code (no animation assets): wing flaps with glides, folded wings at rest,
-- walking legs, tuck in flight, tail sway/trail, a little spine and neck motion. Bone roles per model come from
-- Config/DragonRigs; numbers from there too. Used by RoostAnimationController; not a service (no Init/Start).
--
--   local rig = DragonRig.Build(model, rigConfig)  -- nil if the model has no bones
--   DragonRig.Apply(rig, pose, detail)             -- detail: "Full" | "Simple"
--   DragonRig.Reset(rig)                           -- back to the rest pose
-- pose = { Air = 0..1 (1 = flying), Flap = seconds of flapping clock, Gait = walk cycles, Walk = 0..1, Clock = s }

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RigConfig = require(ReplicatedStorage.Shared.Config.DragonRigs)

export type Pose = { Air: number, Flap: number, Gait: number, Walk: number, Clock: number }
export type Rig = {
	Model: Model,
	Config: RigConfig.Rig,
	Bones: { [string]: Bone },
	Rest: { [Bone]: CFrame }, -- rest rotation relative to the model pivot
	TailPhase: number,
}

local DragonRig = {}

local rad = math.rad
local X_AXIS, Y_AXIS, Z_AXIS = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis
local LEGS = {
	{ Role = "BackRight", Phase = 0 },
	{ Role = "FrontRight", Phase = 0.25 },
	{ Role = "BackLeft", Phase = 0.5 },
	{ Role = "FrontLeft", Phase = 0.75 },
}

function DragonRig.Build(model: Model, config: RigConfig.Rig): Rig?
	local bones: { [string]: Bone } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Bone") then
			d.Transform = CFrame.identity
			bones[d.Name] = d
		end
	end
	if next(bones) == nil then
		return nil
	end
	local pivot = model:GetPivot()
	local rest: { [Bone]: CFrame } = {}
	for _, bone in bones do
		rest[bone] = pivot:ToObjectSpace(bone.WorldCFrame).Rotation
	end
	return { Model = model, Config = config, Bones = bones, Rest = rest, TailPhase = math.random() * 10 }
end

-- Rotates a bone about an axis of the model's frame (through the bone), whatever the bone's own axes are.
local function pose(rig: Rig, name: string?, rotation: CFrame)
	local bone = if name then rig.Bones[name] else nil
	if bone == nil then
		return
	end
	local rest = rig.Rest[bone]
	bone.Transform = rest:Inverse() * rotation * rest
end

local function flapAngle(t: number, scale: number): number
	local s = RigConfig
	local burst = s.FlapsPerBurst * s.FlapSeconds
	local u = t % (burst + s.GlideSeconds)
	if u < burst then
		local mid = (s.FlapUp + s.FlapDown) / 2
		local amp = (s.FlapUp - s.FlapDown) / 2
		return (mid + amp * math.cos(2 * math.pi * u / s.FlapSeconds)) * scale
	end
	local g = math.sin(math.pi * (u - burst) / s.GlideSeconds)
	return (s.FlapUp + (s.GlideAngle - s.FlapUp) * g) * scale
end

function DragonRig.Apply(rig: Rig, p: Pose, detail: string)
	local s = RigConfig
	local c = rig.Config
	local air, ground = p.Air, 1 - p.Air
	local full = detail == "Full"

	-- wings: folded (rest + WingFold, a small breath) on the ground, spread and flapping in the air
	local breath = math.sin(p.Clock * 1.5) * s.FoldedBreath
	local flap = flapAngle(p.Flap, c.FlapScale or 1)
	local lift = (breath - (c.WingFold or 0)) * ground + flap * air -- + = tip up
	local open = (c.WingOpen or 0) * air
	local elbow = (c.ElbowOpen or 0) * air
	local right, left = c.WingRight, c.WingLeft
	if right then
		pose(rig, right[1], CFrame.fromAxisAngle(Z_AXIS, rad(lift)) * CFrame.fromAxisAngle(Y_AXIS, rad(open)))
		pose(rig, right[2], CFrame.fromAxisAngle(Y_AXIS, rad(elbow)))
	end
	if left then
		pose(rig, left[1], CFrame.fromAxisAngle(Z_AXIS, rad(-lift)) * CFrame.fromAxisAngle(Y_AXIS, rad(-open)))
		pose(rig, left[2], CFrame.fromAxisAngle(Y_AXIS, rad(-elbow)))
	end

	-- tail: side sway on the ground, a slow trailing wave in the air
	local tail = c.Tail
	if tail then
		local count = if full then #tail else math.min(#tail, 3)
		for i = 1, count do
			local wave = 2 * math.pi * s.TailWaveSpeed * (p.Clock + rig.TailPhase) - i * 0.55
			local sway = math.sin(wave) * s.TailSway * ground
			local trail = math.sin(wave * 0.6) * s.TailTrail * air
			pose(rig, tail[i], CFrame.fromAxisAngle(Y_AXIS, rad(sway)) * CFrame.fromAxisAngle(X_AXIS, rad(trail)))
		end
	end
	if not full then
		return
	end

	-- legs: gait while walking, still when standing, tucked back in flight
	for _, leg in LEGS do
		local names = (c :: any)[leg.Role] :: { string }?
		if names then
			local phase = 2 * math.pi * (p.Gait + leg.Phase)
			local swing = math.sin(phase) * s.LegSwing * p.Walk
			local bend = math.max(0, math.cos(phase)) * s.KneeLift * p.Walk
			pose(rig, names[1], CFrame.fromAxisAngle(X_AXIS, rad(swing * ground - s.LegTuck * air)))
			pose(rig, names[2], CFrame.fromAxisAngle(X_AXIS, rad(-bend * ground - s.KneeTuck * air)))
		end
	end

	-- spine sways with the steps, neck bobs (and stretches forward a little in flight)
	if c.Spine then
		for i, name in c.Spine do
			pose(rig, name, CFrame.fromAxisAngle(Y_AXIS, rad(math.sin(2 * math.pi * p.Gait + i * 0.5) * s.SpineSway * ground)))
		end
	end
	if c.Neck then
		for i, name in c.Neck do
			local bob = math.sin(p.Clock * 1.2 + i * 0.4) * s.NeckBob * ground - 4 * air
			pose(rig, name, CFrame.fromAxisAngle(X_AXIS, rad(bob)))
		end
	end
end

function DragonRig.Reset(rig: Rig)
	for _, bone in rig.Bones do
		bone.Transform = CFrame.identity
	end
end

return DragonRig
