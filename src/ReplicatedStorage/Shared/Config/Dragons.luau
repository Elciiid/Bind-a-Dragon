--!strict
-- Every dragon species, keyed by SpeciesId. SpeciesId is saved in player data, so never rename or remove a key
-- once the game is live (change Name instead).
-- PLACEHOLDER roster: one species per element per rarity.

export type Species = {
	Name: string,
	Element: string, -- key into Config/Elements
	Rarity: string, -- Id from Config/Rarities
	BindWeight: number, -- relative weight in its element's home pool
	BaseGoldPerSecond: number,
	BasePower: number,
	Role: string,
}

local Dragons: { [string]: Species } = {
	-- Fire
	Cinderwing = { Name = "Cinderwing", Element = "Fire", Rarity = "Common", BindWeight = 600, BaseGoldPerSecond = 750, BasePower = 10, Role = "Starter-balanced" },
	Emberclaw = { Name = "Emberclaw", Element = "Fire", Rarity = "Rare", BindWeight = 250, BaseGoldPerSecond = 1_800, BasePower = 24, Role = "Early economy" },
	Blazefang = { Name = "Blazefang", Element = "Fire", Rarity = "Epic", BindWeight = 110, BaseGoldPerSecond = 4_100, BasePower = 52, Role = "Mid economy" },
	Infernus = { Name = "Infernus", Element = "Fire", Rarity = "Legendary", BindWeight = 36, BaseGoldPerSecond = 10_500, BasePower = 105, Role = "Balanced legendary" },
	Solflare = { Name = "Solflare", Element = "Fire", Rarity = "Mythic", BindWeight = 4, BaseGoldPerSecond = 26_000, BasePower = 175, Role = "Gold chase" },

	-- Ice
	Frostling = { Name = "Frostling", Element = "Ice", Rarity = "Common", BindWeight = 620, BaseGoldPerSecond = 800, BasePower = 11, Role = "Balanced" },
	Glacierback = { Name = "Glacierback", Element = "Ice", Rarity = "Rare", BindWeight = 235, BaseGoldPerSecond = 1_700, BasePower = 26, Role = "Early hybrid" },
	Rimewing = { Name = "Rimewing", Element = "Ice", Rarity = "Epic", BindWeight = 105, BaseGoldPerSecond = 3_900, BasePower = 58, Role = "Hybrid" },
	Borealis = { Name = "Borealis", Element = "Ice", Rarity = "Legendary", BindWeight = 35, BaseGoldPerSecond = 9_500, BasePower = 130, Role = "Combat hybrid" },
	Aurorynth = { Name = "Aurorynth", Element = "Ice", Rarity = "Mythic", BindWeight = 5, BaseGoldPerSecond = 24_000, BasePower = 230, Role = "Upper hybrid" },

	-- Storm
	Gustwing = { Name = "Gustwing", Element = "Storm", Rarity = "Common", BindWeight = 580, BaseGoldPerSecond = 700, BasePower = 14, Role = "Combat common" },
	Sparkscale = { Name = "Sparkscale", Element = "Storm", Rarity = "Rare", BindWeight = 270, BaseGoldPerSecond = 1_500, BasePower = 32, Role = "Combat rare" },
	Thunderhorn = { Name = "Thunderhorn", Element = "Storm", Rarity = "Epic", BindWeight = 108, BaseGoldPerSecond = 3_500, BasePower = 78, Role = "Combat epic" },
	Tempestus = { Name = "Tempestus", Element = "Storm", Rarity = "Legendary", BindWeight = 36, BaseGoldPerSecond = 8_500, BasePower = 190, Role = "Combat legendary" },
	Stormcrown = { Name = "Stormcrown", Element = "Storm", Rarity = "Mythic", BindWeight = 6, BaseGoldPerSecond = 20_000, BasePower = 340, Role = "Apex combat" },

	-- Shadow
	Duskling = { Name = "Duskling", Element = "Shadow", Rarity = "Common", BindWeight = 640, BaseGoldPerSecond = 900, BasePower = 12, Role = "Economy common" },
	Nightclaw = { Name = "Nightclaw", Element = "Shadow", Rarity = "Rare", BindWeight = 220, BaseGoldPerSecond = 2_000, BasePower = 29, Role = "Balanced rare" },
	Umbrafang = { Name = "Umbrafang", Element = "Shadow", Rarity = "Epic", BindWeight = 100, BaseGoldPerSecond = 4_600, BasePower = 70, Role = "Economy epic" },
	Voidwing = { Name = "Voidwing", Element = "Shadow", Rarity = "Legendary", BindWeight = 33, BaseGoldPerSecond = 12_000, BasePower = 155, Role = "Economy legendary" },
	Eclipsar = { Name = "Eclipsar", Element = "Shadow", Rarity = "Mythic", BindWeight = 7, BaseGoldPerSecond = 30_000, BasePower = 270, Role = "Prestige economy" },
}

return Dragons
