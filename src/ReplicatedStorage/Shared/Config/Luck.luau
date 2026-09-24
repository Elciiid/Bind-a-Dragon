--!strict
-- Bind luck. Every source is a multiplier; they're multiplied together and then capped at Cap.
-- Luck boosts rarer tiers more: a tier's weight (Config/Rarities) is multiplied by
--   luck ^ (TierScaling x tier steps above Common)
-- so with TierScaling 0.4 and luck x10: Rare x2.5, Epic x6.3, Legendary x15.8, Mythic x39.8.
-- Area luck is in Config/Areas (BindLuck); constellation luck is in Config/Constellations (Luck).
-- PLACEHOLDER numbers.

export type Offering = {
	Cost: number, -- Stardust
	Luck: number, -- added to the Stardust multiplier (which starts at 1)
}

export type MoonPhase = {
	Name: string,
	Luck: number,
}

return {
	Cap = 10, -- max total luck multiplier

	-- How much harder luck pushes each higher tier. 0 = luck does nothing; higher = rarer tiers gain faster.
	TierScaling = 0.4,

	-- Stardust offerings at a Star Altar, made in order, each night (reset every night, lost if you don't bind).
	-- With these numbers: 1 offering = x1.25, 2 = x1.5, 3 = x2.
	Offerings = {
		{ Cost = 5, Luck = 0.25 },
		{ Cost = 15, Luck = 0.25 },
		{ Cost = 40, Luck = 0.5 },
	} :: { Offering },

	-- One phase per night, looping. Same phase on every server.
	MoonPhases = {
		{ Name = "New Moon", Luck = 1 },
		{ Name = "Waxing Crescent", Luck = 1 },
		{ Name = "First Quarter", Luck = 1 },
		{ Name = "Waxing Gibbous", Luck = 1.1 },
		{ Name = "Full Moon", Luck = 1.5 },
		{ Name = "Waning Gibbous", Luck = 1.1 },
		{ Name = "Last Quarter", Luck = 1 },
		{ Name = "Waning Crescent", Luck = 1 },
	} :: { MoonPhase },

	-- Group binding: every other player at the same altar adds this much, counting up to GroupMaxPlayers.
	-- With these numbers: 2 players = x1.1 ... 6+ players = x1.5.
	GroupLuckPerExtraPlayer = 0.1,
	GroupMaxPlayers = 6,
	GroupRadius = 30, -- studs from the altar that count as "at the altar"

	OfferingPromptHoldSeconds = 0.5,
}
