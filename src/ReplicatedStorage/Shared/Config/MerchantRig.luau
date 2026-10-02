--!strict
-- The Star Merchant NPC's bones and the code-driven animations (MerchantIdleController). Bone names are the UniRig names that
-- tools/glb_to_fbx.py keeps in assets/NPC/fbx/Star_Merchant.fbx (UniRig tip bones are merged into their parents), imported with the
-- model's rig. ROLES come from the skeleton's shape (check them with a Play test; swap names here if a limb is on the wrong side).
-- Every animation channel is: which bones, the bone-space axis to turn around, an amount in radians, a period (seconds per cycle) and a
-- phase. Chains (tail, arms) spread their phase along the chain so they flow like a wave. If a bone is missing in the imported model
-- (an import that kept fewer bones) its channel is skipped; the root bone alone still breathes, sways and turns.

local X, Y, Z = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis

return {
	Root = "Bone_000",

	-- Which bone is which part of the body
	Roles = {
		Pelvis = { "Bone_001" },
		Spine = { "Bone_014", "Bone_013", "Bone_012" },
		Neck = { "Bone_036" },
		Head = { "Bone_035" },
		Jaw = { "Bone_061" },
		EarL = { "Bone_057" },
		EarR = { "Bone_059" },
		Tail = { "Bone_022", "Bone_021", "Bone_020", "Bone_019", "Bone_018", "Bone_017", "Bone_016", "Bone_015" },
		ArmL = { "Bone_055", "Bone_054", "Bone_053", "Bone_052", "Bone_051" }, -- the character's left (+X in the model)
		ArmR = { "Bone_050", "Bone_049", "Bone_048", "Bone_047", "Bone_046" },
		LegL = { "Bone_006", "Bone_005", "Bone_004", "Bone_003", "Bone_002" },
		LegR = { "Bone_011", "Bone_010", "Bone_009", "Bone_008", "Bone_007" },
		Cape = { "Bone_039", "Bone_038", "Bone_037", "Bone_042", "Bone_041", "Bone_040", "Bone_045", "Bone_044", "Bone_043" },
	},

	-- The whole-body turn toward a nearby player is shared out along these roles (they add up to 1)
	TurnShare = { Spine = 0.25, Neck = 0.3, Head = 0.45 },
	TurnAxis = Y,

	-- Always running, layered on each other. Amount in radians.
	Idle = {
		-- breathing: the chest rises and falls, the head counter-moves a little
		{ Role = "Spine", Axis = X, Amount = 0.03, Period = 3.4, Phase = 0, PhasePerBone = 0.12 },
		{ Role = "Neck", Axis = X, Amount = -0.025, Period = 3.4, Phase = 0.4 },
		-- a slow side-to-side lean of the whole body
		{ Role = "Pelvis", Axis = Z, Amount = 0.035, Period = 7.5, Phase = 0 },
		{ Role = "Spine", Axis = Z, Amount = -0.02, Period = 7.5, Phase = 0.3, PhasePerBone = 0.1 },
		-- the tail sways, each segment a little behind the one before
		{ Role = "Tail", Axis = Z, Amount = 0.16, Period = 3.2, Phase = 0, PhasePerBone = 0.55 },
		{ Role = "Tail", Axis = X, Amount = 0.05, Period = 4.9, Phase = 1.2, PhasePerBone = 0.4 },
		-- the head bobs and tilts now and then, ears flick
		{ Role = "Head", Axis = X, Amount = 0.05, Period = 2.6, Phase = 0.8 },
		{ Role = "Head", Axis = Z, Amount = 0.06, Period = 6.1, Phase = 2.1 },
		{ Role = "EarL", Axis = Z, Amount = 0.12, Period = 2.9, Phase = 0 },
		{ Role = "EarR", Axis = Z, Amount = -0.12, Period = 3.3, Phase = 1 },
		-- arms hang loosely
		{ Role = "ArmL", Axis = X, Amount = 0.03, Period = 3.4, Phase = 0.5, PhasePerBone = 0.2 },
		{ Role = "ArmR", Axis = X, Amount = 0.03, Period = 3.4, Phase = 0.9, PhasePerBone = 0.2 },
	},

	-- Reactions: a name, how long, and channels that fade in over Fade seconds, hold, and fade out. Wave = one arm up and waving.
	Reactions = {
		Greet = {
			Duration = 2.6, Fade = 0.35,
			Channels = {
				{ Role = "ArmL", Index = 1, Axis = Z, Amount = 1.9, Static = true }, -- shoulder up
				{ Role = "ArmL", Index = 2, Axis = Z, Amount = 0.25, Static = true },
				{ Role = "ArmL", Index = 3, Axis = Z, Amount = 0.55, Period = 0.55, Phase = 0 }, -- the hand waves
				{ Role = "Head", Axis = Z, Amount = 0.14, Static = true },
				{ Role = "Spine", Axis = Z, Amount = -0.05, Static = true },
			},
		},
		Bye = {
			Duration = 2.0, Fade = 0.3,
			Channels = {
				{ Role = "ArmL", Index = 1, Axis = Z, Amount = 1.9, Static = true },
				{ Role = "ArmL", Index = 2, Axis = Z, Amount = 0.25, Static = true },
				{ Role = "ArmL", Index = 3, Axis = Z, Amount = 0.55, Period = 0.5, Phase = 0 },
				{ Role = "Head", Axis = X, Amount = 0.18, Period = 1.0, Phase = 0 }, -- a goodbye nod
			},
		},
		-- after a sale: a happy hop with both arms up, a coin tossed from the hand
		Hop = {
			Duration = 1.3, Fade = 0.15,
			HopHeight = 1.6, -- studs the whole body rises at the top of the hop (an eased arc)
			Channels = {
				{ Role = "ArmL", Index = 1, Axis = Z, Amount = 1.2, Static = true },
				{ Role = "ArmR", Index = 1, Axis = Z, Amount = -1.2, Static = true },
				{ Role = "LegL", Index = 1, Axis = X, Amount = 0.35, Static = true },
				{ Role = "LegR", Index = 1, Axis = X, Amount = 0.35, Static = true },
				{ Role = "Spine", Axis = X, Amount = -0.12, Static = true },
				{ Role = "Tail", Axis = Z, Amount = 0.4, Period = 0.35, Phase = 0, PhasePerBone = 0.5 },
			},
			Coin = { Delay = 0.12, Rise = 5.5, Seconds = 1.1, Size = 0.9, Color = Color3.fromRGB(255, 205, 70) },
		},
	},

	GreetRange = 18, -- studs: the merchant waves hello when you walk within this (once per GreetCooldown)
	GreetCooldown = 40,
	SaleRange = 40, -- hops for sales made by players this close
	TurnRange = 22,
	MaxTurn = 0.7, -- radians (about 40 degrees)
	TurnSpeed = 3.5,
	LookAwayPeriod = 11,
	LookAwayTurn = 0.25,
	AnimateDistance = 90,
}
