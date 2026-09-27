--!strict
-- Travel ("Waystones"): the Travel button teleports a player to a named spot in the Valley (TravelService checks
-- everything on the server). Landing spots are invisible parts in Workspace.StarterMeadow.TravelPoints (built by
-- ValleyBuild.BuildTravelPoints): one per sanctuary named after its plot (Sanctuary = the player's own), plus
-- Altar, Market and Spire. Wording in Config/Text (Travel); button sizes in UITheme.Sizes.

return {
	Area = "StarterMeadow", -- travel works only inside this area; the button hides elsewhere
	Cooldown = 3, -- seconds between trips per player
	StreamTimeout = 3, -- seconds to wait for the destination to stream in before teleporting anyway
	LandHeight = 3, -- studs above the travel point the character is placed

	-- Menu order. Point = the TravelPoints part (nil = the player's own sanctuary). Kind = button color (UI/Button).
	Destinations = {
		{ Id = "Sanctuary", Point = nil, Kind = "Confirm" },
		{ Id = "Altar", Point = "Altar", Kind = "Primary" },
		{ Id = "Market", Point = "Market", Kind = "Neutral" },
		{ Id = "Spire", Point = "Spire", Kind = "Neutral" },
	} :: { { Id: string, Point: string?, Kind: string } },
}
