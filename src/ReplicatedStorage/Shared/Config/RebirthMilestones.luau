--!strict
-- Rebirth Milestone Ladder (docs/Rebirth_Milestones_Proposal.md). Reaching a rebirth count unlocks perks; each shows a
-- reward pop-up and a node on the milestone track in the Rebirth window. Nothing here is paid.
-- Wording (names, texts, titles) is in Config/Text.Milestones, keyed by the Ids below. Ids are saved in player data
-- (data.MilestonesSeen), so never rename or remove an Id once live. A weekly update adds one Milestone entry.
--
-- Perks (Shared/RebirthMilestones reads them):
--   AutoUpgrade = true        the Auto-Upgrade toggle (server levels roost dragons with spare gold)
--   EchoSigilCap = n          +n to the Echo Sigil cap (Config/Binding EchoSigilCap)
--   AltarTravel = true        the Travel row gets "Altars": go to any unlocked area's altar
--   AscendedLuck = x          bind luck multiplier for that player, a normal luck source (still under Luck caps)
--   Champion = true           a champion dragon (below) and the gold title

export type Milestone = {
	Id: string,
	Rebirths: number,
	Perks: { [string]: any },
}

return {
	-- A rank for every rebirth, changing every 5. Past the last rank, a numeral every TitleStep rebirths (Celestial II...).
	Titles = {
		{ From = 1, Id = "StarApprentice" },
		{ From = 6, Id = "Binder" },
		{ From = 11, Id = "Warden" },
		{ From = 16, Id = "Sage" },
		{ From = 21, Id = "Celestial" },
	} :: { { From: number, Id: string } },
	TitleStep = 5,

	Milestones = {
		{ Id = "AutoUpgrade", Rebirths = 12, Perks = { AutoUpgrade = true } },
		{ Id = "FarTravel", Rebirths = 18, Perks = { EchoSigilCap = 1, AltarTravel = true } },
		{ Id = "Ascended", Rebirths = 20, Perks = { AscendedLuck = 1.25 } },
		{ Id = "Champion", Rebirths = 30, Perks = { Champion = true } },
	} :: { Milestone },

	-- Auto-Upgrade: every Interval seconds the server buys roost-dragon levels (best income per gold first) with gold
	-- above Reserve x the next rebirth cost, at most MaxLevelsPerTick levels per tick. A request to switch it needs
	-- ToggleCooldown seconds between presses.
	AutoUpgrade = {
		Reserve = 0.5,
		Interval = 1,
		MaxLevelsPerTick = 10,
		ToggleCooldown = 0.5,
	},

	-- Ascended altars: while an Ascended player is within GlowRange studs of a Star Altar, everyone sees it glow gold.
	Ascended = {
		GlowRange = 45,
		GlowColor = Color3.fromRGB(255, 205, 90),
	},

	-- The champion dragon (placeholder: an existing species' art, gold-tinted with golden sparkles, until real art):
	-- granted once at the Champion perk and placed in the roost when a slot is free.
	Champion = {
		SpeciesId = "Solflare",
		IncomeMultiplier = 1.25,
		PowerMultiplier = 1.25,
		Color = Color3.fromRGB(255, 205, 90),
		TintStrength = 0.5, -- how far the model's colors blend toward Color
	},

	-- Altar Travel: where you land in front of an area's altar (offset from the altar's PrimaryPart, studs).
	AltarTravel = {
		Offset = Vector3.new(0, 4, 14),
	},
}
