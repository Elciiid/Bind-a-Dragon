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

	-- Flying dragons now and then land on a perch in their sanctuary and rest (client-side only,
	-- RoostAnimationController). Perches are parts named "Perch" in the plot's "Perches" folder; their "Size" attribute
	-- (1 = a ledge, 2 = a pillar top that also fits Elders) must be at least the stage's PerchSize (Config/Evolution).
	Perch = {
		Chance = 0.15, -- chance, each time a flier reaches its flight target, that it heads for a free perch instead
		Seconds = NumberRange.new(6, 15), -- how long it rests on the perch
		ApproachHeight = 6, -- studs above the perch while flying in
		GlideDistance = 14, -- starts gliding down this far (horizontally) from the perch
	},
}
