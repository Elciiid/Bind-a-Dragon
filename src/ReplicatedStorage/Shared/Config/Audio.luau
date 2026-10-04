--!strict
-- Public APM/PSE Creator Store metadata checked 2026-10-03; runtime load/permission checks remain separate.
-- Volumes are 0..1 before the player's settings (music / sound volume) multiply them.

return {
	DefaultArea = "StarterMeadow",
	Areas = {
		StarterMeadow = { DayMusic = "rbxassetid://1842331399", NightMusic = "rbxassetid://9044525961", DayAmbience = "rbxassetid://9120750810", NightAmbience = "rbxassetid://9113203785" }, -- The Enchanted Wood (b) / Make a Wish / Wind Chimes 4 / Attic Wind Whistley Cold Hollow 1
		VolcanoPeak = { DayMusic = "rbxassetid://9043174547", NightMusic = "rbxassetid://9043174547", DayAmbience = "rbxassetid://9112822944", NightAmbience = "rbxassetid://9112822944" }, -- Broken Rebellion Electro Mix / Lava Fire Deep Rumbling 1
		FrozenCliffs = { DayMusic = "rbxassetid://9046499987", NightMusic = "rbxassetid://9044525961", DayAmbience = "rbxassetid://9113203785", NightAmbience = "rbxassetid://9120750810" }, -- Oceanic Underscore C / Make a Wish / Attic Wind / Wind Chimes 4
		StormCanyon = { DayMusic = "rbxassetid://9043174547", NightMusic = "rbxassetid://9046499987", DayAmbience = "rbxassetid://9112853422", NightAmbience = "rbxassetid://9113203785" }, -- Broken Rebellion / Oceanic Underscore C / Rain Heavy Rainfall Grass Wooden Roof 1 / Attic Wind
		EclipseIsles = { DayMusic = "rbxassetid://1837417199", NightMusic = "rbxassetid://1837417199", DayAmbience = "rbxassetid://9113203785", NightAmbience = "rbxassetid://9113203785" }, -- The Return of the Dead King / Attic Wind
	},
	AreaPollSeconds = 0.5,
	Spire = { Sound = "rbxassetid://9046458489", Volume = 0.3, RepeatEndGraceSeconds = 6 }, -- The Revolutionary Army (APM)
	Bind = {
		Common = { Sound = "rbxassetid://9119802009", Volume = 0.3, Seconds = 1.6 }, -- Synth Chime Single Synth Tone 3 (PSE)
		Rare = { Sound = "rbxassetid://9120750810", Volume = 0.35, Seconds = 2 }, -- Wind Chimes 4 (PSE)
		Epic = { Sound = "rbxassetid://1839010065", Volume = 0.4, Seconds = 3 }, -- Orchestral Fantasy (APM)
		Legendary = { Sound = "rbxassetid://1839010065", Volume = 0.5, Seconds = 4 }, -- Orchestral Fantasy (APM)
		Mythic = { Sound = "rbxassetid://1839010065", Volume = 0.55, Seconds = 5 }, -- Orchestral Fantasy (APM)
		Primordial = { Sound = "rbxassetid://1839010065", Volume = 0.6, Seconds = 6 }, -- Orchestral Fantasy (APM)
	},
	Dragon = {
		Wing = { Sound = "rbxassetid://9120771062", Volume = 0.18, Seconds = 1.5, Cooldown = 4 }, -- Wing Flaps 17 (PSE)
		Roar = { Sound = "rbxassetid://9113985445", Volume = 0.18, Seconds = 2.7, Cooldown = 15 }, -- Creature Roar Constant Deep Throaty Growls 2 (PSE)
		Chirp = { Sound = "rbxassetid://9125596224", Volume = 0.2, Seconds = 1.6, Cooldown = 12 }, -- Growls Tiny Creature Cartoon Various Versions 4 (PSE)
		MaxDistance = 65, MinDistance = 8, MaxSimultaneous = 3, HatchlingInterval = 18,
	},
	-- Music crossfades with the day/night blend.
	Music = {
		Day = "rbxassetid://1842331399", -- "The Enchanted Wood (b)" (APM): startup fallback
		Night = "rbxassetid://9044525961", -- "Make a Wish" (APM): startup fallback
		Volume = 0.3,
	},
	-- Ambience loops, also crossfaded with day/night.
	Ambience = {
		Day = "rbxassetid://9120750810", -- "Wind Chimes 4" (PSE): startup fallback
		Night = "rbxassetid://9113203785", -- "Attic Wind Whistley Cold Hollow 1" (PSE): startup fallback
		Volume = 0.35,
	},
	-- 3D sounds on world objects (by tag). NightOnly sources fade with the night blend.
	WorldSources = {
		{ Tag = "DragonstoneForge", Sound = "rbxassetid://150367086", Volume = 0.5, MaxDistance = 45, NightOnly = false }, -- "Torch_Burn"
		{ Tag = "StarAltar", Sound = "rbxassetid://92474343494275", Volume = 0.35, MaxDistance = 60, NightOnly = true }, -- "Healing Winds & Soft Chimes"
		{ Tag = "Waterfall", Sound = "rbxassetid://9116496316", Volume = 0.45, MaxDistance = 110, NightOnly = false }, -- "Medium Size Waterfall 1" (Pro Sound Effects)
	},
	CrossfadeSmoothing = 2, -- seconds to reach a new volume
}
