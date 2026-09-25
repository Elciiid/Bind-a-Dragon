--!strict
-- Shape of a player's saved data. Keep in sync with the template in DataService.
-- Saved data must be plain values only: no Instances, Vector3/Color3, functions, or mixed/gapped tables.

export type Dragon = {
	Id: string,
	SpeciesId: string, -- key into Config/Dragons; rarity and element come from there
	Level: number,
	ObtainedAt: number, -- os.time()
	Evolutions: { [string]: string }?, -- stageId -> constellationId in the sky when it evolved (its branch)
	Trait: string?, -- Config/Traits trait Id (rolled with Wyrm Runes)
	Grade: string?, -- Config/Traits grade Id (rolled with Dragonstones)
}

export type PlayerData = {
	DataVersion: number,

	Gold: number,
	Stardust: number,
	WyrmRunes: number, -- trait rolls (from the Dragon Spire)
	Dragonstones: number, -- grade rolls (from the Dragon Spire)
	Rebirths: number,

	Dragons: { [string]: Dragon }, -- keyed by Dragon.Id
	NextDragonId: number,
	RoostDragonIds: { string }, -- dragons placed in the roost (earn gold)
	RoostSlotUpgrades: number, -- extra roost slots bought
	RoostIncomeLevel: number, -- roost income upgrade level

	MerchantDay: number, -- Cycle NightIndex the MerchantPurchases count belongs to (resets at dawn)
	MerchantPurchases: number, -- Stardust bundles bought on MerchantDay

	StarAtlas: { [string]: number }, -- constellationId -> times bound
	LastBindNight: number, -- Cycle NightIndex of the last bind (one bind per night)
	OfferingNight: number, -- NightIndex the Offerings count belongs to (older nights = 0 offerings)
	Offerings: number, -- Stardust offerings made on OfferingNight

	LastOnline: number, -- os.time() of the last save; used for offline income
	AfkCreditDay: number, -- UTC day (os.time() // 86400) that AfkCreditSeconds belongs to
	AfkCreditSeconds: number, -- offline + idle seconds already paid today (capped by Config/Roost OfflineCapHours)
	PurchaseIds: { string }, -- recent developer product receipt IDs, oldest first
}

return {}
