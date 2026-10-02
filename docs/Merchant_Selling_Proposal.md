# Star Merchant: selling dragons and items (proposal, 2026-10-03)

Status: **approved 2026-10-03 as proposed (Epic+ stays out of "Select all"; Stardust stays unsellable).** Every number is in `Config/Economy.Selling`; the same shared functions
(`DragonStats.GetSellValue`, `GetSellProtection`, `IsRiskySale`) price a sale on the client (what the dialog shows) and on the
server (what is paid), so they cannot disagree.

## Dragons

Gold = the dragon's **own earning rate** (level, evolution stage, branch, trait, grade, mutation, roost income upgrade, rebirth
bonus, Dragon Index: everything permanent) x **seconds for its rarity** x a small **mutation multiplier**. It scales with
progress automatically, so a sale is always small next to what the dragon earns in a roost.

| Rarity | Seconds of its own income | Wyrm Runes + Dragonstones |
| --- | --- | --- |
| Common | 90 | none |
| Rare | 150 | 1 Rune |
| Epic | 240 | 1 Rune + 1 Stone |
| Legendary | 480 | 3 + 3 |
| Mythic | 900 | 8 + 8 |

| Mutation | Gold multiplier (on top of its own income bonus) | Runes/Stones |
| --- | --- | --- |
| Hoardscale | x1.25 | x2 |
| Warcrest | x1.5 | x2 |
| Aetherwing | x1.5 | x2 |
| Primordial | x2 | x2 |

Example at the very start (level 1, no upgrades, rebirth 0; first rebirth costs 50M): Common about 70k, Rare about 270k,
Epic about 1M, Legendary about 5M, Mythic about 22M, plus the runes/stones above. Level compounds the income (x1.06 per level), so a
level 30 Rare is worth about 5.7x that.

**Protected (cannot be selected, and the server refuses them):** dragons in the roost, on the hotbar, being carried, locked (new
Lock toggle on the Inventory cards) and the rebirth champion. **Extra confirm:** Epic or better and mutated dragons get a second
"Are you sure?" step naming them; the server demands `confirmedRisky` for them. Selling is atomic: if any chosen dragon is
protected or not yours, nothing is sold.

## Items (Sell Items)

Gold = seconds of the player's **current roost income** per item. Potions are priced well under their boost value (a Gilded
Draught is x2 for 5 minutes = 300 s of extra income, sold for 60 s). Runes and Stones are cheap on purpose so Spire drops cannot be
farmed into gold. **Stardust is not sold** (the merchant's own rising price would make it a loop).

| Item | Seconds of roost income each |
| --- | --- |
| Gilded Draught | 60 |
| Hoard Elixir | 120 |
| Starlight Tonic | 90 |
| Moonfire Tonic | 240 |
| Wyrmblood Tonic | 90 |
| Conqueror's Brew | 300 |
| Runebright Tonic | 120 |
| Wyrm Rune | 10 |
| Dragonstone | 10 |

The luck charge you have armed is kept. Gold is clamped at the weekly rebirth cap like every other reward.

## Pacing check (tools/sim)

`CohortSim` got a `SellSurplus` switch: after every bind the simulated player sells each Common or Rare that is not in the roost
and not mutated (the "sell all Commons" habit), for the real gold and runes/stones. 24 paired seeds per profile (same seeds with
and without selling), median days to the launch cap (R30):

| Profile | Without selling | With selling |
| --- | --- | --- |
| Dedicated | 8.03 | 8.02 |
| Casual | 29.05 | 29.04 |
| AFK-light | 32.07 | 32.87 |
| Paying AFK | 15.05 | 15.02 |

The differences are inside the sim's one-day resolution and sampling noise (p10 / p90 move by up to about 2 days in either
direction, e.g. AFK-light p90 41.1 vs 42.7): selling does not move pacing, because a sale is a few minutes of that dragon's income and the surplus dragons it
sells were earning nothing anyway. Not modelled: selling potions or runes/stones. Upper bound: a repeat Spire run gives 10 + 10
runes/stones = 200 s of income, against about 1,200 s earned in the same 20 minutes, so selling every drop would add at most a
few percent to a Dedicated player's Spire time and nothing elsewhere.

## Open choices for you

1. The seconds per rarity and the rune/stone rewards above (the "rare ones give a few" part).
2. Should Epic+ also be bulk-selectable, or only via the row ticks (now: "Select all Commons" only)?
3. Keep Stardust unsellable (recommended)?
