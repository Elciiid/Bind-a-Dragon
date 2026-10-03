--!strict
-- Client presentation of an already-confirmed bind. A private ViewportFrame stages the altar and dragon;
-- it never replaces assets, moves world models, or takes ownership of the player's camera.
-- Quick Binds shortens EVERY rarity. Auto-bind/idle results bypass the ceremony. Starborn is retired;
-- Primordial and exceptionally rare species/mutation pairs use the prestige profile below.

return {
	IdleSeconds = 60, -- no cinematic when a player has stopped interacting
	ResponseTimeout = 12, -- release a pending spoiler cover if the server never answers
	AltarRange = 80, -- only stage an altar the player is currently near
	SkipButtonSize = Vector2.new(150, 44), -- accessible touch control, never scaled down
	SkipBottomMargin = 12,
	WaitingStarSize = 36,
	WaitingStars = 5,
	WaitingRadius = 90,
	WaitingStarSeconds = 0.55,
	ReducedHoldSeconds = 0.25, -- static transition; no camera motion, spinning or flashes
	PrestigeOneIn = 5000, -- dramatic presentation also follows exact confirmed pair odds, not just tier
	Profiles = {
		Common = { Anticipation = 0.18, Gather = 0.40, Silhouette = 0.15, Entrance = 0.35, Hold = 0.40, Stars = 4 },
		Rare = { Anticipation = 0.22, Gather = 0.50, Silhouette = 0.20, Entrance = 0.40, Hold = 0.60, Stars = 5 },
		Epic = { Anticipation = 0.28, Gather = 0.65, Silhouette = 0.25, Entrance = 0.45, Hold = 0.80, Stars = 6 },
		Legendary = { Anticipation = 0.32, Gather = 0.75, Silhouette = 0.30, Entrance = 0.50, Hold = 1.10, Stars = 7 },
		Mythic = { Anticipation = 0.35, Gather = 0.85, Silhouette = 0.35, Entrance = 0.55, Hold = 1.40, Stars = 8 },
		Prestige = { Anticipation = 0.35, Gather = 0.90, Silhouette = 0.40, Entrance = 0.55, Hold = 1.50, Stars = 9 },
		Quick = { Anticipation = 0.08, Gather = 0.12, Silhouette = 0.06, Entrance = 0.18, Hold = 0.25, Stars = 3 },
	},
	Viewport = {
		-- Prefer stage-appropriate art, then existing later-stage art, then the shared placeholder. Display only:
		-- a bind still grants a level-one dragon, regardless of which art is currently available in the place.
		StageFallbacks = { "Hatchling", "Drake", "Dragon", "Elder" },
		DragonLength = 14,
		AltarLength = 24,
		AltarHeight = -3,
		AltarMaxParts = 100, -- do not clone unexpectedly expensive scenery into a short-lived mobile cinematic
		Direction = Vector3.new(0.46, 0.20, -1).Unit,
		FieldOfView = 34,
		FitMargin = 1.30, -- allow folded/stretching wings to remain inside the frame
		DollyFraction = 0.10, -- restrained viewport-only push-in (never used with Reduced Motion)
		EntranceHeight = 2,
		PoseSeconds = 1.15,
		PoseAction = "Stretch", -- existing code-driven bone pose; unavailable rigs use a static fallback
		Ambient = Color3.fromRGB(190, 190, 215),
		Light = Color3.fromRGB(255, 246, 225),
		LightDirection = Vector3.new(-0.7, -1, -0.7),
	},
	Presentation = {
		WidthFraction = 0.86, -- reserve room for safe-area text and the skip button
		HeightFraction = 0.76,
		StageY = 0.46,
		PortalY = 0.68,
		PortalWidthFraction = 0.36,
		PortalHeightFraction = 0.18,
		StarSize = 26,
		StarRadiusFraction = 0.38,
		StarStaggerFraction = 0.35,
		PortalTransparency = 0.64, -- local halo only; no full-screen flash or Lighting bloom
		BurstTransparency = 0.40,
		BurstSizeMultiplier = 1.5,
		BurstSeconds = 0.30,
		LabelTop = 12,
		LabelHeight = 40,
		LabelBottom = 64,
		LowStars = 3,
		ExitSeconds = 0.16,
	},
	Burst = {
		RingImage = "rbxthumb://type=Asset&id=111862488111004&w=420&h=420", -- free Creator Store decal "Circle light"
		SparkleImage = "rbxasset://textures/particles/sparkles_main.dds",
	},
	-- Existing sound assets; per-ceremony instances are explicitly destroyed on skip/error/completion.
	Sounds = {
		Pull = "rbxassetid://80454497832356", -- "Whoosh_8"
		Common = "rbxassetid://128502047397803", -- "SE_DEMO_GET_STAR_2"
		Rare = "rbxassetid://128502047397803",
		Epic = "rbxassetid://4612374495", -- "bling_diamond_pickup_3"
		Legendary = "rbxassetid://9040271484", -- "Beauty Over The Rainbow - Sting 1" (APM)
		Mythic = "rbxassetid://9040271484",
		Volume = 0.7,
		CleanupSeconds = 10, -- bounded even when an asset fails to load or never emits Ended
	},
}
