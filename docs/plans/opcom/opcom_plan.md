# OPCOM: remaining work

This plan holds what is left to build of the opposing commander: the archetype, a re-issue span per order, one
difficulty setting, and the tuning that settles in play. The shipped design, and the reasons for each shape, are in
[`opcom.md`](../../info/gameplay/opcom.md). Each section names the part of that design it changes.

The sections marked **WIP** are first-pass decisions: they change as each chunk is built and played. Do not
pre-build: the tuning constants and engine-contact behaviours only settle by running the core.

## Archetype

**WIP.**

One archetype per campaign, a campaign setting chosen at start (Defensive, Balanced, Aggressive or Random), names the
record the commander plays ([`opcom.md` §Archetype](../../info/gameplay/opcom.md#archetype)). The snapshot already
stores the record's `archetype`, and a load never re-rolls it. A Random pick stays hidden: the config diary note
shows "Random", and nothing in play reveals it. The OPCOM debug page gains an Archetype row that overrides it for
testing. BLUFOR's commander always plays Balanced.

| Archetype | Weights toward | Attack lean |
|---|---|---|
| Defensive | Fortify, Reinforce, Build, `attack_qrf`, Patrol, Probe, Garrison | `attack_flank`: shape the fight, stake little |
| Balanced | no strong lean — the baseline | no lean — the baseline |
| Aggressive | Attack, Rapport, Arty saturate; leaves ground thin | `attack_assault`: direct, no setup leg |

A weight cannot override the ladder: an Aggressive commander with no armour tier fields none. Only the band overlap
gives the assault-to-flank ratio room, so the band thresholds and the two weights settle against each other in play.

Beyond its weights and mixes, an archetype sets the commander's patience: the muster ideal, minimum and expiry,
`OPCOM_SAVE_HORIZON` and `OPCOM_VALUE_HALFLIFE`. A patient, strategic commander musters and saves longer for a
properly executed attack; a flexible, aggressive one launches sooner at lesser odds. Every attack musters on the
Balanced figures, one global set (`OPCOM_MUSTER_IDEAL` 1.2:1, `OPCOM_MUSTER_MIN` 0.6:1), until 7.2 splits them.

| Chunk | Builds |
|---|---|
| **7.1** Records and the setting | the campaign setting, the records the other archetypes need, the debug-page override, and OPFOR's record's `archetype` set from the setting. The action table is already wired as each record's `actionWeight` |
| **7.2** Patience | the muster ideal, minimum and expiry per archetype, and `OPCOM_SAVE_HORIZON` and `OPCOM_VALUE_HALFLIFE` per archetype in place of the one global figure |

Phase 7 settles in play each archetype's action weights, Bank's included, since Bank's weight sets how thrifty the
commander is; its assault and flank weights against the band thresholds; the patience figures; and the set of
archetypes itself, which is not final.

## Re-issue: a span per order

**WIP.**

Today every order stamps one hold, `OPCOM_COMMIT_HOLD`, and only a unit at rest is drawable
([`opcom.md` §Commitment](../../info/gameplay/opcom.md#commitment-orders-are-sticky)). This change makes a marching
unit drawable again once its order's span runs out.

Each row of `DUWS_opcom_orders` (`taskings/orders/fnc_opcom_orders.sqf`) carries its order's re-issue span in ticks, and
`fnc_opcom_task` stamps `hold` as the tick + the span, floored at 0. The spans replace `OPCOM_COMMIT_HOLD`. An order
with no row reads −1.

| Order | Span |
|---|---|
| `guard`, `garrison`, `move`, `return` | 0 |
| `patrol`, `probe` | 12 (1 min) |
| `capture`, `intercept`, `errand`, `ferry` | −1, never |

- **The hold stays an absolute anti-flap lock**, not a success deadline: a marching unit is held the full span no
  matter what. Past its hold, a marching unit is drawable as one at rest is — a de-virtualised unit included (a new
  order pushes onto the live group), a unit stopped at a water leg included; a bound attack unit and a bound ferry
  carry are not.
- **The gate.** `DUWS_fnc_opcom_drawable` admits a marching unit once `DUWS_opcom_tick` reaches its `hold` and its
  order's span is 0 or more. Its other exclusions stand: a bound unit, a carrying hull, an engaged unit, and a
  garrison in a contested zone, and a combatant garrison in an awake zone. `DUWS_fnc_opcom_freeSweep` drops its own
  hold test, so a unit is drawable the tick it settles to rest. The ferry and taxi pools read the same gate.
- **`boundTo` still owns a bound unit.** A unit at rest carries no hold and a staging `move` has a span of 0, so the
  hold cannot keep an attack's unit out of the pool
  ([`opcom.md` §Ownership](../../info/gameplay/opcom.md#ownership-the-roster-has-to-skip-a-bound-unit)).
- **The incumbent pays.** A unit drawn off a march abandons no defense, so `DUWS_fnc_opcom_commitCost` adds its
  `expValue`, the Value of the order it drops, to its stake
  ([`opcom.md` §Cost](../../info/gameplay/opcom.md#cost)). `expValue` goes to 0 where an order's purpose ends without
  a send: `DUWS_fnc_opcom_attackClose` for the units it unbinds, `DUWS_fnc_opcom_captureEnd` and
  `DUWS_fnc_opcom_ferryHome`.
- **Sourcing.** A unit becomes drawable once its order ends, or mid-march once the order's span runs out
  ([`opcom.md` §Sourcing](../../info/gameplay/opcom.md#sourcing-hire-on-demand)).
- **Hand-driving** runs with the commander `off`, since the pick draws a hand-ordered unit once its span runs out.
- **Persistence.** Nothing new is saved: `hold` and `expValue` are tasking fields the snapshot already carries, and
  the spans are constants.

## Difficulty

One OPCOM difficulty setting sets the pick rate and the caps together
([`opcom.md` §Caps](../../info/gameplay/opcom.md#caps)). Today only the debug page's Difficulty row exists, and it
steps the pick rate alone.

## Settles in play

The picker, every action, the Values, the score and the roll are shipped. What is left is tuning, which is played
rather than designed:

- **Prices.** `OPCOM_AP_UNIT`, `OPCOM_AP_HARDPOINT`, `OPCOM_AP_REINFORCE`, `OPCOM_AP_FORTIFY`, the zone and asset
  prices, `OPCOM_AP_PER_KM`, `OPCOM_AP_RAPPORT` and `OPCOM_AP_PER_FORCE` (1), against the drip (`OPCOM_AP_DRIP_TICKS`,
  `OPCOM_AP_DRIP_FLOOR`, `OPCOM_AP_DRIP_TIER`). Whether a Fortify is priced on the whole tier or on the tenth it
  fields, since a Reinforce buys back the rest.
- **The score's shape.** `OPCOM_BANK_SCORE`, `OPCOM_PICK_TOP` and `OPCOM_PICK_SHARPNESS`
  ([`opcom.md` §The pick](../../info/gameplay/opcom.md#the-pick)), `OPCOM_VALUE_HALFLIFE`, `OPCOM_SAVE_HORIZON`,
  `OPCOM_TRAFFIC_HALFLIFE` and `OPCOM_TRAFFIC_SHARE`, `OPCOM_NEED_BASE_RATIO` (2.5), the town worth factor (5) and the
  exposure distances (5 / 10 km, 0.2 floor).
- **What an asset is worth.** A radio's reach, an OP's eyes and a gun's fire missions, in place of the coverage
  stand-ins, and the radio's defend ramp (`OPCOM_DEFEND_NEAR` 500 m, `OPCOM_DEFEND_FAR` 2 km) and overlap weight
  (`OPCOM_TOWER_OVERLAP` 1) against that reach. Where a mortar pit or an artillery battery sites, which is the gun
  reach and the standoff.
- **Caution.** `OPCOM_PWIN_FLOOR`, and `OPCOM_GRID_ZONE_ENEMY_FORCE` (8) — the force OPCOM believes every BLUFOR
  zone holds, which sets its baseline caution. Whether belief should carry a threat category, so that a build sites a
  typed counter: AT under armour, AA under air.
- **A surplus.** What the commander does with one, and whether it must spend rather than only can. The absorbers are
  reinforcing over upgrading, Garrison hires, and mustering, which hires the roles the roster lacks.
- **Commit and carry.** The re-issue spans ([§Re-issue](#re-issue-a-span-per-order)), `OPCOM_GARRISON_HEAL_RATE`,
  `OPCOM_FERRY_BOARD_GROUND` and `OPCOM_ROAD_DETOUR`. Whether a staging or Garrison taxi should set its riders down
  short of the target, as a QRF's does, rather than on it; whether a ground taxi needs its pickup drive timed out,
  which no carry phase does today.
- **Sourcing.** `OPCOM_AP_PER_KM` against the delay for a unit that marches rather than drives, whether Patrol should
  hire land combatants or only recon, and whether Garrison hires crowd zone Reinforce out of the defense AP.
- **Patrol.** `OPCOM_PATROL_SHARE` and `OPCOM_PATROL_FORCE_REF` (8, a rifle squad's force), which sets whether a
  hull patrols as readily as a squad. Whether a combatant's staleness stamp should count for less than a recon's,
  since it suppresses re-scouting for up to `OPCOM_BELIEF_EXPIRE` without having learned anything certain there;
  whether a resting unit should stamp at all, since it keeps its own ground off the patrol list while it sits;
  whether patrol needs a cap on the units out at once, the fallback being a count per campaign zone; whether a
  patrol left standing is walked on by the next pick or holds.
- **Garrison.** Whether the reserve pool should field a worn unit at its `effForce` rather than at its whole
  composition, which would make resting a cost rather than a free repair. Whether a withdrawal needs a `P(win)` of
  its own beyond the high λ a `return` routes at.
- **Attack.** The band thresholds and their overlap, each role's λ and how often a route is re-planned, the longest
  off-road leg a hull drives without stalling, `OPCOM_MUSTER_EXPIRY`, `OPCOM_QRF_EXPIRY`, `OPCOM_QRF_HALFLIFE`,
  `OPCOM_QRF_DROP_K`, how far short of the target a rally has to sit to be safe enough to be worth the extra march
  (`OPCOM_RALLY_K`), `OPCOM_MUSTER_HOLD`, `OPCOM_ATTACK_BREAK`, `OPCOM_ATTACK_COOLDOWN`, how far out a `flank`'s hook
  waits (`OPCOM_HOOK_K`), `OPCOM_ATTACK_UNITS`, `OPCOM_ATTACK_VEHICLE_BOOST`, `OPCOM_PROBE_SHARE`,
  `OPCOM_PROBE_FRESH`, `OPCOM_ARTY_CREEP_SHARE` and the creep's box.
- **Arty.** `OPCOM_ARTY_LETHAL`, `OPCOM_ARTY_ROUNDS` and `OPCOM_ARTY_WARN`: how often a sighting is fresh and close
  enough to shell at all now that belief is the only channel, how bunched BLUFOR actually stands, since that is what
  the Value turns on, whether the random rounds draw pays for the step it costs, and whether the telegraph gives the
  players enough to move on. Whether weighting by the clustered share of all fresh belief double-counts what the
  score already does, because a dispersed BLUFOR raises every Attack candidate, QRF included, by itself.
- **What the players see.** Whether they can tell the commander is acting on stale belief, and whether the intel
  system should surface it. Whether a fast airborne player crosses a recon's K between its once-per-tick samples
  unsensed, which a larger K against airborne players would fix.
