--!strict
-- Areas, keyed by AreaId. Star Altars in the world carry an "AreaId" attribute that points here.
-- AreaId may be saved later, so never rename a key once live.

export type Area = {
	Name: string,
	Order: number, -- display/progression order
	RebirthsRequired: number, -- rebirths needed to unlock (areas stay unlocked forever)
	BindLuck: number, -- luck multiplier for this area's Star Altar
	LevelCap: number, -- max dragon level once this area is unlocked
}

local Areas: { [string]: Area } = {
	StarterMeadow = { Name = "Starter Meadow", Order = 1, RebirthsRequired = 0, BindLuck = 1, LevelCap = 50 },
	VolcanoPeak = { Name = "Volcano Peak", Order = 2, RebirthsRequired = 1, BindLuck = 1.25, LevelCap = 60 },
	FrozenCliffs = { Name = "Frozen Cliffs", Order = 3, RebirthsRequired = 3, BindLuck = 1.5, LevelCap = 70 },
	StormCanyon = { Name = "Storm Canyon", Order = 4, RebirthsRequired = 5, BindLuck = 2, LevelCap = 80 },
	SkyIsles = { Name = "Sky Isles", Order = 5, RebirthsRequired = 10, BindLuck = 3, LevelCap = 100 },
}

return Areas
