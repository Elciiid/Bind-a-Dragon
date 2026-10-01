--!strict
-- Dragon mutations. Mutation Ids are saved on dragons; never rename/remove an Id after launch.
-- Shares are the base probability split within each eligible species and must total exactly 1.

export type Mutation = {
	Id: string,
	Name: string,
	Share: number,
	LuckExponent: number,
	IncomeMultiplier: number,
	PowerMultiplier: number,
	Color: Color3,
	AnnounceOnBind: boolean,
}

local Mutations: { Mutation } = {
	{ Id = "Normal", Name = "Unmutated", Share = 0.90, LuckExponent = 0, IncomeMultiplier = 1, PowerMultiplier = 1, Color = Color3.fromRGB(190, 190, 190), AnnounceOnBind = false },
	{ Id = "Hoardscale", Name = "Hoardscale", Share = 0.04, LuckExponent = 0.15, IncomeMultiplier = 1.60, PowerMultiplier = 1.05, Color = Color3.fromRGB(255, 190, 55), AnnounceOnBind = false },
	{ Id = "Warcrest", Name = "Warcrest", Share = 0.04, LuckExponent = 0.15, IncomeMultiplier = 1.05, PowerMultiplier = 1.60, Color = Color3.fromRGB(225, 75, 75), AnnounceOnBind = false },
	{ Id = "Aetherwing", Name = "Aetherwing", Share = 0.015, LuckExponent = 0.35, IncomeMultiplier = 1.30, PowerMultiplier = 1.30, Color = Color3.fromRGB(135, 155, 255), AnnounceOnBind = false },
	{ Id = "Primordial", Name = "Primordial", Share = 0.005, LuckExponent = 0.60, IncomeMultiplier = 1.45, PowerMultiplier = 1.45, Color = Color3.fromRGB(255, 244, 190), AnnounceOnBind = true },
}

local ById: { [string]: Mutation } = {}
for _, mutation in Mutations do
	ById[mutation.Id] = mutation
end

return {
	NormalId = "Normal",
	Mutations = Mutations,
	ById = ById,
	Get = function(id: string?): Mutation
		return ById[id or ""] or Mutations[1]
	end,
}
