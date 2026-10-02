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
	EchoSigil = "", -- assets/icons/EchoSigil.png; set creator-owned image ID after upload

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

	-- UI renewal part 2 (tools/ui_art/gen.py, assets/ui/): day/night timer sun / moon (stand-ins until painted versions)
	Sky_Sun = "rbxassetid://138017457452642",
	Sky_Moon = "rbxassetid://119449803886759",
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
		Confirm = Color3.fromRGB(38, 196, 128), -- jade: go / buy
		Cancel = Color3.fromRGB(236, 78, 118), -- rose: stop / close
		Primary = Color3.fromRGB(248, 178, 36), -- gold: upgrade
		Neutral = Color3.fromRGB(66, 134, 238), -- sky blue: neutral
		Disabled = Color3.fromRGB(116, 116, 132), -- clearly grey
		Close = Color3.fromRGB(236, 78, 118),
		Badge = Color3.fromRGB(236, 60, 90), -- red count badges (bright, readable on every icon)
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

		-- UI renewal part 2 panels: deep indigo -> violet with a faint sparkle pattern and a soft outer glow.
		PanelV2Top = Color3.fromRGB(38, 30, 104),
		PanelV2Bottom = Color3.fromRGB(88, 42, 146),
		PanelGlow = Color3.fromRGB(160, 120, 255), -- soft glow around windows
		PatternTint = Color3.fromRGB(220, 210, 255), -- the sparkle pattern on panels
		ButtonText = Color3.fromRGB(255, 255, 255),
		DisabledText = Color3.fromRGB(205, 205, 214),
		DuskGlow = Color3.fromRGB(255, 150, 90), -- (unused since the sky pill went away; kept for the dusk warning toast)
		-- UI renewal window frame (Style.PanelLook / UI/Window): navy glass, gold ornamental border, jewel title banner.
		GlassTop = Color3.fromRGB(30, 38, 96),
		GlassBottom = Color3.fromRGB(12, 14, 46),
		GlassSheen = Color3.fromRGB(190, 210, 255), -- soft light across the top of the glass
		TrimLight = Color3.fromRGB(255, 240, 170), -- top of the gold border (it shades to Trim, then TrimDark)
		CornerJewel = Color3.fromRGB(110, 220, 255), -- the gem set in each gold corner ornament
		BannerTop = Color3.fromRGB(138, 82, 214), -- window title banner (royal amethyst)
		BannerBottom = Color3.fromRGB(78, 38, 150),
		BannerTail = Color3.fromRGB(58, 28, 112), -- the ribbon ends behind the banner
		BannerStar = Color3.fromRGB(255, 222, 110), -- the small star on top of the banner
		CloseTop = Color3.fromRGB(240, 96, 116), -- the big round close button (ruby)
		CloseBottom = Color3.fromRGB(160, 34, 70),
		CardTop = Color3.fromRGB(48, 56, 132), -- cards inside windows (a lighter glass)
		CardBottom = Color3.fromRGB(28, 30, 84),
		TabTop = Color3.fromRGB(44, 50, 118), -- Inventory tabs (not selected)
		TabBottom = Color3.fromRGB(22, 24, 70),
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
		Altars = { Label = "Altars", Color = Color3.fromRGB(255, 160, 90), Order = 4, Icon = Icons.Travel_Portals, Glyph = "✨" }, -- R18 milestone (Config/RebirthMilestones AltarTravel)
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
		Timer = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic), -- HUD timers (bold italic, white, dark outline)
	},

	TextSizes = {
		Title = 30,
		PhoneTitle = 22,
		Body = 16,
		Small = 13,
		Button = 18,
		Toast = 15,
		Banner = 30, -- window title in the banner (PC)
		PhoneBanner = 21,
	},

	Corner = 16, -- panels
	GlassTransparency = 0.05, -- windows/panels: how see-through the navy glass is (0 = solid)
	SmallCorner = 8, -- cards, buttons
	Strokes = {
		Trim = 4, -- gold outer trim on panels (= Sizes.Border)
		InnerLine = 2, -- dark line inside the trim
		Button = 2.25, -- antique-gold outline on buttons and tiles (Colors.ButtonStroke)
		HoverGrow = 0.75, -- hover: the outline turns Trim gold and grows this much
		TextStroke = 0.35, -- TextStrokeTransparency on light text
	},

	Sizes = {
		Margin = 16, -- screen edge margin on PC
		PhoneMargin = 8,
		RightMargin = 64, -- right-side HUD (timer stack, luck panel) keeps well clear of the screen's right edge
		PhoneRightMargin = 36,
		PhoneLuckPanelScale = 0.5, -- phones: the luck panel is the PC panel drawn this much smaller
		LeftMargin = 64, -- left-side HUD (menu icons, currency) the same, mirrored
		PhoneLeftMargin = 36,
		MenuRaise = 50, -- the 4 left icons sit this many pixels above the vertical center (PC)
		PhoneMenuRaise = 30,
		Gap = 6,
		MenuButton = Vector2.new(74, 74), -- PC: icon tiles in a 2-column grid, left middle
		PhoneMenuButton = Vector2.new(58, 48), -- phone: smaller tiles (3 rows fit above the thumbstick)
		MenuColumns = 2,
		MenuLabelSize = 13,
		PhoneMenuLabelSize = 11,
		Currency = Vector2.new(250, 40), -- PC: one pill per currency, bottom-left
		PhoneCurrency = Vector2.new(130, 22), -- phone: the same stacked pills as PC (bottom-left), scaled down
		PhoneCurrencyRow = 22,
		PhoneCurrencyTextSize = 13,
		SkyCard = Vector2.new(440, 52), -- PC: day/night card, top-center (max size; 90% of the width on narrow screens)
		PhoneSkyCard = Vector2.new(340, 44), -- phone: same card, smaller
		TravelButton = Vector2.new(116, 38), -- PC: Travel button, top, left of the day/night card
		PhoneTravelButton = Vector2.new(96, 34), -- phone: right edge, between the boost timers and the jump button
		PhoneCardTop = 118, -- phone: top of cards under the travel row + day/night pill (their banner hangs above it)
		PhonePillWidth = 170, -- phone: luck pill / boost timers column, top-right
		PhonePillHeight = 28,
		Badge = 22,
		TitleBar = 48, -- window title bar height (PC)
		PhoneTitleBar = 38,
		Close = 36, -- red X button
		Toast = 44, -- toast card height
		TileStripe = Vector2.new(3, 20), -- menu tiles: the colored stripe on the left edge
		TileStripeInset = 6, -- its distance from the tile's left edge

		-- UI renewal window frame (pixels)
		Border = 4, -- gold border around windows and panels
		InnerBorderInset = 8, -- the thin gold line inside it
		CornerOrnament = 20, -- gold diamond (with a jewel) on each corner
		Banner = 50, -- title banner height (PC); it sits on the window's top edge, half above it
		PhoneBanner = 36,
		BannerPadding = 26, -- space left/right of the title inside the banner
		BannerStar = 36, -- the star on top of the banner
		PhoneBannerStar = 24,
		CloseButton = 52, -- big round close button on the top-right corner (PC)
		PhoneCloseButton = 40,
		WindowPadding = 16, -- content inset from the border
		ButtonEdge = 5, -- the 3D bottom edge of buttons (pixels; the face drops onto it when pressed)
		PopupTopGap = 10, -- windows start this far below the travel row (they never cover the top bar)
		ToastPill = 48, -- toast pill height (PC)
		PhoneToastPill = 36,
		ToastIcon = 58, -- the toast's icon, bigger than the pill so it pops out
		PhoneToastIcon = 42,
		RewardCard = Vector2.new(420, 340), -- centered reward pop-up (PC; phones scale it down)
		RewardIcon = 150,
		TimerIcon = 36, -- bottom-right timer stack (day/night, potions): icon size, PC
		PhoneTimerIcon = 24,
		TimerText = 24, -- its bold italic text size
		PhoneTimerText = 16,
		TimerGap = 2, -- between rows
		TimerCaptionText = 17, -- the small line under the day/night timer (tonight's constellation + favored area)
		PhoneTimerCaptionText = 11,
		TravelSlot = 96, -- PC: every travel button gets a slot this wide, so the labels never clip and spacing is even
		PhoneTravelSlot = 62,
		PhoneCardScale = 0.55, -- phones: Inventory dragon and potion cards are drawn this much smaller (a full row fits)
		SpireHud = Vector2.new(500, 200), -- includes separate Auto-Repeat and Stop controls
		MerchantWindow = Vector2.new(460, 300), -- live-price merchant interaction panel
		MerchantText = 18,
		MerchantPriceText = 22,
		PhoneSpireScale = 0.6,
		PhoneSpireHudHeight = 300, -- accommodates physical 44px touch controls
		SpirePortrait = 104, -- dragon portraits in the HUD
		SpireFloorBadge = Vector2.new(170, 46), -- the big "Floor 40" badge on the HUD's top edge
		SpireMini = Vector2.new(150, 46), -- the HUD minimized (Hide): just the floor badge
		SpireDropIcon = 40, -- drops flying to the Inventory button

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
		PotionTimer = 50, -- PC: active potion icons (time under each), a horizontal row under the day/night timer
		PhonePotionTimer = 34,
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
		SpireChip = 1.3, -- seconds a "Floor 39 cleared!" chip stays before it fades
		SpireFly = 0.75, -- seconds a drop icon takes to fly to the Inventory button
		SpireHit = 0.6, -- seconds between the portraits' "hits" during a fight
		SpireMaxFlyers = 8, -- at most this many drop icons in the air (fast floors can drop a lot)
		PopIn = 0.18, -- window open (scale 0.85 -> 1, Back easing)
		PopOut = 0.12,
		StartScale = 0.85,
		Hover = 1.06, -- button scale on hover
		Press = 0.93, -- button scale while pressed
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
		OpenSparkles = 10, -- windows: sparkles fly out of the title banner on open
		WindowFade = 0.16, -- windows fade in while they pop (scale + fade)
		ButtonBounce = 1.07, -- chunky buttons: scale on hover (Back easing)
		ButtonSquish = Vector2.new(1.05, 0.9), -- width/height while pressed
		ToastBounce = 0.35, -- toasts pop in with a bounce
		RewardSpin = 18, -- seconds per turn of the rays behind a reward pop-up
		RewardBurst = 26, -- sparkles in a reward burst (Low effects: a third)
		DuskPulse = 1.2, -- seconds per pulse of the sky pill's glow at dusk
		-- Inventory "Upgrade" button: tap = +1 level; held longer than UpgradeHoldDelay it keeps buying every
		-- UpgradeRepeat seconds: 1 level a time, 5 after UpgradeRamp seconds, 25 after UpgradeRampFast.
		UpgradeHoldDelay = 0.4,
		UpgradeRepeat = 0.15, -- keep above DragonService's 0.1 s request limit
		UpgradeRamp = 1.5,
		UpgradeRampFast = 3.5,
		BannerStarSpin = 6, -- seconds per slow wobble of the banner star
		CloseHoverTurn = 90, -- degrees the close X turns on hover
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
		-- UI renewal part 2 (tools/ui_art/gen.py, assets/ui/)
		PanelPattern = "rbxassetid://127657628261123", -- tileable faint sparkles (panels, cards)
		PatternTile = 180, -- pixels per tile
		PatternTransparency = 0.7,
		Glow = "rbxassetid://137636172705115", -- soft glow, 9-sliced around panels / cards
		GlowSlice = Rect.new(60, 60, 68, 68),
		GlowBody = 44, -- pixels from the glow image's edge to its solid body
		GlowSpread = 34, -- pixels the panel glow reaches out
		Rays = "rbxassetid://78172100001188", -- light rays behind reward pop-ups
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

	-- Toasts (NotificationController): one queue, at most MaxVisible on screen; the same message again adds "x2".
	Toasts = {
		MaxVisible = 2,
		Gap = 6, -- pixels under the travel row
	},

	-- A screen whose short side is at most this many pixels uses the phone layout.
	PhoneMaxShortSide = 500,
	-- Phones show at most this many boost timer pills; the rest collapse into a "+N" chip that opens Boosts.
	PhoneMaxTimers = 3,

	-- In-world panels (Style.WorldPanel: prompts, boards, owner banners, portal labels): the window look made small.
	WorldPanel = {
		Transparency = 0.08, -- navy glass
		Corner = 12,
		Border = 2.5, -- gold border
		EndOrnament = 10, -- gold diamond on each end (pixels)
		Star = 18, -- the little star on top of boards
		KeyBadgeTop = Color3.fromRGB(138, 82, 214), -- prompt key badge (amethyst jewel)
		KeyBadgeBottom = Color3.fromRGB(78, 38, 150),
		PopTime = 0.22, -- prompts pop in (Back easing)
		TriggerSparkles = 8, -- sparkles out of the key badge when a prompt is used
	},

	-- Text floating in the world (BillboardGuis). Every label is hidden past its MaxDistance and hidden behind
	-- terrain/buildings (never AlwaysOnTop). Sizes are pixels (width, height).
	WorldLabels = {
		MaxDistance = 40, -- studs: roost owner signs, dragon nameplates, portal names, upgrade stands, area signs
		NameplateMaxDistance = 70, -- studs: dragon nameplates (big dragons fly high in the 150-stud sanctuaries)
		BadgeMaxDistance = 80, -- studs: the ★ rebirth badge over players (a status symbol, seen from further)
		RoostSign = Vector2.new(180, 34),
		Nameplate = Vector2.new(130, 28),
		PortalName = Vector2.new(190, 36),
		PortalLock = Vector2.new(140, 36),
		UpgradeStand = Vector2.new(140, 32),
		RebirthBadge = Vector2.new(64, 20),
		AreaSign = Vector2.new(240, 40),
	},
}
