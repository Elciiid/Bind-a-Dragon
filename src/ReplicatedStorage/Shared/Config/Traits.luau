--!strict
-- Traits (rolled with Wyrm Runes) and grades (rolled with Dragonstones). Both come from the Dragon Spire.
-- A roll replaces the dragon's current trait/grade with a random one (weighted). New dragons have neither.
-- Trait/grade Ids are saved on dragons, so never rename or remove an Id once live (change Name instead).
-- PLACEHOLDER numbers.

export type Trait = {
	Id: string,
	Name: string,
	Weight: number, -- relative roll chance
	Income: number, -- added income bonus (0.3 = +30% roost gold)
	Power: number, -- added battle power bonus (0.3 = +30% Spire power)
	Tier: string, -- Config/Rarities Id, used for its color and for server announcements
}

export type Grade = {
	Id: string,
	Weight: number, -- relative roll chance
	Multiplier: number, -- multiplies both income and power
	Tier: string, -- Config/Rarities Id, for color
}

local Traits: { Trait } = {
	{ Id = "Hoarder", Name = "Hoarder", Weight = 250, Income = 0.10, Power = 0, Tier = "Common" },
	{ Id = "Scalebound", Name = "Scalebound", Weight = 250, Income = 0, Power = 0.10, Tier = "Common" },
	{ Id = "Swiftwing", Name = "Swiftwing", Weight = 180, Income = 0.08, Power = 0.08, Tier = "Common" },
	{ Id = "Gilded", Name = "Gilded", Weight = 120, Income = 0.30, Power = 0, Tier = "Rare" },
	{ Id = "Ironhide", Name = "Ironhide", Weight = 120, Income = 0, Power = 0.30, Tier = "Rare" },
	{ Id = "Emberheart", Name = "Emberheart", Weight = 50, Income = 0.20, Power = 0.20, Tier = "Epic" },
	{ Id = "Goldhoard", Name = "Goldhoard", Weight = 12, Income = 0.60, Power = 0, Tier = "Epic" },
	{ Id = "Stormcaller", Name = "Stormcaller", Weight = 12, Income = 0, Power = 0.60, Tier = "Epic" },
	{ Id = "Ancient", Name = "Ancient", Weight = 4, Income = 0.75, Power = 0.75, Tier = "Legendary" },
	{ Id = "Celestial", Name = "Celestial", Weight = 0.9, Income = 1.5, Power = 1.5, Tier = "Mythic" },
	{ Id = "Dragonlord", Name = "Dragonlord", Weight = 0.1, Income = 3, Power = 3, Tier = "Mythic" },
}

local Grades: { Grade } = {
	{ Id = "D", Weight = 40, Multiplier = 1, Tier = "Common" },
	{ Id = "C", Weight = 28, Multiplier = 1.1, Tier = "Common" },
	{ Id = "B", Weight = 18, Multiplier = 1.25, Tier = "Rare" },
	{ Id = "A", Weight = 9, Multiplier = 1.5, Tier = "Epic" },
	{ Id = "S", Weight = 4, Multiplier = 2, Tier = "Legendary" },
	{ Id = "SS", Weight = 0.9, Multiplier = 3, Tier = "Mythic" },
	{ Id = "SSS", Weight = 0.1, Multiplier = 5, Tier = "Mythic" },
}

return {
	Traits = Traits,
	Grades = Grades,

	TraitRollCost = 1, -- Wyrm Runes per trait roll
	GradeRollCost = 1, -- Dragonstones per grade roll

	-- Rolls at or above this tier are announced to the whole server.
	AnnounceTier = "Legendary",
}
