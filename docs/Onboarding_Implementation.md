# Task C — onboarding handoff

**Presentation superseded on 2026-10-04:** this document records the earlier Task C implementation and owner-reported
tests. On `codex/mobile-ui-tutorial-reveal`, `UI/TutorialCard`, the supported HudLayout target registry and responsive
Inventory free-upgrade controls replace the hint/pointer presentation and resolve the Home/Upgrade getter gaps
described below. Server-owned progress, conditional first bind, saved fields and once-only rewards are preserved.
The new ceremony uses its own viewport rather than the player's camera. Current changes, source checks and pending
owner-operated Studio tests are in [`Mobile_UI_Polish.md`](Mobile_UI_Polish.md); historical playtests do not certify
the redesigned UI.

## Implemented

Read `Onboarding_Proposal.md` for the step/wording contract. Server owns classification, special bind, free manual level and progress; client owns the bounded ground star trail, hint, pointer and falling-star presentation. Both auto-bootstrap through existing Main Init/Start discovery.

- Fresh players retain the Common starter and get one immediate StarterMeadow bind, even by day, guaranteed minimum Rare. Area/element filtering remains; mutation shares remain. Luck is x1 for this special opportunity, without consuming an armed potion or Echo Sigil. A nighttime special bind occupies its natural night; a daylight special bind leaves the upcoming night available.
- First-bind result uses normalized **conditional** pair probabilities and labeled “First-bind pool” details. The existing leaderboard hook receives the actual conditional base odds, not inflated ordinary-pool odds. Normal binding is unchanged.
- A local isolated altar viewport shows the star falling before the existing ceremony. This runs inside BindingController's existing serialized reveal queue, behind the spoiler cover; no CeremonyController edit. Reduced Motion/Quick Binds use a brief static star. No world model replacement, terrain edit or asset upload.
- Sanctuary proximity is checked on the server; the existing RoostService autofills the granted dragon. Step three has an explicit touch-sized **Free upgrade** action using the normal owned-dragon LevelUpDragon request. Exactly its first level costs zero; later levels in the same bulk purchase cost normally. Auto-Upgrade cannot spend the free entitlement.
- NightIndex refers to the upcoming night during day: a daylight first bind is eligible for that same-index night's hint; a night bind waits for a later night. The final trail/hint remains for 30 seconds, and completed profiles do not replay it on rejoin.
- Quests, 25%-cost Rebirth and level-10 Spire hints have independent saved once-only flags. Skip accepts only true, has a one-second rate limit, revokes unused tutorial grants and hides all further tutorial hints.

## Saved fields

Appended at the **end** of DataService template and PlayerData type, after Task A fields, with no data-version change:

| Field | Default | Purpose |
| --- | --- | --- |
| OnboardingStep | 0 | Unclassified, then -1 skipped or configured steps 1–5 |
| OnboardingFirstBindUsed | false | One-time special-bind entitlement |
| OnboardingFreeLevelUsed | false | One-time manual free level |
| OnboardingHints | {} | Once-only context hints |

ProfileStore `Reconcile()` already runs before load callbacks. Existing saves with a rebirth, more than one owned dragon, or an actual previous bind skip without retroactive grants. Starter callback ordering is safe: zero or one starter dragon remains eligible; classification is idempotent and also performed before reward checks. Existing players with exactly one never-bound starter and no rebirth are indistinguishable from new players under the requested saved-field rules and receive onboarding.

## Files

New: `Config/Onboarding.luau`, `Services/OnboardingService.luau`, `Controllers/OnboardingController.luau`, `Remotes/SkipTutorial.model.json`, this report, proposal, and `tools/sim/OnboardingChecks.ps1`.

Scoped edits: BindingService (server special outcome and daylight prompt), DragonService (manual once-only free price), BindingController (serialized pre-ceremony hook/payload), NotificationController (conditional-pool labels), DataService template, PlayerData type, Config/Text and Config/UITheme. Task A's normal binding record hook is preserved. No protected file was edited.

## Measured source tests

`./tools/sim/OnboardingChecks.ps1` loads the actual OnboardingService methods and real binding/config modules with inert service dependencies. Passed:

- Fresh/previously bound/multiple-dragon/rebirth/skipped eligibility; special bind and free level once-only.
- Daytime same-index night versus night-time next-index threshold.
- Five conditional pools (Fire, Ice, Storm, Shadow, any element) sum to 1 ± 1e-12; eligible species are Rare only, with positive probabilities and consistent denominators.
- **500,000 seeded rolls** (100,000 per pool). All outcomes remain eligible Rare; species × mutation denominator matches joint denominator. Normal mutation counts are within five-sigma binomial bounds around the configured 90% share.
- Empty element pool returns no eligible outcomes.
- Edited Luau modules compile with luau-compile. These checks do not certify Roblox GUI rendering or DataStore persistence.

