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

	-- Perches are parts named "Perch" in the plot's "Perches" folder; their "Size" attribute (1 = a ledge, 2 = a pillar
	-- top that also fits Elders) must be at least the stage's PerchSize (Config/Evolution).
	-- Fliers steer apart when they come too close (client-side roaming, RoostAnimationController). Two fliers are
	-- "too close" when their footprints (half their width/length, wings included) plus Margin overlap and they are at
	-- about the same height; each then turns away and drifts apart.
	Separation = {
		Margin = 4, -- studs of extra space between footprints
		TurnWeight = 1.6, -- how strongly the heading turns away (1 = as much as toward its target)
		Push = 0.6, -- share of its speed a flier drifts sideways while too close
		Climb = 16, -- studs the higher of two crowded fliers may climb above its cruise height to pass over
		ClimbRate = 6, -- studs per second it climbs (and settles back afterwards)
		CenterWeight = 2.2, -- how strongly fliers below the centerpiece's height steer around its zone (plot CenterZone)
	},

	-- Fliers take turns (client-side): at most MaxAirborne fliers of one pen are in the air at once; the others rest
	-- on a free perch (PerchShare of the time) or lie down on the ground (a spot in the meadow zone, clear of other
	-- resters), then swap: each flight lasts FlightSeconds, each rest RestSeconds; a rester whose turn comes while the
	-- sky is full waits RetrySeconds and asks again.
	Turns = {
		MaxAirborne = 4,
		FlightSeconds = NumberRange.new(20, 40),
		RestSeconds = NumberRange.new(15, 30),
		RetrySeconds = NumberRange.new(2, 5),
		PerchShare = 0.5,
		RestSpacing = 5, -- studs between resting dragons (on top of their footprints)
		RestRadius = 0.7, -- ground spots are within this share of the pen radius (when the plot has no meadow zone)
	},

	-- Landing on a perch or on the ground (a flier's rest turn, see Turns).
	Perch = {
		ApproachHeight = 10, -- studs above the perch/spot while flying in
		GlideDistance = 24, -- starts gliding down this far (horizontally) from the perch/spot
	},
}
