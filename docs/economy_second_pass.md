# Economy: second-pass work

The first pass landed the territory-type economy: towns pay their holder (BLUFOR CP, OPFOR AP),
zones trickle AP to both sides, capture pays a one-time liberation bonus, advanced supports carry a
dual CP+AP price, and vehicles are priced CP-only on a metadata-driven scale. The design and its
rationale are in [`economy_plan.md`](economy_plan.md); the shipped machinery is in
[`info/economy.md`](info/economy.md).

This document is the backlog the first pass deliberately left. Each item was cut to keep the pass
shippable, not because it is optional — several are load-bearing, and the ordering below is roughly
the order the next pass should take them.

## The AP tier ladder

The single largest deferred piece, and the one the rest depend on. AP is earned and spent, but the
mission does not yet turn earned AP into a **tier** — a one-way ratchet of capability.

What it needs, from [`economy_plan.md`](economy_plan.md#the-ladder-input-is-not-the-wallet):

- Per-side earned counters (`WARCOM_blufor_ap_earned`, `WARCOM_opfor_ap_earned`) that only ever rise,
  credited by the recurring faucets but never by spending, so a player who spends as they earn still
  climbs. The wallet stays the spendable pool.
- Per-side tier globals derived from the earned counter, and saved, since a reload that restored the
  pool but not the tier would re-derive a tier from a pool since spent down.
- The eight live pool reads switched from the wallet to the tier
  (`server/warcom/fnc_WARCOM_blu_patrol.sqf`, `fnc_WARCOM_blu_assault.sqf`,
  `server/missions/fnc_missionPatrols.sqf`, `fnc_missionPatrolswithintel.sqf`).
- The starting-AP presets regenerated as the ladder's own rungs plus zero.

**Immediate consequence of it being absent.** BLUFOR auto-patrols still read the live wallet
(`fnc_WARCOM_blu_patrol.sqf:10-35,90-100`). Now that AP is spendable on advanced supports, buying one
dips the wallet and can transiently downgrade the player's own patrols below a threshold they had
crossed — the "unlock that un-unlocked" the ladder exists to prevent. Until the ladder lands this is
a known wart, not a new one.

## Tier gates on vehicles and HC squads

Directed for the first pass but gated behind the ladder above, so deferred with it. Vehicles stay
**CP-only**; the gate is the earned tier, not a second price. The intent is that armour and tanks are
unbuyable at tier 1, so raising the tier — by earning AP — is mandatory to field the heavy end.

The classifier already exists: `shared/factions/MODERN/fn_factionAutoDetect.sqf` produces categorised
arrays (`_tank`, `_apcTracked`, `_apcWheeled`, `_carArmed`, `_heliArmed`, `_arty`, `_antiAir`, …)
that `AUTODETECT_blufor.sqf:175-195` flattens into `requestAssets`. The gate is a test against those
categories at menu-build and purchase time, not a hand-authored classname table — which is what keeps
faction auto-detection and mod support intact. HC squads gate on the same tier through
`DUWS_bluforSquads` (`server/init_hq/fnc_BLUFOR_squad_init.sqf`), where the mech and armour sections
are the rows that should sit behind a tier rather than behind CP.

## The OPFOR commander (OPCOM director)

The whole commander phase is deferred: the archetype roll, the four sinks (town-garrison upgrade,
tasking, hardpoint construction, rapport), town garrisons I–IV and town events. Design in
[`opcom_plan.md`](opcom_plan.md). Its budget is now flowing — OPFOR earns AP from town income, the
zone trickle, the flat floor and the retake swing — so when the commander is built it has something
to spend. Until then OPFOR AP has only the existing hardpoint director as a sink, so the pool tends to
accumulate; see the balance note below.

## Per-use CP on supports

Supports charge CP once, at unlock. The plan
([`economy_plan.md`](economy_plan.md#the-drain-moves-to-use-not-to-price)) moves the drain to **use**: each call
costs CP, so CP tracks how much the player is fighting rather than what they own, and escalation gets
something to bite. Deferred because it touches every support's comm-menu use-script (~14 of them)
rather than the catalogue alone. With CP abundant under the territory economy, a one-time unlock cost
cannot absorb the faucet, so this is the piece that makes CP a flow rather than a threshold.

## Save persistence

`DUWS_zone_first_captured` is correct within a session, but the campaign save must carry it or a
reload re-pays the liberation bonus for every zone already taken. The same requirement will apply to
the tier globals and the commander's archetype once those exist. See
[`economy_plan.md`](economy_plan.md#what-army-power-buys-is-permanent).

## The tuning surface

Every constant below was set by judgement to a plausible value and wants play-test, not calculation.
They are collected here so the next pass tunes from one list rather than hunting the tree.

| Constant | Where | Value | Note |
|---|---|---|---|
| `zone_first_capture_cp` / `_ap` | `server/server_var_init.sqf` | 25 / 20 | flat, once ever per zone; front-loads with zone count |
| `zone_ap_trickle` | `server/server_var_init.sqf` | 5 | AP per held zone per tick, each side |
| `zone_ap_swing` | `server/server_var_init.sqf` | 0.15 | OPFOR retake gain / BLUFOR loss, share of worth |
| `zone_ap_consolation` | `server/server_var_init.sqf` | 0.15 | OPFOR's AP per BLUFOR capture, share of worth |
| `opfor_flat_ap_income` | `server/server_var_init.sqf` | 2 | flat OPFOR floor per tick, unthrottled |
| intel loot drop | `server/misc/fnc_addRandomLoot.sqf` | ~60% | share of enemies carrying loot; thins intel + coins at source |
| intel per-item CP | `server/misc/fnc_intelAnalysis.sqf` | 1–5 | turn-in value by document; corpse loot 1, search items above it |
| throttle `k` / `REF_ZONES` | `server/warcom/fnc_WARCOM_init.sqf` | 0.5 / 6 | strength, and the size below which nothing throttles |
| town worth | `server/misc/fnc_civ_init_Tomata.sqf` | 1–5 by size | CP to a BLUFOR town, AP to an OPFOR one |
| mission AP band | `server/missions/mission_threads/*` | 5–20 | per-thread literal, ranked by difficulty |
| civs-off CP lift | `server/missions/fnc_mission_reward.sqf` | ×1.5 | applied when `civ_town_rep` is empty |
| advanced-support AP | `client/supports/fnc_supports_init.sqf` | 20–40 | 9th catalogue column, per row |

## Balance items to watch

These flow from the deferred sinks, not from bugs — most resolve when the demand side is built. The
warning that ties them together: **do not re-tune the faucets down to make the currencies feel scarce
while the sinks are absent.** Scarcity is supposed to come from the tier ladder, the combat-vehicle
gate, BLUFOR garrisons and the OPFOR commander. Cutting a faucet now would leave the economy starved
once those land.

- **AP is not scarce for a zone-holding BLUFOR yet.** Its only sink is the ~6 advanced supports,
  180 AP for the whole set, realistically 90–130 AP bought. Supply is 20 AP × zone count one-time
  (~120 at six zones), plus ~60 AP/hr trickle at full control, plus 5–20 a mission — so liberating
  the map nearly funds the entire AP catalogue from captures alone. The two-currency premise does not
  bite until the combat-vehicle gate, garrisons and commander give AP something to buy.
- **Kill income is untouched** (1 CP per 10 kills per player, `server/server_init.sqf`). Intel is
  held down by a smaller reward and a thinner drop rather than a cap; kill income has had neither. A
  large co-op team in a long firefight banks it off activity alone, so whether it needs the same
  treatment is [open in the plan](economy_plan.md#open-questions).
- **First-capture front-loading.** 25 CP + 20 AP times the zone count is a lump paid in the opening
  hours, ~2/3 of everything AP can currently buy. On a large map that is a meaningful head start; the
  throttle does not touch it, since it rewards an action rather than a holding.
- **OPFOR AP accumulation.** Until the commander lands, OPFOR earns from four faucets and spends only
  on hardpoints, so the pool climbs with nowhere to go — and it trips the live `WARCOM_opfor_ap > 100`
  gate in `server/missions/fnc_missionPatrols.sqf` / `fnc_missionPatrolswithintel.sqf` near
  permanently, so side-mission guards are almost always armoured. Widening town worth to 1–5 raised
  the OPFOR AP faucet by roughly half, which compounds this. Expected, and resolves when the
  commander's sinks drain the pool; it is not a leak.
- **CP abundance versus vehicle price.** Light vehicles now cost ~1–5 CP against a CP economy the
  reroute roughly doubled, so their price is close to free. That is intended — hiring and light
  transport are not meant to be gated by cost — but it means the CP half of the catalogue is legible,
  not load-bearing, until per-use CP lands.

## A second-pass one-currency two-figure question

Town worth is a single figure (`civ_town_ap`, 1–5) paid as CP to a BLUFOR town and AP to an OPFOR
one. The plan allows OPFOR its own per-town AP rate distinct from the BLUFOR CP figure; the first pass
unified them for simplicity. If OPFOR town income needs to move independently of BLUFOR's, this is
where a second array goes.
