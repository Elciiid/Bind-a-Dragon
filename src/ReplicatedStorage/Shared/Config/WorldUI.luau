--!strict
-- In-world UI and feedback (client only): themed ProximityPrompts (PromptController), the portal warp
-- (PortalController), roost banners / gold pops / level-up bursts (RoostFXController) and the boards and glows at the
-- stations (StationFXController). Colors come from Config/UITheme; label distances from UITheme.WorldLabels.

return {
	-- Themed prompts: every ProximityPrompt in the world uses this look (Style = Custom).
	Prompts = {
		Size = Vector2.new(230, 58), -- pixels
		PhoneScale = 0.9,
		-- Icon per prompt Name (UITheme.Icons keys); prompts not listed show no icon.
		Icons = {
			BindPrompt = "Rarity_Mythic",
			OfferPrompt = "Stardust",
			BuyStardustPrompt = "Stardust",
			ClimbPrompt = "Menu_Rebirth",
			LevelUpPrompt = "Gold",
			UpgradePrompt = "Gold",
		} :: { [string]: string },
		-- RollPrompt picks by station: Rune Shrine = WyrmRune, Dragonstone Forge = Dragonstone.
		TouchLabel = "Tap",
	},

	-- Walking through a portal: a whoosh, a quick FOV zoom and a flash in the portal's color.
	Warp = {
		Sound = "rbxassetid://139384716554132", -- "Whoosh_18" (free Creator Store)
		Volume = 0.6,
		FieldOfViewKick = 25, -- degrees added at the peak
		Seconds = 0.55,
		FlashTransparency = 0.5,
	},

	Roost = {
		BannerSize = Vector2.new(210, 46), -- pixels (avatar + "Name's Roost"), within UITheme.WorldLabels.MaxDistance
		-- "+gold" pops rising from your own roost dragons now and then.
		GoldPopEvery = NumberRange.new(5, 9), -- seconds
		GoldPopSeconds = 1.8,
		GoldPopRise = 5, -- studs
		-- Bursts on your roost dragons.
		LevelUpParticles = 18,
		EvolveParticles = 60,
		EvolveSound = "rbxassetid://128502047397803", -- "SE_DEMO_GET_STAR_2"
	},

	Stations = {
		-- Rune Shrine glows while you own Wyrm Runes; the Dragonstone Forge's fire flares while you own Dragonstones.
		ShrineColor = Color3.fromRGB(190, 140, 255),
		ForgeColor = Color3.fromRGB(255, 140, 60),
		GlowRange = 18,
		GlowBrightness = 1.6,
		ShrineSparkleRate = 5,
		ForgeFireRate = 14,
		BoardSize = Vector2.new(150, 40), -- pixels: icon + count / price / record boards
		MerchantBoardSize = Vector2.new(230, 58),
		SpireBoardSize = Vector2.new(210, 58),
		MerchantResetText = "New prices at dawn",
		SpireClimbText = "Climb!",
	},
}
