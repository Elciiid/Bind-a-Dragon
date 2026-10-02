--!strict
-- How odds are shown to players ("Only 1 in 8,400 binds!"). One list of excitement tags, rarest first: the first
-- entry whose MinOneIn is <= the bind's "1 in N" wins. Wording in Config/Text.Odds. Shared/OddsText reads this.

return {
	-- Excitement tags by how rare the bind was (N = 1 in N). Id -> Text.Odds.Tags[Id]; Color is the pop-up line's color.
	Tags = {
		{ MinOneIn = 5000, Id = "Legendary", Color = Color3.fromRGB(255, 120, 200) },
		{ MinOneIn = 1000, Id = "Epic", Color = Color3.fromRGB(255, 190, 60) },
		{ MinOneIn = 200, Id = "Rare", Color = Color3.fromRGB(190, 120, 255) },
		{ MinOneIn = 40, Id = "Nice", Color = Color3.fromRGB(110, 190, 255) },
	} :: { { MinOneIn: number, Id: string, Color: Color3 } },
	CommonColor = Color3.fromRGB(215, 215, 225), -- N below the smallest MinOneIn: no tag
	PopupDetailSeconds = 14, -- the pop-up stays this long when it has a breakdown to tap
	DenominatorDecimals = 2, -- keep non-integer denominators honest (1 in 1.67, not 1 in 2)
	ProbabilityDecimals = 6, -- precise percentage in the result breakdown
}
