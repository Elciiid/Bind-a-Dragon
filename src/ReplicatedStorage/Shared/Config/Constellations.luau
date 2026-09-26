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
	-- Drawing in the night sky (SkyController): star positions from -1 to 1 (x right, y up; the first star is drawn
	-- brightest) and lines between star numbers.
	Stars: { Vector2 },
	Lines: { { number } },
}

local Constellations: { Constellation } = {
	{
		Id = "PhoenixCoil", Name = "The Phoenix Coil", Element = "Fire", Weight = 10, Rare = false, Luck = 1,
		-- a bird with spread wings and a curling tail
		Stars = {
			Vector2.new(0, 0.85), Vector2.new(0.1, 0.5), Vector2.new(0, 0.1), Vector2.new(-0.5, 0.35), Vector2.new(-0.95, 0.65),
			Vector2.new(0.5, 0.35), Vector2.new(0.95, 0.7), Vector2.new(-0.1, -0.35), Vector2.new(0.2, -0.7), Vector2.new(-0.15, -0.95),
		},
		Lines = { { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 5 }, { 3, 6 }, { 6, 7 }, { 3, 8 }, { 8, 9 }, { 9, 10 } },
	},
	{
		Id = "FrostCrown", Name = "The Frost Crown", Element = "Ice", Weight = 10, Rare = false, Luck = 1,
		-- a crown with three points
		Stars = {
			Vector2.new(0, 0.7), Vector2.new(-0.8, -0.4), Vector2.new(0.8, -0.4), Vector2.new(-0.8, 0.35), Vector2.new(-0.4, 0),
			Vector2.new(0.4, 0), Vector2.new(0.8, 0.35),
		},
		Lines = { { 2, 3 }, { 2, 4 }, { 4, 5 }, { 5, 1 }, { 1, 6 }, { 6, 7 }, { 7, 3 } },
	},
	{
		Id = "ThunderWyrm", Name = "The Thunder Wyrm", Element = "Storm", Weight = 10, Rare = false, Luck = 1,
		-- a zig-zag bolt of a serpent
		Stars = {
			Vector2.new(-0.9, 0.75), Vector2.new(-0.4, 0.45), Vector2.new(-0.65, 0.1), Vector2.new(0, -0.05), Vector2.new(-0.2, -0.4),
			Vector2.new(0.45, -0.6), Vector2.new(0.95, -0.4),
		},
		Lines = { { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 5 }, { 5, 6 }, { 6, 7 } },
	},
	{
		Id = "VeiledEye", Name = "The Veiled Eye", Element = "Shadow", Weight = 10, Rare = false, Luck = 1,
		-- an almond eye with a single star for the pupil
		Stars = {
			Vector2.new(0, 0), Vector2.new(-0.95, 0), Vector2.new(-0.4, 0.4), Vector2.new(0.4, 0.4), Vector2.new(0.95, 0),
			Vector2.new(0.4, -0.4), Vector2.new(-0.4, -0.4),
		},
		Lines = { { 2, 3 }, { 3, 4 }, { 4, 5 }, { 5, 6 }, { 6, 7 }, { 7, 2 } },
	},
	{
		Id = "EclipseSerpent", Name = "The Eclipse Serpent", Element = "Shadow", Weight = 1, Rare = true, Luck = 1.5,
		-- a ring (the eclipse) with a serpent's tail winding away from it
		Stars = {
			Vector2.new(0.35, 0.75), Vector2.new(0.7, 0.55), Vector2.new(0.7, 0.1), Vector2.new(0.35, -0.1), Vector2.new(0, 0.1),
			Vector2.new(0, 0.55), Vector2.new(-0.35, -0.25), Vector2.new(-0.25, -0.65), Vector2.new(-0.75, -0.8),
		},
		Lines = { { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 5 }, { 5, 6 }, { 6, 1 }, { 5, 7 }, { 7, 8 }, { 8, 9 } },
	},
	{
		Id = "DragonKing", Name = "The Dragon King", Element = nil, Weight = 1, Rare = true, Luck = 2,
		-- a crowned dragon: head, neck, body, a raised wing, legs and tail
		Stars = {
			Vector2.new(0.75, 0.7), Vector2.new(0.85, 0.95), Vector2.new(0.6, 0.95), Vector2.new(0.45, 0.4), Vector2.new(0.05, 0.1),
			Vector2.new(-0.25, 0.65), Vector2.new(-0.75, 0.9), Vector2.new(-0.5, 0.3), Vector2.new(0.25, -0.45), Vector2.new(-0.15, -0.45),
			Vector2.new(-0.5, -0.2), Vector2.new(-0.9, -0.6),
		},
		Lines = { { 3, 2 }, { 2, 1 }, { 1, 4 }, { 4, 5 }, { 5, 6 }, { 6, 7 }, { 7, 8 }, { 8, 5 }, { 5, 9 }, { 5, 10 }, { 5, 11 }, { 11, 12 } },
	},
}

return Constellations
