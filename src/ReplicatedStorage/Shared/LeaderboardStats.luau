--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.Leaderboards)
local Odds = require(Shared.BindingOdds)
local DragonStats = require(Shared.DragonStats)
local Stats = {}
local function finite(n: any): boolean return type(n) == "number" and n == n and n >= 0 and n < math.huge end
function Stats.EncodeGold(gold: number): number
	return math.round(math.log10(math.min(if finite(gold) then gold else 0, Config.MaxLifetimeGold) + 1) * Config.GoldLogScale)
end
function Stats.DecodeGold(encoded: number): number
	return 10 ^ (math.clamp(encoded, 0, math.log10(Config.MaxLifetimeGold) * Config.GoldLogScale) / Config.GoldLogScale) - 1
end
-- Call before crediting currency. Bank-cap-discarded gold is not counted as earned/credited gold.
function Stats.RecordGold(data: any, amount: number)
	if not finite(amount) then return end
	local limit = DragonStats.GetGoldBankLimit(data)
	local credited = if limit then math.max(0, math.min(amount, limit - data.Gold)) else amount
	data.LifetimeGold = math.min(Config.MaxLifetimeGold, (if finite(data.LifetimeGold) then data.LifetimeGold else 0) + credited)
end
function Stats.RecordBind(data: any, speciesId: string, mutationId: string?, baseOneIn: number?)
	local oneIn = baseOneIn or Odds.GetHomeOneIn(speciesId, mutationId)
	if not finite(oneIn) or (oneIn :: number) <= (data.RarestOneIn or 0) then return end
	data.RarestOneIn, data.RarestSpecies, data.RarestMutation = oneIn, speciesId, mutationId or "Normal"
end
function Stats.Backfill(data: any)
	if (data.RarestOneIn or 0) > 0 then return end
	for _, dragon in data.Dragons do
		if not dragon.Champion then Stats.RecordBind(data, dragon.SpeciesId, dragon.MutationId) end
	end
end
function Stats.Encode(board: string, data: any): number
	local value = if board == "Gold" then Stats.EncodeGold(data.LifetimeGold or 0)
		elseif board == "Rebirths" then data.Rebirths else data.RarestOneIn or 0
	return math.clamp(math.round(if finite(value) then value else 0), 0, Config.MaxOrderedValue)
end
return Stats
