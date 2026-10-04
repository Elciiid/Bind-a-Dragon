--!strict
-- First-time flow. Server (OnboardingService): saved steps and the welcome bind. Client (OnboardingController): Twinkle,
-- a little glowing guide star that flies ahead to the next target and says one short line (Text.Onboarding.Lines), a big
-- bouncing arrow + a soft glow outline on the real target, and a small Skip button in the top-right corner.
return {
	-- The welcome bind at this area's altar hatches the starter dragon (Config/Data.StarterDragon), by day or night,
	-- with no Echo Sigil / potion / offering, and keeps the night's bind.
	StarterArea = "StarterMeadow",
	Steps = { Start = 1, Home = 2, Upgrade = 3, Night = 4, Complete = 5, Skipped = -1 },
	HomeArrivalRange = 110, -- Studs from the assigned sanctuary pivot: the whole sanctuary (rim r 80) and its forecourt (the Home travel point is ~95 out).
	RebirthHintFraction = 0.25, -- Earn this fraction of the next rebirth price before the hint.
	SpireHintLevel = 10, -- First evolution makes the combat hint relevant.
	RequestInterval = 1, -- Minimum seconds between skip requests.
	PollSeconds = 1, -- Server progression cadence.
	NightHintSeconds = 30, -- step 5: "Night is here!" shows this long, then the tutorial is done
	WaitHintSeconds = 8, -- step 4: "Bind again tonight!" shows this long, then Twinkle naps until night

	-- Twinkle in the world (steps 1, 2, 4, 5): flies ahead of the player toward the target, then hovers over it.
	Twinkle = {
		Ahead = 12, -- studs ahead of the player, toward the target
		Height = 2.5, -- studs above the player's root (low, so the bubble stays clear of the travel row)
		NearDistance = 34, -- studs from the target: Twinkle hovers over it. While the Bind prompt shows (step 1 "Hold E at the
		-- altar!") Twinkle hops onto the screen and the line sits above the altar, clear of its art and glow
		HoverAbove = 6, -- studs above the target's top while hovering there
		FollowSpeed = 4, -- how fast Twinkle catches up (higher = snappier)
		BobHeight = 0.6, -- studs (Reduced Motion: 0)
		BobSpeed = 2.4, -- radians per second
		StarSize = 4.5, -- studs (the star sprite)
		Color = Color3.fromRGB(255, 226, 120),
		TrailSeconds = 0.35, -- the short trail behind Twinkle (Low effects / Reduced Motion: none)
		LightRange = 10, -- a small glow (Low effects: none)
		LightBrightness = 1.2,
		-- Twinkle's star and the world arrow are depth-tested (hidden behind walls like other world labels); its speech bubble
		-- is Bubble.AlwaysOnTop. Note: Studio screenshots don't show AlwaysOnTop guis (they do show in play).
		AlwaysOnTop = false,
	},
	-- Twinkle's line: floating text (no box), big title font with a thick outline and a soft shadow, one big icon.
	Bubble = {
		TextSize = 30, -- pixels on PC
		PhoneTextSize = 20, -- pixels on phones (never under 16)
		IconSize = 40, -- the one big icon (phones x0.75)
		Gap = 14, -- pixels between Twinkle and its line (screen)
		WindowInset = 22, -- inside a window: pixels kept clear of its edge (gold border) ...
		WindowTop = 40, -- ... plus this much under its top (the banner and the close button)
		ScrollSeconds = 1.5, -- after a window opens: keep the target's whole card scrolled into view this long
		AlwaysOnTop = true, -- the line is always readable, never hidden by the altar art or a wall
	},
	-- The big bouncing arrow on the target.
	Arrow = {
		WorldSize = 120, -- pixels (over the altar / your sanctuary)
		WorldAbove = 4, -- studs above the target's top (seen from afar)
		SpotAbove = 3.5, -- up close: studs above the action spot (the altar's Bind prompt), pointing down at it
		ScreenSize = 64, -- pixels (next to a HUD button)
		PhoneScreenSize = 52,
		SideRoom = 420, -- pixels free to the right of a HUD target for arrow + Twinkle + bubble; else they go on its left
		Bounce = 14, -- pixels the arrow bounces (Reduced Motion: 0)
		BounceSpeed = 5, -- radians per second
		Color = Color3.fromRGB(255, 214, 90),
	},
	-- The soft glow outline on the target.
	Glow = {
		WorldFill = NumberRange.new(0.7, 0.85), -- Highlight fill transparency on the altar / sanctuary, breathing between these
		WorldOutline = 0,
		ScreenPadding = 8, -- pixels around a HUD button
		ScreenThickness = 4,
		PulseSpeed = 3, -- the screen outline breathes (Reduced Motion: steady)
	},
	-- The small Skip text button (top-right corner, in the top bar row; two taps so a kid can't skip by accident).
	Skip = {
		TextSize = 20, -- pixels
		Size = Vector2.new(64, 44), -- hit area on PC (at least; grows with the text)
		PhoneSize = Vector2.new(64, 44), -- touch target
		Margin = 12, -- pixels from the right edge
		ConfirmSeconds = 3, -- "Skip? Tap again" waits this long for the second tap
	},
	-- Step icons (UITheme.Icons keys): one big icon in the bubble.
	Icons = { Follow = "Stardust", Bind = "Stardust", Home = "Travel_Home", OpenBag = "Menu_Inventory", Upgrade = "Gold", Night = "Sky_Moon", NightNow = "Sky_Moon" },

	-- The falling star before the welcome bind's reveal (OnboardingController.PlayFirstBind).
	StarFallHeight = 60, -- Studs above the altar, locally rendered only.
	StarFallSeconds = 0.75, -- Falling-star anticipation before the existing reveal.
	ReducedStarSeconds = 0.15, -- Static anticipation for Reduced Motion / Quick Binds.
	FallingStar = {
		Size = Vector3.new(4, 4, 4),
		CameraPosition = Vector3.new(0, 35, 95),
		LabelY = 0.78,
		LabelHeight = 0.12,
		LabelWidth = 0.9,
		LayerOffset = 8, -- above the notifications layer
	},
}
