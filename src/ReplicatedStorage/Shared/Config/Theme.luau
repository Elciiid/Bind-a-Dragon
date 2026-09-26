--!strict
-- UI theme: colors, fonts, sizes and layering in one place (HudLayout reads it; controllers should too).
-- The full UI styling pass (designer/artist) replaces these values and adds components on top of HudLayout.
-- PLACEHOLDER look.

return {
	Colors = {
		Panel = Color3.fromRGB(15, 15, 30), -- panel / HUD backgrounds
		Card = Color3.fromRGB(32, 32, 55), -- rows and cards inside panels
		Text = Color3.new(1, 1, 1),
		TextMuted = Color3.fromRGB(190, 190, 205),
		TextOnButton = Color3.fromRGB(15, 15, 30),
		Gold = Color3.fromRGB(255, 210, 70),
		Stardust = Color3.fromRGB(170, 220, 255),
		Positive = Color3.fromRGB(130, 230, 140),
		Negative = Color3.fromRGB(230, 80, 80),
		Disabled = Color3.fromRGB(120, 120, 130),
		Badge = Color3.fromRGB(230, 70, 70),
	},

	-- Menu buttons (id -> look). Order = top to bottom on PC, reading order in the phone grid.
	Menu = {
		Shop = { Label = "Shop", Color = Color3.fromRGB(255, 210, 70), Order = 1 },
		Quests = { Label = "Quests", Color = Color3.fromRGB(130, 230, 140), Order = 2 },
		Index = { Label = "Index", Color = Color3.fromRGB(255, 240, 170), Order = 3 },
		Boosts = { Label = "Boosts", Color = Color3.fromRGB(200, 150, 255), Order = 4 },
		Dragons = { Label = "Dragons", Color = Color3.fromRGB(170, 220, 255), Order = 5 },
		Rebirth = { Label = "Rebirth", Color = Color3.fromRGB(255, 210, 70), Order = 6 },
	} :: { [string]: { Label: string, Color: Color3, Order: number } },

	Fonts = {
		Bold = Enum.Font.GothamBold,
		Regular = Enum.Font.Gotham,
	},

	Sizes = {
		Margin = 16, -- screen edge margin on PC
		PhoneMargin = 8, -- screen edge margin on phones
		Gap = 6, -- between stacked HUD elements
		Corner = 8, -- UICorner radius
		MenuButton = Vector2.new(160, 40), -- PC: labeled column
		PhoneMenuButton = Vector2.new(58, 48), -- phone: buttons in a 2-column grid (3 rows fit above the thumbstick)
		PhoneMenuColumns = 2,
		PhoneMenuTextSize = 11, -- same size on every phone button (labels until the artist's icons)
		Currency = Vector2.new(260, 40), -- PC: one row per currency
		PhoneCurrencyRow = 20, -- phone: small rows top-left under the Roblox top bar
		PhoneCurrencyTextSize = 13,
		PhoneCardTop = 50, -- phone: top of cards under the sky HUD (Spire card)
		PhonePillWidth = 170, -- phone: luck pill / boost timers column, top-right
		PhonePillHeight = 28,
		Badge = 22,
	},

	-- ScreenGui DisplayOrder layers: popups always draw above the HUD.
	Layers = {
		Hud = 0,
		Cards = 5, -- luck panel, Spire card, boost timers
		Popups = 10, -- Dragons, Boosts, Index, Quests, Shop, stations, rebirth confirm
		Notifications = 20,
	},

	-- A screen whose short side is at most this many pixels uses the phone layout.
	PhoneMaxShortSide = 500,
}
