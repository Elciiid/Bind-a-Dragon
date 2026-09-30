--!strict
-- Which look a sanctuary shows (Valley rework). Placeholder rule until the Essence feature exists: the highest look
-- in Config/WorldUI.SanctuaryLooks whose MinPoints the owner's upgrade points reach; points = extra roost slots bought
-- + income levels / IncomeLevelsPerPoint (the same points the sanctuary tiers use). Used by RoostService (server sets
-- the plot attribute "SanctuaryLook") and the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoostConfig = require(ReplicatedStorage.Shared.Config.Roost)
local WorldUI = require(ReplicatedStorage.Shared.Config.WorldUI)

local Settings = WorldUI.SanctuaryLooks

local SanctuaryLooks = {}

function SanctuaryLooks.Points(slots: number, incomeLevel: number): number
	return math.max(0, slots - RoostConfig.BaseSlots) + math.floor(incomeLevel / WorldUI.SanctuaryTiers.IncomeLevelsPerPoint)
end

function SanctuaryLooks.IsLook(id: string): boolean
	for _, look in Settings.Looks do
		if look.Id == id then
			return true
		end
	end
	return false
end

function SanctuaryLooks.ForPoints(points: number): string
	local best = Settings.Default
	for _, look in Settings.Looks do
		if points >= look.MinPoints then
			best = look.Id
		end
	end
	return best
end

function SanctuaryLooks.NameOf(id: string): string
	for _, look in Settings.Looks do
		if look.Id == id then
			return look.Name
		end
	end
	return id
end

return SanctuaryLooks
