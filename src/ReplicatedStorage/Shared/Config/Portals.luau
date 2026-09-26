--!strict
-- Portal look, drawn on each client by PortalController. A portal is the builder's arch (`Art`) with a `Surface`
-- part in its opening; the Surface is tagged "AreaPortal" with AreaId = the destination (AreaService teleports).
-- Locked = the local player hasn't unlocked the destination yet (Config/Areas RebirthsRequired).
-- Label distances and sizes are in Config/UITheme WorldLabels; label wording in Config/Text.

return {
	-- Surface color per destination AreaId.
	Colors = {
		StarterMeadow = Color3.fromRGB(150, 235, 140),
		VolcanoPeak = Color3.fromRGB(255, 110, 40),
		FrozenCliffs = Color3.fromRGB(120, 210, 255),
		StormCanyon = Color3.fromRGB(255, 225, 80),
		EclipseIsles = Color3.fromRGB(165, 100, 240),
	} :: { [string]: Color3 },
	DefaultColor = Color3.fromRGB(200, 200, 255), -- an AreaId without a color above

	SurfaceTransparency = 0.25, -- unlocked Neon surface
	LightBrightness = 1.4,
	LightRange = 18, -- studs

	-- Swirl: two image layers turning in opposite directions over the surface, tinted with the portal color.
	-- Free Creator Store decal "Swirling Vortex" (4871063), used through its thumbnail URL because a Decal id does not
	-- load as an image. "" = no swirl.
	SwirlImage = "rbxthumb://type=Asset&id=4871063&w=420&h=420",
	SwirlTransparency = 0.5,
	SwirlSpeed = 18, -- degrees per second (the second layer turns the other way at SwirlCounterRatio)
	SwirlCounterRatio = 0.6,
	SwirlScale = 1.4, -- image size relative to the surface's longer side
	SwirlPixelsPerStud = 20,
	AnimateWithin = 250, -- studs: only portals this close to the camera animate

	-- Rising particles.
	ParticleRate = 5, -- per second
	ParticleSpeed = 2.5, -- studs per second, upward
	ParticleLifetime = 2.5, -- seconds
	ParticleSize = 0.5, -- studs

	-- Locked look: dim gray, no light, no particles, no swirl.
	LockedColor = Color3.fromRGB(95, 95, 105),
	LockedTransparency = 0.45,
	LockShowDistance = 25, -- studs: the lock + "Rebirth X" label only shows this close
}