## Protected-file gaps / deliberate fallbacks

HudLayout exposes no Home/travel-button getter. The Home step uses its clear wording and ground trail; exact Home overlay highlighting is not implemented. No internal descendant-name guessing or protected layout changes.

InventoryController exposes no supported per-card Upgrade getter and disables Upgrade below its ordinary paid quote. Inventory pointer and the tutorial's **Free upgrade** button are used instead. The normal inventory price remains the paid price; the tutorial explicitly states that this one purchase is free. A future supported getter/free-quote integration would require permission to edit that protected file.

The first-star animation clones only the altar into a temporary viewport, strips scripts/prompts/world labels, and destroys it after animation. It does not reveal the newly granted dragon early. Clone failures restore the normal ceremony flow. If an altar model has no PrimaryPart, the guide can locate a part, but existing BindingService still requires a valid PrimaryPart for its actual prompt; fix that in Studio rather than silently guessing a server anchor.

## Manual Studio checklist — owner performs all Studio actions

No Studio playtest was performed for Task C; the owner requested manual testing. Use **Hakai Test**, an isolated TestProfileKey / PlayerData_Studio, pinned Rojo 7.6.1, and the saved backup. Never reset/access production data.

1. Fresh daytime join: verify hint/trail, mobile/keyboard altar prompt and bind within the first 60 seconds. Confirm Rare-only starter eligibility, one falling star, then normal reveal; result breakdown explicitly labels the special pool.
2. Attempt another daylight bind and spoof SkipTutorial values/spam: no duplicate free bind; skip only valid boolean, cooldown enforced. Armed luck potion/sigil counts remain unchanged by the special bind.
3. Home: follow trail or use Home; verify actual granted dragon is placed and income pops. Verify server advances only near owned sanctuary, not another player's plot.
4. With zero gold, use **Free upgrade**: exactly one owned-dragon level gained, gold unchanged; second purchase requires normal gold. Try bulk purchase and Auto-Upgrade separately; neither duplicates the free entitlement.
5. Advance to upcoming night after daylight bind; verify hint and 30-second trail without an extra-cycle delay. For a first bind at night, verify next night instead. Rejoin after completion: final hint must not replay.
6. Skip at every step and rejoin: all grants/hints remain revoked. Load progressed profiles (rebirth > 0, two dragons, previous bind): no special bind/free level.
7. Verify Quests once after reveal, Rebirth only at 25% cost, Spire only at level 10. Confirm no UI/name spoiler during star or queued reveals.
8. Reduced Motion, Quick Binds, Low Effects, missing/unstreamed altar/plot, respawn, narrow portrait and landscape: no console error, movement remains free, touch actions do not overlap or clip. Verify unused cloned UI/world objects are destroyed.
9. Save/rejoin with API Services permitted in the isolated test experience: flags/progress persist. If APIs unavailable, report mock-only persistence limitation.

## Owner testing and presentation follow-up (2026-10-03)

The owner initially observed a fresh step-1 profile and up to ten generated guide parts, but no visible ground stars. Home arrival advanced the hint; Sparkscale advanced from level 1 to 2, the free entitlement became used, and the tutorial reached step 5. Concurrent income means the supplied before/after balances alone do not prove the free level's exact cost.

The visibility fix replaces low, top-facing image decals with camera-facing, outlined gold star glyphs: three studs above the raycast surface, always on top, with a 90-stud visibility limit and the existing ten-star cap. No image upload/preload is required. These are local directional guide stars, not pathfinding; they may show through nearby foliage/walls and do not promise a walkable route. World geometry and terrain are untouched.

The hint now uses the existing themed world-panel kit with gradient, gold border, ornaments, a step-specific title, five-segment progress, and scalable text/action labels. It is static for Reduced Motion/Low Effects; no new flashes, camera effects or repeating animation. The final guide lasts 30 seconds instead of eight. Only presentation/config changed; saved state and server reward rules did not.

Portable geometry checks cover six usable widths (240–800 pixels), positive progress/action sizes, nonoverlapping action margins, 44-pixel action height and separated content rows. These checks do not certify rendering.

After syncing the fix, the owner confirmed visible trails, the improved hint, and no tutorial return after skipping or completing and rejoining. The owner subsequently reported completing all remaining guided tests, including mobile layout, Reduced Motion and the once-only free upgrade, and authorized pushing the follow-up. These are owner-operated Hakai Test results, not agent-operated Studio verification. No detailed output was supplied for the final tests; exact zero-cost accounting, malformed-request/bulk/Auto-Upgrade edge cases and missing/streamed assets are not independently certified by that general confirmation.
