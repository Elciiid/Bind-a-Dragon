--!strict
-- CLI: luau tools/sim/SpireRewards.test.luau
-- Validate configured guaranteed rewards without relying on random potion samples.
local config = require("../../src/ReplicatedStorage/Shared/Config/Spire")

local function total(limit: number, first: boolean): (number, number)
	local runes, stones = 0, 0
	for floor = 1, limit do
		for _, drops in { config.VictoryDrops, if first then config.FirstClearDrops else config.ReclearDrops } do
			for _, drop in drops do
				if (drop.Chance or 1) == 1 and floor % drop.Every == (drop.Offset or 0)
					and not (drop.SkipBosses and floor % config.BossEvery == 0) then
					runes += drop.WyrmRunes or 0
					stones += drop.Dragonstones or 0
				end
			end
		end
	end
	return runes, stones
end

assert(config.MaxFloors == 100 and config.FightSeconds * config.MaxFloors == 1200, "full run must fight all 100 stages in 20 minutes")
for _, case in { { 5, true, 1 }, { 10, true, 3 }, { 10, false, 1 }, { 100, true, 30 }, { 100, false, 10 } } do
	local runes, stones = total(case[1] :: number, case[2] :: boolean)
	assert(runes == case[3] and stones == case[3], `reward regression at stage {case[1]}: {runes} runes, {stones} stones`)
end
print("Spire guaranteed reward checks passed: first full run 30 each; repeat 10 each; early milestones attainable.")
