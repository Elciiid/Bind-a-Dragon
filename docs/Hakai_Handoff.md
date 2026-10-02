# Claude continuation checklist — Hakai gameplay polish

Prepared 2026-10-02. Read this together with `AGENTS.md`, the repository-root `CLAUDE.md`, `tools/sim/README.md`, and `tools/sim/Hakai_Polish_Results.md` before continuing.

## Scope and current Git state

Continue the approved gameplay/economy/UI fixes. Do not redesign the mutation system or refactor unrelated systems.

- Branch verified at handoff: **`codex/hakai-gameplay-polish`**.
- Latest local commit: **`570ffe2` — `WIP: Hakai gameplay economy and UI polish`**.
- Working tree was clean before adding this handoff file. Remote push status was not verified.
- Implementation checkout on Kyle's PC: `C:\Users\Kyle\AppData\Local\Temp\bind-a-dragon-hakai-polish`.
- Base merged main used for implementation: `c7c9c8cfec8da3bad057458a7175aec4cc290088`.
- The unrelated `C:\Users\Kyle\Documents\ChatGPT\Bind a Dragon Remodel` workspace contains remodel/Studio assets. Do not alter it.

First check `git branch --show-current`, `git status`, and `git log -1`. If working from another PC, fetch the feature branch and use its own checkout. Do not assume a stale temporary path or branch still exists.

### Non-negotiable safety

- Never implement on `main`. Preserve unrelated uncommitted changes.
- No additional commit, push, PR, merge, or publication without the user's explicit authorization. The existing WIP commit was observed, not created by the implementation agent.
- Studio work exclusively in the experience whose verified title is **Hakai Test**. Never production.
- Verify the open place again before editing/testing, not just once at startup.
- Use pinned **Rojo 7.6.1** and the feature-branch checkout. Do not upgrade Rojo.
- Preserve all Studio-only models, terrain, GLBs, assets, and backups. The project mapping deliberately excludes Workspace and ignores unknown instances.
- Create/verify a recoverable local backup before significant Studio changes.
- Use only isolated Studio data. Never access/reset production DataStores.
- RNG, currency, levels, progression, and rewards remain server-authoritative; validate and rate-limit remotes.
- Tunable values belong in configuration modules; wording belongs in Config/Text.
- Do not automate authentication/security settings. If API Services must be enabled, ask the owner to do it.

## Implemented, but not all live-tested

- [x] Geometric dragon upgrade costs and retained-income anchor; exact summed bulk costs; matching server, Auto-Upgrade, inventory, and prompt calculations.
- [x] Rebirth late-growth tuning with seeded simulation.
- [x] Dragonspire stages 1–100, no skipping/elevator entry, 12-second fights, Auto-Repeat OFF by default, validated toggle, sequential rewards.
- [x] Revised Dragonstone/Wyrm Rune rewards, preserving first-clear gold and potion rules.
- [x] Star Merchant themed Buy Stardust/Exit menu, E/gamepad/touch prompt support, server purchase validation and range closing.
- [x] Original transparent Echo Sigil emblem source; uploaded Roblox image integration NOT finished.
- [x] Reveal anticipation/burst, Skip, all-rarity Quick Binds, Reduced Motion setting, queued spoiler cover, delayed binder announcements, missing-model result fallback.
- [x] Effective completed-roll odds prominently displayed; labeled base odds/luck/probability details.
- [x] Shared safe bounds, responsive bottom navigation, top day/night timer, centered modals, clamped/wrapped inventory details and touch Details button.
- [x] Phone inventory row/button sizing corrections in source.

These checkmarks mean code exists, not that every acceptance test passed.

## Final balance values and formulas

### Level prices

`CostGrowthPerLevel = 1.08`; latest-band anchor budget = **900 seconds** unboosted income.
Rarity shares of next rebirth cost: Common .0020, Rare .0025, Epic .0030, Legendary .0035, Mythic .0040.

For R > 0:

```text
bandStart = currentLevelCap - 5
bandSum = sum(1.08^i, i = 0..4)
baseline = max(nextRebirthCost * rarityShare, retainedIncomeAnchor * 900 / bandSum)
nextLevelCost = ceil(baseline * 1.08^(currentLevel - bandStart))
```

