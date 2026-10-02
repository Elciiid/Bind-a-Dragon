# First-time onboarding — implementation contract

One unobtrusive, dismissible line guides movement; no modal, movement lock or compulsory purchase. Server progress survives rejoining. Existing players with a rebirth or more than one dragon, and players who skip, receive no retroactive special bind/free level. The existing free Common starter remains.

| Saved step | Trigger / line | Presentation |
| --- | --- | --- |
| 1 | Fresh spawn: “Bind your first dragon!” | A short, client-only ground star trail toward the Valley altar; the bind prompt is locally available by day for an eligible first-time player. |
| 2 | First successful bind: “Head Home to meet your dragon!” | A falling star precedes the unchanged reveal. Trail points to the owned sanctuary. Home is described rather than directly highlighted: HudLayout has no Home/travel-button getter, and editing it is forbidden. |
| 3 | Server detects sanctuary arrival: “Your dragons earn gold! Your first upgrade is free.” | Inventory icon pointer and a small **Free upgrade** button using the existing validated LevelUpDragon remote. Existing roost gold pops remain; no duplicate currency reward. |
| 4 | Server confirms one level purchase: “Watch the sky: another dragon awaits tonight!” | First manual level on an owned dragon is free once; subsequent levels use normal prices. Inventory remains unmodified. No supported upgrade-button getter exists, so the pointer targets the inventory icon only. |
| 5 | A subsequent night starts: “Night has fallen: you can bind a new dragon!” | Trail returns to altar briefly, then tutorial completes. |

One-time relevance hints: Quests after the tutorial bind/reveal; Rebirth when current gold reaches 25% of the next cost; Spire after any owned dragon reaches level 10. These are separate saved acknowledgments; all are disabled by Skip.

## Server rules and honest odds

- Falling Star is available once at the **StarterMeadow** altar, including daytime. Existing proximity, living-character and area validation remain. No client species/mutation/reward choice.
- Filter the current eligible starter pool to Rare-or-better **before** normalization, then make one server roll at x1. StarterMeadow currently has only Common/Rare, so this does not unlock element-area Epics/Mythics.
- Retain mutation shares. BindResult denominators are the **conditional tutorial pool** odds, explicitly labeled “First-bind pool”; they are not represented as ordinary altar odds. Do not spend an armed luck potion or Echo Sigil for this free opportunity. A nighttime first bind consumes that night's natural bind; a daytime bind does not consume the upcoming night.
- SkipTutorial remote accepts only a true boolean, is rate-limited, and revokes both unspent tutorial entitlements. Saved step/flags are server-owned; no advance-step remote.
- The free level is applied only through the normal validated manual LevelUpDragon path, never automatic upgrades. It grants exactly one level; bulk requests pay normally for additional levels.
- InventoryController disables upgrades below the normal quoted cost and is protected. Its normal paid quote remains unchanged; the onboarding Free upgrade button is the usable zero-gold fallback, preferring the bound Rare. An exact pointer on its internal Upgrade button would require a supported getter or a future approved InventoryController change.
- ProfileStore already calls Reconcile; append fields at the end of template/type without version change. No migration or data reset.

## Accessibility / cleanup

The trail is a bounded handful of noncolliding local stars, raycast onto nearby ground, refreshed slowly. It does not modify world assets. Low Effects disables glow animation; Reduced Motion substitutes a brief static star rather than a falling animation. RevealGate protects the falling star from name spoilers and restores the normal reveal flow. Missing altar/plot/UI targets fall back to the hint; leaving/skipping destroys local trail/pointer.

## Acceptance checks

Fresh profile: daylight bind succeeds once, result is eligible Rare, conditional pool sums to one, reveal follows star, home arrival advances, manual first level spends no gold, second does, subsequent night prompts. Skip at each step prevents further entitlements. Existing progressed profile skips without grant. Rejoin preserves flags/progress. Spoofed/remote spam cannot pick outcomes, advance progress or duplicate free levels. Reduced Motion/Low Effects and mobile Skip remain usable. Studio tests require isolated profiles in Hakai Test; source checks are not gameplay evidence.
