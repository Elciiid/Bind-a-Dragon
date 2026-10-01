--!strict
-- Bone animation for real dragon art (client-side, RoostAnimationController + Controllers/DragonRig). A model is
-- animated when its "<SpeciesId>/<StageId>" has an entry in Rigs below; other models (the placeholder) only move as a
-- whole. Bone names come from the model's rig (Meshy/UniRig: Bone_000 ...); list chains root -> tip.
-- Axes are the model's own: forward -Z, right +X, up +Y. "Right" wing/legs are the ones on +X.
--
-- Roles:
--   Spine: root -> chest (the first one breathes). Neck: base -> top (Head excluded). Head, Jaw: single bones.
--   Tail: root -> tip. WingRight/WingLeft: { root, elbow }. Legs (FrontRight ... BackLeft): { hip, knee }.
--   A role that is missing is skipped (e.g. Infernus is a wyvern: its wings are its front legs).
-- Per-rig tuning (degrees; optional):
--   WingOpen = how far the wing root swings out to spread the wing in flight (+ = outward, i.e. forward from a
--     folded-back rest pose), ElbowOpen = how far the elbow opens in flight, WingFold = extra tip-down at rest,
--   FlapScale = multiplies the flap angles, JawOpen = how far the jaw opens for a roar (negative if it opens upward),
--   WingFoldBack = how far the wings sweep back on the ground (for models whose rest pose has spread wings; they
--     open again for stretches, roars and flight), WingLevel = tip-up added in flight to bring the wings level (negative for models whose rest pose has raised
--     wings), RestWingFold = extra tip-down while lying (default the global RestWingFold; 0 for raised wings).

export type Rig = {
	Spine: { string }?,
	Neck: { string }?,
	Head: string?,
	Jaw: string?,
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
	JawOpen: number?,
	WingLevel: number?,
	RestWingFold: number?,
	WingFoldBack: number?,
}