R0 uses the rebirth-price component with exponent `currentLevel - 1`. Bulk buying sums the same individual prices; never multiply one quoted cost by the requested count.

Persisted server fields: `LevelingIncomeAnchor`, `LevelingAnchorRebirth`. The anchor snapshots the strongest eligible owned dragons filling available slots, with retained/permanent modifiers and new rebirth bonus, excluding temporary boosts. Refresh after rebirth milestone grants. Missing progressed-save anchors initialize once. Removing dragons from roost must not lower prices.

Rebirth **LateGrowth = 2.31**; other existing parameters are unchanged. Read Config/Rebirth for the entire curve rather than reconstructing it from older planning messages.

### Spire

- 100 stages, 12 seconds per fight, approximately 20 minutes per successful full run.
- Every defeated boss: 1 stone + 1 rune, including repeats.
- First-clear boss: an additional 1 each.
- First-clear non-boss stage divisible by five: 1 each.
- First complete run: **30 each**; repeat complete run: **10 each**, before reward boosts. A 2x reward boost makes these 60/20.
- First-clear gold remains 30 income-seconds per new stage; record persists through rebirth, so repeat runs do not get that gold.
- Auto-Repeat restarts only after stage 100, at stage 1. Loss, death, Stop, and departure end the run.
- Elevator purchases/skip controls disabled; old entitlements/counts preserved and not consumed. Verify product IDs remain zero before rollout.

## Simulation evidence — measured, not a human playtest

Extended the existing `tools/sim/CohortSim.luau`. Do not replace it with a competing model.

8,000 paired baseline/revised cohorts total: 1,000 seeds per profile per variant, 180-day cutoff. Raw elapsed days, no historical calibration multiplier.

| Revised profile | Median R30 days | p10 | p90 | Unfinished |
|---|---:|---:|---:|---:|
| Dedicated | 7.9611 | 5.9854 | 10.0326 | 0/1,000 |
| Casual | 26.9799 | 19.8139 | 33.0167 | 0/1,000 |
| AFK-light | 32.7535 | 28.9611 | 38.8493 | 0/1,000 |
| Paying AFK | 16.0000 | 11.9938 | 19.3465 | 0/1,000 |

Dedicated assumes 3.5 active hours/day in two sessions, +/-15% session variation, 3% missed days (realized average approximately 3.40h), up to eight offline hours/day at 50%, 25 minutes/day reserved for sequential Spire, manual upgrade/roost/spending decisions, affordable offerings/Stardust, earned sigils/luck charges, and earned potion use. Auto-Upgrade OFF for the ordinary strategy.

Casual: 1h/day. AFK-light is a 12-minute manual daily check-in, NOT zero-input AFK. Paid strategy has twelve five-minute check-ins, 12h online idle, Auto-bind and 2x AFK. See the report for missed-day rates, algorithm, caveats, baseline censoring, and rewards.

The 7–9-day dedicated median and active-faster-than-paid targets pass in this model. This is not an eight-day minimum: p10 is under six days.

Newest-band roost-only fixed quote: 15 minutes. Separate 1,000-seed continuous-reinvestment check: median **12.1185 minutes**, p10 9.0204, p90 13.6275. Potions and finite first-clear Spire gold can shorten it. First-clear stages plus ordinary income produce a temporary 3.5x rate, so the 15-minute quote can be earned in about 4.29 minutes while new stages remain. Do not advertise the 10–20-minute target as an all-activities minimum. These finite rewards already exist in the cohort model.

## Automated checks completed

- [x] All **132 Luau files** compiled at the last sweep.
- [x] `git diff --check` passed at that sweep.
- [x] Pinned Rojo 7.6.1 built `default.project.json` successfully to a temporary local place file.
- [x] 11,000 ascending per-level cost checks over 20 species and R0/R1/R10/R20/R30.
- [x] 100 bulk-cost scenarios, three anchor checks, and reward-total checks passed through RunCli.
- [x] Independent Spire reward tests covered early stages, full first/repeat runs, and boosts.

Re-run after any change. CLI checks are not complete type/exploit/UI/persistence validation.

Suggested commands (provide your actual installed Luau path):

