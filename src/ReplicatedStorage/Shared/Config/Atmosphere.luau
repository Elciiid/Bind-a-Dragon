--!strict
-- Look and life of each area, drawn on each client (AtmosphereController, SkyController, WorldLifeController).
-- Every area has a Day and a Night preset; the client blends them with the clock (dusk/dawn) and switches presets
-- when the player changes area. Tonight's element tints the night ambient light (NightTint).
-- Lighting.Technology can't be set from scripts: set it to Future in Studio (Lighting properties).

export type Look = {
	Ambient: Color3,
	OutdoorAmbient: Color3,
	Brightness: number,
	Exposure: number, -- Lighting.ExposureCompensation
	-- Atmosphere (haze)
	Density: number,
	Offset: number,
	HazeColor: Color3,
	Decay: Color3,
	Glare: number,
	Haze: number,
	-- Post effects
	BloomIntensity: number,
	BloomSize: number,
	BloomThreshold: number,
	Contrast: number,
	Saturation: number,
	Tint: Color3,
	SunRays: number,
	DepthBlur: number, -- DepthOfField far intensity (0 = off); gentle blur of the far distance only
}

-- Floating particles near the camera (petals, fireflies, embers, snow...). Texture: an image id.
export type Drift = {
	Texture: string,
	Color: Color3,
	Rate: number, -- per second, inside the box around the camera
	Size: number, -- studs
	Speed: number, -- studs per second
	Lifetime: number, -- seconds
	Rise: number, -- upward acceleration (negative = falls)
	Glow: number, -- LightEmission 0..1
	Spin: number, -- degrees per second
}

export type AreaLook = {
	Day: Look,
	Night: Look,
	DayDrift: Drift?,
	NightDrift: Drift?,
}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local PETALS = "rbxthumb://type=Asset&id=13190142512&w=150&h=150" -- free Creator Store decal "pretty petals"

local function look(t: { [string]: any }): Look
	-- defaults shared by all presets
	local base: { [string]: any } = {
		Brightness = 2.5,
		Exposure = 0,
		Density = 0.3,
		Offset = 0.25,
		Glare = 0,
		Haze = 1.2,
		BloomIntensity = 0.6,
		BloomSize = 28,
		BloomThreshold = 1.4,
		Contrast = 0.08,
		Saturation = 0.1,
		Tint = Color3.new(1, 1, 1),
		SunRays = 0.05,
		DepthBlur = 0.06,
	}
	for key, value in t do
		base[key] = value
	end
	return base :: any
end

