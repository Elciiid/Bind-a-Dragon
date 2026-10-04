--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Stats = require(Shared.LeaderboardStats)
local Odds = require(Shared.BindingOdds)
local DragonStats = require(Shared.DragonStats)
return function()
	local checked = 0
	local previous = -1
	for exponent = 0, 300 do
		local gold = 10 ^ exponent
		local encoded = Stats.EncodeGold(gold)
		assert(encoded > previous and encoded < 2 ^ 63)
		assert(math.abs(Stats.DecodeGold(encoded) - gold) / gold < 2e-6)
		previous = encoded; checked += 2
	end
	local data: any = {Gold = 0, Rebirths = 0, LifetimeGold = 0, RarestOneIn = 0, Dragons = {}}
	Stats.RecordGold(data, 123); assert(data.LifetimeGold == 123)
	Stats.RecordGold(data, -10); Stats.RecordGold(data, math.huge); assert(data.LifetimeGold == 123)
	Stats.RecordBind(data, "Cinderwing", "Normal", 900)
	Stats.RecordBind(data, "Solflare", "Primordial", 100)
	assert(data.RarestOneIn == 900 and data.RarestSpecies == "Cinderwing")
	Stats.RecordBind(data, "Solflare", "Primordial", 50000)
	assert(data.RarestOneIn == 50000 and data.RarestMutation == "Primordial")
	data.RarestOneIn = 0
	data.Dragons = {{SpeciesId = "Cinderwing"}, {SpeciesId = "Solflare", MutationId = "Primordial"}}
	Stats.Backfill(data)
	assert(data.RarestOneIn == Odds.GetHomeOneIn("Solflare", "Primordial"))
	data.Rebirths = 30
	local cap = DragonStats.GetGoldBankLimit(data)
	assert(cap); data.Gold = cap * 0.5; data.LifetimeGold = 0
	Stats.RecordGold(data, cap); assert(data.LifetimeGold == cap * 0.5)
	assert(Stats.EncodeGold(0 / 0) == 0 and Stats.EncodeGold(math.huge) == 0)
	print("Leaderboard checks passed", checked + 8)
end