```powershell
./tools/sim/RunCli.ps1 -Luau '<path-to-luau.exe>' -Check -Runs 0
./tools/sim/RunCli.ps1 -Luau '<path-to-luau.exe>' -Runs 1000 -MaxDays 180 -Profile Dedicated
# Repeat for Casual, AfkOnly and PaidAfk using exact profile names in CohortSim.
# Add -Baseline for the paired old-flat-cost / LateGrowth 2.55 control.
rojo --version   # must report 7.6.1
rojo build default.project.json --output '<temporary-test-file.rbxlx>'
git diff --check
```

## Studio evidence actually observed

- Verified open title **Hakai Test - Roblox Studio**.
- Backup: `C:\Users\Kyle\Documents\Hakai-Test-before-polish-2026-10-02.rbxl` (4,256,055 bytes when checked).
- Feature checkout Rojo connected on port **34873**; earlier unrelated 34872 server was not stopped.
- Fresh mock profile loaded Cinderwing level 1, approximately 753/s with Index bonus. Top timer/bottom navigation observed.
- Studio API Services unavailable; ProfileStore reported mock data/no saving. Persistence and rejoin tests remain unverified.
- Test namespace marker: ServerStorage attribute `TestProfileKey = "PolishFresh_20261002"`.
- Studio-only hooks granted R29 and Stormcrown level195, then real UI rebirth reached R30: gold reset, level195 retained, cap200, Champion Solflare milestone granted.
- Common next upgrade quote changed from **5.75T** to **6.21T** after buying one level (8%). Ungraded Stormcrown195 next quote was **35Qi**; do not assume every dragon's band takes exactly 15 minutes.
- Desktop inventory Details showed correct power, income, home odds and modifiers without observed clipping.
- Full Auto-Repeat OFF Spire run started at stage1 with Stormcrown power about 65.8M. **Last confirmed stage60**, consecutive stages with 12-second fights, no skipped-stage assertion failures. Completion NOT verified.

The user explicitly stopped further testing. A play session may have continued afterwards. Inspect its current state and logs; do not infer completion from elapsed time. No test acceleration was used.

## Remaining work — recommended order

### 1. Restore a safe test environment

- [ ] Verify branch/status and actual feature files; do not pull/merge blindly over dirty work.
- [ ] Verify exact Hakai Test place, recoverable backup and correct Rojo checkout/version.
- [ ] Verify Studio data isolation. API Services are blocked: owner must resolve if persistent tests are required; never use production data.
- [ ] Reload Play after source updates: live-required controller modules are cached and may not reload merely through Rojo sync.

### 2. Identify merchant and finish emblem integration

- [ ] Ask owner for imported merchant GLB's exact Explorer path. Current place has no `StarMerchant` tag; found only `Workspace.StarterMeadow.Market.Platform_StarMerchant` and `Placeholder_StarObelisk`. Do NOT guess that either is the GLB.
- [ ] Preserve mesh/model. Tag intended model, use its designated InteractionAnchor/PrimaryPart appropriately; ensure only one prompt/listener.
- [ ] Verify E, gamepad and touch; themed Buy Stardust/price/Exit; insufficient funds; dead/out-of-range denial; cooldown; range close; no duplicate purchase grants.
- [ ] Upload `assets/icons/EchoSigil.png` using an authorized creator-owned Roblox image asset; configure `Config/UITheme.Icons.EchoSigil` (currently empty with fallback). Verify 32/48/64px readability and transparency. Do not invent an ID or publish the experience.

### 3. Complete Spire runtime validation

- [ ] Full OFF: stages1–100 in order, exactly-once 30/30 first rewards, stop after100, manually restart at1.
- [ ] Full ON: stages1–100, 10/10 repeat rewards, automatic new stage1, then Stop works.
- [ ] Toggle OFF mid-run completes current run and does not repeat; default OFF in a fresh session.
- [ ] Loss, death, departure and Stop end the run without late rewards or another loop.
- [ ] Reject repeated Start/concurrent runs, invalid toggle types and remote spam.
- [ ] Check boosted rewards and first-clear gold once-only behavior across rebirth.
- [ ] Stored elevator entitlements/skips remain unchanged and cannot skip stages.

A duplicate-Start/invalid-AutoRepeat command was prepared in the Studio command bar but **not executed** when work stopped. Do not count it as passed.

