--!strict
-- Potions and boosts. Players get potions from the Dragon Spire, quests and the Index (later phases) and use them
-- from the Boosts panel.
--
-- Timed potions: using one adds Minutes to that potion's timer (up to MaxStoredMinutes stored per potion).
-- Timers only tick while the player is in the game (they pause offline). Roblox Premium members get
-- PremiumDurationBonus extra time per potion. Different potions on the same stat multiply
-- (Gilded Draught x Hoard Elixir = x10 gold).
--
-- Luck charges: the player ARMS one for their next bind (Boosts panel or the altar's luck panel). It's used up by
-- that bind only. It multiplies luck after the normal cap (Config/Luck Cap), up to Config/Luck PotionCap.
--
-- Stats: "Gold" = roost income while in game; "RollLuck" = trait/grade roll luck (rarer results, like bind luck);
-- "SpirePower" / "SpireRewards" = used by the Dragon Spire (Phase 5).
-- Potion Ids are saved in player data, so never rename or remove an Id once live (change Name instead).
-- PLACEHOLDER numbers.

export type Potion = {
	Id: string,
	Name: string,
	Kind: "Timed" | "LuckCharge",
	Stat: string?, -- Timed only
	Multiplier: number,
	Minutes: number?, -- Timed only
	Description: string,
	Color: Color3,
}

local Potions: { Potion } = {
	{
		Id = "GildedDraught",
		Name = "Gilded Draught",
		Kind = "Timed",
		Stat = "Gold",
		Multiplier = 2,
		Minutes = 5,
		Description = "x2 roost gold",
		Color = Color3.fromRGB(255, 210, 70),
	},
	{
		Id = "HoardElixir",
		Name = "Hoard Elixir",
		Kind = "Timed",
		Stat = "Gold",
		Multiplier = 5,
		Minutes = 5,
		Description = "x5 roost gold",
		Color = Color3.fromRGB(255, 150, 40),
	},
	{
		Id = "StarlightTonic",
		Name = "Starlight Tonic",
		Kind = "LuckCharge",
		Multiplier = 1.5,
		Description = "x1.5 luck on your next bind",
		Color = Color3.fromRGB(170, 220, 255),
	},
	{
		Id = "MoonfireTonic",
		Name = "Moonfire Tonic",
		Kind = "LuckCharge",
		Multiplier = 2,
		Description = "x2 luck on your next bind",
		Color = Color3.fromRGB(200, 150, 255),
	},
	{
		Id = "RunebrightTonic",
		Name = "Runebright Tonic",
		Kind = "Timed",
		Stat = "RollLuck",
		Multiplier = 2,
		Minutes = 5,
		Description = "x2 luck when inscribing runes and tempering",
		Color = Color3.fromRGB(120, 230, 200),
	},
	{
		Id = "WyrmbloodTonic",
		Name = "Wyrmblood Tonic",
		Kind = "Timed",
		Stat = "SpirePower",
		Multiplier = 2,
		Minutes = 10,
		Description = "x2 power in the Dragon Spire",
		Color = Color3.fromRGB(230, 70, 70),
	},
	{
		Id = "ConquerorsBrew",
		Name = "Conqueror's Brew",
		Kind = "Timed",
		Stat = "SpireRewards",
		Multiplier = 2,
		Minutes = 10,
		Description = "x2 Spire gold, Stardust, Wyrm Runes and Dragonstones (not potions)",
		Color = Color3.fromRGB(240, 240, 240),
	},
}

local byId: { [string]: Potion } = {}
for _, potion in Potions do
	byId[potion.Id] = potion
end

return {
	Potions = Potions, -- display order
	ById = byId,

	MaxStoredMinutes = 60, -- per timed potion; using one past this is refused
	PremiumDurationBonus = 0.10, -- Roblox Premium: +10% duration per potion
	UseCooldown = 0.3, -- seconds between UseBoost requests per player (anti-spam)
}
