--!strict
-- Day/night cycle. The cycle runs on real (server) time, so every server has the same night and constellation.
-- Each full cycle = one day followed by one night = one bind per player.

return {
	DaySeconds = 480, -- 8 min of daylight
	NightSeconds = 240, -- 4 min of night (binding is open)

	-- Changing this reshuffles which constellation appears on which night.
	ConstellationSeed = 1,
}
