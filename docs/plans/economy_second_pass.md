# Economy: command points and army power

The first pass shipped the territory-type economy: towns pay their holder (BLUFOR CP, OPFOR AP),
zones trickle Army Power to both sides, a zone's first capture pays a one-time liberation bonus,
advanced supports carry a dual CP+AP price, and vehicles are priced CP-only on a metadata scale.
The shipped machinery is documented in [`info/economy.md`](../info/gameplay/economy.md) — which still describes
the pre-reroute model in several places and wants a correcting pass of its own.

This document is the economy's design of record and the backlog the first pass deliberately left.
Every deferred item below was cut to keep the pass shippable, not because it is optional; several
are load-bearing, and the [build order](#build-order) at the end is roughly the sequence the next
pass should take. The tuning surface, the balance items to watch and the open questions are collected
at the end so the next pass tunes from one list rather than hunting the tree.

Two currencies, one job each, and the split is what makes either legible.

- **Command Points are throughput.** What the player can put and keep in the field right now.
  Held by the player alone — there is no OPFOR CP anywhere in the mission. Abundant by design:
  CP must never be the reason a decision is impossible, only the reason every decision is not
  possible at once.
- **Army Power is authority.** What either side may field at all. Held by both sides, scarce on
  both, and the only place in the economy where scarcity lives.

Two tests follow, and every price below answers to one of them. If a CP price blocks the player
for more than a few minutes of play, it is wrong. If one action pays for an AP price outright,
the faucet is wrong.

## Where each currency comes from

Territory type decides currency — each kind of ground pays one pool. The two kinds of ground the
mission already generates carry the right scarcity for it:

- **Zones** — few, heavily garrisoned, hard-won — are the **Army Power** source. Six by default,
  against a map of roughly 15-22 towns on Altis (estimated from the selection rules, not a fixed
  count), so the AP faucet is naturally the narrower of the two.
- **Towns** — many, soft, reputation-banded — are the **Command Points** source. Numerous, so CP
  scales with the broad footprint and stays abundant.

A zone pays over its life in two currencies, split event-versus-hold. **Holding** it pays a per-tick
AP *trickle* (the strategic dividend). **Taking** it pays on the event: the first capture ever pays
BLUFOR a one-time CP + AP liberation bonus, tracked in the save so it never pays twice — a recapture
pays nothing, the zone's reward having been earned once; and OPFOR is paid AP every time it loses
the zone, so a fast advance funds the counter-attack. A town pays its holder a per-tick income while its reputation
sits in that side's band.

**The routing is per side.** For BLUFOR the split is clean — towns pay CP, zones pay AP. OPFOR
spends only AP, so everything it holds pays AP: its zones trickle AP the way the player's do, and
its banded towns pay AP at their own per-town rate. A town therefore pays the player command budget
and the enemy war materiel; a zone pays both sides AP for holding it. The one asymmetry is on the
ladder, not the faucet — OPFOR's hour-zero zones fill its wallet but not its earned tier (see
[§Where OPFOR army power comes from](#where-opfor-army-power-comes-from)).

## Passive income is throttled by campaign size

`zones_number` runs 1 to 40, set by the host before play. A per-zone rate that did not answer to it
would let a large campaign pay linearly more on every faucet — a 24-zone war handing four times the
passive income of a six-zone one, and every tier threshold in the mission meaning something
different depending on a number chosen at setup. This was the sharpest objection to a territory AP
faucet at all, and it is the one the throttle exists to close.

A single factor, computed once after generation from the **actual** zone count — not the requested
number, which generation can fall short of — scales every passive faucet:

```
REF_ZONES = 6                                       // the small-campaign baseline
k         = 0.5                                      // throttle strength
DUWS_econ_throttle = (REF_ZONES / (zonesCreated max REF_ZONES)) ^ k
```

At or below `REF_ZONES` the factor is 1 and nothing throttles, so a default or small campaign keeps
the rates below untouched. Above it, total passive income at full control grows as
`sqrt(zonesCreated)` — four times the zones pay twice the income, not four. More ground still pays
more; it stops paying *proportionally* more.

**Only passive hold income is throttled.** Event income is left alone: mission rewards are paced by
their own cooldown and do not scale with zone count, and the first-capture bonus rewards an action
rather than a holding. The factor multiplies the BLUFOR zone AP trickle and town CP income, and the
OPFOR zone AP trickle and town AP income — every passive faucet on both sides, so a large campaign
does not hand the enemy a proportionally larger war chest either.

| zones | throttle | zone AP/hr, full (BLUFOR) | town CP/hr, full (BLUFOR) |
|---|---|---|---|
| 6 | 1.00 | 60 | 108 |
| 12 | 0.71 | 85 | 153 |
| 18 | 0.58 | 104 | 187 |
| 24 | 0.50 | 120 | 216 |

Both constants are the tuning surface: `k` toward 1 flattens total income across campaign sizes,
toward 0 restores the linear payout; `REF_ZONES` sets the size below which nothing throttles and
should track whatever "small campaign" means for balance. Figures assume two 30-minute ticks an
hour.

## The integer contract

**No fractional value reaches a pool writer.** Rounding happens once, where a figure is derived,
and the derived integer is what gets stored, passed and paid. Writers assert rather than repair,
because a writer that repairs makes the same delta worth different amounts depending on what the
pool already holds.

Most of the tree already holds this, which is why the constraint is cheap:

| Figure | Derived at | Integer by |
|---|---|---|
| Zone worth | `server/init_zones/fnc_locatorzones_random.sqf:49` | `round (radius / 10)` |
| Retake / consolation swing | `fnc_opfor_cap.sqf`, and the BLUFOR-capture consolation | `round (_points * zone_ap_swing)` |
| First-capture bonus | `fnc_captured.sqf`, once ever per zone | authored CP + AP, whole |
| Escalation-scaled price | `fnc_escalation_cost` | `ceil` |
| Mission CP + AP reward | `server/missions/fnc_mission_reward.sqf:14` | reward multiplier 1-5 scales both, whole |
| Town income | `civ_town_ap` | CP 1-5 by town size (BLUFOR); AP its own rate (OPFOR) |
| Zone AP trickle | econ tick, per held zone | `5` per zone, whole |
| Campaign-size throttle | `DUWS_econ_throttle`, set at generation | fraction; each faucet rounds after scaling |

**The one gap is `fnc_ap_adjust`.** `fnc_cp_adjust` rounds the running total and logs a `WARN` on
a fractional delta; `fnc_ap_adjust` adds and floors at 0 with no rounding anywhere
(`server/misc/fnc_economy_init.sqf`). Nothing feeds it a fraction today, so it is latent — and it
stops being latent the moment AP becomes a priced currency, because every ladder gate reads
`> N`. A pool resting at 39.97 fails a `>40` gate while a rounded readout prints 40, and the
player has no way to tell why. `fnc_ap_adjust` takes the CP writer's invariant verbatim.

The campaign-size throttle is a fraction at or below 1, so every passive faucet it scales rounds
at its own application site, never at the writer.

Reputation is the deliberate exception and is not a pool in this sense: it is the only figure
taking fractional deltas, and `fnc_town_rep_adjust` owns its rounding for the reason recorded in
[`info/economy.md`](../info/gameplay/economy.md#authority-one-server-side-writer-per-pool).

## Command Points

### The pool is shared, so abundance is a requirement

`commandpointsblu1` is one pool spent by every slot in `Squad_Leaders`
(`server/server_var_init.sqf:225-258`), which as shipped is every playable slot. Four squad leads
drawing on one wallet is why CP has to sit in relative abundance: a scarce shared pool means the
first player to open a request menu spends the team's afternoon.

That is a design constraint, not a nicety, and it is why the answer to "make CP matter" is never
"make CP scarce".

### The drain moves to use, not to price

The CP faucet moves from zones to towns
([§Where each currency comes from](#where-each-currency-comes-from)), but its shape is unchanged:
passive hold pays a recurring income no one-time unlock can absorb. Banded towns pay their worth
(1-5 CP by town size) every 30 minutes, throttled by campaign size, and each zone's first capture
pays a one-time CP lump on top — against eight permanent unlocks at 5-25 CP, roughly 200 CP across
a campaign. A one-time unlock
cost cannot absorb a recurring faucet at any price, and raising the shopping list only postpones
the same problem.

**So the unlock buys the right to call a support, and each call costs CP.**

| Layer | Pays | When | Starting values |
|---|---|---|---|
| Unlock — consumes one of eight slots | CP, plus AP if advanced | once | 5-10 CP regular; 15-25 CP + 20-40 AP advanced |
| Each call | CP | every use | 3-8 CP regular; 10-25 CP advanced |

Several comm-menu supports already pass `_cost = 0` at use time because the charge happened at
unlock (`client/dialog/fnc_MHQ_select.sqf`, both taxis in `supports/taxi/`), so this is a value
change at sites that already route through the spend handshake rather than new plumbing. It gives
CP a recurring, activity-scaled drain that tracks how much the player is fighting rather than how
much they own, and it needs no new state.

Two things fall out. The eight-slot cap starts reading correctly — the slot is the right to call
it, the CP is the call. And escalation gets something to bite: `escalation_multiplier` scales CP
prices, which is nearly inert against one-time unlocks in an abundant pool, but against a
per-use cost a late-campaign CAS run visibly costs double.

**Upkeep was the alternative and is rejected.** A recurring cost per squad, vehicle or holding
needs new state, has no good failure behaviour when a co-op team cannot pay, and taxes owning
things in a mission that is about doing things. Metering use rather than ownership gets the same
pressure from the machinery already in the tree.

### The activity-scaled faucets: kills and intel

Two CP faucets scale with how much the player fights rather than with what they hold — the pair to
watch, because activity-scaled income is what quietly turns "abundant" into "meaningless" under a
territory economy, and neither was priced into the rebalance above.

**Intel analysis is thinned at the source.** `server/search/fnc_intelAnalysis.sqf` converts documents to
CP with no cooldown — the larger and less bounded of the two activity faucets. Documents come from the
body-search `document` draw (`fnc_search_claim.sqf`), so supply is bounded by the search flag rate
rolled at spawn and that draw's document weight — a function of how much OPFOR was fought, not of how
often the turn-in is pressed. Rather than a per-tick cap on the turn-in, the pressure is cut where the
documents are made, and the per-item CP values in `fnc_intelAnalysis` are kept modest. A cap was tried
and rejected — it either punishes a co-op team by zeroing the shared budget after one turn-in, or needs
per-player accounting for a faucet that a smaller reward controls more simply.

**Kill income is the smaller sibling, and wants the same scrutiny.** `fnc_kill_income_sweep`
(`server/server_init.sqf`) pays `kill_cp_award` CP per `kill_cp_kills` kills per player, banked on
the economy tick with departed players' tallies folded in (`server/server_var_init.sqf:97-98`;
defaults 1 CP per 10 kills). It is deliberately absent from Overlord's tick report so it does not
advertise kill-farming, and it is modest by design — but a large co-op team in a long firefight
banks a real sum off activity alone. Neither faucet should be removed: kills and captured intel
*should* pay something, or clearing a garrison feels unrewarded. They simply must not pay so much
that holding ground stops being the point — intel is held down by a smaller reward and a thinner
drop, and whether kill income needs the same treatment is [open](#open-questions).

### The AP-to-CP converter is deleted

`client/dialog/fnc_convertAPtoCP.sqf` trades 15 AP for 10 CP, repeatable, no cooldown. Selling
the scarce currency for the abundant one is strictly wrong under this split, and with the
player's AP now buying supports and garrisons it competes with both. A CP-to-AP path must never
exist in either direction, or the abundant pool launders into the scarce one and the split
collapses.

### The eight slots

The budget is `support_max_slots` (8) consumable supports per player, and which rows draw on it is
now the catalogue's `PERM`/`CONS` column rather than a per-case habit — see
[`info/economy.md`](../info/gameplay/economy.md#supports-permanent-and-consumable). Mobile HQ's half-in state,
where it tested the cap without ever consuming one, was resolved by making it permanent.

**Advanced supports draw on the same slots.** A second currency that bought its own would raise the
campaign-long budget while appearing to be bookkeeping, and the cap would stop meaning anything the
moment AP could bypass it.

### Refunding the slate

Eight permanent slots against seventeen competing rows means a player commits at hour one to a
shape they cannot evaluate until hour six. The refund is the escape hatch, and its CP half is
built: [`info/economy.md`](../info/gameplay/economy.md#supports-permanent-and-consumable) has the mechanism,
including why it pays back the recorded charge rather than the price and why a support that is away
on a mission cannot be sold.

Two things this plan asked for came out differently, and both are better. The refund is
**per support** rather than a wholesale reset of the slate, because a slate you re-cut one row at a
time is a loadout selector in the useful sense rather than an all-or-nothing button. And it needs no
place gate of its own: the support list only exists inside the request menu, which only opens at HQ
or a FOB, so the trip is already the price.

What is left for AP is the second currency, not the mechanism. When a support costs both pools the
ledger has to record both charges and the refund has to return both; today it records one number per
support because there is one pool to record.

## Army Power

### The ladder input is not the wallet

AP does two jobs, and the shipped arrangement makes them fight for the same points. A ratchet fed
by a spendable pool reads its **high-water mark**, and a high-water mark is not lifetime income:
a player who spends as they earn oscillates in a low band and never crosses a rung, however much
they have earned in total. The player this punishes hardest is the one who uses AP for what it
exists to buy.

It also has a known-correct answer — bank just past a rung, then spend down — and a decision with
a known-correct answer is a chore the player performs rather than a choice they make.

**Both sides therefore split the two**, and the symmetry is what makes the ladder tunable at all.

| Side | Wallet | Ladder input | Tier |
|---|---|---|---|
| BLUFOR | `WARCOM_blufor_ap` | `WARCOM_blufor_ap_earned` | `WARCOM_blufor_tier` |
| OPFOR | `WARCOM_opfor_ap` | `WARCOM_opfor_ap_earned` | `WARCOM_opfor_tier` |

A wallet moves both ways; an earned counter and a tier only ever rise. A tier is reached by having
*earned* that total, whatever was spent since, so the wallet and the ladder can be sized
independently on both sides — raise a support's price without pushing the ladder out, lower a rung
without making supports free, and set the enemy's escalation pace without reference to how much it
happens to be buying.

The read surface is small: `server/warcom/fnc_WARCOM_blu_patrol.sqf:13-17,86,90,94` on the
player's side, and the OPFOR sites in
[§The enemy ceiling](#the-enemy-ceiling-is-100-and-one-gate-stands-behind-it).

**A shared pool would make the enemy's two jobs fight each other.** The commander's sinks can
absorb more per hour than its income supplies — a build tick and a squad-tasking rate that
together outrun town income and the flat floor — so a commander that buys whenever it can holds
its balance near zero, and under a high-water ladder that is an enemy which never escalates at
all, however long the campaign runs. The alternative is a commander that hoards to climb and
therefore never buys anything, which empties the map of the pressure the sinks exist to create.
There is no rate that gets both out of one number; splitting them is what lets the enemy spend
continuously *and* harden over time.

**The earned counters credit ground gained, never ground regained.** The wallet's anti-farm
invariant is the `- swing` on a lost zone, which makes lose-then-retake net exactly zero. A
monotonic counter has no such protection, so crediting a re-take would let a zone flipped back and
forth pump a tier that can never come down. On the player's side that means `fnc_captured.sqf`
credits and `fnc_blufor_cap.sqf` does not. On the enemy's side the same rule needs no test at all:
every zone OPFOR takes is one the player took from it first, so `fnc_opfor_cap.sqf` credits the
wallet and never the counter. The two ladders therefore ride the recurring faucets each side
actually earns — the zone trickle and missions for BLUFOR, town, zone and flat income for OPFOR —
the hold-and-earn income, never the one-off capture or retake swings.

The first-capture bonus makes this split structural on the player's side — a zone's CP and AP are
earned once and never again, so there is nothing to farm — where the enemy's wallet swing is still
enforced by hand.

`fnc_ap_adjust` stays the sole writer and owns both counters, so the integer invariant and the log
stay in one place. Each counter is a running sum of already-rounded positive deltas and is
integer by construction.

### The ratchet is otherwise structural, and only in half the read sites

The wave-composition threads already ratchet: each is a `spawn`ed thread walking forward through
`waitUntil` gates, so once it passes a threshold it never re-tests it. A pool drained back below
60 leaves the thread where it got to.

The eight sites that read the pool live, once per spawn, would silently downgrade the moment
anything spends:

| Site | Gate | What is lost |
|---|---|---|
| `fnc_WARCOM_blu_patrol.sqf:86,90,94` | > 60 / > 200 / > 200 | The three vehicle steps, BLUFOR side |
| `fnc_missionPatrols.sqf:33-38` | tank rung 350 (`DUWS_fnc_tokenClass`) | Mission guard fields a car only, no armour |
| `fnc_missionPatrolswithintel.sqf:23-28` | tank rung 350 (`DUWS_fnc_tokenClass`) | Same |

These read the tier, not the pool. A player who watches their own patrols lose armour because
they bought a support is being shown an unlock that un-unlocked, which contradicts the one rule
the ladder has.

The tier globals are also save state. A reload restoring the pools but not the tiers would
re-derive them from a pool that has since been spent down, silently downgrading an enemy that had
already unlocked armour. A ratchet whose only record is a number that goes both ways is not a
ratchet.

### The five-tier ladder and its starting-tier presets

Each side's opening pool once picked a raw AP figure; it now picks a **starting tier** (1–5) — the
campaign begins with that side's ladder already at the chosen tier. Five tiers: **tier 1 is infantry
at 0 AP** (always available), and the four rungs `DUWS_ap_tier_rungs = 60, 150, 350, 600` gate the
vehicle classes above it. Presets are labelled by tier because the number is no longer a spendable
bank (below).

**Each tier is a vehicle class, steepening past tier 2, sized around OPFOR income:**

| Tier | Class | Rung | OPFOR unlock at ~94 AP/hr |
|---|---|---|---|
| 1 | Infantry | 0 | from the start |
| 2 | Motorised | 60 | ~0.6 h |
| 3 | Mechanised + transport heli | 150 | ~1.6 h |
| 4 | Armour + attack heli | 350 | ~3.7 h |
| 5 | Jets | 600 | ~6.4 h |

BLUFOR climbs the same rungs on its own income — captures, missions and its zone trickle once it holds
ground — so its times differ, and the capture bounty is what keeps it in the race.

**A preset seeds the tier, not the wallet.** It writes the earned counter (and the tier derived from
it) to the chosen rung, then opens the wallet at 0. Seeding the wallet to the rung too — which an
earlier, larger-rung version did — would hand a high-tier side hundreds of spendable AP before the
first shot, several times the whole AP catalogue. The tier is capability reached; the wallet is earned
from zero. Tier 1 is the from-scratch option: infantry, both counters empty.

Retune `DUWS_ap_tier_rungs` and the presets follow, since their seeds are those rung values. The
OPFOR vehicle `_ap` values hold the same rung numbers as literals today and must be kept in step
with the array until they are centralised on it. BLUFOR's patrol gates mostly follow suit, but its
tier-3 WAVE gate is a literal 200, not the 150 rung — a second place that would drift from the array
if it moves.

### Where BLUFOR army power comes from

Zones are the backbone; missions top it up. The player's AP is earned from held ground and
completed work, sized so a campaign funds roughly four advanced unlocks, eight combat vehicles and
a garrison or two — about 300 AP of spending.

| Faucet | Rule | Per event | Share, mid-late |
|---|---|---|---|
| Zone hold trickle | per held zone, per 30-min tick, × `DUWS_econ_throttle` | 5 AP/zone (10/hr) | ~60% |
| Side mission | remapped to a 10-40 band by difficulty | 10-40 | ~40% |
| First capture (once ever) | one-time CP + AP bonus, persistence-tracked | bonus | — |

A six-zone campaign held whole pays 60 AP/hr from the trickle, a small four-zone one 40; missions
add roughly 26 at one completion an hour, ~52 at two. Territory still leads once the player holds a
handful of zones, but the mission faucet is deliberately strong enough to climb the tier ladder on
its own pace: at the small-map end a two-mission-an-hour runner now matches or beats the trickle, so
missions are a real second route to the rungs, not only a top-up.

**The mission AP band is capped per thread, then scaled by the campaign reward multiplier.** The 17
threads ship paying 0-45 AP each (`server/missions/mission_threads/*/fnc_*_mission.sqf`), so one hard
mission out-paid an hour of territory. They are remapped into a 10-40 band ranked by difficulty,
edited as the literal beside each thread's CP figure — there is no shared table to turn one knob
against, and the ordering across mission types is the balance decision a flat scalar cannot express,
since it would preserve the 0 and 45 outliers the cap exists to remove. On top of that fixed band the
player's reward multiplier (`cp_reward_multiplier`, 1-5) scales the AP payout as it does the CP one,
so a high-reward campaign climbs the tier ladder proportionally faster — a host setup choice, not a
per-mission balance lever.

**First capture pays a one-time bonus.** The first time BLUFOR ever takes a zone it pays a one-off
CP + AP liberation bonus — the marquee reward for opening the map, and where BLUFOR's capture AP now
comes from. It is tracked in the campaign save as a per-zone first-captured flag
([`campaign_save_format.md`](../info/architecture/campaign_save_format.md)), so a reload, or a zone lost and retaken,
never pays it twice. That is what makes the anti-farm invariant structural rather than arithmetic:
BLUFOR earns a zone's AP exactly once, so lose-then-retake yields no fresh AP however often it
flips. It maps onto the two capture paths already in the tree — `fnc_captured.sqf` is the first-ever
capture and pays the bonus, crediting the wallet and the earned counter; `fnc_blufor_cap.sqf` is a
recapture and pays nothing — the zone's CP and AP were both earned at the first capture, so there is
no reflip income at all. The bonus is a flat authored CP+AP pair, not a worth fraction, so a small
zone is worth liberating too; the amounts are tuning ([open](#open-questions)).

**Passive is not idle.** An earlier draft forbade any passive AP, on the reasoning that a trickle
makes tier gates a matter of waiting. The zone trickle is passive per tick yet earned per zone: it
pays only for ground taken and held, scales with how much is held, and stops when a zone is lost.
Standing still earns nothing new; the only lever is more ground. That is the distinction the
earned-only rule was reaching for, and it is what gives AP the reliable backbone a purely
event-driven faucet never had.

**The two faucets sit on different clocks.** The trickle rides the economy tick's `sleep 1800`,
which `setTimeMultiplier` does not scale; side-mission cooldowns are stamped against `dateToNumber
date`, which it does
([`info/arma_engine_gotchas.md`](../info/architecture/arma_engine_gotchas.md#diag_ticktime-counts-from-process-start-and-is-not-restored-by-a-savegame)).
At the host's higher multipliers a mission type recharges many times faster while the trickle pays
at an unchanged real rate, so missions come to dominate and the 75/25 ordering inverts. The tick
stays on `sleep 1800`: every share here holds at `time_Multiplier = 1`, and the high-multiplier
divergence is an accepted limitation rather than something to redesign the clock around.

### Where OPFOR army power comes from

| Faucet | Amount | Credits |
|---|---|---|
| Zone hold trickle | per held OPFOR zone, per tick, × `DUWS_econ_throttle` (5 each) | wallet + tier |
| Town income | banded OPFOR towns, per tick, × `DUWS_econ_throttle` | wallet + tier |
| Flat income | one constant per tick, independent of everything | wallet + tier |
| Zone retaken | `round (worth * zone_ap_swing)` | wallet only |
| Zone lost | consolation AP whenever BLUFOR takes an OPFOR zone | wallet only |

OPFOR earns AP from everything it holds — every zone it garrisons and every town in its band, on
the same throttle as the player's — plus a flat floor and a swing for retaking a zone. It is
symmetric with BLUFOR's zone trickle, and its per-town payment is OPFOR's own AP figure, set apart
from the CP the same town pays the player. What differs is where each faucet lands: the *Credits*
column is the wallet/counter split
([§The ladder input is not the wallet](#the-ladder-input-is-not-the-wallet)).

**The consolation is the anti-steamroll floor.** Every time BLUFOR takes a zone, OPFOR is paid a
consolation AP — `zone_ap_consolation`, which an earlier draft had zeroed and this reinstates. The
reason is rubber-banding: a player who pushes fast hands OPCOM the AP to fortify and counter-attack,
so a steamroll funds its own resistance rather than running unopposed. It credits the wallet only,
never the tier — losing ground must not raise the enemy's permanent ceiling — so it sharpens the
enemy's immediate pressure without ratcheting how dangerous it is allowed to become.

**The flat income is a floor, not the main faucet.** A town whose radius reaches into an enemy
zone starts at `-20` (`server/civilian/fnc_civ_init_Tomata.sqf:197-205`), so the enemy opens with
several towns already banded and already paying — OPFOR town income outweighs any sensible flat
constant several times over at hour zero. The constant is sized for a director holding nothing,
and the figure that has to be checked is the combined one.

**The zone trickle credits the tier, and the front-load is balanced on the bounty, not a handicap.**
OPFOR holds every zone at hour zero, so crediting that trickle to a one-way counter front-loads the
tier from ground the enemy started on rather than fought for — the reason an earlier design paid the
trickle to the wallet alone. That exclusion is dropped: the ladder is kept **symmetric** — both sides
credit the whole of what they hold, and both scale on the one shared campaign-size throttle
(`DUWS_econ_throttle`), with no per-side income handicap. The head start is answered by the BLUFOR
capture bounty (`zone_first_capture_ap`, 50): it climbs the player's own tier as they take that same
ground, so OPFOR opens ahead and the player closes the gap by advancing, rather than by OPFOR being
penalised for holding. The retake swing and the consolation stay wallet-only — losing ground must
still never raise the enemy's permanent ceiling. `zones_number` running 1 to 40 is handled separately,
by the throttle on every passive faucet.

Both sides gate capability on raw `earned` against the same thresholds for most of the ladder
(BLUFOR's wave/vehicle steps, OPFOR's per-vehicle `_ap` in `DUWS_spawnVehicles`): five tiers, tier 1
infantry at 0 and the rungs 60 / 150 / 350 / 600 gating motorised, mechanised, armour and jets. The
one exception is BLUFOR's tier-3 WAVE gate, a literal 200 rather than the 150 rung. Both sides use
the whole ladder; the tier integer is the readout summary of that climb.

### What enemy AP gates now: the shared vehicle rungs

The old WARCOM patrol, assault and air spawners that held OPFOR's rungs are gone. Enemy Army Power
no longer meets a distinct ceiling; it gates OPFOR vehicles through the same token table the zone
garrisons use (`DUWS_fnc_tokenClass`, `fnc_zone_spawn_sizes.sqf:91`), on the shared rungs above.

The one live spender outside a zone garrison is the mission guard. It raises two tokens rather than
substituting one for the other (`fnc_missionPatrols.sqf:31-39`, `fnc_missionPatrolswithintel.sqf:23-29`):

| Token | Rung | Result |
|---|---|---|
| `car` | 60 | the light vehicle, standing from tier 2 up |
| `tank` | 350 | armour added on top once the enemy reaches tier 4 |

The lighter token stands whether or not the heavier is gated in, so the ladder adds armour to the
guard instead of exchanging a car for it. Beyond this, enemy AP is the OPFOR commander's to spend;
any figure below on what enemy income *should* pace is written against that commander existing.

**Town income alone will reach any ceiling put back.** Every town whose radius overlaps an enemy
zone starts at `-20` (`server/civilian/fnc_civ_init_Tomata.sqf:199-201`), the deepest band, so the enemy
opens with its zone-adjacent towns already paying. Six such towns at 2 AP each is 12 a tick, which
crosses 200 in roughly seventeen ticks without a flat income existing at all. The flat constant is
therefore insurance for a director that has lost its towns, not the faucet that sets the pace.

**The player's lever on escalation is the enemy's income, not its balance.** A player-facing debit
is rejected — it lets the player attack a number rather than the war, and the number is the one
thing on the enemy's side they cannot see. Under split counters, destroying what the enemy bought
no longer slows its climb either: the tier rides gross income, so a cleared garrison costs the
enemy the asset and the AP to replace it, and nothing else.

What remains is better than what it replaces. Town income is the enemy's largest faucet by some
distance, and dragging a town out of the OPFOR band cuts it at the source — permanently, visibly,
through a system the player is already working in. Escalation therefore slows for a reason the
player can see on the map, rather than as an invisible side effect of the enemy's accounting.

Flat income and the retake swing are the two the player cannot touch, which is what stops
suppression from becoming a freeze.

### What army power buys is permanent

CP buys a delivery, a vehicle, a squad — things that are spent or destroyed. **AP buys something
the player still has an hour later.** That is what makes the choice of what to buy weighty rather
than merely expensive.

The mission already implements this shape for radio supports, so an AP support is the same code
with a different pool: each case in `client/dialog/fnc_request_support.sqf` tests its own
`support_*_available` flag, spends once, and adds a comm-menu item.

The eight-slot cap makes an AP purchase exclusive as well as permanent. Permanent *and* capped
means spending AP on the wrong support is a misallocation the player lives with for the campaign,
and it costs nothing to get because the cap already exists.

**Two exceptions, both of which have to be legible.** A town garrison is bought with AP and can be
cleared, so it is a risked investment where a support unlock is not. And a tier is not bought at
all: it is reached, which makes it permanent by construction rather than by rule.

**Permanence depends on work that is not built yet.** Support unlocks are client-local with no
server-side record of what the team owns, so today a permanent unlock survives neither a reload
nor a reconnect. That is tolerable for a 5 CP supply drop and is not tolerable for the most
coveted resource in the campaign.

### Civilians off costs BLUFOR its passive CP faucet

Three configurations register no town reputation: `CIV_PRESENCE` of `NONE`, `RAVAGE` or `WBK`.
Civs-off leaves the town arrays empty (`server/misc/fnc_zonesundercontrol.sqf:29-39`); the two mode
campaigns register no town reputation at all, so `fnc_civ_townIncome`
(`server/civilian/fnc_civ_state_init.sqf`) pays nobody. Under the town→CP routing that zeroes BLUFOR's
passive CP, leaving zone capture bounties and mission CP to carry it, and it zeroes OPFOR's town AP,
leaving its flat floor and retake swing. BLUFOR's AP is untouched — it comes from zones, which every
configuration has. The loss is one-sided in effect: OPFOR keeps a floor, BLUFOR's passive CP goes to
zero. Turning civilians off should be a presentation choice; it must not quietly be a difficulty
setting.

CP is abundant by design and its real drain is per-use, which scales with fighting rather than
holding, so a civs-off campaign is tighter rather than broken. The substitute still rides missions,
which exist in every configuration:

- **Mission CP lifts when `civ_town_rep` is empty**, restoring the passive faucet's rough share
  through a route that is always there.
- **Gate on the faucet being absent, not on the mode being named.** One condition covers all three
  configurations, and a fourth mode added later inherits it instead of being forgotten.
- **BLUFOR only.** OPFOR keeps its floor, so a symmetric lift would over-pay it.

A flat BLUFOR trickle was the alternative and is rejected: set at what a well-played civs-on
campaign yields, civs-off becomes the CP-optimal way to play. Routing the substitute through
missions keeps it tied to activity and needs no new passive number.

## Prices

### Two tiers, one price format

| Tier | Pays | Examples |
|---|---|---|
| Regular support | CP only | UAV recon, supply drop, taxis, paradrop |
| Advanced support | CP **and** AP | Artillery, mortar, cluster, napalm, attack helicopter, CAS |
| Utility vehicle | CP only | Unarmed cars, transport trucks, boats, transport helicopters |
| Combat vehicle | CP **and** AP | Tanks, tracked APCs, armed helicopters, artillery pieces |

**Both halves are charged.** An AP-only price for the top of the catalogue was rejected: it leaves
CP with nothing expensive to buy, and it makes the player learn two price formats instead of one.

Under an abundant CP pool the AP half is what actually decides an advanced purchase, and the CP
half is close to a rounding error. The dual price is therefore carried for legibility — one price
format across the whole catalogue — rather than as a second constraint. Saying so is what stops
someone later tuning the CP half as though it were load-bearing.

**Escalation scales the CP half only.** `fnc_pool_try_spend` applies `fnc_escalation_cost` on
entry to whatever it is given; the AP component opts out. CP is the player's own purchasing power,
so a hardening enemy making the shopping list dearer is what escalation models — and AP purchases
are permanent, so scaling them would make buying early strictly better than buying well, which is
the opposite of a decision worth having. Taking AP out of escalation also removes the accidental
`ceil` that was keeping AP prices whole, which is why the integer contract above has to be
explicit.

### The dual price needs an atomic handshake

`fnc_pool_spend` takes one pool per call. Charging CP and then AP as two sequential calls is not
one purchase: the first can succeed and the second fail, leaving the player charged for nothing,
and in co-op another player's spend can land between them. That is the same race the single-pool
handshake was written to close
([`info/economy.md`](../info/gameplay/economy.md#authority-the-server-decides-a-purchase-not-the-buyer)),
reopened one level up.

`fnc_pool_try_spend` gains a dual case that tests both pools and debits both as adjacent
statements against the one server copy, replying with a single verdict. Partial success must be
impossible rather than merely unlikely.

### The two label formats are opposites

| Catalogue | Label built | Consequence |
|---|---|---|
| Vehicles | At runtime, `_typeDisplayName + ' (' + str(_typeCost) + 'CP)'` (`shared/factions/MODERN/AUTODETECT_blufor.sqf:223`) | English-only, generated. Free to reformat into a dual price |
| Supports | Baked into stringtable text across five languages | The AP figure must be **appended**, never substituted |

The support constraint already forced escalation to append its surcharge rather than rewrite the
row (`client/dialog/fnc_request_menu.sqf`): a `%1` placeholder added to English but not to the
other four languages leaves them printing a stale baked number, which is a wrong figure rather
than an untranslated one. A dual price inherits that exactly, and so does a per-use price.

### Vehicles split on a classifier that already exists

`shared/factions/MODERN/AUTODETECT_blufor.sqf:35` unpacks 26 categorised arrays from
`fnc_parseFaction` — `_tank`, `_apcTracked`, `_apcWheeled`, `_carArmed`, `_carTransport`,
`_heliArmed`, `_heliTransport`, `_arty`, `_antiAir` among them — and `:195-215` flatten every one
of them into a single `requestAssets` list, discarding the category one line later.

The split is a test against arrays that already exist at build time, not a new taxonomy and not a
per-classname table maintained against every faction mod on the Workshop. Keeping it derived from
`fnc_parseFaction` is what preserves faction auto-detection: a hand-authored list of tank
classnames would silently mis-price any mod the list has not heard of.

The cost figure stays `fnc_evalVehicleCost`, which already reads armour, threat and type
multipliers from config. What changes is which pool it draws from and what the AP component
alongside it is.

## What OPFOR Army Power buys

OPFOR Army Power is spent by one server-side actor — the commander. Its sinks (town and zone
garrisons, taskings, hardpoint construction), the archetype that weights how it splits income
across them, and the two-sided garrison ladders are designed in
[`opcom_plan.md`](opcom_plan.md#what-the-commander-spends-on); the wallet and the faucets that
fill it stay here ([§Army Power](#army-power)). Spend authority is [below](#spending-authority).

## Spending authority

`fnc_cp_adjust` and `fnc_ap_adjust` stay the sole writers of their pools. Player spends go through
the purchase handshake — a client testing its own copy of a networked pool is a round trip out of
date, so two co-op players can both pass one gate.

**AP spends on the same authority as CP: any `Squad_Leader`.** Both pools are shared and every
squad lead can already spend CP, so AP keeps that parity rather than moving the call to
`game_master` alone. The trade is taken deliberately: permanence means a bad AP purchase cannot be
worked off the way a wasted CP one can, and any lead can make one — but a separate premium-currency
permission is a role split the mission does not otherwise carry, and gating AP to one player would,
in a two-player session, just mean the other cannot buy. Spend authority stays the single edit to
`Squad_Leaders` it already is for CP.

### The captured-gear settle trusts the client loadout, by choice

The captured-gear settle credits a pool for the difference between the loadout a player opened the
arsenal with and the one they close it with, so a search-and-bank pays out. Both the open and the
close loadout are read on the client and sent to the server (`server/misc/fnc_economy_init.sqf`). An
earlier hardening pass re-read the close loadout on the server to corroborate it against a lying
client, but a remote unit's loadout replicates with lag: a grab made just before close had not always
reached the server, so the settle diffed against a stale close and stripped gear off an *honest* co-op
player. Reading both sides on the client is symmetric and correct in co-op — one loadout diffed
against itself with no network lag between the reads.

The cost is that a tampered client can report a richer-than-real open (or close) and over-credit the
pool, bounded by what the shelf stocked; and the support-tier backstop guards the debit, not the
client-side application, so a free (0-cost) call bypasses it. Both are accepted. The only client that
can trip either is a modified one — an honest client's greyed row blocks the tier buy before any
charge — and the server-authoritative alternatives cost honest co-op play more than the cheat costs
the campaign.

## Reading the war from the map

**AP needs a live readout, which it has never had.** `fnc_ap_adjust` broadcasts the pool but
refreshes no control, and there is no `publicVariableEventHandler` for either pool. Three dialogs
read AP at open time (`client/dialog/fnc_request_menu.sqf` for both the HQ and FOB forms, and
`fnc_convertAPtoCP.sqf`) and none updates afterwards. A stale counter was cosmetic when AP was a
score; it is a purchase made on wrong information once AP is a currency, and worse in co-op, where
someone else's spend is exactly what the reader cannot see.

The map view is where that goes. Both pools are `publicVariable`d, so the client's copies are
current and the readout can print them directly with no round trip — and a readout the player
opens is read at the moment they are deciding, where a dialog control left open is not. The wallet
and the tier are both printed: the pool figure alone stops describing capability the moment
spending starts.

**Garrison tier is in the click readout, not on the markers.** Nothing was added to the map itself:
the player clicks a zone or town and the popup that already answers carries a Garrison Tier line
above the strength bar, in roman, for both sides' ground. A zone reports the tier it rolled, and 0
once the player holds it; a town reports what it owes, which is not always what is standing in it,
since a town nobody has walked into yet has a tier and no men. That is the honest answer for a map
read before travelling: the readout describes what the player will meet, not what is loaded. A town
that is holding says so instead — `Mobilising` if it has only just fallen, `Regrouping` if its
garrison was destroyed.

Tier above strength is the pair the player reads together, and they are orthogonal by design: tier is
how big this ground was ever meant to be, the bar is how much of it is left. A tier I zone at a full
bar is small and untouched, not mauled.

The lookup stays server-side because `civ_locations`, `civ_radii`, `civ_town_rep` and
`DUWS_townGarrisonTier` are none of them broadcast, so this costs no new networked state. Reveal
gating is already correct: an unrevealed town answers as empty ground rather than as a hit the
readout declines to describe, so the map cannot be swept for towns the presence trigger is hiding.

### SITREP becomes free

It costs 1 CP today (`server/supports/fnc_sitrep_support.sqf`) and reports what the player can
already work out — more so once the map carries the same figures. The stronger argument is that
SITREP is the only save in the mission: it is the sole caller of `fnc_autoSave`, so the 1 CP is a
charge for saving the game, and a player who has spent down to nothing cannot save at all.

**The cost is also the only throttle**, since there is no cooldown on the support. Removing the
price without adding one leaves `saveGame` spammable, and a save is a real frame hitch. The
cooldown replaces the price; it does not accompany it.

## The unlock state model has to be settled first

The mixed locality that blocked this is now named rather than incidental. A permanent unlock is
team state, broadcast, and mirrored on the server in `DUWS_support_permanent`; a consumable is the
buyer's alone and is deliberately not broadcast, because it dies with its buyer. `support_count` is
still per-client, and that is now correct rather than a gap — it counts one player's slate.

One thing the flags rest on is still unverified: defaulting behind `isNil` preserves a broadcast
value only if `publicVariable` values are delivered to joining clients at all, which is an open
engine question in [`KNOWN_ISSUES.md`](../../KNOWN_ISSUES.md). If they are not, the defaults preserve
nothing and the team can still be charged twice for the same permanent unlock. The server mirror
does not close that on its own: it records what the team owns, but nothing yet reads it back to a
joining client.

## Build order

Each phase is independently shippable, and the ordering is forced rather than chosen. The faucet
reroute has shipped; the phases below it are the remaining work, in sequence.

| Phase | Contains | Why it is gated here |
|---|---|---|
| **Faucet reroute** — shipped | Town income routed BLUFOR→CP (1-5 by town size), OPFOR→AP; the 5 AP/zone hold trickle on both sides; `DUWS_econ_throttle` on every passive faucet; the one-time first-capture CP+AP bonus (persisted, BLUFOR); delete the CP capture bounty and its recapture decay; OPFOR consolation AP on every zone loss; mission AP remapped to a 10-40 band; mission CP lifted with no town reputation; the OPFOR flat income; delete the AP-to-CP converter | This is the model. Playable the moment it lands; nothing downstream matters until the faucets are right |
| **Floor** | `fnc_ap_adjust` integer invariant; both earned counters and both tier globals, seeded by the presets; the eight live pool reads switched to tiers; CP, AP and tier in the map readout; presets regenerated to the rungs | Without the tier globals the first AP spend downgrades that side's own patrols. Without a readout, deciding what to buy is guesswork |
| **CP becomes a flow** | Per-use CP on supports; the intel-analysis cap | Independent of AP entirely |
| **AP becomes spendable** | The dual case in `fnc_pool_try_spend`; AP halves on advanced supports and combat vehicles; the refund's second currency | The permanent/consumable split and the CP refund are in; what is left is the second pool |
| **The commander** | The OPCOM director, its archetype and four sinks (town and zone garrisons, taskings, hardpoints), plus random events — designed in [`opcom_plan.md`](opcom_plan.md) | Everything above is its budget |
| **Reconcile the reference** | Rewrite `info/economy.md`'s pre-reroute passages: AP now spends from menus, the AP→CP converter is gone, town income routes CP to BLUFOR and AP to OPFOR, the zone CP bounty and its recapture decay are replaced by the one-time first-capture bonus, and `zones_held × 6` CP is now the AP trickle | Last: it documents shipped machinery, so it lags until the machinery stops moving |

## The tuning surface

Every constant below was set by judgement to a plausible value and wants play-test, not calculation.
They are collected here so the next pass tunes from one list rather than hunting the tree.

| Constant | Where | Value | Note |
|---|---|---|---|
| `zone_first_capture_cp` / `_ap` | `server/server_var_init.sqf` | 25 / 50 | flat, once ever per zone; the AP half is the main BLUFOR lever balancing OPFOR's zone tier |
| `zone_ap_trickle` | `server/server_var_init.sqf` | 5 | AP per held zone per tick, each side; credits both wallet and tier |
| `zone_ap_swing` | `server/server_var_init.sqf` | 0.15 | OPFOR retake gain / BLUFOR loss, share of worth; wallet only |
| `zone_ap_consolation` | `server/server_var_init.sqf` | 0.15 | OPFOR's AP per BLUFOR capture, share of worth; wallet only |
| `opfor_flat_ap_income` | `server/server_var_init.sqf` | 2 | flat OPFOR floor per tick, unthrottled |
| `DUWS_ap_tier_rungs` | `server/misc/fnc_economy_init.sqf` | 60/150/350/600 | steepens past tier 2; the four rungs above tier 1 (infantry, 0). Preset seeds and the shared capability scale (OPFOR `_ap` and BLUFOR's vehicle gates hold the same values as literals; BLUFOR's tier-3 WAVE gate is a literal 200, not the 150 rung) |
| OPFOR vehicle AP gates | `server/init_zones/fnc_zone_spawn_sizes.sqf` | car 60 (T2) / APC·IFV·AA·trans-heli 150 (T3) / tank·attack-heli 350 (T4) / plane 600 (T5) | OPFOR's capability ladder; utility trucks ungated |
| BLUFOR wave/vehicle gates | `server/warcom/fnc_WARCOM_blu_patrol.sqf` | car 60 (T2) / apc·ifv·transheli 150 (T3) / tank·attackheli 350 (T4); infantry free (T1) | BLUFOR's capability ladder; the T3 WAVE gate (armored/air in `fnc_WARCOM_blu_patrol.sqf`) is a literal 200, not the 150 vehicle rung |
| corpse money drop | `server/search/fnc_addRandomLoot.sqf` | ~60% | share of enemies carrying `Money_roll`; intel documents no longer dropped here |
| intel per-item CP | `server/search/fnc_intelAnalysis.sqf` | 1–5 | turn-in CP by document, always paid; each also rolls a per-item reveal chance |
| throttle `k` / `REF_ZONES` | `server/warcom/fnc_WARCOM_init.sqf` | 0.5 / 6 | strength, and the size below which nothing throttles |
| town worth | `server/civilian/fnc_civ_init_Tomata.sqf` | 1–5 by size | CP to a BLUFOR town, AP to an OPFOR one |
| mission AP band | `server/missions/mission_threads/*` | 10–40 | per-thread literal, ranked by difficulty |
| civs-off CP lift | `server/missions/fnc_mission_reward.sqf` | ×1.5 | applied when `civ_town_rep` is empty |
| advanced-support AP | `client/supports/fnc_supports_init.sqf` | 20–40 | 9th catalogue column, per row |

## Balance items to watch

These flow from the deferred sinks, not from bugs — most resolve when the demand side is built. The
warning that ties them together: **do not re-tune the faucets down to make the currencies feel scarce
while the sinks are absent.** Scarcity is supposed to come from the tier ladder, the combat-vehicle
gate, BLUFOR garrisons and the OPFOR commander. Cutting a faucet now would leave the economy starved
once those land.

- **AP is not scarce for a zone-holding BLUFOR yet.** Its only sink is the ~6 advanced supports,
  180 AP for the whole set, realistically 90–130 AP bought. Supply is 50 AP × zone count one-time
  (~300 at six zones), plus ~60 AP/hr trickle at full control, plus 10–40 a mission — so liberating
  the map more than funds the entire AP catalogue from captures alone. The raised capture bounty
  deepens this on the wallet even as it earns the tier; the two-currency premise does not bite until
  the combat-vehicle gate, garrisons and commander give AP something to buy.
- **Kill income is untouched** (1 CP per 10 kills per player, `server/server_init.sqf`). Intel is
  held down by a smaller reward and a thinner drop rather than a cap; kill income has had neither. A
  large co-op team in a long firefight banks it off activity alone, so whether it needs the same
  treatment is [open below](#open-questions).
- **First-capture front-loading.** 25 CP + 50 AP times the zone count is a lump paid in the opening
  hours, and the AP half also climbs BLUFOR's tier — deliberately, to answer OPFOR's hour-zero zone
  tier. On a large map it is a meaningful head start on both wallet and ladder; the throttle does not
  touch it, since it rewards an action rather than a holding.
- **OPFOR AP accumulation.** Until the commander lands, OPFOR's wallet has only the hardpoint director
  as a sink, so it climbs with little to spend it on. Its
  earned counter meanwhile crosses the tank rung (350) off town+zone income, so side-mission and zone
  armour appear once OPFOR has held enough ground; that gate reads the earned counter (the token
  `_ap`), not the wallet. Expected, and the wallet drains when the commander's sinks land; not a leak.
- **CP abundance versus vehicle price.** Light vehicles now cost ~1–5 CP against a CP economy the
  reroute roughly doubled, so their price is close to free. That is intended — hiring and light
  transport are not meant to be gated by cost — but it means the CP half of the catalogue is legible,
  not load-bearing, until per-use CP lands.

## A one-currency, two-figure question

Town worth is a single figure (`civ_town_ap`, 1–5) paid as CP to a BLUFOR town and AP to an OPFOR
one. The design allows OPFOR its own per-town AP rate distinct from the BLUFOR CP figure; the first
pass unified them for simplicity. If OPFOR town income needs to move independently of BLUFOR's, this
is where a second array goes.

## Open questions

- **How long a passive campaign should take to reach maximum enemy capability.** Enemy capability
  now tops out at the shared vehicle rungs ([above](#what-enemy-ap-gates-now-the-shared-vehicle-rungs)), the
  ratchet is one-way, and a director that never spends climbs at its whole income. Picking that
  duration *is* picking the flat income, so the constant cannot be set before it.
- **The flat income figure**, which falls out of the answer above once OPFOR town income is
  measured on a real map rather than estimated.
- **The throttle constants `k` and `REF_ZONES`.** `k = 0.5` and `REF_ZONES = 6` are starting
  values: `k` sets how hard a large campaign is throttled and `REF_ZONES` the size below which
  nothing is, and both want play against real campaign sizes rather than paper.
- **The zone AP trickle rate.** 5 AP/zone/tick (10/hr) is the anchor a small campaign was tuned
  around; whether it holds once the throttle and the mission cap are both in is a play-test
  question.
- **Whether the throttle keys on zone count or each faucet's own source count.** Town CP is thrown
  by zone count as a proxy, since towns scale with zones; a town-count key with its own reference
  is more accurate at the cost of a second constant.
- **Whether the wallet/counter split holds OPFOR's hour-zero zone income in check.** The zone
  trickle fills its wallet but not its tier, and OPCOM spends continuously, but a defensive
  commander that banks could still fortify hard in its strongest hours. Only play shows whether the
  throttle and the counter exclusion together are enough.
- **The first-capture bonus and consolation amounts.** The one-time CP + AP liberation bonus and
  the OPFOR per-loss consolation are placeholders — the two bonus figures and the consolation rate
  want play-test. Recapture pays BLUFOR nothing, so there is no bounty to weigh them against.
- **Re-pricing the sinks against the resized faucets.** The rebalance moved the faucets but did not
  re-derive the sinks. CP roughly doubled (town income plus missions against the old territory
  faucet), so the per-use support costs and the unit, squad and vehicle CP prices now meter about
  half as hard and want a pass upward. The whole AP price column — advanced-support AP halves,
  combat-vehicle AP halves (`fnc_evalVehicleCost` yields only CP today), the radio tiers — is new
  and unset. This is a tuning pass once the faucets land, not a redesign.
- **How the activity-scaled CP faucets are tuned against the territory economy.** Intel analysis is
  held down by a smaller per-item reward and a thinner drop (roughly three enemies in five carry
  loot); kill income (1 CP / 10 kills / player) is untouched, and a large co-op team banks it off
  combat alone. Whether kill income needs the same treatment or a rate change is a play question —
  but activity income must not scale with playtime while territory is what the economy rewards.
- **The AP component of each advanced support and combat vehicle.** The starting values here are
  round numbers against a 300 AP campaign budget; what they should be is a play-test question.
- **Where the boundary falls for armed cars and wheeled APCs.** Tanks and unarmed transport are
  clear; the middle of the catalogue is where a rule stated as "armed costs AP" starts pricing an
  armed offroad like a main battle tank.
- **Whether flipping towns out of the OPFOR band suppresses escalation too well.** It is now the
  player's whole lever on enemy income, so it wants to work; the question is whether a diligent
  player freezes the war, and only play answers that.
- **Whether anything bought with AP is consumable after all.** The rule admits one exception
  already, and a second would make "AP buys permanence" a guideline rather than something a player
  can rely on when deciding what to spend.
