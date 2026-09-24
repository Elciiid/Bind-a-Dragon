--!strict
-- Shape of a player's saved data. Keep in sync with the template in DataService.
-- Saved data must be plain values only: no Instances, Vector3/Color3, functions, or mixed/gapped tables.

export type Dragon = {
	Id: string,
	SpeciesId: string, -- key into Config/Dragons; rarity and element come from there
	Level: number,
	ObtainedAt: number, -- os.time()
}

export type PlayerData = {
	DataVersion: number,

	Gold: number,
	Stardust: number,
	Rebirths: number,

	Dragons: { [string]: Dragon }, -- keyed by Dragon.Id
	NextDragonId: number,

	StarAtlas: { [string]: number }, -- constellationId -> times bound

	LastOnline: number, -- os.time() of the last save; used for offline income
	PurchaseIds: { string }, -- recent developer product receipt IDs, oldest first
}

return {}
