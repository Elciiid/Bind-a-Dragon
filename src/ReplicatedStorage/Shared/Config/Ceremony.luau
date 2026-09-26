--!strict
-- The binding ceremony (CeremonyController), played on the binder's client after the server's result:
-- camera eases toward the altar, tonight's stars streak down into it, a burst in the rarity color, then the dragon
-- rises over the altar with its name. Any key/click/tap skips it.
-- No ceremony (just the toast) for Auto-bind pass binds or when the player has been idle (IdleSeconds without input).
-- "Quick binds" (Settings; LocalPlayer attribute "QuickBinds") plays only the burst + reveal, except for FullAlways.

return {
	IdleSeconds = 60,
	AltarRange = 80, -- studs: the player must be this close to an altar for the ceremony
	FullAlways = { Legendary = true, Mythic = true }, -- rarities that always play the full (big) ceremony
	StarbornIsBig = true, -- Starborn binds get the big ceremony too

	Camera = {
		Distance = 40, -- studs from the altar's main crystal, on the player's side
		Height = 9,
		EaseSeconds = 0.6,
		ReturnSeconds = 0.4,
	},
	Stars = {
		Count = 7,
		FlySeconds = 0.9,
		Stagger = 0.08, -- seconds between each star's start
		Size = 3, -- studs
	},
	Burst = {
		Particles = 45,
		BigParticles = 110,
		RingSize = 28, -- studs
		BigRingSize = 60,
		RingSeconds = 0.7,
		FlashTransparency = 0.6, -- screen flash in the rarity color (lower = stronger)
		BigFlashTransparency = 0.35,
		LightRange = 40,
		LightBrightness = 6,
		RingImage = "rbxthumb://type=Asset&id=111862488111004&w=420&h=420", -- free Creator Store decal "Circle light"
		SparkleImage = "rbxasset://textures/particles/sparkles_main.dds",
	},
	SkyFlash = { Seconds = 0.8, Brightness = 0.2 }, -- big ceremonies only
	Reveal = {
		RiseHeight = 7, -- studs above the altar's main crystal
		RiseSeconds = 0.6,
		SpinSpeed = 45, -- degrees per second
		HoldSeconds = 1.2,
		BigHoldSeconds = 2.3,
		QuickHoldSeconds = 0.6,
		Scale = 2.2, -- model scale over its normal (Hatchling) size
	},
	-- Free Creator Store sounds (verified to load). Per rarity; Big plays on top for big ceremonies.
	Sounds = {
		Pull = "rbxassetid://80454497832356", -- "Whoosh_8"
		Common = "rbxassetid://128502047397803", -- "SE_DEMO_GET_STAR_2"
		Rare = "rbxassetid://128502047397803",
		Epic = "rbxassetid://4612374495", -- "bling_diamond_pickup_3"
		Legendary = "rbxassetid://9040271484", -- "Beauty Over The Rainbow - Sting 1" (APM)
		Mythic = "rbxassetid://9040271484",
		Big = "rbxassetid://128502047397803",
		Volume = 0.7,
	},
	SkipHint = "Tap or press any key to skip",
}