local Areas: { [string]: AreaLook } = {
	StarterMeadow = {
		Day = look({
			Ambient = Color3.fromRGB(95, 90, 100),
			OutdoorAmbient = Color3.fromRGB(145, 135, 125),
			HazeColor = Color3.fromRGB(215, 210, 200),
			Decay = Color3.fromRGB(106, 118, 140),
			Glare = 0.2,
			Tint = Color3.fromRGB(255, 250, 240),
			Saturation = 0.14,
		}),
		Night = look({
			Ambient = Color3.fromRGB(60, 70, 120),
			OutdoorAmbient = Color3.fromRGB(75, 90, 155),
			Brightness = 1.4,
			Exposure = 0.15,
			Density = 0.28,
			HazeColor = Color3.fromRGB(90, 100, 160),
			Decay = Color3.fromRGB(40, 45, 95),
			Haze = 1.6,
			BloomIntensity = 1,
			BloomSize = 36,
			BloomThreshold = 1.1,
			Contrast = 0.12,
			Tint = Color3.fromRGB(225, 232, 255),
			SunRays = 0,
		}),
		DayDrift = { Texture = PETALS, Color = Color3.new(1, 1, 1), Rate = 3, Size = 1.1, Speed = 1.5, Lifetime = 9, Rise = -0.4, Glow = 0, Spin = 40 },
		NightDrift = { Texture = SPARKLE, Color = Color3.fromRGB(215, 255, 140), Rate = 5, Size = 0.35, Speed = 0.6, Lifetime = 6, Rise = 0.05, Glow = 1, Spin = 0 },
	},
	VolcanoPeak = {
		Day = look({
			Ambient = Color3.fromRGB(110, 80, 70),
			OutdoorAmbient = Color3.fromRGB(160, 110, 90),
			Density = 0.38,
			HazeColor = Color3.fromRGB(255, 170, 120),
			Decay = Color3.fromRGB(170, 80, 50),
			Haze = 2,
			Glare = 0.3,
			Tint = Color3.fromRGB(255, 232, 215),
			Saturation = 0.15,
		}),
		Night = look({
			Ambient = Color3.fromRGB(110, 60, 50),
			OutdoorAmbient = Color3.fromRGB(120, 60, 50),
			Brightness = 1.4,
			Exposure = 0.1,
			Density = 0.36,
			HazeColor = Color3.fromRGB(140, 60, 40),
			Decay = Color3.fromRGB(80, 30, 20),
			Haze = 2,
			BloomIntensity = 1,
			BloomSize = 36,
			BloomThreshold = 1.1,
			Tint = Color3.fromRGB(255, 225, 210),
			SunRays = 0,
		}),
		DayDrift = { Texture = SPARKLE, Color = Color3.fromRGB(255, 140, 60), Rate = 6, Size = 0.3, Speed = 1, Lifetime = 5, Rise = 1.2, Glow = 1, Spin = 0 },
		NightDrift = { Texture = SPARKLE, Color = Color3.fromRGB(255, 120, 40), Rate = 9, Size = 0.35, Speed = 1, Lifetime = 5, Rise = 1.4, Glow = 1, Spin = 0 },
	},
	FrozenCliffs = {
		Day = look({
			Ambient = Color3.fromRGB(95, 105, 130),
			OutdoorAmbient = Color3.fromRGB(150, 165, 195),
			Density = 0.33,
			HazeColor = Color3.fromRGB(215, 235, 255),
			Decay = Color3.fromRGB(150, 180, 220),
			Haze = 1.6,
			Tint = Color3.fromRGB(235, 245, 255),
			Saturation = -0.05,
		}),
		Night = look({
			Ambient = Color3.fromRGB(60, 80, 130),
			OutdoorAmbient = Color3.fromRGB(70, 95, 150),
			Brightness = 1.4,
			Exposure = 0.15,
			HazeColor = Color3.fromRGB(80, 110, 160),
			Decay = Color3.fromRGB(40, 60, 110),
			Haze = 1.8,
			BloomIntensity = 1,
			BloomSize = 36,
			BloomThreshold = 1.1,
			Tint = Color3.fromRGB(220, 235, 255),
			SunRays = 0,
		}),
		DayDrift = { Texture = SPARKLE, Color = Color3.fromRGB(240, 250, 255), Rate = 8, Size = 0.3, Speed = 0.8, Lifetime = 7, Rise = -1, Glow = 0.4, Spin = 20 },
		NightDrift = { Texture = SPARKLE, Color = Color3.fromRGB(220, 240, 255), Rate = 8, Size = 0.3, Speed = 0.8, Lifetime = 7, Rise = -1, Glow = 0.8, Spin = 20 },
	},
	StormCanyon = {
		Day = look({
			Ambient = Color3.fromRGB(100, 98, 85),
			OutdoorAmbient = Color3.fromRGB(145, 140, 115),
			Density = 0.42,
			HazeColor = Color3.fromRGB(190, 185, 160),
			Decay = Color3.fromRGB(120, 115, 90),
			Haze = 2.2,
			Contrast = 0.12,
			Tint = Color3.fromRGB(250, 248, 225),
			Saturation = -0.1,
		}),
		Night = look({
			Ambient = Color3.fromRGB(80, 78, 60),
			OutdoorAmbient = Color3.fromRGB(85, 82, 65),
			Brightness = 1.3,
			Exposure = 0.1,
			Density = 0.4,
			HazeColor = Color3.fromRGB(70, 70, 60),
			Decay = Color3.fromRGB(45, 45, 35),
			Haze = 2.2,
			BloomIntensity = 1,
			BloomSize = 36,
			BloomThreshold = 1.1,
			Tint = Color3.fromRGB(245, 240, 215),
			SunRays = 0,
		}),
		DayDrift = { Texture = SPARKLE, Color = Color3.fromRGB(230, 220, 170), Rate = 5, Size = 0.25, Speed = 3, Lifetime = 4, Rise = 0, Glow = 0.2, Spin = 0 },
		NightDrift = { Texture = SPARKLE, Color = Color3.fromRGB(255, 235, 90), Rate = 5, Size = 0.3, Speed = 2, Lifetime = 3, Rise = 0.3, Glow = 1, Spin = 0 },
	},
	EclipseIsles = {
		Day = look({
			Ambient = Color3.fromRGB(95, 80, 115),
			OutdoorAmbient = Color3.fromRGB(140, 120, 165),
			Density = 0.35,
			HazeColor = Color3.fromRGB(190, 160, 230),
			Decay = Color3.fromRGB(90, 60, 140),
			Haze = 1.8,
			Tint = Color3.fromRGB(240, 225, 255),
			Saturation = 0.1,
		}),
		Night = look({
			Ambient = Color3.fromRGB(80, 50, 120),
			OutdoorAmbient = Color3.fromRGB(85, 55, 130),
			Brightness = 1.3,
			Exposure = 0.15,
			HazeColor = Color3.fromRGB(60, 35, 100),
			Decay = Color3.fromRGB(35, 20, 70),
			Haze = 2,
			BloomIntensity = 1.1,
			BloomSize = 36,
			BloomThreshold = 1.05,
			Tint = Color3.fromRGB(235, 215, 255),
			SunRays = 0,
		}),
		DayDrift = { Texture = SPARKLE, Color = Color3.fromRGB(190, 140, 255), Rate = 5, Size = 0.3, Speed = 0.6, Lifetime = 6, Rise = 0.5, Glow = 1, Spin = 0 },
		NightDrift = { Texture = SPARKLE, Color = Color3.fromRGB(170, 110, 255), Rate = 8, Size = 0.35, Speed = 0.6, Lifetime = 6, Rise = 0.6, Glow = 1, Spin = 0 },
	},
}

