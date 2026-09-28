--!strict
-- Travel: the three buttons at the top-center (Portals | Home | Market, TravelController) teleport the player to a
-- spot in the Valley, from any area (TravelService checks everything on the server). Landing spots are invisible parts
-- in Workspace.StarterMeadow.TravelPoints (built by ValleyBuild.BuildTravelPoints): one per sanctuary named after its
-- plot (its forecourt, facing the gate), Altar, Portals (the front of the portal terrace, facing the gates) and Market
-- (the valley mouth, where new players spawn). Wording in Config/Text (Travel); looks in UITheme.Travel.

return {
	Cooldown = 3, -- seconds between trips per player
	StreamTimeout = 3, -- seconds to wait for the destination to stream in before teleporting anyway
	LandHeight = 3, -- studs above the travel point the character is placed

	-- Point = the TravelPoints part (nil = the player's own sanctuary; Fallback while they have none).
	Destinations = {
		{ Id = "Portals", Point = "Portals" },
		{ Id = "Home", Point = nil, Fallback = "Altar" },
		{ Id = "Market", Point = "Market" },
	} :: { { Id: string, Point: string?, Fallback: string? } },
}
