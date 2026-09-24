--!strict
-- Every dragon species, keyed by SpeciesId. SpeciesId is saved in player data, so never rename or remove a key
-- once the game is live (change Name instead).
-- PLACEHOLDER roster: one species per element per rarity.

export type Species = {
	Name: string,
	Element: string, -- key into Config/Elements
	Rarity: string, -- Id from Config/Rarities
}

local Dragons: { [string]: Species } = {
	-- Fire
	Cinderwing = { Name = "Cinderwing", Element = "Fire", Rarity = "Common" },
	Emberclaw = { Name = "Emberclaw", Element = "Fire", Rarity = "Rare" },
	Blazefang = { Name = "Blazefang", Element = "Fire", Rarity = "Epic" },
	Infernus = { Name = "Infernus", Element = "Fire", Rarity = "Legendary" },
	Solflare = { Name = "Solflare", Element = "Fire", Rarity = "Mythic" },

	-- Ice
	Frostling = { Name = "Frostling", Element = "Ice", Rarity = "Common" },
	Glacierback = { Name = "Glacierback", Element = "Ice", Rarity = "Rare" },
	Rimewing = { Name = "Rimewing", Element = "Ice", Rarity = "Epic" },
	Borealis = { Name = "Borealis", Element = "Ice", Rarity = "Legendary" },
	Aurorynth = { Name = "Aurorynth", Element = "Ice", Rarity = "Mythic" },

	-- Storm
	Gustwing = { Name = "Gustwing", Element = "Storm", Rarity = "Common" },
	Sparkscale = { Name = "Sparkscale", Element = "Storm", Rarity = "Rare" },
	Thunderhorn = { Name = "Thunderhorn", Element = "Storm", Rarity = "Epic" },
	Tempestus = { Name = "Tempestus", Element = "Storm", Rarity = "Legendary" },
	Stormcrown = { Name = "Stormcrown", Element = "Storm", Rarity = "Mythic" },

	-- Shadow
	Duskling = { Name = "Duskling", Element = "Shadow", Rarity = "Common" },
	Nightclaw = { Name = "Nightclaw", Element = "Shadow", Rarity = "Rare" },
	Umbrafang = { Name = "Umbrafang", Element = "Shadow", Rarity = "Epic" },
	Voidwing = { Name = "Voidwing", Element = "Shadow", Rarity = "Legendary" },
	Eclipsar = { Name = "Eclipsar", Element = "Shadow", Rarity = "Mythic" },
}

return Dragons