return {
	Areas = Areas,
	DefaultArea = "StarterMeadow", -- used when the player's area can't be found
	AutoLowQuality = 3, -- Low effects turns on by itself at this Roblox graphics quality level or below (1-10)
	TransitionSeconds = 25, -- dusk and dawn: how long day and night blend (end of day / end of night)
	AreaBlendSeconds = 2, -- blend time when changing area (teleport)
	NightTint = 0.3, -- how strongly tonight's element colors the night ambient
	RareNightTint = 0.55,

	-- Drifting particles: a box around the camera (studs), only near the ground.
	DriftBox = Vector3.new(90, 16, 90),
	DriftLowEffects = 0.35, -- rate multiplier with Low effects

	-- Lanterns (Models tagged "Lantern" with a Neon "Lamp" part): on at dusk, gentle flicker, off by day.
	Lanterns = {
		MaxLights = 8, -- only this many nearest lanterns cast light (others just glow)
		LightDistance = 90, -- studs
		Brightness = 1.3,
		Flicker = 0.15, -- +/- fraction of brightness
		FlickerSpeed = 3,
		DayColor = Color3.fromRGB(120, 105, 85), -- unlit lamp glass
		NightColor = Color3.fromRGB(255, 196, 110),
	},

	-- Tonight's constellation in the sky (SkyController).
	Sky = {
		Distance = 320, -- studs from the camera (closer = less haze over the lines)
		Direction = Vector3.new(0, 0.42, -1), -- centre of the drawing (north, above the Spire)
		Span = Vector2.new(0.55, 0.32), -- horizontal / vertical size (fraction of the distance)
		RareScale = 1.3, -- rare constellations are drawn bigger and brighter
		StarSize = 34, -- pixels
		BrightStarSize = 50, -- the first star of each drawing
		StarImage = SPARKLE,
		LineWidth = 0.9, -- studs
		LineTransparency = 0.2,
		Twinkle = 0.25, -- +/- size fraction
		-- Shooting stars at night.
		ShootingStarEvery = NumberRange.new(40, 90), -- seconds
		ShootingStarSeconds = 1.2,
		ShootingStarColor = Color3.fromRGB(230, 240, 255),
		DefaultColor = Color3.fromRGB(200, 220, 255), -- constellations without an element
	},
}
