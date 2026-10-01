# Hakai gameplay polish validation — 2026-10-02

Branch: `codex/hakai-gameplay-polish`. No commit, push, merge or publication is part of this validation.

This is a working evidence record. Source inspection and compilation are not substitutes for a completed player-flow playtest. The final economy results belong in the simulation report; no pacing target is marked passed here without those measurements.

## Automated and source checks

| Check | Evidence / status |
| --- | --- |
| Client syntax | All 19 changed/new client Luau modules compiled successfully with `luau-compile` during the independent layout audit. |
| Patch whitespace | `git diff --check` passed. |
| Safe-area architecture | Source: shared HUD root uses `CoreUISafeInsets`; portrait/landscape enabled; viewport and safe-root geometry changes trigger relayout. Tooltips and reward popups use the same measured usable rectangle. |
| Modal geometry | Source: requested frame width/height are bounded by available space and maximum size; title ornament overhang is included in centering; oversized title banners fit safe width. |
| Tooltip behavior | Source: wrapped measured content, bounded height with scrolling, edge flip/clamp, periodic live-data refresh, explicit independent touch Details target. |
| Upgrade presentation | Source: inventory and roost prompts quote the shared cost function with the persisted leveling income anchor. Runtime/server agreement still requires progressed-data tests. |
| Reward odds details | Source: wrapped measured two-column rows in a scrolling container. |
| Reduced-motion reward cards | Source: no reward-card pop scale, sparkle burst, ray rotation, or shrinking exit when Reduced Motion is enabled. |
| Reveal privacy | Source: pre-result cover masks existing/new ScreenGuis; bind results are queued; named announcement metadata is delayed through the reveal gate. Timing still requires live tests. |

## Hakai Test evidence so far

The following observations were reported by the primary implementation agent from the current **Hakai Test** Studio session:

- A fresh play session loaded, with the day/night timer at the top and navigation at the bottom.
- Dragonspire began at stage 1 with Auto-Repeat OFF and the configured 12-second fight duration. A full stage-100 completion was still pending when this draft was written.
- Studio API Services were unavailable; ProfileStore used mock data. Saving, reconnect persistence, and persistent migration correctness have **not** been validated by that session.
- No recognizable tagged Star Merchant model was found in the open test place. The exact imported merchant must be identified before its interaction can be verified. No unrelated imported model should be guessed or modified.
- The original sigil source asset was generated. Its Roblox image ID and in-game uploaded-image rendering remain pending.

## Required remaining player-flow checks

| Scenario | Current status / measurable requirement |
| --- | --- |
| Full Dragonspire, OFF | Pending: stages 1–100 observed in order; one reward grant per clear; stop at completion; another run starts manually at 1. |
| Full Dragonspire, ON | Pending: toggle replicated authoritatively; complete 100; next run starts at 1; no concurrent loop or duplicate rewards. |
| Dragonspire cancellation | Pending: Stop, defeat, death, leaving range and repeated Start requests terminate/reject correctly. |
| Rebirth progression | Pending: fresh plus representative progressed player; gold reset; retained bonuses/items accounted for; prices ascend per level; bulk/auto-upgrade costs match the server. |
| Merchant | Blocked by model identification: keyboard E, gamepad, touch prompt; menu price refresh; purchase validation; insufficient funds; exit/range close. |
| Reveals | Pending: ordinary, Legendary/Mythic and mutated results; skip; Quick Binds; Reduced Motion; missing model fallback; announcement/inventory/nameplate spoiler checks. |
| Desktop layout | Initial timer/navigation placement observed; all windows, details, live resizing and long text still need verification. |
| Mobile layout | Pending: portrait/landscape notch presets; left/right bounds; movement/jump controls; centered windows; wrapped details; touch-target usability. |
| Save compatibility | Blocked by unavailable Studio API Services: existing saves, anchor initialization, settings persistence, migration and rejoin. Use only isolated `PlayerData_Studio` profiles when enabled. |
| Economy target | Pending measured cohort report: dedicated 3.5 active hours/day, two sessions, up to eight hours/day offline at 50%; raw median R30 in 7–9 days; p10/p90 and other profiles disclosed. |

## Layout review follow-up

The independent source audit identified an inventory portrait risk and it was corrected before handoff: Equip Best now occupies its own row; dragon/roost counts and item counters occupy separate rows beneath it. Phone dragon cards are taller and both Upgrade and roost controls now have a minimum 44px physical height. Details remains a 64×44 physical target. The same responsive sizing applies when a card is first created and after rotation. Compilation passed; actual portrait touch/overlap verification is still pending.

Record final simulator outputs, Rojo build results, screenshots, completed stage sequences and any additional blockers here before handoff. Do not convert a pending row into a pass based only on compilation or source inspection.
