--!strict
-- Player data settings. Starting values here are what a brand-new player begins with.

return {
	-- DataStore name. Changing this starts everyone with fresh data, so only change it on purpose.
	-- Studio playtests automatically use "<StoreName>_Studio" instead, so tests never touch live data.
	StoreName = "PlayerData",

	-- Starting currency for a new player.
	StartingGold = 0,
	StartingStardust = 0,

	-- How many developer product receipt IDs to remember per player (prevents double-granting).
	-- Oldest IDs are dropped first; Roblox stops retrying a receipt long before this fills up.
	MaxStoredPurchaseIds = 50,
}
