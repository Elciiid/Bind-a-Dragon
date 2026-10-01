--!strict
-- One source of truth for direct SpeciesId x MutationId binding probabilities.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local LuckConfig = require(ReplicatedStorage.Shared.Config.Luck)
local Mutations = require(ReplicatedStorage.Shared.Config.Mutations)

export type Outcome = {
	SpeciesId: string,
	MutationId: string,
	BaseWeight: number,
	EffectiveWeight: number,
	BaseProbability: number,
	EffectiveProbability: number,
	BaseOneIn: number,
	EffectiveOneIn: number,
}

local BindingOdds = {}

local function eligibleSpecies(areaId: string, element: string?): { string }
	local result = {}
	local area = Areas[areaId]
	for _, speciesId in if area then area.Species else {} do
		local species = Dragons[speciesId]
		if species and (element == nil or species.Element == element) then
			table.insert(result, speciesId)
		end
	end
	table.sort(result)
	return result
end

function BindingOdds.GetPool(areaId: string, element: string?, luck: number): { Outcome }
	local speciesIds = eligibleSpecies(areaId, element)
	local baseTotal, effectiveTotal = 0, 0
	local pool: { Outcome } = {}
	for _, speciesId in speciesIds do
		local species = Dragons[speciesId]
		for _, mutation in Mutations.Mutations do
			local baseWeight = species.BindWeight * mutation.Share
			local exponent = math.min(1, (LuckConfig.RarityExponent[species.Rarity] or 0) + mutation.LuckExponent)
			local effectiveWeight = baseWeight * math.max(1, luck) ^ exponent
			baseTotal += baseWeight
			effectiveTotal += effectiveWeight
			table.insert(pool, {
				SpeciesId = speciesId,
				MutationId = mutation.Id,
				BaseWeight = baseWeight,
				EffectiveWeight = effectiveWeight,
				BaseProbability = 0,
				EffectiveProbability = 0,
				BaseOneIn = math.huge,
				EffectiveOneIn = math.huge,
			})
		end
	end
	for _, outcome in pool do
		outcome.BaseProbability = if baseTotal > 0 then outcome.BaseWeight / baseTotal else 0
		outcome.EffectiveProbability = if effectiveTotal > 0 then outcome.EffectiveWeight / effectiveTotal else 0
		outcome.BaseOneIn = if outcome.BaseProbability > 0 then 1 / outcome.BaseProbability else math.huge
		outcome.EffectiveOneIn = if outcome.EffectiveProbability > 0 then 1 / outcome.EffectiveProbability else math.huge
	end
	return pool
end

function BindingOdds.Roll(rng: Random, areaId: string, element: string?, luck: number): Outcome?
	local pool = BindingOdds.GetPool(areaId, element, luck)
	local roll = rng:NextNumber()
	for _, outcome in pool do
		roll -= outcome.EffectiveProbability
		if roll < 0 then
			return outcome
		end
	end
	return pool[#pool]
end

function BindingOdds.GetOutcome(areaId: string, element: string?, luck: number, speciesId: string, mutationId: string?): Outcome?
	local wanted = mutationId or Mutations.NormalId
	for _, outcome in BindingOdds.GetPool(areaId, element, luck) do
		if outcome.SpeciesId == speciesId and outcome.MutationId == wanted then
			return outcome
		end
	end
	return nil
end

function BindingOdds.FormatOneIn(oneIn: number): string
	if oneIn == math.huge then return "Unavailable" end
	if oneIn < 10 then return string.format("1 in %.2f", oneIn) end
	if oneIn < 100 then return string.format("1 in %.1f", oneIn) end
	return `1 in {math.floor(oneIn + 0.5)}`
end

function BindingOdds.ValidatePool(pool: { Outcome }): (boolean, string?)
	local sum = 0
	for _, outcome in pool do
		if outcome.EffectiveProbability <= 0 or outcome.EffectiveProbability ~= outcome.EffectiveProbability then
			return false, `Invalid probability for {outcome.SpeciesId}/{outcome.MutationId}`
		end
		sum += outcome.EffectiveProbability
	end
	if math.abs(sum - 1) > 1e-12 then return false, `Pool sums to {sum}` end
	return true, nil
end

-- The pieces of one outcome's odds (for the "tap for details" breakdown): the species on its own, the mutation share
-- inside that species, and both together, all as "1 in N" at this luck; plus the combined odds at luck 1 (Base).
export type Breakdown = { SpeciesOneIn: number, MutationOneIn: number, OneIn: number, BaseOneIn: number }

function BindingOdds.Breakdown(areaId: string, element: string?, luck: number, speciesId: string, mutationId: string?): Breakdown?
	local wanted = mutationId or Mutations.NormalId
	local speciesProbability, outcomeProbability, baseOneIn = 0, 0, math.huge
	for _, outcome in BindingOdds.GetPool(areaId, element, luck) do
		if outcome.SpeciesId == speciesId then
			speciesProbability += outcome.EffectiveProbability
			if outcome.MutationId == wanted then
				outcomeProbability = outcome.EffectiveProbability
				baseOneIn = outcome.BaseOneIn
			end
		end
	end
	if outcomeProbability <= 0 then
		return nil
	end
	return {
		SpeciesOneIn = 1 / speciesProbability,
		MutationOneIn = speciesProbability / outcomeProbability,
		OneIn = 1 / outcomeProbability,
		BaseOneIn = baseOneIn,
	}
end

-- "1 in N" of an outcome at its home altar (the species' element area) with no luck, for the Index and dragon tooltips.
function BindingOdds.GetHomeOneIn(speciesId: string, mutationId: string?): number?
	local species = Dragons[speciesId]
	if species == nil then
		return nil
	end
	for areaId, area in Areas do
		if area.Element == species.Element and table.find(area.Species, speciesId) then
			local outcome = BindingOdds.GetOutcome(areaId, species.Element, 1, speciesId, mutationId)
			return if outcome then outcome.BaseOneIn else nil
		end
	end
	return nil
end

return BindingOdds
