--!strict
-- Evolution stages, from first to last. A dragon's stage comes from its level (it evolves when it reaches MinLevel).
-- Stage Id is used to find art: ReplicatedStorage/Assets/Dragons/<SpeciesId>/<StageId>.
--
-- Branches: when a dragon evolves, the constellation in the sky is saved as that stage's branch
-- (dragon.Evolutions[stageId]). Each night-time branch gives an income bonus, bigger when the constellation's
-- element matches the dragon's. Evolving during the day gives a plain branch (DayBranchId) with no bonus.
-- The latest branch also tints the dragon's accent color in that constellation's element.
-- PLACEHOLDER numbers.

export type Stage = {
	Id: string,
	Name: string,
	MinLevel: number,
	IncomeMultiplier: number, -- multiplies roost gold/sec
	ModelScale: number, -- size of the placeholder model (real art can ignore this)
}

local Stages: { Stage } = {
	{ Id = "Hatchling", Name = "Hatchling", MinLevel = 1, IncomeMultiplier = 1, ModelScale = 1 },
	{ Id = "Drake", Name = "Drake", MinLevel = 10, IncomeMultiplier = 3, ModelScale = 1.4 },
	{ Id = "Dragon", Name = "Dragon", MinLevel = 25, IncomeMultiplier = 8, ModelScale = 1.9 },
	{ Id = "Elder", Name = "Elder", MinLevel = 50, IncomeMultiplier = 20, ModelScale = 2.5 },
}

return {
	Stages = Stages,

	-- Income bonus per branch, added together (e.g. two matching branches = +40%).
	BranchIncomeBonus = 0.10, -- evolved under any night constellation
	MatchingBranchIncomeBonus = 0.20, -- evolved under a constellation of the dragon's own element

	-- Saved as the branch when a dragon evolves during the day. Never rename once live.
	DayBranchId = "Day",
}
