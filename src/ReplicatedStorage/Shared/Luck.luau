--!strict
-- Bind luck math, shared by server and client. The server uses it for the real roll; the client uses the
-- exact same function to show the player their luck before they bind, so the two always match.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local LuckConfig = require(ReplicatedStorage.Shared.Config.Luck)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Cycle = require(ReplicatedStorage.Shared.Cycle)

export type Breakdown = {
	Total: number, -- after the cap
	Capped: boolean,
	Area: number,
	Moon: number,
	MoonName: string,
	Constellation: number,
	Stardust: number,
	Group: number,
	GroupSize: number,
}

export type OfferingData = {
	OfferingNight: number,
	Offerings: number,
}

local Luck = {}

function Luck.GetMoonPhase(nightIndex: number): LuckConfig.MoonPhase
	return LuckConfig.MoonPhases[nightIndex % #LuckConfig.MoonPhases + 1]
end

-- Offerings made tonight (offerings from earlier nights don't count).
function Luck.GetOfferingCount(data: OfferingData, nightIndex: number): number
	return if data.OfferingNight == nightIndex then data.Offerings else 0
end

-- The next offering the player can make, or nil if they've made them all.
function Luck.GetNextOffering(offeringCount: number): LuckConfig.Offering?
	return LuckConfig.Offerings[offeringCount + 1]
end

-- Players whose characters are within radius of position (including the local/binding player).
function Luck.CountPlayersNear(position: Vector3, radius: number): number
	local count = 0
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - position).Magnitude <= radius then
			count += 1
		end
	end
	return count
end

-- Each rarity's roll weight at the given luck, in Config/Rarities order. Rarer tiers gain more (TierScaling).
function Luck.GetRarityWeights(luck: number): { number }
	local weights = {}
	for index, rarity in Rarities do
		weights[index] = rarity.BindWeight * luck ^ (LuckConfig.TierScaling * (index - 1))
	end
	return weights
end

function Luck.Compute(areaId: string, nightIndex: number, offeringCount: number, groupSize: number): Breakdown
	local area = Areas[areaId]
	local areaLuck = if area then area.BindLuck else 1

	local moon = Luck.GetMoonPhase(nightIndex)
	local constellationLuck = Cycle.GetConstellation(nightIndex).Luck

	local stardustLuck = 1
	for i = 1, math.min(offeringCount, #LuckConfig.Offerings) do
		stardustLuck += LuckConfig.Offerings[i].Luck
	end

	local counted = math.clamp(groupSize, 1, LuckConfig.GroupMaxPlayers)
	local groupLuck = 1 + LuckConfig.GroupLuckPerExtraPlayer * (counted - 1)

	local raw = areaLuck * moon.Luck * constellationLuck * stardustLuck * groupLuck
	return {
		Total = math.min(raw, LuckConfig.Cap),
		Capped = raw > LuckConfig.Cap,
		Area = areaLuck,
		Moon = moon.Luck,
		MoonName = moon.Name,
		Constellation = constellationLuck,
		Stardust = stardustLuck,
		Group = groupLuck,
		GroupSize = groupSize,
	}
end

return Luck
