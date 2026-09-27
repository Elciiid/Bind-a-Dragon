--!strict
-- Bone animation for real dragon art (client-side, RoostAnimationController + Controllers/DragonRig). A model is
-- animated when its "<SpeciesId>/<StageId>" has an entry in Rigs below; other models (the placeholder) only move as a
-- whole. Bone names come from the model's rig (Meshy/UniRig: Bone_000 ...); list chains root -> tip.
-- Axes are the model's own: forward -Z, right +X, up +Y. "Right" wing/legs are the ones on +X.
--
-- Roles:
--   Spine, Neck: sway/bob a little. Tail: root -> tip, sways side to side (walking/idle) or trails (flying).
--   WingRight/WingLeft: { root, elbow }: root flaps (about the forward axis) and swings out (about the up axis),
--     elbow opens the wing in flight. Legs: { hip, knee, ... }: hip swings, knee bends; tucked back in flight.
-- Per-rig tuning (degrees; all optional, default 0 / 1):
--   WingOpen = how far the root swings out to spread the wing in flight (+ = outward)
--   ElbowOpen = how far the elbow opens in flight
--   WingFold = extra tip-down at rest/perched (for models whose rest pose has raised wings)
--   FlapScale = multiplies the flap angles

export type Rig = {
	Spine: { string }?,
	Neck: { string }?,
	Tail: { string }?,
	WingRight: { string }?,
	WingLeft: { string }?,
	FrontRight: { string }?,
	FrontLeft: { string }?,
	BackRight: { string }?,
	BackLeft: { string }?,
	WingOpen: number?,
	ElbowOpen: number?,
	WingFold: number?,
	FlapScale: number?,
}

local Rigs: { [string]: Rig } = {
	["Solflare/Elder"] = {
		Spine = { "Bone_005", "Bone_004", "Bone_003", "Bone_002" },
		Neck = { "Bone_030", "Bone_029" },
		Tail = { "Bone_028", "Bone_027", "Bone_026", "Bone_025", "Bone_024", "Bone_023", "Bone_022", "Bone_021", "Bone_020" },
		WingRight = { "Bone_036", "Bone_034" },
		WingLeft = { "Bone_042", "Bone_040" },
		FrontRight = { "Bone_047", "Bone_046" },
		FrontLeft = { "Bone_052", "Bone_051" },
		BackRight = { "Bone_017", "Bone_016" },
		BackLeft = { "Bone_011", "Bone_010" },
		WingOpen = 40,
		ElbowOpen = 30,
		WingFold = 0,
		FlapScale = 1,
	},
}

return {
	Rigs = Rigs,

	-- Level of detail, by distance from the camera (studs). Full = every role, every frame. Simple = wings and tail
	-- only, every SimpleEvery-th frame. Beyond SimpleDistance the dragon holds its last pose.
	FullDistance = 140,
	SimpleDistance = 280,
	SimpleEvery = 3,
	LowEffectsScale = 0.5, -- Low effects: both distances are multiplied by this, and full detail drops the legs/spine

	-- Wings in flight: bursts of flaps with glides between.
	FlapUp = 34, -- degrees, tip up at the top of the stroke
	FlapDown = -26, -- degrees, tip down at the bottom
	FlapSeconds = 0.55, -- one full beat
	FlapsPerBurst = 3,
	GlideSeconds = 1.6, -- wings held out between bursts
	GlideAngle = 8, -- degrees, wing held slightly up while gliding
	FoldedBreath = 3, -- degrees, idle wing movement when folded

	-- Legs
	StepsPerStud = 0.18, -- gait cycles per stud walked
	LegSwing = 24, -- degrees, hip swing forward/back while walking
	KneeLift = 28, -- degrees, knee bend while the foot swings forward
	LegTuck = 45, -- degrees the legs swing back in flight
	KneeTuck = 35,

	-- Tail, spine, neck
	TailSway = 7, -- degrees per tail bone, side to side (idle/walking)
	TailTrail = 4, -- degrees per tail bone, slow up/down wave in flight
	TailWaveSpeed = 0.6, -- waves per second
	SpineSway = 2, -- degrees
	NeckBob = 3, -- degrees
	TransitionSeconds = 0.6, -- blend time between folded and flying poses (take off / landing)
}
