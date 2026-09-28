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

	-- Roost upgrade stands on each sanctuary forecourt (UpgradeStandController; the art is built in Studio by
	-- ValleyBuild.BuildUpgradeStands). Everyone sees the owner's progress: the slots stand lights one gem per roost slot,
	-- the income stand one jade gem per GemLevels income levels (a gem in progress glows part-way).
	UpgradeStands = {
		AnimateDistance = 150, -- studs from the camera; farther stands hold still
		LightDistance = 70, -- the glow light only near the camera
		BobHeight = 0.35, -- studs up and down (times the stand's scale)
		BobSpeed = 1.3, -- radians per second
		EggSpin = 0.5, -- radians per second
		CoinSpin = 1.6,
		OrbitSpeed = 0.9,
		GemLevels = 5, -- income levels per jade gem
		SlotGemColor = Color3.fromRGB(140, 205, 255),
		IncomeGemColor = Color3.fromRGB(96, 224, 150),
		MaxedColor = Color3.fromRGB(255, 214, 110), -- egg core / coin glow once that upgrade is maxed
		LightRange = 12,
		LightBrightness = 1.2,
		SparkleRate = 3, -- per second (more as the upgrade fills up, x2 when maxed; Low effects: none)
		BurstParticles = 40, -- on every upgrade bought
		BoardSize = Vector2.new(190, 50), -- pixels
		BoardHeight = 14.5, -- studs above the stand's floor (just over the floating egg / coin)
		BoardSideOffset = 3.5, -- studs outward from the gate's center line (clear of the owner banner)
	},

	-- Sanctuaries look grander as their owner upgrades the roost (SanctuaryTierController; the art is built in Studio by
	-- ValleyBuild.BuildSanctuaryTiers into ReplicatedStorage.Assets.SanctuaryTiers). Upgrade points = extra roost slots
	-- bought (0-5) + income levels / IncomeLevelsPerPoint (0-5); every PointsPerTier points unlock the next tier:
	-- 1 Gilded, 2 Runed, 3 Crystal, 4 Ascendant, 5 Legendary (all upgrades maxed). Tiers add up.
	SanctuaryTiers = {
		IncomeLevelsPerPoint = 5,
		PointsPerTier = 2,
		Names = { "Gilded", "Runed", "Crystal", "Ascendant", "Legendary" },
		LightDistance = 120, -- studs from the camera; brazier lights farther away stay off
		AuroraNightBlend = 0.35, -- the aurora (tier 4) shows once the night blend passes this
		BurstParticles = 90, -- starburst at the gate when a sanctuary reaches a new tier
		BurstSound = "rbxassetid://128502047397803", -- "SE_DEMO_GET_STAR_2"
		BurstVolume = 0.6,
	},
}
