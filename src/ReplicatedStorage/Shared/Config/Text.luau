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
	},

	-- Travel button + menu (TravelController, TravelService). {place} = a destination name below.
	Travel = {
		Button = "Travel",
		Title = "Waystones",
		Hint = "Choose a place in the Valley",
		Places = {
			Sanctuary = "My Sanctuary",
			Altar = "Star Altar",
			Market = "Market",
			Spire = "Dragon Spire",
		} :: { [string]: string },
		Arrived = "Traveled to {place}.",
		Unavailable = "{place} isn't available right now.",
		OnlyInValley = "Waystones only work in the Valley.",
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
