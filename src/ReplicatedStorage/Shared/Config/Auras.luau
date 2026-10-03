--!strict
-- Mutation auras (checkpoint 5 of the 2026-10-02 update; code in Controllers/MutationAura + MutationAuraController, pictures in
-- Controllers/UI/DragonPicture). Every mutation has its own look, drawn on client-only objects (the art is never recolored):
--   Hoardscale  gold coin glints twinkling around the body
--   Warcrest    red embers rising off the body
--   Aetherwing  cyan wisps (soft motes, plus a few glowing orbs with a trail circling the dragon)
--   Primordial  a ring of rainbow starlight circling the dragon + starlight sparkles
-- Where they show: roost dragons, carried companions, the bind reveal, and a glow ring around the dragon's picture (cards, hotbar, pop-ups).
-- Cost control: auras farther than Distances.Emit from the camera are off; the orbiting parts only run within Distances.Orbit;
-- at most MaxHighlights dragons (the nearest) get a Highlight outline; Low effects (setting or low graphics quality) draw a fraction of
-- everything and no Highlights; Reduced Motion draws no orbiting (the ring and the orbs stand still) and no turning picture rings.

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SOFT = "rbxasset://textures/particles/smoke_main.dds"

export type Emitter = {
	Texture: string,
	Rate: number, -- particles per second for a 10-stud dragon (scaled by size)
	Lifetime: NumberRange,
	Speed: NumberRange,
	Size: number, -- studs at the start for a 10-stud dragon (scaled by size); the emitter grows and fades it
	Rise: number, -- upward acceleration, studs/s^2
	Color: ColorSequence,
	Transparency: NumberSequence,
	LightEmission: number,
	Drag: number?,
	Spin: NumberRange?,
}

export type Orbit = {
	Count: number, -- parts circling the dragon
	Radius: number, -- x the dragon's length
	Height: number, -- x the dragon's length above its center
	Size: number, -- part size, x the dragon's length
	Speed: number, -- radians/second
	Wobble: number, -- how much each part bobs up and down (x length)
	Rainbow: boolean?, -- hue-shifting colors instead of Color
	Trail: boolean?, -- each part leaves a trail
	Color: Color3?,
}

export type Aura = {
	Color: Color3, -- the mutation's identity color (Highlight, picture ring)
	Emitters: { Emitter },
	Orbit: Orbit?,
	RingGradient: ColorSequence?, -- the picture ring's colors (default: Color)
}

local function seq(...: Color3): ColorSequence
	local colors = { ... }
	local keys = {}
	for index, color in colors do
		table.insert(keys, ColorSequenceKeypoint.new((index - 1) / math.max(1, #colors - 1), color))
	end
	return ColorSequence.new(keys)
end

local fade = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.1), NumberSequenceKeypoint.new(0.8, 0.35), NumberSequenceKeypoint.new(1, 1) })

return {
	Distances = {
		Emit = 150, -- beyond this from the camera the aura is off
		Orbit = 80, -- beyond this the orbiting parts are off (the particles stay)
		LowEmit = 60, -- the same with Low effects
		LowOrbit = 0, -- Low effects: no orbiting parts at all
		Companion = 120, -- carried companions use this instead of Emit
	},
	MaxHighlights = 8, -- Roblox allows 31 Highlights; keep it well below
	CompanionOrbitScale = 0.55, -- a carried companion's orbiting parts: ring radius and part size x this (it flies right beside the player)
	MaxOrbiting = 8, -- dragons with orbiting parts at once (the nearest)
	LowScale = 0.35, -- particle rate scale with Low effects
	SizeReference = 10, -- the dragon length the emitter numbers are written for
	MinSizeScale = 0.6,
	MaxSizeScale = 2.4,
	ClassifySeconds = 0.25, -- how often distances/caps are re-evaluated
	ScanSeconds = 1, -- how often the roost plots are scanned for mutated dragons

	Highlight = { FillTransparency = 0.88, OutlineTransparency = 0.35 },

	-- the glow ring around dragon pictures (UI/DragonPicture)
	Ring = { Thickness = 2.5, GlowTransparency = 0.55, SpinSeconds = 6 },

	Auras = {
		Hoardscale = {
			Color = Color3.fromRGB(255, 190, 55),
			Emitters = {
				-- coin glints: sparkles that flash up bright and out again, anywhere on the body
				{ Texture = SPARKLE, Rate = 11, Lifetime = NumberRange.new(0.7, 1.3), Speed = NumberRange.new(0, 0.6), Size = 1.1, Rise = 0.4,
					Color = seq(Color3.fromRGB(255, 232, 140), Color3.fromRGB(255, 190, 55)), Transparency = fade, LightEmission = 1, Spin = NumberRange.new(-90, 90) },
			},
		} :: Aura,
		Warcrest = {
			Color = Color3.fromRGB(225, 75, 75),
			Emitters = {
				-- embers drifting up and cooling from yellow to deep red
				{ Texture = SPARKLE, Rate = 11, Lifetime = NumberRange.new(1.4, 2.4), Speed = NumberRange.new(0.5, 1.5), Size = 0.8, Rise = 3.2,
					Color = seq(Color3.fromRGB(255, 205, 90), Color3.fromRGB(240, 90, 40), Color3.fromRGB(150, 25, 25)), Transparency = fade, LightEmission = 1, Drag = 0.6 },
			},
		} :: Aura,
		Aetherwing = {
			Color = Color3.fromRGB(80, 220, 255),
			Emitters = {
				-- soft cyan wisps that curl slowly upward
				{ Texture = SOFT, Rate = 5, Lifetime = NumberRange.new(1.6, 2.6), Speed = NumberRange.new(0.4, 1.2), Size = 1.6, Rise = 1.2,
					Color = seq(Color3.fromRGB(150, 240, 255), Color3.fromRGB(60, 190, 255)), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.65), NumberSequenceKeypoint.new(1, 1) }),
					LightEmission = 0.9, Drag = 0.8 },
				{ Texture = SPARKLE, Rate = 4.5, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(0, 0.5), Size = 0.7, Rise = 0.6,
					Color = seq(Color3.fromRGB(200, 250, 255), Color3.fromRGB(90, 210, 255)), Transparency = fade, LightEmission = 1 },
			},
			Orbit = { Count = 3, Radius = 0.62, Height = 0.1, Size = 0.035, Speed = 1.3, Wobble = 0.14, Trail = true, Color = Color3.fromRGB(120, 230, 255) },
		} :: Aura,
		Primordial = {
			Color = Color3.fromRGB(255, 244, 190),
			RingGradient = seq(Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 220, 110), Color3.fromRGB(120, 255, 170), Color3.fromRGB(110, 190, 255), Color3.fromRGB(200, 140, 255), Color3.fromRGB(255, 120, 150)),
			Emitters = {
				-- starlight dust in every color of the ring
				{ Texture = SPARKLE, Rate = 9, Lifetime = NumberRange.new(0.9, 1.6), Speed = NumberRange.new(0.2, 0.9), Size = 0.9, Rise = 0.8,
					Color = seq(Color3.fromRGB(255, 150, 190), Color3.fromRGB(255, 235, 150), Color3.fromRGB(150, 255, 200), Color3.fromRGB(150, 205, 255), Color3.fromRGB(220, 170, 255)),
					Transparency = fade, LightEmission = 1, Spin = NumberRange.new(-120, 120) },
			},
			Orbit = { Count = 14, Radius = 0.7, Height = 0.05, Size = 0.04, Speed = 0.8, Wobble = 0.05, Rainbow = true },
		} :: Aura,
	} :: { [string]: Aura },

	SparkleTexture = SPARKLE,
}
