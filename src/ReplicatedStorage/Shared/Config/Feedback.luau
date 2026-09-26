--!strict
-- Game-feel feedback (FeedbackController): one sound palette plus a small camera shake and screen flash, driven by
-- what changed in the player's data (and the Spire climb). Shake and flash are off with Low effects; sounds follow
-- the player's sound volume. All sounds are free Creator Store audio, verified to load.

export type Event = {
	Sound: string, -- key in Sounds ("" = none)
	Shake: number, -- 0 = none; 1 = small, 2 = medium, 3 = big (see Shake)
	Flash: Color3?, -- screen flash color (nil = none)
}

return {
	Sounds = {
		LevelUp = "rbxassetid://4612374495", -- "bling_diamond_pickup_3"
		Buy = "rbxassetid://135165335432475", -- "Success Correct Sound"
		Arm = "rbxassetid://128502047397803", -- "SE_DEMO_GET_STAR_2"
		ClimbStart = "rbxassetid://80454497832356", -- "Whoosh_8"
		FloorClear = "rbxassetid://128502047397803",
		IndexEntry = "rbxassetid://4612374495",
		Reward = "rbxassetid://135165335432475",
		Rebirth = "rbxassetid://9040271484", -- "Beauty Over The Rainbow - Sting 1" (APM)
	} :: { [string]: string },
	Volume = 0.55,
	-- A palette sound replaces the toast's own chime when both come at the same moment (seconds).
	ToastSoundWindow = 0.35,

	Shake = {
		{ Angle = 0.35, Seconds = 0.18 }, -- 1 small (degrees)
		{ Angle = 0.8, Seconds = 0.3 }, -- 2 medium
		{ Angle = 1.6, Seconds = 0.5 }, -- 3 big
	},
	FlashTransparency = 0.8, -- how strong a flash starts (1 = invisible)
	FlashSeconds = 0.35,

	Events = {
		LevelUp = { Sound = "LevelUp", Shake = 0, Flash = nil },
		Evolve = { Sound = "IndexEntry", Shake = 1, Flash = Color3.fromRGB(255, 220, 120) },
		Buy = { Sound = "Buy", Shake = 0, Flash = nil },
		RoostUpgrade = { Sound = "Buy", Shake = 1, Flash = nil },
		Arm = { Sound = "Arm", Shake = 0, Flash = nil },
		ClimbStart = { Sound = "ClimbStart", Shake = 0, Flash = nil },
		FloorClear = { Sound = "FloorClear", Shake = 0, Flash = nil },
		NewRecord = { Sound = "FloorClear", Shake = 2, Flash = Color3.fromRGB(255, 200, 120) },
		IndexEntry = { Sound = "IndexEntry", Shake = 1, Flash = Color3.fromRGB(170, 220, 255) },
		Reward = { Sound = "Reward", Shake = 1, Flash = nil }, -- runes, stones, potions, Stardust gained
		Rebirth = { Sound = "Rebirth", Shake = 3, Flash = Color3.fromRGB(255, 230, 150) },
	} :: { [string]: Event },
}
