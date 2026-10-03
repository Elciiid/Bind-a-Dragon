--!strict
-- The Star Merchant NPC's bones and the code-driven animations (MerchantIdleController). Bone names are the UniRig names kept in
-- assets/NPC/fbx/Star_Merchant.fbx (76 bones, imported with File > Import 3D). The art faces -Z in its own frame (+X = its right, +Y up,
-- +Z = behind it), and every Axis below is in THAT frame: the controller converts each rotation into the bone's own rest frame, so
-- the imported bones' odd local axes do not matter. Positive rotation turns counter-clockwise looking down the axis toward the
-- origin: about Y a positive angle swings the front toward its LEFT (-X); about Z a positive angle raises the RIGHT arm (+X) and drops the
-- left; about X a positive angle tilts the top backward.
-- Every animation channel is: which bones (a Role), the model-frame axis, an amount in radians, a period (seconds per cycle) and a phase.
-- Chains (tail, arms, cape) spread their phase along the chain so they flow like a wave. A bone that is missing is skipped.

local X, Y, Z = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis

return {
	Root = "Bone_000",

	-- The importer parented the two hands' finger bones to the wrong hand (R fingers under a cape bone, L fingers under the right hand):
	-- put them under their own hand (world pose kept) so waving an arm carries its own fingers. Checked at start; harmless when fixed.
	Reparent = {
		{ Bone = "Bone_064", Parent = "Bone_046" }, { Bone = "Bone_067", Parent = "Bone_046" },
		{ Bone = "Bone_070", Parent = "Bone_046" }, { Bone = "Bone_073", Parent = "Bone_046" },
		{ Bone = "Bone_076", Parent = "Bone_051" }, { Bone = "Bone_079", Parent = "Bone_051" },
		{ Bone = "Bone_082", Parent = "Bone_051" }, { Bone = "Bone_085", Parent = "Bone_051" },
	},

	-- Which bone is which part of the body (L = the character's left = -X, R = +X)
	Roles = {
		Pelvis = { "Bone_001" },
		Spine = { "Bone_014", "Bone_013", "Bone_012" },
		Neck = { "Bone_036" },
		Head = { "Bone_035" },
		Jaw = { "Bone_061" },
		EarL = { "Bone_057", "Bone_056" },
		EarR = { "Bone_059", "Bone_058" },
		Tail = { "Bone_022", "Bone_021", "Bone_020", "Bone_019", "Bone_018", "Bone_017", "Bone_016", "Bone_015" },
		ArmL = { "Bone_055", "Bone_054", "Bone_053", "Bone_052", "Bone_051" },
		ArmR = { "Bone_050", "Bone_049", "Bone_048", "Bone_047", "Bone_046" },
		LegL = { "Bone_006", "Bone_005", "Bone_004", "Bone_003", "Bone_002" },
		LegR = { "Bone_011", "Bone_010", "Bone_009", "Bone_008", "Bone_007" },
		Cape = { "Bone_039", "Bone_038", "Bone_037", "Bone_042", "Bone_041", "Bone_040", "Bone_045", "Bone_044", "Bone_043" },
	},

	-- The whole-body turn toward a nearby player is shared out along these roles (they add up to 1)
	TurnShare = { Pelvis = 0.1, Spine = 0.2, Neck = 0.25, Head = 0.45 },
	TurnAxis = Y,
	TurnSign = 1, -- flip to -1 if the merchant turns away from the player

	-- Always running, layered on each other. Amount in radians.
	Idle = {
		-- breathing: the chest rises and falls, the head counter-moves a little
		{ Role = "Spine", Axis = X, Amount = 0.03, Period = 3.4, Phase = 0, PhasePerBone = 0.12 },
		{ Role = "Neck", Axis = X, Amount = -0.025, Period = 3.4, Phase = 0.4 },
		-- a slow side-to-side lean of the whole body
		{ Role = "Pelvis", Axis = Z, Amount = 0.03, Period = 7.5, Phase = 0 },
		{ Role = "Spine", Axis = Z, Amount = -0.02, Period = 7.5, Phase = 0.3, PhasePerBone = 0.1 },
		-- the tail sways side to side, each segment a little behind the one before, and lifts a little
		{ Role = "Tail", Axis = Y, Amount = 0.2, Period = 3.2, Phase = 0, PhasePerBone = 0.55 },
		{ Role = "Tail", Axis = X, Amount = 0.06, Period = 4.9, Phase = 1.2, PhasePerBone = 0.4 },
		-- the head bobs and tilts now and then, ears flick
		{ Role = "Head", Axis = X, Amount = 0.05, Period = 2.6, Phase = 0.8 },
		{ Role = "Head", Axis = Z, Amount = 0.06, Period = 6.1, Phase = 2.1 },
		{ Role = "EarL", Axis = Z, Amount = 0.14, Period = 2.9, Phase = 0 },
		{ Role = "EarR", Axis = Z, Amount = -0.14, Period = 3.3, Phase = 1 },
		-- arms hang loosely, the cape stirs
		{ Role = "ArmL", Axis = X, Amount = 0.03, Period = 3.4, Phase = 0.5, PhasePerBone = 0.2 },
		{ Role = "ArmR", Axis = X, Amount = 0.03, Period = 3.4, Phase = 0.9, PhasePerBone = 0.2 },
		{ Role = "Cape", Axis = X, Amount = 0.05, Period = 4.2, Phase = 0.3, PhasePerBone = 0.45 },
	},

	-- Reactions: a name, how long, and channels that fade in over Fade seconds, hold, and fade out. Wave = the right arm up and waving.
	-- (No hello wave on approach: the merchant only waves goodbye and hops after a sale.)
	Reactions = {
		Bye = {
			Duration = 2.2, Fade = 0.3,
			Channels = {
				{ Role = "ArmR", Index = 1, Axis = Z, Amount = 0.2, Static = true },
				{ Role = "ArmR", Index = 2, Axis = Z, Amount = 1.35, Static = true },
				{ Role = "ArmR", Index = 3, Axis = Z, Amount = 0.55, Static = true },
				{ Role = "ArmR", Index = 3, Axis = Z, Amount = 0.35, Period = 0.45, Phase = 0 },
				{ Role = "Head", Axis = X, Amount = -0.18, Period = 1.0, Phase = 0 }, -- a goodbye nod
			},
		},
		-- after a sale: a happy hop with both arms up, a coin tossed from the hand
		Hop = {
			Duration = 1.3, Fade = 0.15,
			HopHeight = 1.6, -- studs the whole body rises at the top of the hop (an eased arc)
			Channels = {
				{ Role = "ArmL", Index = 1, Axis = Z, Amount = -0.2, Static = true },
				{ Role = "ArmL", Index = 2, Axis = Z, Amount = -1.5, Static = true },
				{ Role = "ArmR", Index = 1, Axis = Z, Amount = 0.2, Static = true },
				{ Role = "ArmR", Index = 2, Axis = Z, Amount = 1.5, Static = true },
				{ Role = "LegL", Index = 1, Axis = X, Amount = -0.3, Static = true },
				{ Role = "LegR", Index = 1, Axis = X, Amount = -0.3, Static = true },
				{ Role = "Spine", Axis = X, Amount = 0.1, Static = true },
				{ Role = "Tail", Axis = Y, Amount = 0.4, Period = 0.35, Phase = 0, PhasePerBone = 0.5 },
			},
			Coin = { Delay = 0.12, Rise = 5.5, Seconds = 1.1, Size = 0.9, Color = Color3.fromRGB(255, 205, 70), Hand = "ArmR" },
		},
	},

	SaleRange = 40, -- hops for sales made by players this close
	TurnRange = 22,
	MaxTurn = 0.7, -- radians (about 40 degrees)
	TurnSpeed = 3.5,
	LookAwayPeriod = 11,
	LookAwayTurn = 0.25,
	AnimateDistance = 90,
}
