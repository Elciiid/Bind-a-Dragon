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
	MutationId: string?, -- Config/Mutations; nil is the backward-compatible Normal state
	Champion: boolean?, -- the rebirth champion dragon (Config/RebirthMilestones Champion)
	Locked: boolean?, -- the player locked it: it can't be sold at the Star Merchant (SetDragonLocked)
}

export type QuestState = {
	Id: string, -- Config/Quests quest Id
	Target: number,
	Progress: number,
	Done: boolean, -- reward granted
}

export type PlayerData = {
	DataVersion: number,

	Gold: number,
	Stardust: number,
	WyrmRunes: number, -- trait rolls (from the Dragon Spire)
	Dragonstones: number, -- grade rolls (from the Dragon Spire)
	Rebirths: number,
	LevelingIncomeAnchor: number, -- unboosted strongest legal roost at the start of this rebirth
	LevelingAnchorRebirth: number, -- rebirth for which the immutable anchor was initialized

	Dragons: { [string]: Dragon }, -- keyed by Dragon.Id
	NextDragonId: number,
	RoostDragonIds: { string }, -- dragons placed in the roost (earn gold)
	RoostUnplacedDragonIds: { string }, -- dragons explicitly picked up; kept out of automatic slot filling
	Hotbar: { string }, -- Dragon Hotbar: Config/Hotbar.Slots dragon ids ("" = empty slot), slot 1 first
	RoostSlotUpgrades: number, -- extra roost slots bought
	RoostIncomeLevel: number, -- roost income upgrade level

	MerchantDay: number, -- Cycle NightIndex the MerchantPurchases count belongs to (resets at dawn)
	MerchantPurchases: number, -- Stardust bundles bought on MerchantDay

	Potions: { [string]: number }, -- Config/Boosts potion Id -> count owned
	ActiveBoosts: { [string]: number }, -- timed potion Id -> seconds left (ticks only while online)
	ArmedLuckPotion: string, -- luck charge potion Id used by the next bind ("" = none)
	PotionHintShown: boolean, -- the one-time "open Boosts to use it" hint was shown

	QuestDay: number, -- UTC day (os.time() // 86400) DailyQuests belong to
	DailyQuests: { QuestState },
	QuestWeek: number, -- UTC week (Monday start) WeeklyQuests belong to
	WeeklyQuests: { QuestState },
	LoginDay: number, -- UTC day of the last counted login
	LoginStreak: number, -- current streak day (1..#StreakRewards)

	SpireRecord: number, -- highest Dragon Spire floor cleared
	ElevatorSkips: number, -- Single Elevator Skip developer products owned (one climb each)
	EchoSigils: number, -- earned extra binds, capped by Config/Binding
	EchoSigilQuestDay: number, -- UTC day the all-dailies sigil was awarded
	EchoSigilSpireDay: number, -- UTC day the Spire sigil was awarded
	EchoSigilSpireProgressDay: number, -- UTC day the qualifying win counter belongs to
	EchoSigilSpireWins: number, -- qualifying non-fast wins today

	StarAtlas: { [string]: number }, -- constellationId -> times bound
	Index: { [string]: number }, -- normal species discovery -> os.time() found
	MutationIndex: { [string]: number }, -- "SpeciesId:MutationId" discovery -> os.time() found
	MilestonesSeen: { [string]: boolean }, -- Config/RebirthMilestones Ids already celebrated (pop-up, grants)
	AutoUpgrade: boolean, -- the R12 Auto-Upgrade toggle
	IndexMilestones: number, -- MilestoneEvery rewards already given
	IndexElementsRewarded: { [string]: boolean }, -- element -> its completion reward was given
	LastBindNight: number, -- Cycle NightIndex of the last bind (one bind per night)
	OfferingNight: number, -- NightIndex the Offerings count belongs to (older nights = 0 offerings)
	Offerings: number, -- Stardust offerings made on OfferingNight

	LastOnline: number, -- os.time() of the last save; used for offline income
	AfkCreditDay: number, -- UTC day (os.time() // 86400) that AfkCreditSeconds belongs to
	AfkCreditSeconds: number, -- offline + idle seconds already paid today (capped by Config/Roost OfflineCapHours)
	PurchaseIds: { string }, -- recent developer product receipt IDs, oldest first
	Settings: Settings, -- the player's Settings window choices (Config/Data DefaultSettings)
	LifetimeGold: number, -- credited earnings since this counter was introduced; historical spending cannot be recovered
	RarestOneIn: number, -- best server base pair odds ever bound; owned-dragon fallback for old saves
	RarestSpecies: string,
	RarestMutation: string,
	OnboardingStep: number, -- 0 unclassified, -1 skipped, configured positive steps
	OnboardingFirstBindUsed: boolean, -- once-only special bind; server-owned
	OnboardingFreeLevelUsed: boolean, -- once-only manual level; server-owned
	OnboardingHints: { [string]: boolean }, -- once-only relevance hints
}

export type Settings = {
	MusicVolume: number, -- 0..1
	SoundVolume: number, -- 0..1
	LowEffects: boolean,
	QuickBinds: boolean,
	ReducedMotion: boolean,
}

return {}
