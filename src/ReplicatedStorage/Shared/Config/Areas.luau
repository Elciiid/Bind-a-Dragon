--!strict
-- Areas, unlocked by rebirths. Each has a Star Altar (tag "StarAltar", attribute AreaId = this key).
--
-- Rosters: Species lists every dragon bindable at that area's altar. A roll only picks rarities present in the list.
-- Element areas (Element set) are that element's home: they hold all of its rarities, and a night whose constellation
-- has the same element gives their altar Config/Luck FavoredAreaLuck. Areas without an Element (Starter Meadow) let
-- tonight's constellation pick the element from their list, as before.
-- A new area or dragon only needs config here (plus the altar, AreaSpawn and portal in the world).
-- Area Ids are used by altars/portals in the place file, so never rename an Id once built (change Name instead).
-- PLACEHOLDER numbers.

export type Area = {
	Name: string,
	Order: number, -- display/progression order
	RebirthsRequired: number, -- rebirths needed to unlock (areas stay unlocked forever)
	BindLuck: number, -- luck multiplier for this area's Star Altar
	Element: string?, -- home element (Config/Elements); nil = tonight's constellation picks it
	Species: { string }, -- Config/Dragons SpeciesIds bindable here
}

local Areas: { [string]: Area } = {
	StarterMeadow = {
		Name = "Starter Meadow",
		Order = 1,
		RebirthsRequired = 0,
		BindLuck = 1,
		Element = nil,
		-- Common + Rare of every element; luck only shifts toward Rare here.
		Species = { "Cinderwing", "Emberclaw", "Frostling", "Glacierback", "Gustwing", "Sparkscale", "Duskling", "Nightclaw" },
	},
	VolcanoPeak = {
		Name = "Volcano Peak",
		Order = 2,
		RebirthsRequired = 1,
		BindLuck = 1.25,
		Element = "Fire",
		Species = { "Cinderwing", "Emberclaw", "Blazefang", "Infernus", "Solflare" },
	},
	FrozenCliffs = {
		Name = "Frozen Cliffs",
		Order = 3,
		RebirthsRequired = 3,
		BindLuck = 1.5,
		Element = "Ice",
		Species = { "Frostling", "Glacierback", "Rimewing", "Borealis", "Aurorynth" },
	},
	StormCanyon = {
		Name = "Storm Canyon",
		Order = 4,
		RebirthsRequired = 5,
		BindLuck = 2,
		Element = "Storm",
		Species = { "Gustwing", "Sparkscale", "Thunderhorn", "Tempestus", "Stormcrown" },
	},
	EclipseIsles = {
		Name = "Eclipse Isles", -- Shadow-themed (builder note: match the Shadow dragons)
		Order = 5,
		RebirthsRequired = 10,
		BindLuck = 3,
		Element = "Shadow",
		Species = { "Duskling", "Nightclaw", "Umbrafang", "Voidwing", "Eclipsar" },
	},
}

return Areas
