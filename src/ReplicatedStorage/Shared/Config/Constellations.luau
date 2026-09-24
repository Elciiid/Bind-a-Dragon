--!strict
-- Constellations that can appear at night. One is picked per night (same pick on every server).
-- Id is saved in the Star Atlas, so never rename or remove an Id once live.
-- Order matters for the nightly pick, so add new ones at the end.
-- PLACEHOLDER list.

export type Constellation = {
	Id: string,
	Name: string,
	Element: string?, -- dragons bound tonight are this element; nil = any element
	Weight: number, -- relative chance to be tonight's constellation
	Rare: boolean, -- rare ones get a server-wide announcement and a stronger sky tint
	Luck: number, -- bind luck multiplier for everyone while it's up (the "rare sky event" boost)
}

local Constellations: { Constellation } = {
	{ Id = "PhoenixCoil", Name = "The Phoenix Coil", Element = "Fire", Weight = 10, Rare = false, Luck = 1 },
	{ Id = "FrostCrown", Name = "The Frost Crown", Element = "Ice", Weight = 10, Rare = false, Luck = 1 },
	{ Id = "ThunderWyrm", Name = "The Thunder Wyrm", Element = "Storm", Weight = 10, Rare = false, Luck = 1 },
	{ Id = "VeiledEye", Name = "The Veiled Eye", Element = "Shadow", Weight = 10, Rare = false, Luck = 1 },
	{ Id = "EclipseSerpent", Name = "The Eclipse Serpent", Element = "Shadow", Weight = 1, Rare = true, Luck = 1.5 },
	{ Id = "DragonKing", Name = "The Dragon King", Element = nil, Weight = 1, Rare = true, Luck = 2 },
}

return Constellations
