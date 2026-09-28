--!strict
-- Player-facing wording the designer can edit. {name} placeholders are filled in by Text.Format:
-- {player} = display name, {dragon} = dragon name, {trait} = trait name, {grade} = grade letter,
-- {cost} = amount, {rebirths} = number of rebirths.
-- Theme: runes are inscribed at the Rune Shrine, dragons are tempered at the Dragonstone Forge. Avoid dice/gacha words
-- (roll, spin, gacha); "trait" and "grade" stay as the nouns.

local Text = {
	RuneShrine = {
		Title = "Rune Shrine",
		PromptAction = "Inscribe a Rune",
		Button = "Inscribe ({cost} Wyrm Rune)",
		Hint = "pick a dragon to inscribe a rune",
		Result = "The rune awakens: {trait}!",
		Announcement = "{player} awakened the {trait} trait!",
		WrongPlace = "Go to the Rune Shrine to inscribe runes.",
		OutOfCurrency = "You're out of Wyrm Runes. Earn more in the Dragon Spire.",
	},
	DragonstoneForge = {
		Title = "Dragonstone Forge",
		PromptAction = "Temper",
		Button = "Temper ({cost} Dragonstone)",
		Hint = "pick a dragon to temper",
		Result = "Tempered to grade {grade}!",
		Announcement = "{player} tempered a dragon to grade {grade}!",
		WrongPlace = "Go to the Dragonstone Forge to temper.",
		OutOfCurrency = "You're out of Dragonstones. Earn more in the Dragon Spire.",
	},
	SpireStuckTip = "Level up, inscribe runes and temper grades, or use a Wyrmblood Tonic to go higher.",
	PortalLocked = "Rebirth {rebirths}", -- under the lock on a portal the player can't use yet

	-- Day/night card at the top of the screen (DayNightController). {time} = m:ss left in the phase,
	-- {constellation} = tonight's constellation, {where} = the luck line below, {luck} = a multiplier like "x1.5".
	SkyHud = {
		DayIcon = "☀", -- glyphs that Builder Sans draws (☾ and ✦ show as boxes)
		NightIcon = "🌙",
		DayTitle = "Daylight · Night falls in {time}",
		DayDetail = "The stars are resting · prepare for the next constellation",
		NightTitle = "Nightfall · {constellation}",
		NightDetail = "{where} · {time} left",
		LuckEverywhere = "{luck} luck at every altar",
		Favors = "favors {area} ({luck})",
		NoBonus = "Bind at a Star Altar",
		-- Toast DuskWarningSeconds before night ({seconds}); {where} = DuskFavors or DuskNoFavor.
		DuskWarning = "Night falls in {seconds}s: {constellation} rises. {where}",
		DuskFavors = "It favors {area}!",
		DuskNoFavor = "Head to a Star Altar!",
		-- the slim pill under the travel buttons (one line); {extra} = PillFavors / PillEverywhere parts, or ""
		PillDay = "Daylight · night in {time}",
		PillNight = "{constellation} · {time}{extra}",
		PillFavors = " · favors {area}",
		PillEverywhere = " · {luck} luck everywhere",
	},

	-- Boards over the roost upgrade stands (UpgradeStandController). {slots}/{max} = roost slots, {bonus} = income %.
	UpgradeStands = {
		SlotsTitle = "Roost slots",
		SlotsLine = "{slots} / {max} slots",
		IncomeTitle = "Roost income",
		IncomeLine = "+{bonus}% gold",
		MaxedLine = "Fully upgraded!",
		-- toast for the owner when their sanctuary reaches a new tier; {tier} = a name from WorldUI.SanctuaryTiers.Names
		TierUp = "Your sanctuary grows: {tier}!",
	},

	-- Travel buttons, top-center (TravelController, TravelService). {place} = a destination name below.
	Travel = {
		Places = {
			Home = "your Sanctuary",
			Portals = "the Portals",
			Market = "the Market",
		} :: { [string]: string },
		HomeFallback = "the Star Altar", -- Home before the player has a sanctuary
		Arrived = "Traveled to {place}.",
		Unavailable = "{place} isn't available right now.",
	},

	-- Items tab of the Inventory (ItemsController).
	Items = {
		WyrmRunes = { Name = "Wyrm Runes", Info = "Inscribe a rune on a dragon at the Rune Shrine to awaken a trait. Earned in the Dragon Spire, quests and the Index." },
		Dragonstones = { Name = "Dragonstones", Info = "Temper a dragon at the Dragonstone Forge to raise its grade. Earned in the Dragon Spire, quests and the Index." },
		Stardust = { Name = "Stardust", Info = "Offer it at a Star Altar for more luck on your next bind. Buy it from the Star Merchant or find it in the Spire." },
	},
}

-- Replaces {key} with values[key]; unknown keys are left as they are.
function Text.Format(template: string, values: { [string]: any }): string
	return (template:gsub("{(%w+)}", function(key)
		local value = values[key]
		return if value ~= nil then tostring(value) else nil
	end))
end

return Text
