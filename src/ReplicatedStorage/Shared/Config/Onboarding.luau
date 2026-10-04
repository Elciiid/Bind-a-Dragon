--!strict
return {
	StarterArea = "StarterMeadow", -- The special first bind never unlocks another area's roster.
	MinimumRarity = "Rare", -- Conditional tutorial pool; normal binding odds are unchanged.
	BindLuck = 1, -- Tutorial binds do not consume offerings or armed potions.
	Steps = { Start = 1, Home = 2, Upgrade = 3, Night = 4, Complete = 5, Skipped = -1 },
	HomeArrivalRange = 90, -- Studs from the assigned sanctuary pivot (sanctuaries are large).
	RebirthHintFraction = 0.25, -- Earn this fraction of the next rebirth price before the hint.
	SpireHintLevel = 10, -- First evolution makes the combat hint relevant.
	RequestInterval = 1, -- Minimum seconds between skip requests.
	PollSeconds = 1, -- Server progression / client trail refresh cadence.
	NightHintSeconds = 30, -- Give players time to notice the final hint and follow its guide stars.
	HintSeconds = 6, -- Duration for the three once-only relevance hints.
	TrailCount = 10, -- Bounded client-only trail parts; never a full map path.
	TrailLowCount = 2, -- Static supporting markers only in Low Effects / Reduced Motion.
	TrailSpacing = 5, -- Studs between local guide stars.
	TrailStartDistance = 5, -- Keep the nearest star out from under the player.
	TrailGroundOffset = 3, -- Float guides above grass; camera-facing icons also remain readable through foliage.
	TrailMaxDistance = 90, -- Keep always-on-top guidance local rather than visible across the map.
	RayHeight = 30, -- Ground raycast starts above the player.
	RayDepth = 90, -- Ground raycast length.
	StarFallHeight = 60, -- Studs above the altar, locally rendered only.
	StarFallSeconds = 0.75, -- Falling-star anticipation before the existing reveal.
	ReducedStarSeconds = 0.15, -- Static anticipation for Reduced Motion / Quick Binds.
}
