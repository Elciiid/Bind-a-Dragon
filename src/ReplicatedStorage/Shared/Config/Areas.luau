--!strict
-- Areas, keyed by AreaId. Star Altars in the world carry an "AreaId" attribute that points here.
-- AreaId may be saved later, so never rename a key once live.
-- Level caps are no longer per area: they come from rebirths (Config/Leveling CapBase + CapPerRebirth).

export type Area = {
	Name: string,
	Order: number, -- display/progression order
	RebirthsRequired: number, -- rebirths needed to unlock (areas stay unlocked forever)
	BindLuck: number, -- luck multiplier for this area's Star Altar
}

local Areas: { [string]: Area } = {
	StarterMeadow = { Name = "Starter Meadow", Order = 1, RebirthsRequired = 0, BindLuck = 1 },
	VolcanoPeak = { Name = "Volcano Peak", Order = 2, RebirthsRequired = 1, BindLuck = 1.25 },
	FrozenCliffs = { Name = "Frozen Cliffs", Order = 3, RebirthsRequired = 3, BindLuck = 1.5 },
	StormCanyon = { Name = "Storm Canyon", Order = 4, RebirthsRequired = 5, BindLuck = 2 },
	SkyIsles = { Name = "Sky Isles", Order = 5, RebirthsRequired = 10, BindLuck = 3 },
}

return Areas
