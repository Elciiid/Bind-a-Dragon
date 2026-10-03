# Task A: global leaderboards

Implemented on `codex/leaderboards-audio-onboarding`. No map parts, Studio assets, production data, commits, or publication were changed by this task agent.

## Behavior

- Three independent ordered stores: Rebirths, Lifetime Gold, Rarest Dragon. Studio store names end `_Studio`, including the ancillary rarity-metadata store.
- Gold score is `round(log10(LifetimeGold + 1) * 1e6)`. Decoding is approximate (display marked `≈`), with maximum relative quantization error approximately 1.2 ppm. Scores remain exact double integers below `2^63`.
- Routine player writes are at most once per 300 seconds, starting on load; leave/shutdown flushes are explicit exceptions. All updates retain the larger prior score; rare metadata likewise retains the larger base denominator atomically. Requests retry three times with budget checks. Ordered updates check ordered-write and read budgets. API failure retains cached results, not mock results.
- Global snapshots refresh every 150 seconds. Pagination stops once the top ten and all active viewers are found, with an absolute ten-page/1,000-entry budget. Unresolved ranks are explicitly unavailable, never fabricated. Ties use the ordered store's returned position; log quantization can create gold ties. Ranks/values are cached rather than real-time.
- Rare labels only display metadata matching the cached ordered score; during independent-store update or cache lag, the odds remain visible without a potentially wrong dragon name.
- Rarity records use actual `BindResult.BaseOneIn`, never effective lucky odds. Existing owned dragons backfill canonical home-pool base odds when the record is zero. Champions are excluded from owned-dragon backfill. Dragons already sold before this update cannot be recovered from history.
- New fields appended to the template/type: `LifetimeGold`, `RarestOneIn`, `RarestSpecies`, `RarestMutation`. Existing `ProfileStore:Reconcile()` fills these; data version is unchanged.

## Gold accounting limitation

Lifetime Gold starts at zero: historical lifetime income is unrecoverable. New online/idle roost payouts, offline payouts and SellService sales are recorded, excluding gold discarded by the bank cap. Rebirth spending/reset does not reduce lifetime income. Developer grants are deliberately excluded.

**Spire gold is not recorded yet:** `SpireService` is explicitly protected by the user, so this task does not edit it. A later permitted change should call `LeaderboardStats.RecordGold(data, gold)` immediately before each actual Spire gold credit. Current quest/Index rewards grant no gold. The board is therefore lifetime gold from the hooked sources, not a complete all-source ledger until the Spire hook is authorized.

## Checks performed

`tools/tests/RunLeaderboardsChecks.ps1` reuses the existing CLI module loader and runs 610 assertions against real shared modules: finite integer encodings for `10^0` through `10^300`, monotonicity, round-trip error, invalid input handling, base-odds record retention, old-owned backfill and bank-cap credit accounting. Passed.

Luau compiler parsing/bytecode checks passed for new service, controller and shared stats. `git diff --check` passed. These are **not** Roblox runtime/type-analysis or DataStore integration tests.

## Manual Hakai Test verification (user operates Studio)

1. Confirm **Hakai Test**, backup already saved, pinned Rojo 7.6.1 connected to this feature checkout. Do not publish.
2. Create three temporary anchored parts; tag each `Leaderboard`, set string `Board` to `Rebirths`, `Gold`, or `Rarest`. Boards render on the Front face; orient parts appropriately. Do not replace existing world models.
3. Start a two-player Local Server. Verify themed top rows, avatars, medal colors, own rank/value, Rebirths player-list entry. Negative local-test user IDs are accepted only in Studio and use local names without external avatar requests.
4. With Studio API access enabled and isolated Studio profiles, earn online/offline gold, sell a dragon, bind outcomes, rebirth, then wait for the 300-second publish and 150-second refresh. Verify balances reset but lifetime does not, and lucky effective odds never enter the rare record. Leave/rejoin and check persistence/backfill.
5. Bind a new rare dragon between refreshes: prior rank/value must not be paired with the new name. Check unavailable-rank behavior when outside the pagination budget.
6. Disable API access: boards should stay loading/retain their last successful snapshot with server warnings, not invent global rows. Verify portrait/landscape viewing/readability and removal/retagging of board parts.

All Studio, cross-server monotonic update, DataStore budget/API, persistence, avatar and visual checks remain **unverified**. Partial failures and Roblox's shutdown deadline may prevent the latest flush; normal future writes recover monotonic scores from saved player records.
