--!strict
-- Dragon rarities, in order from most common to rarest. Order matters: luck boosts every tier after the first.
-- PLACEHOLDER numbers; the designer owns balancing.

export type Rarity = {
	Id: string,
	Name: string,
	Color: Color3,
	BindWeight: number, -- relative chance when binding (weights don't need to add up to anything)
	GoldPerSecond: number, -- base roost income before level/stage multipliers
	BasePower: number, -- base Spire battle power before level/stage/trait/grade multipliers
	AnnounceOnBind: boolean, -- tell the whole server when someone binds one
}

local Rarities: { Rarity } = {
	{ Id = "Common", Name = "Common", Color = Color3.fromRGB(190, 190, 190), BindWeight = 600, GoldPerSecond = 1, BasePower = 10, AnnounceOnBind = false },
	{ Id = "Rare", Name = "Rare", Color = Color3.fromRGB(80, 160, 255), BindWeight = 250, GoldPerSecond = 5, BasePower = 25, AnnounceOnBind = false },
	{ Id = "Epic", Name = "Epic", Color = Color3.fromRGB(180, 90, 255), BindWeight = 110, GoldPerSecond = 20, BasePower = 60, AnnounceOnBind = false },
	{ Id = "Legendary", Name = "Legendary", Color = Color3.fromRGB(255, 190, 40), BindWeight = 35, GoldPerSecond = 100, BasePower = 150, AnnounceOnBind = true },
	{ Id = "Mythic", Name = "Mythic", Color = Color3.fromRGB(255, 60, 110), BindWeight = 5, GoldPerSecond = 500, BasePower = 400, AnnounceOnBind = true },
}

return Rarities
