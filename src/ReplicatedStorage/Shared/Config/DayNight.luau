--!strict
-- Day/night cycle. The cycle runs on real (server) time, so every server has the same night and constellation.
-- Each full cycle = one day followed by one night = one bind per player (~8.6 binds/hour).
-- The Star Merchant price and Stardust offerings reset at dawn (each cycle); the moon has one phase per night.

return {
	DaySeconds = 240, -- 4 min of daylight
	NightSeconds = 180, -- 3 min of night (binding is open)

	DuskWarningSeconds = 30, -- players get a "Night falls in 30s" message this long before night

	-- Changing this reshuffles which constellation appears on which night.
	ConstellationSeed = 1,
}
