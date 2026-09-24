--!strict
-- Roost and AFK income.
-- A dragon's gold/sec = rarity GoldPerSecond (Config/Rarities)
--                       x (1 + IncomePerLevel x (level - 1))
--                       x stage IncomeMultiplier (Config/Evolution)
-- PLACEHOLDER numbers.

return {
	BaseSlots = 3, -- roost slots every player starts with (roost upgrades will add more)
	MaxSlots = 8, -- hard limit; each roost plot in the world has this many perches

	IncomePerLevel = 0.15, -- +15% of base income per level above 1

	PayoutInterval = 1, -- seconds between gold payouts while online

	OfflineCapHours = 8, -- offline time beyond this earns nothing
	OfflineIncomeMultiplier = 1, -- fraction of the online rate earned while offline
}
