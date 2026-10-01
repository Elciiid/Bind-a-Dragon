--!strict
-- Poses a real dragon model's bones from code (no animation assets). Bone roles per model and every number come from
-- Config/DragonRigs. Used by RoostAnimationController; not a service (no Init/Start).
--   Flight: flap bursts with glides (length varies per dragon), a fast deep beat while hovering, wings sweeping
--     forward on the down-stroke and folding at the elbow on the up-stroke, swept back in dives, inner wing lower in
--     turns; chest heaves with the beat, legs tucked (reaching forward while hovering in to land), tail trailing the
--     turn, head turning into it.
--   Ground/perch: folded wings that breathe, chest breathing, weight shifting, walking gait, head looking around.
--   Lying down (Rest): legs folded, wings tucked lower, head sunk, tail curled, deeper breathing.
--   Idle actions (Pose.Action, Pose.ActionT 0..1): Stretch, Roar, Yawn, Shake, Preen, TailFlick.
--
--   local rig = DragonRig.Build(model, rigConfig)  -- nil if the model has no bones
--   DragonRig.Apply(rig, pose, detail)             -- detail: "Full" | "Simple"
--   DragonRig.Heave(pose)                          -- studs the body rises with the wing beat (for the controller)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RigConfig = require(ReplicatedStorage.Shared.Config.DragonRigs)

export type Pose = {
	Air: number, -- 0 = on the ground/perch, 1 = flying
	Flap: number, -- flapping clock (seconds, runs while flying)
	Gait: number, -- walk cycles
	Walk: number, -- 0..1 walking
	Clock: number, -- seconds
	Rest: number, -- 0..1 lying down
	Hover: number, -- 0..1 hovering (take off, landing)
	Turn: number, -- -1..1 turning (+ = left)
	Pitch: number, -- -1..1 climbing (+) or diving (-)
	LookYaw: number, -- degrees, + = left
	LookPitch: number, -- degrees, + = up
	Action: string?,
	ActionT: number, -- 0..1 progress of Action
	Seed: number, -- per-dragon variation (integer)
}
export type Rig = {
	Model: Model,
	Config: RigConfig.Rig,
	Bones: { [string]: Bone },
	Rest: { [Bone]: CFrame }, -- rest rotation relative to the model pivot
	TailPhase: number,
}

local DragonRig = {}

local rad, sin, cos, max, pi = math.rad, math.sin, math.cos, math.max, math.pi
local X_AXIS, Y_AXIS, Z_AXIS = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis
local LEGS = {
	{ Role = "BackRight", Phase = 0, Front = false },
	{ Role = "FrontRight", Phase = 0.25, Front = true },
	{ Role = "BackLeft", Phase = 0.5, Front = false },
	{ Role = "FrontLeft", Phase = 0.75, Front = true },
}

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- 0 -> 1 over [0, a], held, 1 -> 0 over [b, 1]
local function envelope(t: number, a: number, b: number): number
	if t <= 0 or t >= 1 then
		return 0
	elseif t < a then
		return smooth(t / a)
	elseif t > b then
		return smooth((1 - t) / (1 - b))
	end
	return 1
end

-- `ignore`: a part whose bones are not part of this rig (the low-poly LOD mesh has bones with the same names).
function DragonRig.Build(model: Model, config: RigConfig.Rig, ignore: Instance?): Rig?
	local bones: { [string]: Bone } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Bone") and not (ignore and d:IsDescendantOf(ignore)) then
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

-- Rotates a bone about axes of the model's frame (through the bone), whatever the bone's own axes are.
local function pose(rig: Rig, name: string?, rotation: CFrame)
	local bone = if name then rig.Bones[name] else nil
	if bone == nil then
		return
	end
	local rest = rig.Rest[bone]
	bone.Transform = rest:Inverse() * rotation * rest
end

local function yawPitch(yaw: number, pitch: number): CFrame
	return CFrame.fromAxisAngle(Y_AXIS, rad(yaw)) * CFrame.fromAxisAngle(X_AXIS, rad(pitch))
