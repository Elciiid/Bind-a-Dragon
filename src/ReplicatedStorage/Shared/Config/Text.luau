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
		Button = "Inscribe · {cost}",
		Hint = "pick a dragon to inscribe a rune",
		Owned = "{count} Wyrm Runes",
		Chances = "What can awaken",
		NoDragons = "You have no dragons yet.",
		Result = "The rune awakens: {trait}!",
		Announcement = "{player} awakened the {trait} trait!",
		WrongPlace = "Go to the Rune Shrine to inscribe runes.",
		OutOfCurrency = "You're out of Wyrm Runes. Earn more in the Dragon Spire.",
	},
	DragonstoneForge = {
		Title = "Dragonstone Forge",
		PromptAction = "Temper",
		Button = "Temper · {cost}",
		Hint = "pick a dragon to temper",
		Owned = "{count} Dragonstones",
		Chances = "Grades it can reach",
		NoDragons = "You have no dragons yet.",
		Result = "Tempered to grade {grade}!",
		Announcement = "{player} tempered a dragon to grade {grade}!",
		WrongPlace = "Go to the Dragonstone Forge to temper.",
		OutOfCurrency = "You're out of Dragonstones. Earn more in the Dragon Spire.",
	},
	SpirePanelTitle = "Dragon Spire", -- the banner on the Spire card
	SpireStuckTip = "Level up, inscribe runes and temper grades, or use a Wyrmblood Tonic to go higher.",
	-- Spire battle HUD (SpireController). {floor}, {from}, {to}, {record}, {n} are filled in.
	Spire = {
		Floor = "Floor {floor}",
		Floors = "Floors {from}-{to}",
		Record = "Record {record}",
		Best = "Best {record}",
		Boss = "BOSS",
		Vs = "VS",
		Cleared = "Floor {floor} cleared!", -- the chip that pops over the HUD (first clears also sparkle)
		Ready = "Your best dragon climbs!",
		Fast = "Zooming up...",
		Lost = "Beaten on floor {floor}",
		Top = "You reached the top!",
		Stopped = "Climb stopped",
		Climb = "Climb",
		Again = "Climb again",
		Elevator = "Elevator {floor}",
		ElevatorLeft = "Elevator {floor} ({n})",
		Stop = "Stop",
		AutoRepeatOn = "Auto-Repeat ON",
		AutoRepeatOff = "Auto-Repeat OFF",
		AutoRepeatOnShort = "Auto ON", -- phones: the buttons are narrow
		AutoRepeatOffShort = "Auto OFF",
		-- difficulty picker + leaderboard (CP4). {difficulty}, {floor}, {record}, {time} are filled in.
		Difficulty = {
			Easy = "Easy",
			Medium = "Medium",
			Hard = "Hard",
			Infinite = "Infinite",
		} :: { [string]: string },
		Locked = "Clear {difficulty} floor {floor} to unlock",
		LockedShort = "Locked",
		DifficultyRecord = "{difficulty} · Record {record}",
		DifficultyReady = "{difficulty} difficulty",
		HasteTag = "HASTE x2",
		Board = {
			Title = "Weekly Infinite",
			Mine = "Your best: floor {floor}",
			MineNone = "No floors yet this week",
			Reset = "Resets in {time}",
			Offline = "Test board (offline)",
			Empty = "Be the first!",
			Floor = "F{floor}",
		},
	},
	-- The Star Merchant NPC (MerchantController): a speech bubble with the merchant's line, and the choices as big numbered lines on
	-- the screen (no window). {placeholders} are filled with Text.Format.
	Merchant = {
		Title = "Star Merchant",
		Talk = "Talk",
		Greeting = "Welcome, binder!", -- the speech bubble over the merchant when you walk up
		MenuLine = "Welcome, binder! What can I do for you?",
		ChoiceBuy = "I want to buy Stardust!",
		ChoiceSellThis = "I want to sell this!",
		ChoiceSellInventory = "I want to sell my inventory!",
		ChoiceAutoSell = "Edit auto sell settings!",
		ChoiceBye = "Goodbye!",
		ByeLine = "Come back any night, binder!",
		-- buy Stardust
		BuyLine = "{amount} Stardust for {price} gold. Deal?",
		BuyLineBroke = "{amount} Stardust costs {price} gold. Come back with more gold!",
		BuyYes = "Yes, buy it!",
		MaybeLater = "Maybe later.",
		-- sell this (the carried dragon)
		NoCarry = "Carry a dragon from your hotbar first!",
		CarryFavorite = "{name} is one of your favorites. I can't buy it.",
		CarryProtected = "{name} lives in your sanctuary. Take it out first!",
		SellThisLine = "{name} ({rarity}, Lv {level})? I'll give you {gold} gold{extra}. Deal?",
		Deal = "Deal!",
		NoWait = "No, wait!",
		Okay = "Okay!",
		RiskyLine = "That's {desc}! Are you really sure?",
		RiskyYes = "Yes, sell it!",
		RiskyNo = "No, keep it!",
		Done = "Pleasure doing business! Anything else?",
		-- sell inventory
		InventoryLine = "Sell {count} dragon{s} for {gold} gold{extra}?",
		InventoryEmpty = "Your backpack has nothing I can buy! Favorites and your sanctuary dragons stay with you.",
		InventoryRiskyLine = "That includes {names}. Sell them too?",
		InventoryYes = "Yes, sell them all!",
		InventoryNo = "No, not now.",
		-- auto sell panel
		AutoTitle = "Auto sell",
		AutoLine = "New dragons of the rarities you switch on are sold right after you bind them. Favorites are never sold.",
		KeepMutated = "Keep mutated dragons",
		KeepNewSpecies = "Keep new species (not in the Index yet)",
		Level = "Lv {level}",
	},
	Reveal = {
		Waiting = "The stars are gathering…",
		Skip = "Skip reveal",
		ReducedMotion = "Reduced motion",
		ReducedMotionHint = "No camera movement, spinning or flashes",
		QuickHint = "Short ceremony for every dragon",
	},
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
		DuskWarning = "Night in {seconds}s: {constellation}! {where}",
		DuskFavors = "Favors {area}",
		DuskNoFavor = "Head to a Star Altar!",
		-- the slim pill under the travel buttons (one line); {extra} = PillFavors / PillEverywhere parts, or ""
		PillDay = "Daylight · night in {time}",
		PillNight = "{constellation} · {time}{extra}",
		PillFavors = " · favors {area}",
		PillEverywhere = " · {luck} luck everywhere",
		-- the day/night timer row (DayNightController, UI/TimerRow): BigDay/BigNight; SmallNight/Favors/Everywhere = its hover tooltip
		BigDay = "Night in {time}",
		BigNight = "Day in {time}",
		SmallDay = "Tonight: {constellation}{extra}", -- the caption under the timer by day
		SmallNight = "{constellation}{extra}", -- {extra} = SmallFavors / SmallEverywhere, or ""
		SmallFavors = " · favors {area}",
		SmallEverywhere = " · {luck} luck",
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
		EchoSigils = { Name = "Echo Sigils", Info = "Spend one for an extra bind after your nightly bind. Earn one from all daily quests and one from five non-fast Spire wins each day. Holds up to 6." },
	},

	-- Reward pop-ups for big moments (NotificationController -> UI/RewardPopup). {placeholders} as noted.
	Moments = {
		Button = "Awesome!",
		NewDragon = "New dragon!",
		Mutation = "Mutation!",
		NewDragonTag = "{rarity} · {element}",
		AutoTag = "Auto-bind · {rarity} · {element}",
		Evolve = "Evolved!",
		EvolveTag = "{stage}{under}", -- {under} = EvolveUnder or ""
		EvolveUnder = " · {constellation}",
		Rebirth = "Rebirth!",
		RebirthName = "Rebirth {n}",
		RebirthTag = "Income {income} · Level cap {cap}",
		Tier = "Sanctuary grows!",
		TierTag = "Tier {tier} of 5",
		Constellation = "Rare night!",
		ConstellationTag = "{luck} bind luck tonight",
		ConstellationPlain = "Bind at a Star Altar",
		Look = "New look!",
		LookTag = "Your sanctuary is transformed",
	},

	-- Dragon Hotbar (HotbarController, Inventory cards) and the carried companion. {n} = a slot number, {name} = a dragon.
	Hotbar = {
		EmptySlot = "Empty slot. New dragons you bind or take out of your sanctuary appear here by themselves. Drag a dragon from Inventory > Dragons onto a slot.",
		FavoriteTip = "Favorite: a favorite dragon can never be sold",
		TipCarry = "Press {key} or tap to carry it",
		TipPutAway = "Carrying · press {key} or tap to put it away",
		TipEmpty = "Empty slot {n}",
	},

	-- Dragons tab of the Inventory (InventoryController) and the Equip best button (RoostService). {n} = a count.
	Dragons = {
		Details = "Details",
		HomeOdds = "Home altar · x1 luck",
		TooltipBaseIncome = "Base income",
		TooltipBasePower = "Base power",
		TooltipGold = "Dragon income",
		TooltipModifiers = "Dragon income multiplier",
		TooltipRoost = "Roost {roost} · Rebirth {rebirth} · Index {index}",
		EquipBest = "Equip best",
		Equipped = "Equipped your {n} best dragons!",
		AlreadyBest = "Your best dragons are already in the roost!",
		Header = "{count} dragons · Roost {placed}/{slots}",
		Empty = "Bind a dragon at a Star Altar at night!",
		Upgrade = "Upgrade", -- the button shows the cost next to it; hold to keep upgrading
		MaxLevel = "Max level",
		InRoost = "In roost",
		Resting = "Resting",
		Tooltip = "Power {power} · {trait} · {grade}",
		NoTrait = "No trait",
		NoGrade = "No grade",
	},

	-- Shop cards (ShopController): one short line per item (the full rules from Config/Products are in the tooltip).
	Shop = {
		Short = {
			ElevatorPass = "Climbs start above your record",
			ElevatorSkip = "One climb above your record",
			SpireHaste = "Spire fights take half the time",
			AfkIncome2x = "x2 gold while you're away",
			AutoBind = "Binds for you every night",
		} :: { [string]: string },
		SkipsOwned = "You have {n}",
		Owned = "Owned",
		ComingSoon = "Coming soon",
	},

	-- Luck panel at a Star Altar (LuckController): the banner title; the total luck shows under it.
	LuckPanel = {
		Title = "Bind Luck",
		Max = "{luck} max",
	},

	-- Rebirth confirm window (RebirthController). {n} = the rebirth number.
	Rebirth = {
		Heading = "Rebirth {n}",
		Cost = "{cost} gold",
		Have = "You have {gold}",
		Income = "Income",
		LevelCap = "Level cap",
		Unlocks = "New area",
		Keeps = "Only your gold resets. You keep your dragons, Stardust, items and upgrades.",
		Confirm = "Rebirth!",
		NotEnough = "Need more gold",
		Cancel = "Not yet",
		CapHeading = "Rebirth cap reached",
		CapInfo = "More rebirths arrive in the next update. Your gold is saved up to one rebirth's cost until then.",
		CapButton = "Cap reached",
	},

	-- Rebirth Milestone Ladder (Config/RebirthMilestones, MilestoneService, the track in the Rebirth window). Ids match the config.
	Milestones = {
		TrackHeading = "Milestones",
		Next = "Next: {name} at ★{n}",
		AllDone = "Every milestone reached!",
		Reached = "Unlocked",
		Level = "★{n}",
		ChampionTitle = "Rebirth Champion",
		YourTitle = "Your title: {title}",
		PopupTitle = "Milestone!",
		PopupTag = "Rebirth {n}",
		Titles = {
			StarApprentice = "Star Apprentice",
			Binder = "Binder",
			Warden = "Warden",
			Sage = "Sage",
			Celestial = "Celestial",
		} :: { [string]: string },
		Items = {
			AutoUpgrade = { Name = "Auto-Upgrade", Info = "Spare gold levels up your roost dragons by itself." },
			FarTravel = { Name = "Far Travel", Info = "+1 Echo Sigil cap, and travel to any unlocked area's altar." },
			Ascended = { Name = "Ascended Altars", Info = "+25% bind luck for you, and altars glow gold for everyone when you bind." },
			Champion = { Name = "Rebirth Champion", Info = "A champion dragon joins you, and you earn the gold title." },
		} :: { [string]: { Name: string, Info: string } },
		AutoUpgradeLabel = "Auto-Upgrade",
		AutoUpgradeOn = "On",
		AutoUpgradeOff = "Off",
		AutoUpgradeInfo = "Spends gold above half of your next rebirth cost on the best level-ups.",
		ChampionPrefix = "Champion",
		Altars = {
			Button = "Altars",
			Heading = "Altars",
			Arrived = "Traveled to the {place} altar.",
			Unavailable = "The {place} altar isn't available right now.",
			Locked = "Rebirth {n} to unlock",
		},
	},

	-- Odds shown to players (Shared/OddsText, Config/Odds). {n} = the N of "1 in N".
	Odds = {
		OneIn = "1 in {n}",
		Unknown = "super rare",
		Only = "Only {oneIn} binds!",
		Plain = "{oneIn} binds",
		Tags = {
			Legendary = "LEGENDARY LUCK!",
			Epic = "Super rare!",
			Rare = "Rare find!",
			Nice = "Nice one!",
		} :: { [string]: string },
		Details = "Tap for details",
		DetailsTitle = "How lucky was that?",
		RowSpecies = "This dragon",
		RowMutation = "This mutation",
		RowTogether = "Both together",
		RowBase = "Base altar odds · x1 luck",
		RowProbability = "Actual probability",
		Effective = "Current odds: {oneIn}",
		RowLuck = "Your luck",
		Chance = "Chance: {oneIn}",
		Undiscovered = "Chance: {band}",
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
