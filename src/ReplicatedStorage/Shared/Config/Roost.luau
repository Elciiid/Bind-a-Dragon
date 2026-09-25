--!strict
-- Roost and AFK income.
-- A dragon's gold/sec = rarity GoldPerSecond (Config/Rarities) x level (Config/Leveling) x stage (Config/Evolution)
--                       x evolution branches x trait x grade (Config/Traits)
-- Roost gold/sec = sum of roost dragons x roost income upgrade x rebirth bonus (Config/Rebirth)
-- PLACEHOLDER numbers.

return {
	BaseSlots = 3, -- roost slots every player starts with (roost upgrades add more)
	MaxSlots = 8, -- hard limit on dragons in one roost

	PayoutInterval = 1, -- seconds between gold payouts while online

	OfflineCapHours = 8, -- offline (and idle) time beyond this per day earns nothing
	OfflineIncomeMultiplier = 0.5, -- fraction of the online rate earned while offline or idle (2x AFK pass doubles it)

	-- A player in game with no input for this long counts as idle: their roost earns like offline
	-- (OfflineIncomeMultiplier, sharing the OfflineCapHours daily cap). Keeps AFK farming slower than active play.
	IdleAfterSeconds = 1200,
}
