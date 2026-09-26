--!strict
-- Music, ambience and 3D world sounds (AudioController). All free Creator Store audio, verified to load.
-- Volumes are 0..1 before the player's settings (music / sound volume) multiply them.

return {
	-- Music crossfades with the day/night blend.
	Music = {
		Day = "rbxassetid://1836974139", -- "Into The Distance" (APM)
		Night = "rbxassetid://9046021524", -- "Oceanic Passions - With Piano" (APM)
		Volume = 0.3,
	},
	-- Ambience loops, also crossfaded with day/night.
	Ambience = {
		Day = "rbxassetid://9112749254", -- "Birds Park 1" (Pro Sound Effects)
		Night = "rbxassetid://9114894515", -- "Jungle Insects 2" (Pro Sound Effects): crickets and a mild breeze
		Volume = 0.35,
	},
	-- 3D sounds on world objects (by tag). NightOnly sources fade with the night blend.
	WorldSources = {
		{ Tag = "DragonstoneForge", Sound = "rbxassetid://150367086", Volume = 0.5, MaxDistance = 45, NightOnly = false }, -- "Torch_Burn"
		{ Tag = "StarAltar", Sound = "rbxassetid://92474343494275", Volume = 0.35, MaxDistance = 60, NightOnly = true }, -- "Healing Winds & Soft Chimes"
	},
	CrossfadeSmoothing = 2, -- seconds to reach a new volume
}
