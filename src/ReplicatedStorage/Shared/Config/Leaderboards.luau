--!strict
return {
	Stores = { Rebirths = "Leaderboard_Rebirths_v1", Gold = "Leaderboard_LifetimeGold_v1", Rarest = "Leaderboard_Rarest_v1" },
	MetadataStore = "Leaderboard_RarestMetadata_v1", -- cross-server species/mutation accompanying the numeric record
	TopCount = 10,
	WriteInterval = 300, -- at most one routine publish per player per five minutes; leave flush is the exception
	RefreshInterval = 150, -- refresh all cached lists every 2.5 minutes
	ClientPollInterval = 30, -- clients read only cached results, never issue DataStore queries
	RequestCooldown = 5,
	TickInterval = 5,
	RetryCount = 3,
	RetrySeconds = 2,
	BudgetWaitSeconds = 5, -- bounded retries; keep the last good board on API/budget failure
	PageSize = 100,
	RankPageLimit = 10, -- exact viewer position in the first 1,000 entries; beyond this budget return unknown
	GoldLogScale = 1e6, -- integer log10 encoding; relative decode error <= about 1.2e-6
	MaxOrderedValue = 9007199254740991, -- exact double integer, safely below the OrderedDataStore 2^63 ceiling
	MaxLifetimeGold = 1e300, -- finite save/display limit far above existing progression
	MetadataCacheSeconds = 600,
	ShutdownSeconds = 25, -- leave/shutdown handlers never hold the server indefinitely
}