end

-- Wing beat: angle (degrees, + = tip up) and stroke (-1..1, + = down-stroke), blending bursts and the hover beat.
function DragonRig.Wing(p: Pose): (number, number)
	local s = RigConfig
	local mid, amp = (s.FlapUp + s.FlapDown) / 2, (s.FlapUp - s.FlapDown) / 2
	local flaps = s.FlapsPerBurst.Min + p.Seed % (s.FlapsPerBurst.Max - s.FlapsPerBurst.Min + 1)
	local burst = flaps * s.FlapSeconds
	local u = p.Flap % (burst + s.GlideSeconds)
	local angle, stroke
	if u < burst then
		local phase = 2 * pi * u / s.FlapSeconds
		angle, stroke = mid + amp * cos(phase), sin(phase)
	else
		local g = sin(pi * (u - burst) / s.GlideSeconds)
		angle, stroke = s.FlapUp + (s.GlideAngle - s.FlapUp) * g, 0
	end
	if p.Hover > 0 then
		local phase = 2 * pi * p.Clock * s.HoverRate / s.FlapSeconds
		local hoverAngle = (mid + amp * cos(phase)) * s.HoverScale
		angle += (hoverAngle - angle) * p.Hover
		stroke += (sin(phase) - stroke) * p.Hover
	end
	return angle, stroke
end

function DragonRig.Heave(p: Pose): number
	local _, stroke = DragonRig.Wing(p)
	return max(0, stroke) * RigConfig.FlapLift * p.Air
end

