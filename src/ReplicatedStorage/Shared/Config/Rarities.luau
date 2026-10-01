--!strict
-- Broad presentation tiers only. Exact odds and stats live on species/mutations, never here.

export type Rarity = {
	Id: string,
	Name: string,
	Color: Color3,
	AnnounceOnBind: boolean, -- tell the whole server when someone binds one
	UndiscoveredOddsBand: string, -- deliberately broad; exact species odds unlock on discovery
}

local Rarities: { Rarity } = {
	{ Id = "Common", Name = "Common", Color = Color3.fromRGB(190, 190, 190), AnnounceOnBind = false, UndiscoveredOddsBand = "about 1 in 1-2" },
	{ Id = "Rare", Name = "Rare", Color = Color3.fromRGB(80, 160, 255), AnnounceOnBind = false, UndiscoveredOddsBand = "about 1 in 3-5" },
	{ Id = "Epic", Name = "Epic", Color = Color3.fromRGB(180, 90, 255), AnnounceOnBind = false, UndiscoveredOddsBand = "about 1 in 8-12" },
	{ Id = "Legendary", Name = "Legendary", Color = Color3.fromRGB(255, 190, 40), AnnounceOnBind = true, UndiscoveredOddsBand = "about 1 in 25-35" },
	{ Id = "Mythic", Name = "Mythic", Color = Color3.fromRGB(255, 60, 110), AnnounceOnBind = true, UndiscoveredOddsBand = "about 1 in 100-300" },
}

return Rarities
