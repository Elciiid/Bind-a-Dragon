--!strict
-- Look and life of each area, drawn on each client (AtmosphereController, SkyController, WorldLifeController).
-- Every area has a Day and a Night preset; the client blends them with the clock (dusk/dawn) and switches presets
-- when the player changes area. Tonight's element tints the night ambient light (NightTint).
-- The place uses Lighting.LightingStyle = Realistic (set in Studio; it replaced the old Future technology).

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
	SunColor: Color3, -- Lighting.ColorShift_Top: tints sunlit surfaces (black = no tint; warm gold = golden hour)
	-- 3D clouds (Terrain.Clouds, one for the whole place; each area sets its own sky)
	CloudCover: number, -- share of the sky covered, 0..1
	CloudDensity: number, -- how thick the clouds look, 0..1
	CloudColor: Color3,
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
		SunColor = Color3.new(0, 0, 0),
		CloudCover = 0.5,
		CloudDensity = 0.3,
		CloudColor = Color3.new(1, 1, 1),
	}
	for key, value in t do
		base[key] = value
	end
	return base :: any
end

local Areas: { [string]: AreaLook } = {
	StarterMeadow = {
		-- The Starlit Highlands, Starter Meadow by day: sunny late morning, crisp clear air, bright ambient, soft shadows,
		-- gentle bloom. Simplify 2026-10-04 (kid-friendly Roblox look, KISS): brighter ambient, less haze/bloom/rays, no far
		-- blur, softer contrast, a bit more color. Works with Lighting.LightingStyle Realistic or Soft.
		Day = look({
			Ambient = Color3.fromRGB(130, 130, 140),
			OutdoorAmbient = Color3.fromRGB(165, 165, 172),
			Brightness = 3.2,
			Exposure = 0.12,
			HazeColor = Color3.fromRGB(205, 225, 245),
			Decay = Color3.fromRGB(150, 180, 215),
			Density = 0.08, -- clear air
			Offset = 0,
			Haze = 0.2,
			Glare = 0,
			BloomIntensity = 0.2,
			BloomSize = 24,
			BloomThreshold = 1.6,
			Contrast = 0.05,
			Saturation = 0.2,
			Tint = Color3.fromRGB(252, 252, 250),
			SunRays = 0.03,
			DepthBlur = 0,
			SunColor = Color3.fromRGB(50, 38, 18),
			CloudCover = 0.62, -- fair-weather clouds over the peaks, blue sky between
			CloudDensity = 0.26,
		}),
		-- Night is the show: bright starry sky, clearly visible; the altar, portals, gates and Spire glow (NightGlow).
		-- (brighter since the Valley: the valley floor, paths and sanctuaries stay readable in blue moonlight)
		Night = look({
			Ambient = Color3.fromRGB(92, 104, 158),
			OutdoorAmbient = Color3.fromRGB(120, 136, 200),
			Brightness = 2.2,
			Exposure = 0.55,
			Density = 0.14,
			Offset = 0,
			HazeColor = Color3.fromRGB(80, 100, 165),
			Decay = Color3.fromRGB(40, 52, 115),
			Haze = 0.3,
			BloomIntensity = 0.6, -- Simplify 2026-10-04: softer glow (was 1.2)
			BloomSize = 30,
			BloomThreshold = 1.1,
			Contrast = 0.08,
			Saturation = 0.2,
			Tint = Color3.fromRGB(214, 224, 255),
			SunRays = 0,
			SunColor = Color3.fromRGB(28, 38, 80),
			CloudCover = 0.4, -- fewer, darker clouds so the stars and the constellation show
			CloudDensity = 0.2,
			CloudColor = Color3.fromRGB(110, 122, 165),
		}),
		-- a few golden light motes by day (magic is an accent), fireflies at night
		DayDrift = { Texture = SPARKLE, Color = Color3.fromRGB(255, 232, 160), Rate = 4, Size = 0.26, Speed = 0.5, Lifetime = 8, Rise = 0.1, Glow = 1, Spin = 0 },
		NightDrift = { Texture = SPARKLE, Color = Color3.fromRGB(226, 255, 140), Rate = 12, Size = 0.36, Speed = 0.7, Lifetime = 6, Rise = 0.08, Glow = 1, Spin = 0 },
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
			CloudCover = 0.45,
			CloudDensity = 0.35,
			CloudColor = Color3.fromRGB(215, 190, 175), -- ash-tinted
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
			CloudCover = 0.4,
			CloudDensity = 0.3,
			CloudColor = Color3.fromRGB(90, 55, 45), -- lit red from below
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
			CloudCover = 0.55,
			CloudDensity = 0.3,
			CloudColor = Color3.fromRGB(245, 250, 255),
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
			CloudCover = 0.35,
			CloudDensity = 0.2,
			CloudColor = Color3.fromRGB(90, 110, 150), -- thin, so the aurora shows
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
			CloudCover = 0.85,
			CloudDensity = 0.55,
			CloudColor = Color3.fromRGB(170, 165, 185), -- heavy storm clouds
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
			CloudCover = 0.8,
			CloudDensity = 0.5,
			CloudColor = Color3.fromRGB(60, 58, 78),
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
			CloudCover = 0.35,
			CloudDensity = 0.25,
			CloudColor = Color3.fromRGB(215, 195, 245),
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
			CloudCover = 0.3,
			CloudDensity = 0.2,
			CloudColor = Color3.fromRGB(60, 40, 95),
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

	-- World particle effects placed in the areas (ParticleEmitters tagged "AmbientFX": waterfall foam and mist, ...).
	-- With Low effects they run at this share of their rate (AmbientFXController).
	AmbientFXLowRate = 0.3,
	-- Beams tagged "DistanceFade" (the waterfall's water sheets) fade out with distance from the camera: fully drawn
	-- within BeamFadeStart studs, gone past BeamFadeEnd (far away they read as thin white poles). The foam and spray
	-- stay. AmbientFXController.
	BeamFadeStart = 380,
	BeamFadeEnd = 500,

	-- Parts tagged "NightGlow" (mushroom caps, rune carvings, magic flowers) light up in their "GlowColor" attribute
	-- once the night blend passes this (0 = day, 1 = full night). WorldLifeController.
	NightGlowAt = 0.4,

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
		-- The drawing sits this far from the camera and follows its position (like a skybox), so everything in the
		-- world (Spire, mountains, trees, players) is in front of it and hides it. Stars and lines are depth-tested
		-- BillboardGuis (pixel-sized, not fogged by the Atmosphere), so the distance doesn't change how big or bright
		-- the drawing looks.
		Distance = 2000,
		CeremonyDistance = 320, -- studs: the binding ceremony's stars start this far out, in the same directions
		Direction = Vector3.new(0, 0.42, -1), -- centre of the drawing (north, above the Spire)
		Span = Vector2.new(0.55, 0.32), -- horizontal / vertical size (fraction of the distance)
		RareScale = 1.3, -- rare constellations are drawn bigger and brighter
		StarSize = 34, -- pixels
		BrightStarSize = 50, -- the first star of each drawing
		StarImage = SPARKLE,
		LineWidth = 3, -- pixels (bright core)
		LineGlowWidth = 9, -- pixels (soft glow around the core)
		LineTransparency = 0.2,
		LineGlowTransparency = 0.75,
		Twinkle = 0.25, -- +/- size fraction
		-- Shooting stars at night.
		ShootingStarEvery = NumberRange.new(40, 90), -- seconds
		ShootingStarSeconds = 1.2,
		ShootingStarWidth = 4, -- pixels at the head (the tail tapers off)
		ShootingStarColor = Color3.fromRGB(230, 240, 255),
		DefaultColor = Color3.fromRGB(200, 220, 255), -- constellations without an element
	},
}
