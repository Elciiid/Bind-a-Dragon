--!strict
-- Bind luck math, shared by server and client. The server uses it for the real roll; the client uses the
-- exact same function to show the player their luck before they bind, so the two always match.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local Boosts = require(ReplicatedStorage.Shared.Config.Boosts)
local LuckConfig = require(ReplicatedStorage.Shared.Config.Luck)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Cycle = require(ReplicatedStorage.Shared.Cycle)

export type Breakdown = {
	Total: number, -- after the cap
	Capped: boolean, -- normal sources hit Cap (a luck charge can still go past it, up to PotionCap)
	Potion: number, -- armed luck charge multiplier (1 = none)
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

-- Same idea for trait/grade rolls: each entry's Weight, boosted by roll luck (Runebright Tonic) by its Tier.
function Luck.GetTierWeights(entries: { any }, luck: number): { number }
	local tierIndex: { [string]: number } = {}
	for index, rarity in Rarities do
		tierIndex[rarity.Id] = index
	end
	local weights = {}
	for index, entry in entries do
		weights[index] = entry.Weight * luck ^ (LuckConfig.TierScaling * ((tierIndex[entry.Tier] or 1) - 1))
	end
	return weights
end

-- The armed luck charge's multiplier (Config/Boosts), or 1 if none is armed or the player has none left.
function Luck.GetArmedPotionLuck(data: { ArmedLuckPotion: string, Potions: { [string]: number } }): number
	local potion = Boosts.ById[data.ArmedLuckPotion]
	if potion == nil or potion.Kind ~= "LuckCharge" or (data.Potions[potion.Id] or 0) <= 0 then
		return 1
	end
	return potion.Multiplier
end

-- potionLuck (an armed luck charge) applies after the normal Cap, up to PotionCap.
function Luck.Compute(areaId: string, nightIndex: number, offeringCount: number, groupSize: number, potionLuck: number?): Breakdown
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
	local potion = potionLuck or 1
	return {
		Total = math.min(math.min(raw, LuckConfig.Cap) * potion, LuckConfig.PotionCap),
		Capped = raw > LuckConfig.Cap,
		Potion = potion,
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