### 4. Complete economy/save runtime validation

- [ ] Fresh and representative progressed profiles; nil/missing/invalid anchor initialization once.
- [ ] New rebirth anchor includes milestone grants/new bonus, excludes potion boosts, cannot be lowered by roost unplacement.
- [ ] Individual/bulk/server/UI costs agree at several levels, rarities, rebirths and max cap; funds are never overspent.
- [ ] Auto-Upgrade exact totals/reserves; retained potions/items/perks affect progress as modeled.
- [ ] Online/idle/offline payouts correct; isolated persistence/rejoin/settings only when API access is available.
- [ ] Preserve Species IDs, mutations, traits, grades, evolution, Index and existing valid saves.

### 5. Reveal and layout player flows

- [ ] Ordinary, Legendary/Mythic and all mutated result presentations; actual server-frozen effective odds, base pool label/luck/probability.
- [ ] No identifying text before reveal: notifications, announcements, inventory/discovery, HUD/nameplates and queued results.
- [ ] Skip immediately reveals/restores UI; Quick Binds applies to every rarity; Reduced Motion removes movement/spin/shake/flashes.
- [ ] Missing models/error recovery restore camera and HUD; multiple queued binds do not leak the next result.
- [ ] Desktop resizing plus phone portrait AND landscape with notch/camera-cutout presets.
- [ ] Left/right safe bounds, top Roblox controls, bottom navigation clear of thumbstick/jump, all modals including title overhang centered.
- [ ] Inventory long names, hover near every screen edge, live stat refresh, touch Details independent of Upgrade/Roost, no clipped controls.
- [ ] Reward popups/reveal banners fit longest mutation/species combinations. Ceremony banner received a width-scaling fix, compiled but not live-tested on mobile.

### 6. Resolve source review follow-ups and finish docs

- [ ] Spire setup may add another Triggered connection when a tagged model is removed/re-added. Guard prompt hookup if confirmed; current synchronous run reservation prevents duplicate runs but not connection accumulation.
- [ ] Merchant menu only checks tag validity on open; if tag removed while open, menu can linger although server denies purchases. Close on invalidation if confirmed.
- [ ] Review RewardPopup long title banner width on narrow screens, not only the ceremony banner.
- [ ] Update stale root CLAUDE status/Spire/Monetization sections describing 150 stages, fast-forwarding or elevators. A new header alone does not resolve contradictory old descriptions.
- [ ] Update `docs/Hakai_Polish_Validation.md`: its earlier draft still says economy/rebirth evidence pending; use the evidence above and measured report, leaving untested cases pending.
- [ ] Final compilation/build/tests; report expected vs observed rewards, sample counts, elapsed times, layout evidence and all limitations.
- [ ] Hand off branch, changed-file summary, final balance, simulation assumptions/results, Studio results, and remaining blockers. Ask user before commit/push/merge/publish.

## Main file map

- Economy: Config/Leveling, Config/Rebirth, Shared/DragonStats, Types/PlayerData; DataService, DragonService, MilestoneService, EconomyService.
- Spire: Config/Spire, Config/Products; SpireService, MonetizationService; SpireController, ShopController.
- Merchant: Config/Economy/Text; Remotes/BuyStardust; EconomyService, MerchantController.
- Reveal/odds: Config/Ceremony/Odds/Text; OddsText; BindingService; BindingController, CeremonyController, NotificationController, UI/RevealGate, UI/RewardPopup.
- Accessibility/layout: Config/Layout/UITheme/Data; SettingsService/SettingsController, EffectsQuality, HudLayout, DayNightController, TravelController, InventoryController, DragonPromptController, UI/Window/Tooltip/Banner.
- Sigil: assets/icons/EchoSigil.png, UITheme.Icons.EchoSigil, ItemsController.
- Evidence: tools/sim/CohortSim.luau, RunCli.ps1, CostChecks.luau, SpireRewards.test.luau, README.md, Hakai_Polish_Results.md; docs/Hakai_Polish_Validation.md.

Git does not transfer Studio-only content. A friend testing elsewhere needs the correct Hakai Test place/assets separately. Do not overwrite their place with the Rojo build; it is only a code-build diagnostic artifact.
