# Hakai gameplay polish — economy validation (2026-10-02)

## Final configuration and reproducibility

Rebirth `LateGrowth = 2.31` (formerly 2.55), with the other rebirth parameters unchanged. Level prices grow 1.08x
per level. From R1 onward, the latest five-level band costs at least 900 seconds of the strongest legal retained
owned roost's unboosted income, snapshotted once per rebirth. At R0, prices grow from the rarity share of R1 cost.

The portable harness loads the real repository economic modules. It uses deterministic Park–Miller RNG with seeds
`7919, 15838, ... 7919000`. The table below is **1,000 independent seeds per profile**, with a 180-day cutoff. Days
are raw elapsed days from first play; no calibration multiplier is used. Minute-resolution decisions and 12-second
Spire stages are simulated. The full run uses 20 minutes within the active-session budget.

Run commands, model details and caveats are in `README.md`. Static numbers are not a Studio or human playtest.

## Revised cohorts

| Profile | Scheduled daily active time | Median R30 days | p10 | p90 | Unfinished/1,000 |
|---|---:|---:|---:|---:|---:|
| Dedicated | 3.5h in two sessions | **7.9611** | 5.9854 | 10.0326 | 0 |
| Casual | 1h | 26.9799 | 19.8139 | 33.0167 | 0 |
| AFK-light (`AfkOnly`) | 12-minute manual check-in | 32.7535 | 28.9611 | 38.8493 | 0 |
| Paying AFK | 12 five-minute check-ins, 12h online idle, Auto-bind + 2x AFK | 16.0000 | 11.9938 | 19.3465 | 0 |

Dedicated sessions vary +/-15% in length and have a 3% missed-day chance, so realized average active time is about
3.40h/day. Casual/AFK-light/paid missed-day chances are 25%/10%/5%. Offline income remains 50% for at most eight hours
per UTC day; paid AFK restores that rate to 100%. The true zero-input, no-Auto-bind player acquires no new dragons;
`AfkOnly` is deliberately a check-in strategy, not a claim of unattended binding.

The **7–9 raw-day median target passes** under this strategy. Dedicated progression is about twice as fast as paid
AFK. The p10 is under six days: lucky players can finish considerably sooner. This is disclosed, not presented as
a guaranteed eight-day minimum. Median Dedicated milestones are R7 by day 1, R15 by day 3, R27 by day 7, and R30 by
day 14. Normal play deliberately leaves Auto-Upgrade OFF; the player makes the manual spending decisions below.

| Profile | Median runes earned | Median stones earned | Median level gold spent | Median Spire record at day 7 |
|---|---:|---:|---:|---:|
| Dedicated | 127 | 127 | 8.249e21 | 100 |
| Casual | 123 | 123 | 3.825e21 | 40 |
| AFK-light | 45 | 45 | 6.202e20 | 0 |
| Paying AFK | 65 | 65 | 4.895e21 | 25 |

Earned item totals include actual quest completions, streak and Spire currency, rather than guessed drop counts.
Species Index rewards are also applied; the counters above focus quest/Spire/streak grants and omit Index item grants.
Spire victory config separately proves 30 of each on the first full clear and 10 of each on repeat full clears,
before Conqueror boosts. First stage-five victory grants one of each; the first stage-ten boss grants two of each.

## Upgrade grind and strategy

For R10–R30, the median and p90 newest five-level-band quote are **15.00 minutes of the snapshotted unboosted roost
income** in every profile. A separate 1,000-seed Dedicated measurement allows continuous reinvestment into the
strongest dragon and recomputes the hypothetical legal-roost income after every purchased level: **12.1185 minutes
median**, **9.0204 p10**, **13.6275 p90**. This meets the typical **roost-income-only** 10–20-minute target; it does
not establish a minimum for every unboosted activity. A minority of catch-up cases is faster. This is an unboosted,
zero-starting-gold calculation for the new band, excluding finite first-clear Spire gold; banked earnings or
starting below the prior level cap change the player's actual experience. The quote is 7.5 minutes at x2 and 3 minutes at x5 if the player has
enough remaining potion duration; potion availability/timers are included in the progression cohorts. Rebirth resets
gold but retains dragon levels, traits, grades, mutation, evolution, Index and roost upgrades. These feed the anchor.

