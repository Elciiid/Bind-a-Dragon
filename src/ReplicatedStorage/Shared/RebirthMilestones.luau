--!strict
-- Rebirth Milestone Ladder helpers (Config/RebirthMilestones), used by server and client: which milestones a rebirth
-- count has reached, the perks they give and the title rank.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.RebirthMilestones)
local BindingConfig = require(ReplicatedStorage.Shared.Config.Binding)
local Text = require(ReplicatedStorage.Shared.Config.Text)

local RebirthMilestones = {}

export type Milestone = Config.Milestone

local ROMAN = { "", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }

-- Milestones in rebirth order.
local sorted: { Milestone } = table.clone(Config.Milestones)
table.sort(sorted, function(a, b)
	return a.Rebirths < b.Rebirths
end)
RebirthMilestones.All = sorted

-- The milestones reached with this many rebirths.
function RebirthMilestones.Reached(rebirths: number): { Milestone }
	local list = {}
	for _, milestone in sorted do
		if rebirths >= milestone.Rebirths then
			table.insert(list, milestone)
		end
	end
	return list
end

-- The next milestone not reached yet, or nil.
function RebirthMilestones.Next(rebirths: number): Milestone?
	for _, milestone in sorted do
		if rebirths < milestone.Rebirths then
			return milestone
		end
	end
	return nil
end

-- True if any reached milestone has this boolean perk.
function RebirthMilestones.Has(rebirths: number, perk: string): boolean
	for _, milestone in sorted do
		if rebirths >= milestone.Rebirths and milestone.Perks[perk] then
			return true
		end
	end
	return false
end

-- Sum of a numeric perk over the reached milestones.
function RebirthMilestones.Sum(rebirths: number, perk: string): number
	local total = 0
	for _, milestone in sorted do
		local value = milestone.Perks[perk]
		if rebirths >= milestone.Rebirths and type(value) == "number" then
			total += value
		end
	end
	return total
end

-- The Echo Sigil cap for a player with this many rebirths.
function RebirthMilestones.GetEchoSigilCap(rebirths: number): number
	return BindingConfig.EchoSigilCap + RebirthMilestones.Sum(rebirths, "EchoSigilCap")
end

-- Ascended altars: the bind luck multiplier from milestones (1 = none). Product of the AscendedLuck perks.
function RebirthMilestones.GetAscendedLuck(rebirths: number): number
	local luck = 1
	for _, milestone in sorted do
		local value = milestone.Perks.AscendedLuck
		if rebirths >= milestone.Rebirths and type(value) == "number" then
			luck *= value
		end
	end
	return luck
end

-- The title on the nameplate: (text, isGold). A rank every Titles[].From, numerals past the last rank; the Champion
-- milestone swaps the rank for the gold champion title. nil with no rebirths.
function RebirthMilestones.GetTitle(rebirths: number): (string?, boolean)
	if rebirths <= 0 then
		return nil, false
	end
	if RebirthMilestones.Has(rebirths, "Champion") then
		return Text.Milestones.ChampionTitle, true
	end
	local rank = Config.Titles[1]
	for _, entry in Config.Titles do
		if rebirths >= entry.From then
			rank = entry
		end
	end
	local name = Text.Milestones.Titles[rank.Id] or rank.Id
	if rank == Config.Titles[#Config.Titles] then
		local steps = math.floor((rebirths - rank.From) / Config.TitleStep)
		if steps > 0 then
			name ..= " " .. (ROMAN[steps + 1] or tostring(steps + 1))
		end
	end
	return name, false
end

-- Display name / description of a milestone (Config/Text.Milestones.Items[Id]).
function RebirthMilestones.NameOf(milestone: Milestone): string
	local item = Text.Milestones.Items[milestone.Id]
	return if item then item.Name else milestone.Id
end

function RebirthMilestones.InfoOf(milestone: Milestone): string
	local item = Text.Milestones.Items[milestone.Id]
	return if item then item.Info else ""
end

return RebirthMilestones
