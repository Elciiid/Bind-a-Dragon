# Mobile UI, tutorial and binding reveal handoff

Date: 2026-10-04. Branch: `codex/mobile-ui-tutorial-reveal`.

Code implementation and portable checks are complete. **Roblox rendering, input and playtests remain pending.**
The owner explicitly requested: “I'll do the testing just focus on the code.” No Studio syncing, place edits,
playtests, asset uploads, PR, merge or publication were performed for this UI pass. On 2026-10-04 the owner authorized
committing and pushing the feature branch only; Nas will handle review and merge.

## Repository and scope

- Feature checkout: `C:\Users\Kyle\AppData\Local\Temp\bind-dragon-mobile-ui-tutorial-reveal`.
- Base: merged main `3c93596`, including the new Spire difficulties, Haste, Infinite weekly board, merchant dialogue,
  favorite/auto-sell features, companions and hotbar drag/drop.
- With the owner's explicit “Include both” approval, the previous leaderboard/audio/onboarding feature changes
  (`5342dfb`, `d42360b`, `978ea0b`, `cdaa048`) were applied without committing. The BindingService import conflict
  retained both SellService and OnboardingService/OnboardingConfig. No merge/cherry-pick operation remains pending.
- The approved prior feature changes and new UI work are intentionally included together in the feature-branch
  commit. No unrelated remodel or Studio assets belong in this source-code handoff.
- Pre-push remote inspection found main at `a6c9001`, newer than this branch's `3c93596` base. Main was not merged
  or rebased into this branch during the push handoff; Nas should review and resolve any merge conflicts.
- The original unborn-master remodel workspace and old feature checkout remain untouched. Main is not checked out
  or edited in this feature worktree.
- This pass changes presentation only. Level/rebirth costs, income, mutation multipliers, normal binding probabilities,
  purchases and Spire rewards/progression stay server-authoritative and unchanged. The previously approved onboarding
  server work is included, not newly invented by this UI pass. The prior economy simulation was not retuned or rerun
  for this presentation task.
- `default.project.json` remains unchanged, with `$ignoreUnknownInstances` on the existing mapped containers.
  Studio-only terrain, models, GLBs, art and backups are not replaced by code builds.

## Screenshot audit and actual causes

The owner's twelve landscape-phone screenshots are the baseline evidence, not post-change runtime evidence.

| Evidence | Problems found in the source | Code response |
| --- | --- | --- |
| Inventory Dragons (7/8), Potions (6) | Whole-card phone scaling; fixed grid widths; header consuming the short page; dense overlapping controls; tiny descriptions | Unscaled reflowing cards, scrollable headers when space is short, measured wrapping text, independent physical controls |
| Items (5), Collection (4) | Tiny fixed description rows; fixed five-species element grid; content cut off at the bottom | Measured rows and stacked quantities; responsive species cards grouped by element; explicit scrollbars |
| Rebirth (3) | Fixed milestone area and bottom warning compete with buttons; weak unavailable/confirmation hierarchy | Scrolling cost/reward/milestone body with fixed actions and a separate reset confirmation |
| Merchant (2) | Oversized similar actions and inaccessible bottom exit | Readable numbered scrolling dialogue/shop choices, live wallet/prices, distinct purchases/selling, always-reachable Goodbye |
| Shrine (1), Forge (12) | Two columns squeezed by phone scaling; outcome probabilities reduced to tiny labels | Stack below 720px content width, selected-state summary, physical dragon rows and readable single-column odds |
| Spire (9/11), HUD/hotbar (10) | Climb and Auto-Repeat overlap; large dead space; undersized icons/slots and unsafe edge placement | Unscaled compact Spire with a scrolling body and separate controls; usable-area HUD bounds and paginated 44px hotbar |
| Existing tutorial/reveal source | Guidance relies heavily on trails; hidden/inaccessible upgrade target; possible underlying result spoilers; camera/effect cleanup burden | Reusable target-aware tutorial, genuine free-upgrade UI, opaque serialized reveal gate, isolated viewport ceremony and complete result card |