**First-clear Spire sensitivity:** a newly defeated stage grants 30 seconds of current roost income, while the fight
takes 12 seconds. With normal unboosted income accruing throughout, uninterrupted new-stage clears produce an
effective `1 + 30/12 = 3.5x` gold rate. The 15-minute fixed-income band quote can therefore be funded in about
**4.29 minutes** while enough uncleared stages remain; the 12.1185-minute reinvesting median would be approximately
**3.46 minutes** under a continuously available 3.5x rate. These are rate-sensitivity estimates, not independent
player-cohort results. The bonus is finite: 100 first clears grant 3,000 income-seconds (50 minutes), distributed
over a 20-minute successful run. SpireRecord survives rebirth; repeat runs do not pay first-clear gold. Rebirthing
midway through an initial climb retains eligibility for its remaining new stages and can thus shorten that band.
Conqueror's Brew and gold potions can shorten it further through their respective reward/income sources.

The full progression cohorts above already include first-clear Spire gold at its actual simulated stage completion
time, including newly earned rebirth income thereafter. Thus the 7.9611-day Dedicated median already accounts for
this source; no additional pacing retune is justified by this sensitivity alone. The 10–20-minute band result must
be presented as ordinary roost-only earning, not as an all-activities lower bound. Keeping the finite bonus follows
the approved requirement to preserve existing first-clear gold.

The player binds each available natural night outside their reserved Spire budget, uses earned sigils, prefers the
favored unlocked altar, buys affordable Stardust bundles for offerings, and arms earned luck charges. Sigils reuse
the same night's offering multiplier. The model replaces a roost dragon only with 1.5x better equal-level quality,
uses runes/stones until the best roost dragon has a useful trait/grade, and buys the best payback level/stage/cap/roost
purchase when payback is within 60% of time to the next rebirth. Rebirth happens immediately when affordable.

## Parameter sweep and controlled baseline

The deterministic pilot used the same seeded profiles: LateGrowth 2.55 produced roughly 12 raw Dedicated days,
2.40 about 9.39 days, 2.35 about 8.94 days after reserving Spire time, and 2.31 about 8.07 days (100 seeds).
The final corrected sigil model gives the 7.9611-day 1,000-seed median above.

Baseline controls use old flat prices and LateGrowth 2.55 with the **same repaired timeline/new Spire rewards**.
They isolate price/curve changes; they are not a claim to replay the old fast-skipping game. Controls use the same
1,000 seed IDs and a 180-day cutoff; percentiles below describe completed players and explicitly disclose censoring.

| Controlled old flat costs + 2.55 growth | Median completed days | p10 | p90 | Unfinished/1,000 |
|---|---:|---:|---:|---:|
| Dedicated | 16.9965 | 10.0618 | 27.9597 | 23 |
| Casual | 41.8563 | 27.9722 | 66.0813 | 31 |
| AFK-light | 61.9778 | 40.1104 | 104.9833 | 12 |
| Paying AFK | 23.0160 | 16.1049 | 33.0285 | 95 |

## Checks and limitations

- Passed 11,000 strictly increasing per-level prices across 20 species and R0/R1/R10/R20/R30.
- Passed 100 bulk quotes equal to the exact individual purchase sums, and latest-band income floors.
- Passed anchor invariance against roost unplacement, temporary potions and within-rebirth upgrades; a new rebirth
  refreshes it from retained stats. Old progressed saves initialize their missing anchor once on server load.
- Passed first/repeat Spire currency totals from the live configuration. Changed modules compile with Luau CLI.
- Group luck, event nights, Premium potion duration, travel time and human decision delays are not modeled.
  Offline gaps use current-income closed-form payouts; idle Auto-bind arrivals occur between active check-ins.
  Potion minutes represent a player using their inventory during active sessions. The roster model retains a
  12-dragon bench for simulation performance, rather than every low-quality collectible owned in the actual save.
- Roblox RNG is distinct from harness RNG. Studio tests are a separate result owned by the playtest report; these
  cohorts do not certify DataStore persistence, actual mobile input or live server UI flows.