local Rigs: { [string]: Rig } = {
	["Solflare/Elder"] = {
		Spine = { "Bone_005", "Bone_004", "Bone_003", "Bone_002" },
		Neck = { "Bone_030" },
		Head = "Bone_029",
		Jaw = "Bone_054",
		Tail = { "Bone_028", "Bone_027", "Bone_026", "Bone_025", "Bone_024", "Bone_023", "Bone_022", "Bone_021", "Bone_020" },
		WingRight = { "Bone_036", "Bone_034" },
		WingLeft = { "Bone_042", "Bone_040" },
		FrontRight = { "Bone_047", "Bone_046" },
		FrontLeft = { "Bone_052", "Bone_051" },
		BackRight = { "Bone_017", "Bone_016" },
		BackLeft = { "Bone_011", "Bone_010" },
		WingOpen = 40,
		ElbowOpen = 30,
		WingFold = 25,
		RestWingFold = 12,
		JawOpen = 22,
	},
	["Aurorynth/Elder"] = {
		Spine = { "Bone_004", "Bone_003", "Bone_002" },
		Neck = { "Bone_049", "Bone_048", "Bone_047" },
		Head = "Bone_046",
		Jaw = "Bone_063",
		Tail = { "Bone_023", "Bone_022", "Bone_021", "Bone_020", "Bone_019", "Bone_018" },
		WingRight = { "Bone_029", "Bone_026" },
		WingLeft = { "Bone_033", "Bone_030" },
		FrontRight = { "Bone_038", "Bone_037" },
		FrontLeft = { "Bone_044", "Bone_043" },
		BackRight = { "Bone_010", "Bone_009" },
		BackLeft = { "Bone_016", "Bone_015" },
		WingOpen = 20,
		ElbowOpen = 15,
		WingLevel = -35, -- rest pose has raised, spread wings
		WingFold = 25,
		WingFoldBack = 35,
		RestWingFold = 0,
		JawOpen = 18,
	},
	["Borealis/Elder"] = {
		Spine = { "Bone_005", "Bone_004", "Bone_003" },
		Neck = { "Bone_031", "Bone_030", "Bone_029" },
		Head = "Bone_028",
		Jaw = "Bone_027",
		Tail = { "Bone_025", "Bone_024", "Bone_023", "Bone_022", "Bone_021", "Bone_020", "Bone_019" },
		WingRight = { "Bone_051", "Bone_049" },
		WingLeft = { "Bone_047", "Bone_045" },
		FrontRight = { "Bone_042", "Bone_041" },
		FrontLeft = { "Bone_036", "Bone_035" },
		BackRight = { "Bone_011", "Bone_010" },
		BackLeft = { "Bone_017", "Bone_016" },
		WingOpen = 15,
		ElbowOpen = 10,
		WingLevel = -30, -- rest pose has raised, spread wings
		WingFold = 20,
		WingFoldBack = 35,
		RestWingFold = 0,
		JawOpen = 18,
	},
	["Duskling/Elder"] = {
		Spine = { "Bone_005", "Bone_004", "Bone_003" },
		Neck = { "Bone_032", "Bone_031", "Bone_030" },
		Head = "Bone_029",
		Jaw = "Bone_028",
		Tail = { "Bone_026", "Bone_025", "Bone_024", "Bone_023", "Bone_022", "Bone_021", "Bone_020", "Bone_019" },
		WingRight = { "Bone_050", "Bone_048" },
		WingLeft = { "Bone_047", "Bone_045" },
		FrontRight = { "Bone_037", "Bone_036" },
		FrontLeft = { "Bone_043", "Bone_042" },
		BackRight = { "Bone_011", "Bone_010" },
		BackLeft = { "Bone_017", "Bone_016" },
		WingOpen = 15,
		ElbowOpen = 12,
		WingLevel = -5,
		WingFold = 30,
		WingFoldBack = 30,
		FlapScale = 0.8,
		RestWingFold = 10,
		JawOpen = 18,
	},
	["Infernus/Elder"] = { -- wyvern: the wings are its front legs
		Spine = { "Bone_017", "Bone_016", "Bone_015" },
		Neck = { "Bone_014", "Bone_028" },
		Head = "Bone_027",
		Jaw = "Bone_043",
		Tail = { "Bone_026", "Bone_025", "Bone_024", "Bone_023", "Bone_022", "Bone_021", "Bone_020", "Bone_019" },
		WingRight = { "Bone_034", "Bone_032" },
		WingLeft = { "Bone_040", "Bone_038" },
		BackRight = { "Bone_007", "Bone_006" },
		BackLeft = { "Bone_013", "Bone_012" },
		WingOpen = 25,
		ElbowOpen = 30,
		WingLevel = 15, -- rest pose leans on the wings
		JawOpen = 22,
	},
}

