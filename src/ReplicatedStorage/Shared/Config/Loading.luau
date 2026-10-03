--!strict
-- Join loading step (Simplify 2026-10-04; LoadingController, wording Text.Loading). A kid-friendly screen covers the world
-- right after joining while the area around the player streams in and the key art downloads, then fades out. It never waits
-- longer than MaxSeconds. It sits under pop-ups, toasts and the binding ceremony (UITheme.Layers.Popups - 1), never takes
-- input, and closes at once when a ProximityPrompt (e.g. the altar's Bind) shows.

return {
	MaxSeconds = 8, -- continue anyway after this long
	MinSeconds = 1, -- show at least this long (no flash)
	FadeSeconds = 0.6, -- Low effects: half
	-- streamed in around these points (Player:RequestStreamAroundAsync) before the screen fades:
	Plaza = Vector3.new(0, 0, 0), -- the altar plaza
	RingRadius = 250, -- the first terrain ring: points this far from the player, in RingPoints directions
	RingPoints = 4,
	OwnSanctuaryWait = 3, -- seconds to wait for the server to assign the player's sanctuary (then it streams it too)
	-- art preloaded (ContentProvider:PreloadAsync) from these places (paths from game), when they exist:
	Preload = {
		{ "Workspace", "StarterMeadow", "Plaza" },
		{ "Workspace", "StarterMeadow", "Buildings" },
		{ "Workspace", "StarterMeadow", "Portals" },
		{ "Workspace", "StarterMeadow", "Spire" },
		{ "ReplicatedStorage", "Assets", "Horizon" },
	} :: { { string } },
	WaitForSanctuaryLooks = true, -- also wait until SanctuaryLookController has cloned in the looks it wants
	-- the look of the screen
	Top = Color3.fromRGB(120, 196, 255), -- sky-blue gradient
	Bottom = Color3.fromRGB(196, 232, 255),
	BarColor = Color3.fromRGB(255, 205, 90),
	TitleSize = 54,
	PhoneTitleSize = 34,
}
