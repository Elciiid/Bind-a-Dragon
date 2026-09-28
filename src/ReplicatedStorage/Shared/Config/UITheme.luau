--!strict
-- UI theme: every color, font, size, motion timing, sound and icon the UI uses. The component kit
-- (StarterPlayerScripts/Controllers/UI) and HudLayout read only from here, so the whole game restyles from this file.
--
-- Look: dragon-themed (night-sky navy/indigo panels, antique-gold trim, star sparkles, constellation title bars).
-- Controls use soft jewel tones from the portals in the world (jade confirm, rose cancel/close, stargold primary,
-- dusk-blue neutral); menu tiles share one twilight surface with a thin colored stripe (Kyle's restyle, Hakai branch).
-- Icons/sounds: an empty string ("") means "none": icons fall back to a styled tile, sounds stay silent.
-- Art slots are empty until the artist delivers panel frame art; panels use a procedural look until then.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Elements = require(ReplicatedStorage.Shared.Config.Elements)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

-- Uploaded icons (owned by the game's creator). Keys are used by the kit (UI/Icon).
local Icons: { [string]: string } = {
	Gold = "rbxassetid://136249359355144",
	Stardust = "rbxassetid://79393071959270",
	WyrmRune = "rbxassetid://112660725792759",
	Dragonstone = "rbxassetid://89473820390429",

	Menu_Dragons = "rbxassetid://115314657694318",
	Menu_Index = "rbxassetid://82066920142194",
	Menu_Quests = "rbxassetid://130648912241775",
	Menu_Shop = "rbxassetid://109078212372624",
	Menu_Boosts = "rbxassetid://79993778967468",
	Menu_Rebirth = "rbxassetid://112960311566243",

	Potion_GildedDraught = "rbxassetid://84406193624731",
	Potion_HoardElixir = "rbxassetid://109789505573815",
	Potion_StarlightTonic = "rbxassetid://105408050004258",
	Potion_MoonfireTonic = "rbxassetid://133556741216865",
	Potion_WyrmbloodTonic = "rbxassetid://125458662116176",
	Potion_ConquerorsBrew = "rbxassetid://72918194294072",
	Potion_RunebrightTonic = "rbxassetid://106070488783807",

	Rarity_Common = "rbxassetid://100900963979911",
	Rarity_Rare = "rbxassetid://83102036357881",
	Rarity_Epic = "rbxassetid://88414933800867",
	Rarity_Legendary = "rbxassetid://130927982390997",
	Rarity_Mythic = "rbxassetid://121015932549603",

	-- Roblox's own settings gear (ships with the client; white, matches the Roblox top bar buttons)
	Settings = "rbxasset://textures/ui/Settings/MenuBarIcons/GameSettingsTab@2x.png",

	-- UI renewal icons (painted, assets/new_icons.png, cut to assets/icons/)
	Menu_Inventory = "rbxassetid://131935771919529",
	Travel_Home = "rbxassetid://80330708379862",
	Travel_Portals = "rbxassetid://125960619227000",
	Travel_Market = "rbxassetid://89424033701741",
	Tab_Items = "rbxassetid://86820373487722",
	Tab_Collection = "rbxassetid://109516944039537",
}

-- Per rarity / element: colors come from their game configs (one source); icons from above.
local Rarity: { [string]: { Color: Color3, Icon: string } } = {}
for _, rarity in Rarities do
	Rarity[rarity.Id] = { Color = rarity.Color, Icon = Icons[`Rarity_{rarity.Id}`] or "" }
end
local Element: { [string]: { Color: Color3 } } = {}
for elementId, element in Elements do
	Element[elementId] = { Color = element.Color }
end

return {
	Colors = {
		-- Panels: vertical gradient night sky, gold trim, a darker inner line (the "scale" border for now).
		PanelTop = Color3.fromRGB(34, 38, 92),
		PanelBottom = Color3.fromRGB(22, 16, 56),
		PanelInnerLine = Color3.fromRGB(12, 10, 34),
		Trim = Color3.fromRGB(255, 204, 92),
		TrimDark = Color3.fromRGB(176, 118, 36),
		TitleBar = Color3.fromRGB(46, 38, 120),
		Card = Color3.fromRGB(40, 42, 104),
		CardDark = Color3.fromRGB(28, 28, 74),
		Sparkle = Color3.fromRGB(255, 244, 200),
		Constellation = Color3.fromRGB(170, 190, 255),

		Text = Color3.fromRGB(255, 247, 226),
		TextMuted = Color3.fromRGB(196, 202, 226),
		TextStroke = Color3.fromRGB(20, 14, 40),
		Title = Color3.fromRGB(255, 214, 102),

		-- Buttons: jewel tones that keep the usual meanings (green-ish confirm, red-ish cancel) in the twilight palette.
		Confirm = Color3.fromRGB(50, 144, 119), -- moonlit jade
		Cancel = Color3.fromRGB(157, 69, 98), -- muted rose
		Primary = Color3.fromRGB(171, 121, 43), -- warm stargold
		Neutral = Color3.fromRGB(71, 86, 139), -- dusk blue
		Disabled = Color3.fromRGB(91, 91, 116),
		Close = Color3.fromRGB(157, 69, 98),
		Badge = Color3.fromRGB(172, 70, 99),
		ButtonStroke = Color3.fromRGB(176, 118, 36), -- outline on buttons and tiles (antique gold)
		MenuTop = Color3.fromRGB(75, 70, 119), -- menu tiles: one twilight surface for every tile
		MenuBottom = Color3.fromRGB(31, 29, 70),

		Gold = Color3.fromRGB(255, 210, 70),
		Stardust = Color3.fromRGB(170, 220, 255),
		Positive = Color3.fromRGB(128, 217, 177),
		IconLabel = Color3.fromRGB(255, 255, 255), -- HUD icon labels: white with a dark outline
		IconLabelStroke = Color3.fromRGB(24, 16, 48),
		IconShadow = Color3.fromRGB(10, 6, 30), -- soft drop shadow under HUD icons
		Ready = Color3.fromRGB(96, 224, 150), -- "READY!" tag (e.g. Rebirth affordable)
		ProgressDim = Color3.fromRGB(150, 146, 190), -- progress ring: dots still to fill
		Negative = Color3.fromRGB(235, 145, 163),
		Info = Color3.fromRGB(160, 198, 239),
	},

	Rarity = Rarity,
	Element = Element,
	Icons = Icons,

	-- HUD icons (UI/HudIcon): big standalone icons with a label under them. Left column: Menu (Order = top to bottom).
	-- Icon = UITheme.Icons asset ("" = not painted yet: the Glyph (an emoji) or the Fallback icon shows instead).
	-- Color = glow on hover and the fallback tint.
	Menu = {
		Inventory = { Label = "Inventory", Color = Color3.fromRGB(112, 193, 224), Order = 1, Icon = Icons.Menu_Inventory },
		Quests = { Label = "Quests", Color = Color3.fromRGB(112, 211, 173), Order = 2, Icon = Icons.Menu_Quests },
		Shop = { Label = "Shop", Color = Color3.fromRGB(230, 186, 101), Order = 3, Icon = Icons.Menu_Shop },
		Rebirth = { Label = "Rebirth", Color = Color3.fromRGB(255, 205, 90), Order = 4, Icon = Icons.Menu_Rebirth },
	} :: { [string]: { Label: string, Color: Color3, Order: number, Icon: string, Fallback: string?, Glyph: string? } },

	-- Travel buttons, top-center (TravelController; destinations in Config/Travel). Home sits in the middle, bigger.
	Travel = {
		Portals = { Label = "Portals", Color = Color3.fromRGB(170, 130, 255), Order = 1, Icon = Icons.Travel_Portals, Glyph = "🌀" },
		Home = { Label = "Home", Color = Color3.fromRGB(128, 217, 177), Order = 2, Icon = Icons.Travel_Home, Glyph = "🏡" },
		Market = { Label = "Market", Color = Color3.fromRGB(255, 205, 90), Order = 3, Icon = Icons.Travel_Market, Glyph = "🎪" },
	} :: { [string]: { Label: string, Color: Color3, Order: number, Icon: string, Glyph: string? } },

	-- Inventory window tabs (InventoryWindow). Icon = UITheme.Icons key; Fallback while the tab's own art is missing.
	InventoryTabs = {
		Dragons = { Label = "Dragons", Order = 1, Icon = "Menu_Dragons" },
		Potions = { Label = "Potions", Order = 2, Icon = "Menu_Boosts" },
		Items = { Label = "Items", Order = 3, Icon = "Tab_Items", Fallback = "WyrmRune" },
		Collection = { Label = "Collection", Order = 4, Icon = "Tab_Collection", Fallback = "Menu_Index" },
	} :: { [string]: { Label: string, Order: number, Icon: string, Fallback: string? } },

	-- Shop item icons (Config/Products keys). "" = styled placeholder tile.
	ShopIcons = {
		ElevatorPass = "rbxassetid://134740752067580",
		ElevatorSkip = "rbxassetid://100198617713618",
		AfkIncome2x = "rbxassetid://121189065531863",
		AutoBind = "rbxassetid://129574556776206",
	} :: { [string]: string },

	Fonts = {
		Title = Enum.Font.LuckiestGuy, -- titles only
		Body = Enum.Font.BuilderSans,
		Bold = Enum.Font.BuilderSansBold,
		Heavy = Enum.Font.BuilderSansExtraBold, -- buttons, numbers
	},

	TextSizes = {
		Title = 30,
		PhoneTitle = 22,
		Body = 16,
		Small = 13,
		Button = 18,
		Toast = 14,
	},

	Corner = 12, -- panels
	SmallCorner = 8, -- cards, buttons
	Strokes = {
		Trim = 3, -- gold outer trim on panels
		InnerLine = 2, -- dark line inside the trim
		Button = 2.25, -- antique-gold outline on buttons and tiles (Colors.ButtonStroke)
		HoverGrow = 0.75, -- hover: the outline turns Trim gold and grows this much
		TextStroke = 0.35, -- TextStrokeTransparency on light text
	},

	Sizes = {
		Margin = 16, -- screen edge margin on PC
		PhoneMargin = 8,
		Gap = 6,
		MenuButton = Vector2.new(74, 74), -- PC: icon tiles in a 2-column grid, left middle
		PhoneMenuButton = Vector2.new(58, 48), -- phone: smaller tiles (3 rows fit above the thumbstick)
		MenuColumns = 2,
		PhoneMenuColumns = 3, -- phone: 3 columns, so 7 tiles fit in 3 short rows above the thumbstick
		MenuLabelSize = 13,
		PhoneMenuLabelSize = 11,
		Currency = Vector2.new(250, 40), -- PC: one pill per currency, bottom-left
		PhoneCurrencyRow = 18, -- phone: small pills top-left under the Roblox top bar
		PhoneCurrencyTextSize = 13,
		SkyCard = Vector2.new(440, 52), -- PC: day/night card, top-center (max size; 90% of the width on narrow screens)
		PhoneSkyCard = Vector2.new(340, 44), -- phone: same card, smaller
		TravelButton = Vector2.new(116, 38), -- PC: Travel button, top, left of the day/night card
		PhoneTravelButton = Vector2.new(96, 34), -- phone: right edge, between the boost timers and the jump button
		PhoneCardTop = 92, -- phone: top of cards under the travel row + day/night pill
		PhonePillWidth = 170, -- phone: luck pill / boost timers column, top-right
		PhonePillHeight = 28,
		Badge = 22,
		TitleBar = 48, -- window title bar height (PC)
		PhoneTitleBar = 38,
		Close = 36, -- red X button
		Toast = 44, -- toast card height
		TileStripe = Vector2.new(3, 20), -- menu tiles: the colored stripe on the left edge
		TileStripeInset = 6, -- its distance from the tile's left edge

		-- UI renewal HUD (pixels). Icons are ~1.5x the old tile icons; labels in the title font.
		HudIcon = 80, -- PC: left column icons (Inventory, Quests, Shop, Rebirth)
		PhoneHudIcon = 34, -- phone: same column, sized to end above the thumbstick
		HudLabel = 20,
		PhoneHudLabel = 10,
		HudGap = 6, -- between icons in the column
		PhoneHudGap = 2,
		TravelIcon = 58, -- PC: Portals / Market
		TravelHomeIcon = 72, -- PC: Home (middle, bigger)
		PhoneTravelIcon = 34,
		PhoneTravelHomeIcon = 42,
		TravelTop = 4, -- PC: pixels from the very top of the screen to the travel row (it sits in Roblox's top bar, between
		-- its left and right buttons); the day/night pill sits under it
		PhoneTravelTop = 2,
		SkyPill = Vector2.new(440, 30), -- PC: slim day/night pill (max size)
		PhoneSkyPill = Vector2.new(330, 24),
		PotionTimer = 50, -- PC: bottom-right active potion icons (time under each)
		PhonePotionTimer = 34,
		PhoneTimersBottom = 150, -- phone: the potion timers stay above the jump button
		TopbarGap = 6, -- the settings gear's distance from Roblox's own top-bar buttons
	},

	-- Text buttons (UI/Button): vertical gradient from the kind color, lighter at the top.
	Buttons = {
		ShadeTop = 0.16,
		ShadeBottom = -0.2,
		CornerExtra = 2, -- added to SmallCorner (tiles add 3)
		DisabledTextTransparency = 0.15,
	},

	Motion = {
		PopIn = 0.18, -- window open (scale 0.85 -> 1, Back easing)
		PopOut = 0.12,
		StartScale = 0.85,
		Hover = 1.04, -- button scale on hover
		Press = 0.96, -- button scale while pressed
		PressTime = 0.1,
		ToastIn = 0.25,
		ToastSeconds = 4,
		SparkleTwinkle = 1.6, -- seconds per sparkle fade in/out
		BadgePulse = 5, -- pulse speed of attention outlines
		SkyPhaseChange = 0.45, -- day/night card: pop + icon swing + outline flash when night falls or day breaks
		-- HUD icons (UI/HudIcon): hover = bounce up + glow, press = squish, tap = a few sparkles fly out.
		IconHover = 1.12,
		IconHoverTime = 0.22,
		IconSquish = Vector2.new(1.14, 0.84), -- width/height scale while pressed
		IconSquishTime = 0.08,
		IconSparkles = 6,
		ReadyBounce = 5, -- pixels the icon hops while "ready" (e.g. Rebirth affordable)
		ReadySpeed = 3, -- hops per ~2 seconds
		ProgressDots = 16, -- dots in the progress ring around a calm icon
	},

	-- Free Creator Store UI sounds (verified to load and play in a playtest). "" = silent.
	Sounds = {
		Click = "rbxassetid://88442833509532",
		Open = "rbxassetid://106879573498735",
		Close = "rbxassetid://12222200",
		Confirm = "rbxassetid://135165335432475",
		Error = "rbxassetid://87519554692663",
		Volume = 0.45,
	},

	-- Art slots (9-slice images from the artist). Empty = procedural look.
	Art = {
		PanelFrame = "", -- panel border with dragon scales
		PanelFrameSlice = Rect.new(24, 24, 104, 104),
		TitleOrnament = "", -- constellation ornament behind titles
		PanelTexture = "", -- subtle scale/star texture tiled on panels
	},

	-- ScreenGui DisplayOrder layers: popups always draw above the HUD.
	Layers = {
		Hud = 0,
		Cards = 5, -- luck panel, Spire card, boost timers
		Popups = 10, -- windows
		Notifications = 20,
	},

	-- A screen whose short side is at most this many pixels uses the phone layout.
	PhoneMaxShortSide = 500,
	-- Phones show at most this many boost timer pills; the rest collapse into a "+N" chip that opens Boosts.
	PhoneMaxTimers = 3,

	-- Text floating in the world (BillboardGuis). Every label is hidden past its MaxDistance and hidden behind
	-- terrain/buildings (never AlwaysOnTop). Sizes are pixels (width, height).
	WorldLabels = {
		MaxDistance = 40, -- studs: roost owner signs, dragon nameplates, portal names, upgrade stands, area signs
		BadgeMaxDistance = 80, -- studs: the ★ rebirth badge over players (a status symbol, seen from further)
		RoostSign = Vector2.new(180, 34),
		Nameplate = Vector2.new(130, 28),
		PortalName = Vector2.new(170, 30),
		PortalLock = Vector2.new(120, 30),
		UpgradeStand = Vector2.new(140, 32),
		RebirthBadge = Vector2.new(64, 20),
		AreaSign = Vector2.new(240, 40),
	},
}