The screenshots predate some newer main-branch features. They were used as layout evidence, not permission to remove
the new merchant pages, four Spire difficulties, Haste, Infinite rankings, auto-selling, favorites or companion controls.

## Design and implementation

### Shared presentation and safe bounds

- Navy/indigo glass replaces uniformly bright violet surfaces. Rarity, jade, gold and rose accents communicate identity
  and action type without recoloring every surface. Existing artwork/icons remain in use.
- `UITheme.MobileUI`: body 16px, supporting text 14px, titles 20px, touch actions at least 44px, 10px gaps and 12px padding.
  Phone card and Spire scale are 1. Text wraps and content scrolls rather than shrinking the panel.
- `UIGeometry` holds pure popup, grid, hotbar, tutorial and clipping math used by portable tests and runtime layout.
- HudLayout measures a CoreUISafeInsets probe, responds to viewport/inset changes and converts camera/mouse viewport
  coordinates once. No extra `GetGuiInset()` is added to GUI-relative AbsolutePosition/InputObject coordinates.
  This follows [Roblox GuiService documentation](https://create.roblox.com/docs/reference/engine/classes/GuiService)
  and [ScreenInsets](https://create.roblox.com/docs/reference/engine/enums/ScreenInsets).
- Modal centering includes the visible title-banner overhang and respects each requested maximum size. The ornamental
  top star is omitted only in the short phone banner. Close controls remain physical size.
- Windows cancel superseded tweens, protect open/close races, restore visible gamepad selection and select Close for
  empty/informational windows. Back/Skip does not also close the window behind a bind/result overlay.
- Bounded scrolling details flip/clamp near screen edges, refresh changing stats, support explicit touch Details and
  gamepad selection, and disappear when the owner is hidden, destroyed or scrolled out of view.
- Toasts wrap at physical font sizes; overlong messages scroll. Relevant notifications wait behind reveals/results.
  Prompts and HUD effects respect Low Effects. Temporary highlights, tweens and connections have cleanup paths.

### Inventory

- Horizontally scrollable 44px tabs with meaningful icons, readable names and badges.
- Dragons use full-size reflowing cards: model/name, level, rarity/element, income, power, favorite, roost state and
  independent Upgrade/Details/hotbar controls. Local sorting supports Income, Power and Level; it does not change data.
- Long names expand the card rather than forcing smaller body text. Short pages scroll their header alongside cards.
- The free tutorial level is labeled and enabled even at zero Gold while the server-synced entitlement is unused.
  A gesture that begins as the free upgrade sends a normal single-level request and never becomes a paid hold-repeat.
- Potions distinguish Use, Arm, Disarm, Armed, Active, zero count and full inventory states. Effects/descriptions wrap.
- Items use measured descriptions and aligned/stacked quantities. Echo Sigil capacity comes from retained milestone
  perks instead of a hard-coded zero cap.
- Collection reflows by element instead of forcing five tiny columns. Discovered species show their identity and
  appropriate odds/details; undiscovered names and odds remain concealed. Progress, income bonus and rewards remain visible.

### Stations, rebirth and Spire

- Merchant keeps the imported GLB, existing prompt, dialogue camera, numbered keyboard choices, purchases, selling,
  favorites and auto-sell. The sheet has high contrast 56px choices, a scrolling list, wallet/price information and an
  always-visible 88×44 Goodbye action. Existing selling confirmations remain. Asynchronous close callbacks do not
  steal focus from another modal. No client-side purchase or proximity authority was added.
- Rebirth displays a cost/progress card, reward chips, retained/reset wording and milestone track in a scrolling body.
  Primary actions stay visible, and the second confirmation distinguishes Back from Confirm rebirth.
- Rune Shrine/Dragonstone Forge stack below 720px, show the selected dragon's current trait/grade, resource counts and
  40px outcome rows. Roll actions remain at least 44px and reflect unavailable resources.
- Spire keeps Easy/Medium/Hard/Infinite and the current server timing/reward behavior. Pre-climb, fighting, won/lost,
  minimized and weekly-board states reflow without scale-down. Difficulty choices use two/four columns; power,
  progress and receipts sit in scrolling content; Climb/Auto-Repeat/Stop/Hide have separate physical targets.
- At short landscape heights, record/progress move beside the floor badge to leave useful portrait space. The
  minimized badge sits above the hotbar. Infinite rankings open their own scrolling window, not a squeezed side panel.
- Owner-requested HUD follow-up (2026-10-04): the phone menu is a single vertical column, centered along the left edge.
  Its position is lifted only when necessary to stay clear of the bottom-left Gold/Stardust stack. Short-screen overflow
  scrolls instead of shrinking the 44px targets. Desktop side icons are also vertically centered.
- Navigation is centered on the whole usable display, with 16px inter-button gaps and a small 6px top margin,
  aligning the phone row with Roblox's chat/microphone controls. Settings now uses the top-bar-safe host with a
  local 6px gap after those controls, fixing the misplaced gear inside the microphone.
  It uses TopbarSafeInsets when the centered row fits beside Roblox/settings controls; otherwise it remains centered
  at the CoreUISafeInsets top edge. Unlocking the fourth Altars button reruns this layout. Tutorial outlines correctly
  recognize Home above the core-safe origin, using device-safe bounds for top-bar targets.
- Hotbar pages adapt the number of visible slots instead of shrinking them below 44px, retaining all ten slots,
  drag/drop and keyboard bindings. Their phone placement reserves space for bottom-left money and the right jump area;
  narrow layouts lift the bar above the currency. Long sky captions wrap/scroll and yield to the tutorial.
  Timer placement and navigation destinations remain unchanged; no older gameplay/economy plan was applied.

### Tutorial

- `UI/TutorialCard` is reusable presentation: icon, short title, step counter, progress strip, wrapped/scrollable
  instruction, contextual touch/keyboard/gamepad wording, primary action and Skip.
- HudLayout exposes supported target registration for Home, Inventory and eligible Upgrade controls. Outlines use
  real visible/clipped bounds, not descendant-name guesses or positions of scrolled-off cards.
- A local world Highlight and bounded edge/on-screen arrow guide toward the altar; a star trail remains secondary.
  Missing/streamed targets show a loading instruction and retry instead of trapping the player.
- The card avoids covering the world target, reserves travel/hotbar space, uses a compact short-screen layout, and
  pauses/hides behind important modals, bind ceremonies and result cards. The appropriate Inventory Upgrade can
  remain outlined while the card itself yields. Final-night hint time pauses during those interruptions.
- Home and free-level actions use the existing server-validated remotes. Presentation cannot advance a saved step,
  roll a dragon or grant a reward. Skip/completion persistence and once-only rewards remain on OnboardingService.
- Low Effects/Reduced Motion use static target emphasis and only two supporting trail stars instead of ten.

### Binding reveal and result

- A single queue presents confirmed BindResult snapshots. An opaque full-viewport cover masks underlying HUD,
  Inventory/discoveries/nameplates and relevant named announcements until the visible reveal.
- The private viewport stages script-free altar/dragon clones: anticipation → gathered starlight → silhouette →
  clear entrance/pose → complete result card. Only its disposable camera moves. The player's CameraType/CFrame,
  controls and Lighting are never overwritten, eliminating player-camera restoration races.
- Existing folded-wing rig and Stretch pose are reused when supported; unsupported art stays static. Preferred
  stage art falls back Hatchling → Drake → Dragon → Elder → shared placeholder without changing the owned dragon.
- Profiles total Common 1.48s, Rare 1.92s, Epic 2.43s, Legendary 2.97s, Mythic 3.50s, prestige 3.70s. Prestige is selected
  for Primordial or a confirmed pair at least 1 in 5,000. Quick Binds is 0.69s for every rarity; Reduced Motion uses a
  0.25s static transition; Auto-bind/idle results bypass the cinematic. Low Effects bounds stars and decorative motion.
- Skip is a 150×44 button, Space/Escape or controller B. Controller selection can activate Skip/Continue. Death,
  camera replacement, missing models and errors share cleanup and still deliver the confirmed result exactly once.
- The responsive result card shows name, element, broad rarity, mutation, prominent effective “1 in N”, species base
  income and base Spire power. Details retain the roll's base-pool probability, effective probability, luck and variant
  modifiers. They never recompute completed-roll odds from changed luck. Continue/Details remain outside scrolling facts.
- Reading/interacting with details pauses dismissal. Relevant named announcement release is queued once per dragon;
  refusal/timeout releases the cover and pending display callbacks without rolling back a server grant.
- **Starborn is retired in the current repository.** This pass does not reactivate it. The four existing mutations,
  including Primordial prestige, replace that requested legacy test case.

## Files changed by this UI pass

Shared:

- `src/ReplicatedStorage/Shared/Config/{UITheme,Text,Ceremony,Onboarding}.luau`
- `src/ReplicatedStorage/Shared/UIGeometry.luau` (new)

Client controllers:

- `BindingController.luau`, `CeremonyController.luau`, `NotificationController.luau`
- `HudLayout.luau`, `InventoryWindow.luau`, `InventoryController.luau`
- `BoostController.luau`, `ItemsController.luau`, `IndexController.luau`
- `MerchantController.luau`, `RebirthController.luau`, `RollStationController.luau`, `SpireController.luau`
- `OnboardingController.luau`, `PromptController.luau`, `TravelController.luau`, `HotbarController.luau`

Shared client components under `Controllers/UI`:

- `Banner.luau`, `Button.luau`, `Style.luau`, `Window.luau`, `HudIcon.luau`, `TimerRow.luau`
- `DragDrop.luau`, `Tooltip.luau`, `Toast.luau`, `PromptPill.luau`
- `RevealGate.luau`, `RewardPopup.luau`, `TutorialCard.luau` (new)

Verification/documentation:

- `tools/tests/MobileUIChecks.luau`, `RunMobileUIChecks.ps1`, `RevealGateChecks.ps1` (new)
- `tools/sim/OnboardingChecks.ps1` (retired hint-panel geometry assertions replaced with current test routing)
- `CLAUDE.md`, `docs/Onboarding_Implementation.md`, this report

The additional staged leaderboard/audio/onboarding files are the owner-approved prior work; their complete lists and
contracts remain in `docs/Leaderboards_Implementation.md`, `docs/Audio_Manifest.md` and `docs/Onboarding_Implementation.md`.

## Measured automated checks

| Check | Result | Limit |
| --- | --- | --- |
| Luau compile, `src` plus `tools/tests` | 150 files, zero failures | Syntax/bytecode compilation, not full Roblox type/runtime analysis |
| `RunMobileUIChecks.ps1` | 10 popup envelopes; 30 reflow grids; 20 complete hotbar paginations (symmetric and currency-aware); 10 centered side columns; 20 centered/gapped top rows (3/4 buttons); 30 tutorial envelopes; 6 clipping intersections; 1,264 direct Text/MobileUI reference checks; odds/text/touch/profile contracts pass | Real shared config/math with inert Roblox constructors; no font rasterization, GUI rendering or physical input |
| `RevealGateChecks.ps1` | 10 lifecycle assertions pass against the actual module | Callback release/cancel/once-only behavior, not GUI masking/rendering |
| `OnboardingChecks.ps1` | Eligibility, day/night thresholds, once-only free level, old/skipped saves and five conditional pools pass; 500,000 seeded rolls; Normal share within five-sigma bounds | Actual service/config methods with inert dependencies; no ProfileStore session or client flow |
| `RunLeaderboardsChecks.ps1` | 610 checks pass | Portable contracts, not live OrderedDataStore permissions or world rendering |
| `AudioConfig.test.luau` | 20 area slots, 6 bind cues and 3 bounded dragon cues pass | Manifest/config only; asset permissions, loading and sound quality not tested |
| Rojo 7.6.1 build | Passed, source-only ignored `MobileUIPolishValidation.rbxlx` | No terrain/models copied, no Studio connection, no sync |
| Diff whitespace/conflict markers | Passed | Does not establish visual correctness |

Portable usable rectangles (not full device viewport sizes): 320×520, 452×252, 584×252, 667×292, 733×313,
720×270, 768×952, 1024×700, 1280×680 and 1440×820. Tutorial checks include short, three-line and ten-line
instruction heights. These do not replace the device/input matrix below.
The HUD follow-up additionally checks full-width centering, the small aligned top margin, native/settings clearance with a
safe fallback, side-column currency clearance/overflow, all ten currency-aware hotbar slots and top-bar target geometry.
Owner screenshots demonstrate the previous HUD placement; the latest centering changes still need a fresh owner playtest.

Commands, from the feature checkout (supply your local interpreter path through `-Luau` if different):

```powershell
./tools/tests/RunMobileUIChecks.ps1
./tools/tests/RevealGateChecks.ps1
./tools/sim/OnboardingChecks.ps1
./tools/tests/RunLeaderboardsChecks.ps1
& C:/Users/Kyle/AppData/Local/Temp/luau-cli/luau.exe tools/tests/AudioConfig.test.luau
```

## Owner-operated Hakai Test validation — all pending

### Safe setup

1. Confirm the place is **Hakai Test** (the owner authorized this capitalization), not production. Earlier read-only
   inspection identified that window; it is not evidence of a later playtest or correct Rojo connection.
2. Stop play mode and save a timestamped recoverable local place backup. Preserve all Studio-only assets/backups.
3. In the feature checkout, verify `git branch --show-current` is `codex/mobile-ui-tutorial-reveal` and review status.
   Do not switch the original remodel workspace or discard the staged prior feature work.
4. Run the pinned `C:\Users\Kyle\AppData\Local\Programs\Rojo\7.6.1\rojo.exe` from this feature checkout.
   Connect the Studio plugin to that server/checkout only, inspect the sync diff, and keep unknown instances.
   Do not open the source-only build as a replacement for your full Studio world.
5. Use `PlayerData_Studio` and a unique `ServerStorage.TestProfileKey` for disposable fresh test profiles. Never reset
   or access production profiles. Use separate isolated fixtures for progressed/maximum-content tests.
6. Capture the same emulator preset/camera/panel before and after when available. Baseline Git revisions can be
   inspected in a separate safe checkout; do not reset this feature worktree to capture a baseline.

### Viewport and input matrix

| Device / input | Required checks | Current result |
| --- | --- | --- |
| Screenshot landscape phone, including its left camera cutout; iPhone 13 Pro Max 926×428 as an additional explicit preset | Every panel, notch/topbar margins, readable text and all actions | Not run |
| Smaller landscape phone, e.g. 667×375 | One-column/stacked content, short-screen scroll, reachable final actions | Not run |
| Tablet, e.g. 1024×768 | Card reflow, modal sizing, touch and orientation resize | Not run |
| Desktop, e.g. 1280×720 and 1920×1080 | Resizing, hover bounds, mouse/keyboard and full hotbar | Not run |
| Controller connected on desktop/tablet | Initial selection, tabs, scrollers, details, Skip/Continue/B and selection recovery | Not run |
| Low Effects and Reduced Motion | Static target guidance, bounded particles, no moving viewport for Reduced Motion | Not run |

The game retains its existing LandscapeSensor phone orientation. Portrait math is checked portably, but portrait
runtime support/input has not been certified. Full display sizes above differ from safe usable rectangles in the CLI tests.

### Screen/state checklist

- [ ] HUD with no modal: centered vertical side buttons; bottom-left Gold/Stardust; centered/gapped top navigation
  with a small aligned top margin; Settings beside the microphone; 3/4 navigation buttons; short-screen sidebar scrolling;
  all hotbar pages; cutout/control clearance.
- [ ] Inventory tabs: empty, two dragons, many dragons, long names, large amounts and increased text lengths;
  sorting, favorites, details, single/held upgrade, equip best, roost actions, hotbar drag/drop/page access.
- [ ] Potions: zero/available/active/armed/full states, Use/Arm/Disarm, resource changes and details.
- [ ] Items: all currencies, multiline descriptions, zero/large quantities and retained Echo Sigil cap.
- [ ] Collection: undiscovered/discovered/full element, additional same-tier species, mutation details and rewards.
- [ ] Rebirth: unavailable/ready/final confirmation/cancel/completed; bottom warning and actions never clipped.
- [ ] Merchant: keyboard/touch/gamepad opening; live purchase price/wallet; insufficient funds; single/backpack selling,
  favorites, destructive confirmation/cancel, auto-sell modal transitions, Goodbye/Back and leaving range.
- [ ] Shrine/Forge: no dragons/resources, selected/current trait/grade, all outcome probabilities, sufficient resources,
  rolling/result state, portrait updates and rapid selection.
- [ ] Spire: each difficulty, locked states, Climb, Auto-Repeat ON/OFF, fights, rewards, Stop/loss, minimized/reopen,
  weekly board, leaving range and Haste. Verify existing current-main server progression remains unchanged.
- [ ] Every window: close/reopen quickly, switch to another modal, resize while open, scroll to final row, controller Back.
- [ ] Notifications/prompts: long messages, queue/duplicates, touch hold, stacked rewards and modal/reveal suppression.

### Tutorial and reveal checklist

- [ ] Fresh profile starts once; old/progressed/skipped/completed profiles do not replay tutorial rewards.
- [ ] First bind/daytime opportunity, actual altar pointer, off-screen arrow and streamed-out/missing-target fallback.
- [ ] Home highlights the real Home control and advances from the server-validated action/proximity.
- [ ] Free upgrade with **zero Gold** via tutorial and via Inventory: exactly one level, no paid hold-repeat, then normal quote.
- [ ] Opening another modal hides/moves guidance; return resumes the current step without a second reward.
- [ ] Night transition, final hint, Skip, completion and rejoin persistence; Low Effects trail/outline and all input glyphs.
- [ ] Common/Rare/Epic/Legendary/Mythic and all four mutations, especially Primordial/prestige, with clear model framing.
- [ ] Exact result odds match the server packet; change luck afterward and confirm the completed-roll card stays unchanged.
- [ ] Inventory open and announcements/nameplates during binding: no dragon identity visible before reveal.
- [ ] Skip button/Space/Escape/B, Quick Binds at every tier, Auto-bind and idle bypass.
- [ ] Missing model/non-archivable art/unsupported rig/sound failure still shows a full result and Continue.
- [ ] Respawn, camera replacement, denied bind and response timeout release the cover without duplicating a result/reward.
- [ ] Continue/Details, long facts, scrolling, paused auto-dismiss and controller selection recovery.
- [ ] Low Effects/Reduced Motion, repeated binds and interrupted reveals leave no camera override, controls lock,
  growing temporary-object count or new Output errors.

## Remaining limitations

- No matching before/after playtest captures exist for this pass. The attached screenshots are baseline evidence only.
- All device/input/state checkboxes above are pending owner testing. No claim is made that clipping, overlap, camera
  recovery under Roblox runtime, purchase flows or completion criteria passed in Studio.
- `luau-compile` and mock-based portable checks are not full Roblox type checking. FontFace measurement, engine layout,
  viewport rendering, streaming, audio asset permissions, mobile GPU cost and input routing need runtime verification.
- Several species may only have later-stage art or placeholder icons in the Studio place. Code falls back safely,
  but this does not supply missing dragon models/animations or new uploaded artwork.
- The imported merchant's interaction anchor and assets are preserved and depend on the existing tagged Studio setup.
- Starborn-specific cinematic tests are not applicable to the current game; test Primordial and legacy-save migration
  separately without reintroducing a retired economy variant.
- Commit and push are authorized for `codex/mobile-ui-tutorial-reveal` only. Nas handles merging; do not merge,
  force-push, write to main, create a PR or publish either Roblox experience as part of this handoff.