function DragonRig.Apply(rig: Rig, p: Pose, detail: string)
	local s = RigConfig
	local c = rig.Config
	local air, ground = p.Air, 1 - p.Air
	local full = detail == "Full"
	local action, t = p.Action, p.ActionT
	local function act(name: string, a: number, b: number): number
		return if action == name then envelope(t, a, b) else 0
	end
	local stretch = act("Stretch", 0.3, 0.7)
	local roar = act("Roar", 0.2, 0.75)
	local yawn = act("Yawn", 0.3, 0.7)
	local shake = act("Shake", 0.1, 0.85)
	local preen = act("Preen", 0.2, 0.8)
	local flick = if action == "TailFlick" then 1 - t else 0
	local side = if p.Seed % 2 == 0 then 1 else -1 -- per-dragon handedness (preen side, tail curl)
	local breath = sin(p.Clock * 2 * pi * s.BreathRate)
	local turn = p.Turn * air

	-- wings
	local angle, stroke = DragonRig.Wing(p)
	local spread = max(air, stretch, roar * 0.5)
	local fold = ground * (1 - spread) -- folded against the body (opens for stretches, roars and flight)
	local folded = breath * s.FoldedBreath - (c.WingFold or 0) * fold - (c.RestWingFold or s.RestWingFold) * p.Rest
	local lift = folded * ground + (angle * (c.FlapScale or 1) + (c.WingLevel or 0)) * air
		+ 30 * stretch + 15 * roar + sin(t * 2 * pi) * 10 * stretch + sin(p.Clock * 45) * 6 * shake
	local open = (c.WingOpen or 0) * spread - (c.WingFoldBack or 0) * fold
		+ stroke * s.WingSweep * air - max(0, -p.Pitch) * s.DiveSweep * air
	local elbow = (c.ElbowOpen or 0) * spread - max(0, -stroke) * s.ElbowFold * air
	local bank = turn * s.BankWing
	local right, left = c.WingRight, c.WingLeft
	if right then
		pose(rig, right[1], CFrame.fromAxisAngle(Z_AXIS, rad(lift + bank)) * CFrame.fromAxisAngle(Y_AXIS, rad(open)))
		pose(rig, right[2], CFrame.fromAxisAngle(Y_AXIS, rad(elbow)))
	end
	if left then
		pose(rig, left[1], CFrame.fromAxisAngle(Z_AXIS, rad(-(lift - bank))) * CFrame.fromAxisAngle(Y_AXIS, rad(-open)))
		pose(rig, left[2], CFrame.fromAxisAngle(Y_AXIS, rad(-elbow)))
	end

	-- tail: sway on the ground, trailing wave and turn in the air, curl while lying, flicks
	local tail = c.Tail
	if tail then
		local count = if full then #tail else math.min(#tail, 3)
		for i = 1, count do
			local wave = 2 * pi * s.TailWaveSpeed * (p.Clock + rig.TailPhase) - i * 0.55
			local yaw = sin(wave) * s.TailSway * ground * (1 - 0.6 * p.Rest)
				+ s.TailCurl * side * p.Rest
				- turn * s.TailTurn
				+ sin((t * 3 - i * 0.12) * 2 * pi) * s.TailFlick * flick
			local pitch = sin(wave * 0.6) * s.TailTrail * air + p.Pitch * 5 * air - 8 * roar
			pose(rig, tail[i], yawPitch(yaw, pitch))
		end
	end

	-- neck and head: look around, turn into turns, roar/yawn/preen/shake, sink while lying down
	local neck = c.Neck or {}
	local links = #neck + (if c.Head then 1 else 0)
	if links > 0 then
		local calm = 1 - 0.7 * air
		local yaw = p.LookYaw * calm + turn * s.NeckTurn + side * 75 * preen
		local pitch = p.LookPitch * calm + 28 * roar + 14 * yawn + 10 * stretch - 18 * preen
			- s.RestHeadDrop * p.Rest * (1 - max(roar, yawn)) - 4 * air + 8 * p.Hover * air
		for i, name in neck do
			local bob = sin(p.Clock * 1.2 + i * 0.4) * s.NeckBob * ground
			pose(rig, name, yawPitch(yaw / links, pitch / links + bob))
		end
		if c.Head then
			local nibble = sin(p.Clock * 9) * 3 * preen
			local jolt = sin(p.Clock * 40) * 10 * shake
			pose(rig, c.Head, yawPitch(yaw / links + jolt, pitch / links + nibble))
		end
	end
	if c.Jaw then
		local open = (roar + yawn * 0.8) * (c.JawOpen or 20)
		pose(rig, c.Jaw, CFrame.fromAxisAngle(X_AXIS, rad(-open)))
	end
	if not full then
		return
	end

	-- legs: gait while walking, weight shifting while standing, tucked in flight (reaching forward while hovering),
	-- folded while lying down
	for _, leg in LEGS do
		local names = (c :: any)[leg.Role] :: { string }?
		if names then
			local phase = 2 * pi * (p.Gait + leg.Phase)
			local swing = sin(phase) * s.LegSwing * p.Walk
			local bend = max(0, cos(phase)) * s.KneeLift * p.Walk
			local shift = sin(p.Clock * 0.7 + leg.Phase * 2 * pi) * s.WeightShift * (1 - p.Walk)
			local standing = ground * (1 - p.Rest)
			local tuck = air * (1 - p.Hover)
			local hip = (swing + shift) * standing - s.LegTuck * tuck + s.LegReach * p.Hover * air
				+ (if leg.Front then s.RestFrontHip else s.RestBackHip) * p.Rest
			local knee = -bend * standing - s.KneeTuck * tuck + s.RestKnee * p.Rest
			pose(rig, names[1], CFrame.fromAxisAngle(X_AXIS, rad(hip)))
			pose(rig, names[2], CFrame.fromAxisAngle(X_AXIS, rad(knee)))
		end
	end

	-- spine: the chest breathes (deeper lying down) and heaves with the wing beat; the rest sways with the steps
	if c.Spine then
		for i, name in c.Spine do
			local yaw = sin(2 * pi * p.Gait + i * 0.5) * s.SpineSway * p.Walk * ground + sin(p.Clock * 45) * 2 * shake
			local pitch = 0
			if i == 1 then
				pitch = breath * (s.Breath + (s.RestBreath - s.Breath) * p.Rest) * ground + stroke * s.FlightHeave * air
			end
			pose(rig, name, yawPitch(yaw, pitch))
		end
	end
end

return DragonRig