return {
	Rigs = Rigs,

	-- Level of detail, by distance from the camera (studs). Full = every role, every frame. Simple = wings, tail and
	-- head only, every SimpleEvery-th frame. Beyond SimpleDistance the dragon holds its last pose.
	FullDistance = 140,
	SimpleDistance = 280,
	SimpleEvery = 3,
	LowEffectsScale = 0.5, -- Low effects: both distances are multiplied by this, and full detail drops the legs/spine

	-- Mesh detail by distance (RoostAnimationController, Valley rework). An Elder model may hold a second, low-poly skinned
	-- MeshPart named LodPart (about 4k triangles instead of 10k; same bones, same pose; tools/glb_to_fbx.py --tris 4000
	-- --flip makes it): beyond LodDistance it is drawn instead of the body (same bone animation). Beyond HideDistance no
	-- dragon is drawn at all. With Low effects at most LowEffectsMaxVisible dragons of one sanctuary are drawn (the nearest
	-- to the camera).
	LodPart = "BodyLOD",
	LodDistance = 120,
	LodMargin = 10, -- hysteresis: the full mesh comes back this many studs inside LodDistance (and a dragon reappears inside HideDistance)
	HideDistance = 260,
	LowEffectsMaxVisible = 4,

	-- Wings in flight: bursts of flaps with glides between (burst length varies per dragon), a fast continuous beat
	-- while hovering (take off, landing), a sweep forward on the down-stroke, the elbow folding on the up-stroke, wings
	-- swept back in dives, the inner wing lower in turns.
	FlapUp = 34, -- degrees, tip up at the top of the stroke
	FlapDown = -26, -- degrees, tip down at the bottom
	FlapSeconds = 0.55, -- one full beat
	FlapsPerBurst = NumberRange.new(2, 4),
	GlideSeconds = 1.6, -- wings held out between bursts
	GlideAngle = 8, -- degrees, wing held slightly up while gliding
	HoverRate = 1.5, -- hover beats this much faster than cruising beats
	HoverScale = 1.15, -- and this much deeper
	WingSweep = 8, -- degrees forward on the down-stroke
	ElbowFold = 25, -- degrees the elbow folds on the up-stroke
	DiveSweep = 25, -- degrees the wings sweep back in a dive
	BankWing = 8, -- degrees lower for the inner wing in a turn
	FlapLift = 0.6, -- studs the body rises on each down-stroke
	FoldedBreath = 3, -- degrees, idle wing movement when folded
	RestWingFold = 6, -- extra tip-down while lying on the ground

	-- Legs
	StepsPerStud = 0.18, -- gait cycles per stud walked
	LegSwing = 24, -- degrees, hip swing forward/back while walking
	KneeLift = 28, -- degrees, knee bend while the foot swings forward
	LegTuck = 45, -- degrees the legs swing back in flight
	KneeTuck = 35,
	LegReach = 20, -- degrees the legs reach forward while hovering in to land
	WeightShift = 2, -- degrees, slow idle weight shifting while standing/perched
	RestFrontHip = 35, -- lying down: front legs forward
	RestBackHip = 25, -- lying down: back legs forward under the body
	RestKnee = -70, -- lying down: knees folded

	-- Tail
	TailSway = 7, -- degrees per tail bone, side to side (idle/walking)
	TailTrail = 4, -- degrees per tail bone, slow up/down wave in flight
	TailWaveSpeed = 0.6, -- waves per second
	TailTurn = 7, -- degrees per tail bone, trailing the turn in flight
	TailCurl = 9, -- degrees per tail bone, curled to one side while lying down
	TailFlick = 18, -- degrees, whip wave of a tail flick

	-- Body: breathing (chest), spine sway, neck
	BreathRate = 0.3, -- breaths per second
	Breath = 1.6, -- degrees, chest rise standing/perched
	RestBreath = 2.6, -- degrees, chest rise lying down
	FlightHeave = 3, -- degrees, chest heave with the wing beat
	SpineSway = 2, -- degrees
	NeckBob = 3, -- degrees
	NeckTurn = 14, -- degrees, head turns into the turn in flight
	RestHeadDrop = 16, -- degrees the head sinks while lying down
	TransitionSeconds = 0.6, -- blend time between poses (take off, landing, lying down)

	-- Idle actions while perched or resting on the ground (RoostAnimationController picks one every ActionEvery
	-- seconds by weight). Look = turn the head toward a new spot (up to LookYaw / LookPitch degrees).
	ActionEvery = NumberRange.new(2.5, 6),
	LookYaw = 45,
	LookPitch = 18,
	Actions = {
		Look = { Seconds = 0, Perch = 40, Rest = 35 },
		Stretch = { Seconds = 3.2, Perch = 12, Rest = 12 }, -- wings open wide, one slow beat, fold again
		Roar = { Seconds = 2.2, Perch = 8, Rest = 5 }, -- head up, jaw open, wings half open
		TailFlick = { Seconds = 1.2, Perch = 14, Rest = 12 },
		Shake = { Seconds = 1, Perch = 8, Rest = 6 }, -- quick head and wing shake
		Preen = { Seconds = 3.5, Perch = 12, Rest = 12 }, -- head turns back to groom a wing
		Yawn = { Seconds = 2.5, Perch = 0, Rest = 10 }, -- slow jaw open
	} :: { [string]: { Seconds: number, Perch: number, Rest: number } },
	AirRoarEvery = NumberRange.new(18, 40), -- seconds between roars in flight
	SwoopEvery = NumberRange.new(8, 18), -- seconds between swoops in flight
	SwoopDepth = 6, -- studs a swoop dips below the cruise height
	SwoopSeconds = 2.6,
	BodyPitch = 12, -- degrees nose up/down when climbing/diving
	ShakeRoll = 4, -- degrees of body roll during a shake
	RestDrop = 0.2, -- share of its height the body sinks while lying down
}
