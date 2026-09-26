--!strict
-- Star Altar night glow, drawn on each client (AltarGlowController). Works for every altar (tag "StarAltar"): glow points
-- sit on invisible "GlowAnchor" parts in the altar's "Glow" folder (Rank 1 = the main crystal). Color = the area's
-- element (Config/Areas Element -> Config/Elements), or NoElementColor. Everything fades with the night blend and is
-- brighter when tonight's constellation favors the altar's area.

return {
	NoElementColor = Color3.fromRGB(150, 205, 255), -- altars in areas without an element (Starter Meadow)
	FarDistance = 400, -- studs: no effects beyond this from the camera
	FavoredBoost = 1.6, -- brightness/size/rate multiplier when tonight favors this area
	BreathSeconds = 4, -- slow pulse of the whole glow
	BreathAmount = 0.15,

	-- Light beam rising from the main crystal (a soft core and a wider sparkling shell).
	Beam = {
		Height = 150, -- studs
		CoreWidth = 2.5,
		ShellWidth = 9,
		CoreTransparency = 0.45, -- at full night (fades toward the top)
		ShellTransparency = 0.6,
		ShellTexture = "rbxasset://textures/particles/sparkles_main.dds",
		TextureLength = 12,
		TextureSpeed = 0.35,
	},

	-- Glow points on the crystal tips.
	Tips = {
		MainSize = 9, -- studs (Rank 1)
		Size = 4.5, -- studs (other tips)
		Image = "rbxasset://textures/particles/sparkles_main.dds",
		MaxLights = 3, -- only the first few tips cast real light (phone budget)
		LightRange = 14,
		LightBrightness = 2,
	},

	-- Gentle sparkles rising around the altar.
	Sparkles = {
		Rate = 6, -- per second at full night
		Radius = 18, -- studs around the altar
		Speed = 2.5,
		Lifetime = 3.5,
		Size = 0.45,
	},

	-- A faint outline + fill on the altar that pulses slowly (only close up, never with Low effects).
	Highlight = {
		Enabled = true,
		Distance = 120,
		FillTransparency = 0.82, -- at the brightest point of the pulse
		OutlineTransparency = 0.55,
		PulseSeconds = 4,
	},
}
