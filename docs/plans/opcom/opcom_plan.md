# OPCOM: the opposing commander

OPCOM is one server-side actor that turns the enemy's Army Power into pressure: it garrisons towns, tasks
squads, builds hardpoints, and lets low-reputation towns fight back. Its wallet and faucets are the economy's
([`info/economy.md`](../../info/gameplay/economy.md#faucets)); the hardpoint mechanics it draws from are
[`info/hardpoints.md`](../../info/gameplay/hardpoints.md); the standalone-siting economics are
[`info/opfor_area_of_influence.md`](../../info/gameplay/opfor_area_of_influence.md#band-siting). The published
game AI methods behind the design are in [`opcom_ai_comparison.md`](opcom_ai_comparison.md).

One thread runs on a 5 s tick (`OPCOM_TICK_PERIOD`): **perception** keeps the enemy's belief about BLUFOR,
**appraisal** weighs candidate actions and picks one, and **commitment** turns the pick into a sticky order.

Phases 1–5 are shipped, and the code under `src/duws/server/warcom/opcom/` is the source of truth for them. This doc
specifies what remains: persistence, then the archetype.
The sections marked **WIP** are first-pass decisions: they change as each chunk is built and played.

## Status

| Phase | State |
|---|---|
| 1–3, 4A, 4B, 4C — Perception, recruitment and tasking, orders driven by hand, the random picker with every action wired, and the weighted commander's score, shortlist and roll | [§Shipped](#shipped-the-substrate-the-loop-drives) — **shipped** |
| 4D — Hire on demand: every unit an action needs is a free unit or a hire, weighed in the pick | [§Sourcing](#sourcing-hire-on-demand-phase-4d) — **shipped** |
| 5 — Attack: a buildup and execution spine, assault, flank and the QRF, threat-aware routes where a role asks for one, the probe, and the fires split | [§Attack](#attack-phase-5) — **shipped** |
| 6 — Persistence: OPCOM's store saved and restored, then a campaign played across a save | [§Persistence](#persistence-phase-6) — **next** |
| 7 — Archetype: the campaign setting, the records the other archetypes need, and the commander's patience | [§Archetype](#archetype-phase-7) — WIP |

The ordering is forced by what the next phase reads and by what is worth playing before more is built.
**The Attack comes first**: an attack's role binds its unit through the 4D sourcing, and it is the
last phase that adds state worth saving — the attack records and their role bindings — and a save contract
written before it would be written twice, once for taskings and again for attacks. It is also the phase that
changes how the enemy fights, which is what a play-test is for. The cost is accepted rather than overlooked: until
persistence lands, every tuning pass runs inside one session.
**Persistence comes next**, and the archetype last, because the archetype leans between assault and flank, and
those rows do not exist until Phase 5 writes them: a set of one cannot be weighted. An attack musters against one
global pair of muster bars in the meantime, which the archetype later splits per record. Do not pre-build later
phases: the tuning constants and engine-contact behaviours only settle by running the core.

**Every wired action is scored before any new one is written**: an unappraised row returns its price and scores
break-even, so a half-appraised picker quietly favours whatever it cannot yet judge, and adding actions into that
only widens the blind spot. The archetype is last for the same reason: it multiplies scores it does not set, so
it has nothing to tilt until every row it weighs is there.

## Shipped: the substrate the loop drives

`src/duws/server/warcom/opcom/` holds it: `belief/` the perception and the influence grid, whose layers `_fri` (known
OPFOR) and `_ene` (believed BLUFOR) the scoring reads, with the traffic layer and the observation tracker the guns
are gated on; `taskings/` the orders, streaming, the carry, the fire mission and the attack record and its runner;
`appraisal/` the action list, every buy, the supply trucks, the roster,
the sources and lifts, the commit orders, the siting pass, the score and the pick; and `appraisal/value/` the score's
terms, one file each. The debug harness (`fnc_opcom_debug_task.sqf` and the Debug
menu's OPCOM pages) runs the orders by hand and spends no AP.

New work holds to:

- **Belief, never truth.** The commander plans against belief; only the sensors read live player state.
- **The engine resolves every fight**, and `P(win)` never dices one.
- **State** is numbers, strings and arrays only, and every time counts in ticks off `DUWS_opcom_tick`.
- **A lift is the commander's call, not the rider's.** A unit stopped at a water leg takes a ferry, a boat or a
  helicopter, the tick one is free or affordable (`fnc_opcom_ferry.sqf`), and a land-taxi — a truck, a car, an APC, an
  IFV or a transport helicopter — is sourced with the order it carries, when the pickup drive plus the carry beats the
  walk (`fnc_opcom_taxi.sqf`). Either lift is a free unit or a hire ([§Sourcing](#sourcing-hire-on-demand-phase-4d)).
  Both run the one carry. Only an assault's or a flank's staging leg, a Garrison or a debug Move takes a land-taxi, so
  no lift carries a Patrol or a QRF, though a patrol stopped at a water leg still takes a ferry. Drawing a combatant
  hull onto taxi duty empties its post, like any other order that takes a garrisoned unit out.

Two terms carry one meaning each throughout:

| Term | Applies to | Meaning |
|---|---|---|
| **Contested** | a zone or a town | BLUFOR are assaulting the site: a sighting within one grid cell of its edge (`fnc_opcom_contested.sqf`) |
| **Engaged** | a unit | The unit is live and fighting BLUFOR. A virtual unit, a zone and a town are never engaged |

## Appraisal (Phase 4)

Every weight, Value, price and constant here is a first pass and changes as it is played.

On each pick, enumerate candidate `[action, target]` pairs, gate them cheaply, weight the survivors, shortlist the
best, and pick one by weighted random (`selectRandomWeighted`, the `fnc_createzone.sqf:117` idiom). No search or
lookahead. The pick pass runs inside `isNil { }` (unscheduled, no `sleep`) and enumerates every row with no deadline: a
deadline would hide the cost, not remove it, and a pass cut short biases the draw toward the rows enumerated first.
The pick executes after it in scheduled space, because an order plans a route and the router may yield. One pick a
tick by default (1 pick per tick); the difficulty setting changes the rate ([§OPCOM debug page and overlay](#opcom-debug-page-and-overlay)). The action list (`fnc_opcom_actions`) holds each
action's id, targets, gate, price, execute, weight key, Value and Cost.

`random` mode, switched on from the Debug menu's OPCOM page, is the unscored control it was built as: it draws an
action with a legal target uniformly, then one of its targets uniformly. The mode is `off` by default.

The score is one number — expected AP returned per AP spent:

```
score = archWeight[archetype][action] × P(win) × Value / Cost
```

`Value` and `Cost` are both Army Power, so the units agree; `archWeight`, the playing archetype's `actionWeight`,
tilts by action ([§Archetype](#archetype-phase-7)); `P(win)` scales to the expected return.

**Only an order that fights for its target carries a `P(win)`** — Attack, QRF included, Patrol and `arty_saturate`.
`arty_creeping` names none: its objective stands still where a sighting drifts, so there are no odds that it moved. A purchase does not: Reinforce, Fortify, Build and Rapport stock ground OPCOM already holds, and their
site is gated on being uncontested, so the term would read 1 wherever it was legal to spend. A buy scores
`Value / Cost`. A commit order that fights for nothing names 1 rather than leaving the term out, since its row still
has to name its Cost past it: a Garrison rests and a Probe observes.

- **`P(win)` — Lanchester-square.** `P(win) = r² / (r² + 1)`, with `r` = Σ`_fri` ÷ (Σ`_ene` + 1) over the target's
  3×3 block. Parity is a coin-flip, a 2:1 edge ≈ 0.8, a hopeless ratio floors near 0.
- **A defender's edge is its guns.** Both layers price force off one table (`belief/fnc_opcom_force.sqf`): a man
  is 1, a static MG 2, and a static GMG, AT or AA gun 4. A hardpoint or a zone's centre statics therefore weigh their
  guns on top of their garrison, so `r` reads a dug-in site above its headcount. Infantry in cover counts 1 a man,
  and no posture factor is planned: a higher bar only makes attacks fewer and larger. A sighted player adds
  `OPCOM_PLAYER_WORTH` (3) to their group's firepower, because a player can turn a fight that headcount says is lost.
- **The band** reads the same `r` to gate *how* an offensive runs (`≥2` assault; `0.5–2` assault or flank; `<0.5`
  hold). Every offensive then musters to the ideal bar before it launches
  ([§Commitment](#commitment-orders-are-sticky)). `P(win)` (whether) and the band (how) are two jobs off one `r`. The
  band gates once, at commit ([§Attack](#attack-phase-5)).

### Settles in play

The picker, every action, the Values, the score and the roll are shipped. What is left is tuning, which is played
rather than designed:

- **Prices.** `OPCOM_AP_UNIT`, `OPCOM_AP_HARDPOINT`, `OPCOM_AP_REINFORCE`, `OPCOM_AP_FORTIFY`, the zone and asset
  prices, `OPCOM_AP_PER_KM`, `OPCOM_AP_RAPPORT` and `OPCOM_AP_PER_FORCE` (1). Whether a Fortify is priced on the
  whole tier or on the tenth it fields, since a Reinforce buys back the rest.
- **The score's shape.** `OPCOM_BANK_SCORE`, `OPCOM_PICK_TOP` and `OPCOM_PICK_SHARPNESS` ([§The pick](#the-pick)),
  `OPCOM_VALUE_HALFLIFE`, `OPCOM_SAVE_HORIZON`, `OPCOM_TRAFFIC_HALFLIFE` and `OPCOM_TRAFFIC_SHARE`,
  `OPCOM_NEED_BASE_RATIO` (2.5), the town worth factor (5) and the exposure distances (5 / 10 km, 0.2 floor).
- **What an asset is worth.** A radio's reach, an OP's eyes and a gun's fire missions, in place of the coverage
  stand-ins, and the radio's defend ramp (`OPCOM_DEFEND_NEAR` 500 m, `OPCOM_DEFEND_FAR` 2 km) against that reach.
  Where a mortar pit or an artillery battery sites, which is the gun reach and the standoff.
- **Caution.** `OPCOM_PWIN_FLOOR`, and `OPCOM_GRID_ZONE_ENEMY_FORCE` (8) — the force OPCOM believes every BLUFOR
  zone holds, which sets its baseline caution. Whether belief should carry a threat category, so that a build sites a
  typed counter: AT under armour, AA under air.
- **A surplus.** What the commander does with one, and whether it must spend rather than only can. The absorbers are
  reinforcing over upgrading, Garrison hires, and mustering, which hires the roles the roster lacks.
- **Commit and carry.** `OPCOM_COMMIT_HOLD`, `OPCOM_GARRISON_HEAL_RATE`, `OPCOM_FERRY_BOARD_GROUND` and
  `OPCOM_ROAD_DETOUR`. Whether a taxi should set its riders down short of the target rather than on it; whether a
  ground taxi needs its pickup drive timed out, which no carry phase does today.
- **Patrol.** `OPCOM_PATROL_SHARE` and `OPCOM_PATROL_FORCE_REF` (8, a rifle squad's force), which sets whether a
  hull patrols as readily as a squad. Whether a combatant's staleness stamp should count for less than a recon's,
  since it suppresses re-scouting for up to `OPCOM_BELIEF_EXPIRE` without having learned anything certain there;
  whether a resting unit should stamp at all, since it keeps its own ground off the patrol list while it sits;
  whether patrol needs a cap on the units out at once, the fallback being a count per campaign zone; whether a
  patrol left standing is walked on by the next pick or holds.
- **Garrison.** Whether the reserve pool should field a worn unit at its `effForce` rather than at its whole
  composition, which would make resting a cost rather than a free repair.
- **Arty.** `OPCOM_ARTY_LETHAL`, `OPCOM_ARTY_ROUNDS` and `OPCOM_ARTY_WARN`: how often a sighting is fresh and close
  enough to shell at all now that belief is the only channel, how bunched BLUFOR actually stands, since that is what
  the Value turns on, whether the random rounds draw pays for the step it costs, and whether the telegraph gives the
  players enough to move on. Whether weighting by the clustered share of all fresh belief double-counts what the
  score already does, because a dispersed BLUFOR raises every Attack candidate, QRF included, by itself.
- **What the players see.** Whether they can tell the commander is acting on stale belief, and whether the intel
  system should surface it. Whether a fast airborne player crosses a recon's K between its once-per-tick samples
  unsensed, which a larger K against airborne players would fix.

### The pick

The pick is three steps over the gated candidates.

1. Score every survivor by the formula above.
2. Keep the top `OPCOM_PICK_TOP` (10) by score and drop the rest.
3. Draw one of the ten with `selectRandomWeighted` on `score ^ OPCOM_PICK_SHARPNESS`.

The exponent is how decisive the commander is, and the only dial that changes its temperament without touching a
price or a Value. At 0 the draw is uniform across the ten; at 1 an action that scores twice as well is picked twice
as often, which reads as indecisive because a good action and a mediocre one differ by well under an order of
magnitude; above that the best candidate takes most of the probability, and a high value is all but greedy.

- **The shortlist is what keeps the roll honest.** Scores span the whole candidate set, so a proportional draw over
  every survivor hands a long tail of poor actions a real share of the picks. Cutting to ten first bounds that tail,
  then the exponent shapes the choice among candidates that are all worth taking.
- **A candidate is an `[action, target]` pair,** so one action's targets can fill several of the ten slots. That is
  the point: with a score to rank them, a zone that needs reinforcing three places over is three good buys, not one
  action crowding the list.
- **`random` mode stays the unscored draw** — uniform over the actions, then over the chosen action's
  targets, never over a shortlist — so the debug page keeps a control to compare the weighted commander against.

### Candidates

| Action | Targets swept |
|---|---|
| Bank | one null |
| Zone Reinforce | each uncontested OPFOR zone below full strength |
| Zone Fortify | each uncontested OPFOR zone below tier IV |
| Zone hardpoint Build | one action per unlocked ring type, its targets every uncontested OPFOR zone with a free hardpoint slot (`fnc_hardpoint_zone_cap`) |
| Town Reinforce | each OPFOR-band town below full strength |
| Town Fortify | each OPFOR-band town below tier IV |
| Rapport | each town above −15 and below +10 that OPFOR's area of influence covers (`fnc_aoi_opfor_covers`) |
| Standalone hardpoint Build | one action per unlocked standalone type, its target the band cell the siting pass picks by cover Value ([§Asset siting](#asset-siting)) |
| Tower / OP / mortar / battery Build | one action each, under the type's cap, target the band cell the siting pass picks by the type's own rule ([§Asset siting](#asset-siting)) |
| Minefield | one action per variant (AT, AP), target the band cell the siting pass picks by traffic, a belt 150 m deep and 500 m to 1.5 km long |
| Attack assault, Attack flank | each BLUFOR-held zone, each town they have garrisoned, and each attack of the row's kind still in buildup that needs more units; flank only below band 2 and from the target's own landmass, and a source across water only as infantry ([§Attack](#attack-phase-5)) |
| Attack QRF | each cluster of BLUFOR sightings inside OPFOR's area of influence with no QRF on it, and each QRF still in buildup that needs more units ([§QRF](#qrf-an-attack-on-a-moving-cluster)) |
| Patrol | each sampled stale cell, one unit apiece, taken by the recon or land combatant, free or hired, that scores best |
| Probe | each assault or flank target whose 3×3 block reads stale and has no probe already on it, and that an Attack can source or a buildup stages for, one unit apiece, sourced from Patrol's rows |
| Garrison | each open zone under the garrison cap ([§Caps](#caps)), taken by the combatant, free or hired, healthy or worn, that scores best |
| Arty saturate | each fresh belief sighting in range of an owned battery that is not firing or held by a creep and has a gun off cooldown |
| Arty creeping | each attack, assault or flank, in buildup or execution, with no creep yet, whose target an owned battery reaches that is not firing or held by a creep and has a gun off cooldown |

An action that needs a unit offers each target with the best source for it, a free unit or a hire
([§Sourcing](#sourcing-hire-on-demand-phase-4d)). An attack offers a package of them instead
([§Attack](#attack-phase-5)).

### Value

Value is the AP worth of what an action delivers. Every build, refill and tier reads slow state only: threat
(`_ene`) shifts tick to tick, while the trucks and buys it would drive take minutes and stand for the campaign, so
threat drives only the fast actions — the QRF and attack staging. A standalone build or a minefield also reads the
traffic layer ([§Need and cover fields](#need-and-cover-fields)): built from sightings, it fades over half an hour,
so it moves no faster than a truck delivers.

- **Worth** is a holding's fixed AP figure. A zone's is `_points`, its radius ÷ 10 (35–50 at the default radii). A
  town's is its level `civ_town_ap` (1–5, the figure its income pays) × a tunable 5, so 5–25 and always below a
  zone.
- **Exposure** (0–1) is how close the holding sits to BLUFOR-held ground: 1 within 5 km, falling in a straight line
  to 0.2 at 10 km. OPCOM knows every zone and town owner for free, so exposure moves only when ground changes hands.
  OPCOM holds the player HQ's position from the start behind a hidden flag, and a hidden HQ counts toward nothing;
  the first BLUFOR sighting within 2 cells of it flips the flag for good, checked once in
  `fnc_opcom_belief_upsert`. Until the first capture or that reveal, exposure sits at its floor everywhere and
  OPCOM defends evenly.
- **Gain** (0–1) is the share of the job a partial action finishes: the force a purchase adds ÷ the force the
  holding fields at full strength **on its own current tier**, or 3/10 for Rapport, whose −3 step is three tenths
  of a flip. Measured against the top tier instead, a small zone's refill read as a few percent of a zone it will
  never be, so every buy scored a fraction of what it was worth and the commander banked rather than defend. A
  Fortify's gain is the size of the jump against what the holding has now, since it buys the next tier rather than
  filling this one. Two holdings on different tiers therefore compete on how finished each is, which is the
  question that matters at each of them; worth and exposure still separate a big frontline zone from a small rear
  one.

| Action | Value |
|---|---|
| Zone or town Reinforce / Fortify, zone hardpoint | worth × exposure × gain |
| Standalone hardpoint, minefield | Σ over its 5×5 block of need × the cover it adds ([§Need and cover fields](#need-and-cover-fields)) |
| Radio tower | Σ worth of the towns it newly brings under OPFOR's area of influence × defend |
| OP | build price × the share of its 5×5 block (`OP_OBSERVE_K`) that no other OP watches, sea excluded |
| Mortar pit, artillery battery | build price × the share of its reach that is OPFOR ground no gun of its own type reaches |
| Rapport | town worth × skew × 3/10, with skew = max(0.1, 1 − \|rep\| ÷ 10) |
| Attack QRF | Σ need over the lead sighting's 7×7 block × min(1, the cluster's summed force ÷ (Σ `_fri` over its 3×3 + 1)) |
| Attack assault, Attack flank | the zone's `_points` |
| Patrol | Σ need × staleness over the unique cells within its reach of the line it walks, × its scale, × `OPCOM_PATROL_SHARE` (0.2). A recon's reach is `OPCOM_RECON_K` and its scale 1; a combatant's reach is its engage reach (`DUWS_opcom_streamK`) and its scale its threat, `effForce` ÷ `OPCOM_PATROL_FORCE_REF` |
| Garrison | the defense the unit adds at the zone, worth × exposure × unitForce ÷ (the zone's current force + unitForce); for a worn free unit on `guard`, the larger of that and the rebuy its heal recovers, `(fullForce − effForce) × OPCOM_AP_PER_FORCE`. A unit already resting in `garrison` heals where it stands, so its heal is no reason to move it |
| Probe | the mean staleness over the target's 3×3 block × the stake at that target × `OPCOM_PROBE_SHARE` (0.25). The stake is the cheapest Attack package's `Cost` there, or the force a buildup already binds at `OPCOM_AP_PER_FORCE` |
| Arty saturate | net `effForce` killed × `OPCOM_AP_PER_FORCE`: believed force within `lethal × √rounds` of the aim point, less OPFOR's own force inside the spread, × that force's share of all fresh belief |
| Arty creeping | the parent offensive's staked force × `OPCOM_AP_PER_FORCE` × `OPCOM_ARTY_CREEP_SHARE`, since a creep buys that wave's survival rather than kills |

- **Rapport favours a neutral town.** A town near −10 turns anyway on the free area-of-influence drift, and a −3
  step barely moves one near +10. The skew is 1 at 0, 0.5 at ±5 and 0.1 from ±9 out, so a town between −15 and −10
  scores at the floor; a town at +10 or more is BLUFOR-held and no target.
- **Garrison gathers the QRF pool.** A unit counts once: a worn unit's Value is the larger of defense and heal,
  never the sum, because one unit serves one role at a time. Its defense share shrinks as the zone stacks up, so
  garrisons gather where exposure is high, and a QRF pool forms there with no roster table.
- **A probe buys belief, not ground.** `_ene` decays, so a stale objective yields a wrong `r`, and every figure
  read off it — `P(win)`, the band and both muster bars — is wrong with it. A probe closes on the objective until its
  3×3 block reads fresh, which is the whole of its resolve: it takes no ground, holds none, and names a `P(win)` of
  1. Its Value is the error it removes, so it scales with the stake about to be laid on that reading and is worth
  nothing where belief is already fresh. Recon wins the row with no preference written into it: `OPCOM_RECON_K` reads
  the block from further out and a `noncombat` unit or a hire abandons no defense, so recon buys the same reading at
  a lower Cost. A land combatant has to close, and against a dug-in garrison it draws fire and often dies — which
  still bought the reading, and is the only way to read a garrison that observation from outside cannot see. Patrol
  is the standing sweep over stale valuable ground; a Probe is one objective, refreshed now.
- **A land-taxi is worth the time it saves.** That is the order's Value landing sooner, priced by the delay discount
  (`DUWS_fnc_opcom_taxiWorth`). The lift is sourced with the order at commit, so it is priced on an order not yet
  sent, never on a unit already marching.
- **Lift sources compete on saving less Cost.** Only the lift with the best net carries a rider, so a transport
  helicopter takes the long rides its time saving pays for and a truck keeps the short ones. On score alone the truck
  would take every ride, because its lift is more than a third of the helicopter's at under a third of the price. A
  ground hull's drive is priced at `OPCOM_ROAD_DETOUR` (1.3) × the straight line, since it keeps to the roads a
  helicopter flies over. With a 2 km pickup the helicopter wins from a ride of about 8.5 km for an order worth 40,
  14 km for 20 and 21.5 km for 10.
- **The QRF share** is how much of the local defense the sighted cluster can overwhelm. `P(win)` says whether the
  QRF can win, and a QRF short of the odds musters more units rather than sending none, so a platoon is worth
  stopping and no lone small unit is thrown at it.
- **Staleness** is min(1, ticks since the cell's last sweep in `DUWS_opcom_grid_seen` ÷ `OPCOM_BELIEF_EXPIRE`).
  The share holds Patrol below the ground it sweeps, since a patrol takes and protects nothing itself.
- **Every unit on patrol resets the staleness timer, omniscient or not.** Staleness asks when OPCOM last looked at a
  cell, never how sure it is of what it saw, so a rifle squad walking a valley stamps it as a recon does
  (`fnc_opcom_patrol_sense`). A resting unit stamps its own reach too, which keeps the ground OPFOR sits on off the
  patrol list for as long as it sits; a `noncombat` hull that is no recon stamps nothing, since a truck on an errand
  is not out watching ground. What the stamp is not is proof: only a `recon` unit's guaranteed sweep also
  stamps belief for every BLUFOR group in reach and clears the rows it disproves, because a fallible look that comes
  up empty proves nothing (`fnc_opcom_cover_clear.sqf`).
- **The two kinds scale on different axes.** A recon's worth is the reach of its certain bubble, so its Value counts
  every cell within `OPCOM_RECON_K` of its line at face value. A combatant sees only what it can fight over, so its
  Value counts the narrower engage reach and scales by the threat it walks with, `effForce` ÷
  `OPCOM_PATROL_FORCE_REF`. Scaling by threat is what keeps a hull patrol-eligible at all: Cost already prices the
  force staked, so an unscaled Value would have the cheapest infantry take every patrol and leave the hulls parked.
  With it, a tank's patrol and a squad's score alike and the pick chooses on the delay and on the defense each
  abandons.
- **A combatant's guaranteed reach stays nil.** Only the `recon` flag buys a certain sighting, whatever the reach it
  buys it over; a rifle squad reports what it happens to see as any live OPFOR group does, fallibly
  (`fnc_opcom_sense`), and stamps only that it passed. Selling certainty to every rifle squad would leave the recon
  rows nothing to buy.
- **Patrol is how OPCOM keeps presence between its zones.** It sweeps a line rather than sitting, and settles to
  `guard` where it was sent (`fnc_opcom_stepMove`), so it stays drawable, deposits its force on the `_fri` layer
  where it stands, streams live when players come within its K, and is the nearest unit the next Attack sweep, QRF
  included, can bind. The staleness stamp is what spreads the units: ground just swept scores nothing, so the next pick
  takes a line elsewhere, and the field decays that ground back in over `OPCOM_BELIEF_EXPIRE` rather than leaving it
  worthless for good. The ground a unit leaves behind is not added back — its Cost already prices the defense it
  abandons.
- **An asset is worth the ground it covers that nothing of its kind covers already**, so a second mortar sited on
  the first one's ground scores nothing and the commander spreads its assets rather than stacking them. A radio's
  towns, an OP's cells and a gun's reach are properties of the ground an asset overlooks, not of the cell it stands
  on, so no asset reads the need field. A gun's reach is sampled at 81 lattice points, since testing every cell of a
  20 km disc against the area of influence would not fit the pick's unscheduled pass, and the whole disc is the
  share's denominator, so reach over sea, BLUFOR ground or past the play box counts against a site. Overlap counts
  against the asset's own type: a pit answers a contact in seconds where a battery shells across the map, so neither
  does the other's job. An asset still siting or on its truck counts as standing, as it counts against its type's
  cap, or consecutive ticks send two of a type to the same ground.
  What a radio's reach, an OP's eyes and a gun's fire missions are actually worth, in place of these stand-ins,
  settles in play ([§Appraisal](#appraisal-phase-4)).
- **Defend trades a radio's reach against its life.** The towns worth covering sit toward the front, where a mast
  is also easiest to reach and clear, so coverage pulls the mast forward and defend pulls it back. Defend (0–1) is
  exposure's mirror, measured to OPFOR's own fixed defenses instead of BLUFOR's ground: 1 within
  `OPCOM_DEFEND_NEAR` (500 m) of an OPFOR zone's edge or a standing OPFOR hardpoint, falling in a straight line to
  a 0.2 floor at `OPCOM_DEFEND_FAR` (2 km) — the span a band candidate can sit at, since `DUWS_fnc_aoi_bandPos`
  draws from a zone's edge out to `AOI_ZONE_REACH`. Only standing defense counts, never a tasking, which drives
  away tomorrow.
- **A mast's Value is an absolute AP sum** where an OP's and a gun's are a share of their own footprint, because
  the towns in reach vary by site: a share would score one town out of one as highly as five out of five.
- **The tower amplifier is a bonus, not a reason to build.** Every standing tower, to `AOI_OPFOR_TOWER_CAP` (5),
  adds 1 to the reputation push on *every* OPFOR-covered town wherever the mast stands
  (`fnc_zonesundercontrol.sqf`), which at the cap flips a neutral town five times faster. It stays out of Value:
  it reads the same at every candidate site, so it ranks nothing, and a mast is bought for the towns it reaches. A
  mast that reaches no uncovered town scores 0.
- **A minefield is valued on its ground, not as an asset.** It is flat-priced like the assets above, which is a
  pricing likeness and not a Value one: what a minefield is worth is the ground it denies, the same question a
  standalone gun nest answers. It leans on the traffic layer harder than any other build — a field on a road
  nobody drives is worth nothing, and one on the route BLUFOR take every trip is the cheapest ground denial
  OPCOM can buy.
- **The mix steers the build types toward a target share.** Every zone and standalone Build and every Minefield Value
  above is × its type's mix, (target + 1) ÷ (standing + 1). The target is the type's share × every hardpoint of the
  types in the mix, seeded ones and builds on their way included; the standing count is the type's own. The share is
  the type's weight over the sum of its archetype's `hpMix` ([§Archetype](#archetype-phase-7)), so 1 in every type spreads
  evenly and a 2 makes a type twice as common as a 1. Balanced's `hpMix` is MG 2, roadblock 2, AT 1, AA 1, GMG 1, and
  AT and AP minefield 0.5 each. The asset builds (tower, OP, mortar and battery) stay out of the mix and weigh each by
  its own action weight ([§Archetype](#archetype-phase-7)): a cap, not a share, bounds how many stand, and a flat-capped type
  in the mix would hold a share its cap never fills, which pushes every other type over its own. A minefield is
  counted by variant, which OPCOM records for each belt it lays; a field it did not lay carries no variant on record
  and stays out of the mix, though it counts against the caps. The mix reads 1 at the target, below 1 past it and
  above 1 short of it, so a cheap type cannot fill the caps ahead of the rest. It tilts the pick and never sets a
  quota: a type past its share still builds where its Value is high enough. The +1 keeps a type with none standing
  finite. A type outside the mix reads 1, and random mode ignores Value, so it ignores the mix too.
- **A hire takes the same mix over the roster.** A hire source's Value is × its row's factor off its archetype's
  `recruitMix`, the same formula counted over OPCOM's live units by menu row, supply trucks included. The shares are
  taken over only the rows the faction can field now: a row it cannot hire would hold a share nothing can fill, and
  push every other row over its own. Balanced's `recruitMix` is rifles 8, weapons team 4, truck 3, APC 3, IFV 2,
  car, foot recon and car recon 2 each, MBT, boat, recon and transport helicopter 1 each, attack helicopter 0.5 and
  jet 0.25: an even spread would field as many jets as rifle squads.
- **Delay.** Value that lands later counts for less: Value × 0.5 ^ (ETA ÷ `OPCOM_VALUE_HALFLIFE`, 360 ticks), with
  ETA in ticks from the straight-line distance and the unit's per-cell speed (`DUWS_opcom_speed`). The distance is
  not the route's, since planning a route per candidate would not fit the pick's unscheduled pass. Every action
  that needs a unit takes the discount from where its source starts; a zone action's ETA is 0.
- **No route-risk discount, no emergency reserve.** A truck's odds en route would read threat, so the risk stays
  with the player as counterplay. A QRF binds free combatants, often ones a Garrison banked at an
  exposed zone, or hires at the open zone nearest the sighting ([§Sourcing](#sourcing-hire-on-demand-phase-4d)).

### Need and cover fields

A standalone hardpoint's Value comes from cover over the whole map, not over one zone, because a zone's ring already
defends its zone: weighted toward OPFOR's holdings, and rewarding cover over the sparse sectors between them. Need
and cover span every land cell; standalone and minefield candidates are band cells only. Both change when a
hardpoint is built or cleared or ground changes hands, and need also moves with the traffic layer.

- **Need** (AP). Each OPFOR holding — an OPFOR zone, or a town at −10 or below — spreads worth × exposure over the
  7×7 block around its cell (`OPCOM_NEED_K` 3), with weights of 4, 3, 2 and 1 by Chebyshev ring, normalised over the
  block's land inside the play box so they sum to exactly that figure at a coast or the box edge too. Every band
  cell — a land cell whose centre the area of influence reads OPFOR-positive, outside every zone — also carries a
  flat base for the sparse sectors: the average zone's pull per cell (worth ÷ 49) ÷ `OPCOM_NEED_BASE_RATIO` (2.5),
  × the cell's exposure, so a holding pulls harder than a gap but not so hard that hardpoints cluster around zones.
  Each standing asset hardpoint spreads its build price the same way and becomes an asset worth protecting; assets
  site by their own rules ([§Asset siting](#asset-siting)), so the cover network builds up around them into the
  gaps.
- **The holdings and the band base rebuild only when their inputs change** — BLUFOR's zones and FOBs, the HQ
  reveal, a town crossing a band, a radio tower built or cleared. The band test runs the area of influence over
  every land cell in the box, so the rebuild runs in its own spawned thread and swaps the field whole when done.
  Any other OPFOR hardpoint built or cleared changes only the deposits, so the tick re-spreads them over the cached
  base.
- **Traffic** (force), a belief layer. Each sighting raises its cell to the larger of the cell's current value and
  the sighting's force; the value halves every `OPCOM_TRAFFIC_HALFLIFE` (360 ticks, 30 min), so a cell BLUFOR
  crosses once fades within the hour and a route they use every trip stays lit. The decay is applied when a cell is
  read, never in a sweep. Need adds each land cell's traffic × `OPCOM_AP_PER_FORCE` × `OPCOM_TRAFFIC_SHARE` (0.5),
  so hardpoints site on the ground BLUFOR use as well as around what OPFOR holds.
- **Cover** (0–1). Each OPFOR hardpoint within 2 cells, zone rings included, covers half of what is left:
  0, 0.5, 0.75, 0.875, so a new hardpoint adds half of what each cell in its reach still lacks. Every type shares
  that reach. A build still siting or on its truck counts, as an asset does
  against its cap, so the siting pass never sends a second truck to ground the first is still driving to.
- **The grid overlay shows all three.** The Views page's OPCOM need/cover/traffic toggle draws each cell's need,
  cover and traffic, so the fields can be checked in play before a Value leans on them. Each grid layer toggle is
  off by default: the overlay opens as the lattice and the tasking units alone.
- A first hardpoint at a frontline zone worth 40 earns about 10, beside that zone's Reinforce at 15; one beside
  other hardpoints earns little.

### Cost

- **Spend** actions (Reinforce, Fortify, Build, Rapport, Arty) pay fresh AP at the prices in
  [§What AP buys](#what-ap-buys); a supply-gated one adds its truck's source Cost
  ([§Sourcing](#sourcing-hire-on-demand-phase-4d)).
- **Commit** actions (the three Attack rows, Patrol, Probe, Garrison) stake units. A hire's `Cost` is its
  price ([§Sourcing](#sourcing-hire-on-demand-phase-4d)); a free unit's is the AP to rebuy the force
  (`Σ effForce × OPCOM_AP_PER_FORCE`) plus the defense the unit abandons, read off the grid at its home cell with no
  counterfactual rebuild:

  ```
  defenseAbandoned = homeWorth × min(1, 1 / r_home) × min(1, unitForce / Σ_fri_home)
  ```

  `homeWorth` is the home zone's `_points` (0 for a unit that holds no zone). `r_home` is the 3×3 ratio there, so a
  safe backline costs almost nothing to draw from and a threatened one its full worth. The last term is the share of
  the local OPFOR force that leaves, capped for a deposit that spreads past the block. A draw takes only
  OPCOM-recruited units, never a zone's base garrison, so the term prices a thinned zone, never an empty one; a
  `noncombat` unit covers nothing and abandons 0.

  The rebuy prices the whole stake at every ratio, never the expected losses. The square law has a win at ratio `r`
  keep √(1 − 1/r²) of the force, so a Cost of expected losses would score a 3:1 attack 12 times above an even one,
  where the whole stake scores it 1.8 times above. That steep a preference has OPCOM attack only at crushing odds,
  which is no fight for the players. How often OPCOM attacks is Attack's `archWeight`'s job, not the Cost's.

### Gate and the savings goal

- **Gate.** A zone or town action drops while that site is contested — the same rule and the same reach for both, so a garrison buy reads one answer wherever it lands. An action that needs a unit drops a
  target with no source: no eligible unit free, and no eligible row the faction can field under the unit cap
  ([§Sourcing](#sourcing-hire-on-demand-phase-4d)). No action draws a unit garrisoned in a contested zone. Patrol
  draws, free or hired, every unit carrying the `recon` flag, the helicopter included and `noncombat` or not, and
  every **land** combatant — infantry, wheeled and tracked.
  A `noncombat` row that is not recon stays out, and so does combat air: the faction's air scout is the recon
  helicopter, and an attack helicopter or a jet crosses the ground it would sweep faster than a tick. Probe draws
  that same pool and drops a target whose block already reads fresher than `OPCOM_PROBE_FRESH` (0.1) or that holds a
  bound probe, so one reading is never bought twice. Garrison draws every free combatant, healthy or worn, except one already homed at the target
  zone. An action past one of OPCOM's caps drops too ([§Caps](#caps)). The random draw drops any action the wallet
  cannot cover.
  An offensive that does not muster drops below `OPCOM_PWIN_FLOOR` at commit. An Attack musters, so its source drops
  only below `OPCOM_MUSTER_HOLD` (0.5:1), and the minimum bar is its floor at launch
  ([§Commitment](#commitment-orders-are-sticky)).
- **An unaffordable action is still scored.** When the top scorer is unaffordable and its ETA,
  `(price − wallet) ÷ income rate`, is inside `OPCOM_SAVE_HORIZON`, it is the savings goal and OPCOM banks that
  tick; an action that outscores it later, such as a QRF, still commits. Past the horizon it drops, and the pick
  runs over the affordable top `OPCOM_PICK_TOP`. Without the goal, cheap actions spend every refill and a better,
  dearer one never becomes affordable. The income rate is OPFOR's last economy payout ÷ the economy period
  (`DUWS_econ_period`, 30 min), so no goal stands before the first payout. The horizon starts at one economy
  period, 360 ticks, since income lands in lumps and a shorter horizon would rarely hold a payout. Random mode
  still draws only what the wallet covers.
- **Bank** is a candidate, not a policy: `OPCOM_BANK_SCORE`, a flat score below the break-even of an action that
  returns exactly what it costs, so it wins when nothing on the shortlist pays for itself, or when a savings goal
  stands. Its archetype weight is what sets how thrifty the commander is (7.1).

### Caps

A flush wallet otherwise stacks units, trucks and hardpoints without bound, because a buy's Value shrinks as its
site fills but never reaches 0. A capped action returns no targets, so it is never scored and never a savings goal.
The debug harness spends outside the pick and is not capped.

| Cap | Drops | Counts |
|---|---|---|
| `OPCOM_CAP_UNITS` (50) | every hire source except a truck | every OPCOM unit alive except the supply trucks |
| `OPCOM_CAP_GARRISON` (10) | a Garrison's zone | the combatants homed at that zone, the set its reserve pool fields |
| `OPCOM_CAP_SUPPLY` (10) | every supply action | the trucks out on an errand |
| `OPCOM_CAP_HP_PER_ZONE` (12) × zones | every Build and Minefield | every standing OPFOR hardpoint of every type, towers, OPs and guns included, seeded ones included, and every build still siting or on its truck |
| per type × zones | a Build or Minefield of that type | the same, by type ([§What the commander builds](#what-the-commander-builds)) |

- **Supply trucks sit outside the unit cap.** The supply cap bounds the trucks in flight. If the trucks counted, a
  full roster would stop every supply action.
- **The garrison cap is a zone's.** Only a zone homes an OPCOM unit: a town is taken by a unit that guards it, never
  one that garrisons it ([§Attack](#attack-phase-5)).
- **The hardpoint caps scale with the campaign's zone count,** because the seeded hardpoints count and the seed
  grows with the zones, at about 7 a zone. A flat cap would sit under the seed of a 40-zone campaign and far over
  that of a 10-zone one.
- **Difficulty sets the caps.** The OPCOM difficulty setting sets the pick rate and these caps together. Today the
  debug page steps only the pick rate ([§OPCOM debug page and overlay](#opcom-debug-page-and-overlay)).

### OPCOM debug page and overlay

The Debug menu's OPCOM page and the OPCOM AI overlay are shipped (`fnc_debug_menu.sqf`,
`fnc_debug_opcom_ai_overlay.sqf`). The page holds:

| Row | Does |
|---|---|
| Mode: weighted | Runs the scored pick. Shipped |
| Pick once: weighted | Runs one scored pick, whatever the mode. Shipped |
| Archetype | Overrides the campaign's archetype (7.1) |
| Difficulty | Steps the picks per tick through 0.25, 0.5, 1 and 2, carried as a debt so a rate below 1 picks once every few ticks. Shipped |

## Sourcing: hire on demand (Phase 4D)

OPCOM hires a unit only for the action that sends it (`appraisal/fnc_opcom_sources.sqf`). An action that needs a unit
weighs, in the pick, each free unit it may draw against a hire of each row that can do the job, and offers each target
with the source that scores best. A unit exists because an action sent it, and it stays drawable once that order
ends. Nothing is hired ahead of need, so no hire is a candidate of its own, and a combatant's zone defense is a job of
its own, Garrison.

| Source | Starts at | Price, charged | Cost, scored |
|---|---|---|---|
| Free unit | its own position | 0 | its stake ([§Cost](#cost)) + `OPCOM_AP_PER_KM` × distance |
| Hire | the open zone nearest the target that can raise the row, a boat at that zone's port | the row's `OPCOM_AP_UNIT` | the price + `OPCOM_AP_PER_KM` × distance |

The distance runs from where the source starts to where the action needs it: the target, or the rider for a lift.

- **One score picks the source.** Each source scores as its action would with that unit sent: `P(win)` with the
  source's force added at the target (`DUWS_fnc_opcom_pWinWith`), the Value discounted by the delay from where the
  source starts ([§Value](#value)), and the action's own Cost plus the source's. A hire's Value is also × its row's
  `recruitMix` factor, so the mix tilts both which row is hired and whether a hire beats a free unit.
- **Distance is scored, never charged.** `OPCOM_AP_PER_KM` (0.5) is what makes a near hire beat a far free unit. A
  free truck stakes its force, 2, against a 3 AP hire, so, the mix aside, a hire takes the errand once the free
  truck stands more than 2 km further off. A supply truck no longer pays for its drive.
- **A source under the floor is no source.** A source whose `P(win)` at the target is below `OPCOM_PWIN_FLOOR`
  drops, a hire as a free unit does, so OPCOM never hires for a fight it could not win even with the hire standing
  there.
- **A source the wallet cannot pay beats no other.** A target offers the best source the wallet covers. When a
  dearer source outscores it, the target also offers that one, so it can stand as the savings goal
  ([§Gate and the savings goal](#gate-and-the-savings-goal)).
- **The execute raises and routes every hire before it gives an order.** It hires through `fnc_opcom_recruit` with
  `_pay` false, since the candidate's price already carries the hire (`DUWS_fnc_opcom_raise`). A hire that cannot
  route is dismissed and the execute returns false, so the pick charges nothing and no order stands half-given.
- **The unit cap drops hire sources, never free units.** At `OPCOM_CAP_UNITS` an action draws only what stands; a
  truck hire stays outside the cap ([§Caps](#caps)).

| Action | Sources, free or hired |
|---|---|
| Attack assault, Attack flank | land combatants: rows with neither `recon` nor `noncombat`, on foot, wheels or tracks |
| Attack QRF | combatants, air included, less a land unit across water from its target |
| Garrison | combatants, air included |
| Patrol, Probe | `recon` rows, the helicopter included, and land combatants |
| Rapport, town Reinforce / Fortify, standalone and asset Build, Minefield | `supply` rows |
| A land-taxi for an assault's or a flank's staging leg, or a Garrison | `transport` rows on wheels, tracks or a rotor |
| A ferry | `transport` rows on water or a rotor |

A fire mission fires the guns OPCOM owns, so it sources no unit.

- **A land-taxi is sourced with the order it carries.** When a commit's unit is `transportable`, the sweep weighs
  walking against each lift source, free hull or hire, on its saving less its Cost (`DUWS_fnc_opcom_taxiSaving`).
  The best lift adds its saving to the candidate's Value, its price to the price and its Cost to the Cost. The
  execute routes the rider and the lift before it gives either an order, and commits neither when either fails, so
  a lift that cannot reach its rider charges nothing (`appraisal/fnc_opcom_lift.sqf`). Only a debug Move still binds
  the best free hull (`DUWS_fnc_opcom_taxiBind`), since the harness spends no AP.
- **A lift never prices an affordable order out of reach.** A lift's price is capped by what the wallet holds past
  the rider's, so walking stays on offer whenever the rider alone is affordable.
- **A hull is offered only over a dry straight line**, from the hull to the rider and on to the target. The route
  cannot be planned inside the pick, and without the test a ground taxi to an island target would score in every
  pick and fail in every execute, so the order never went. The line reads a bay as wet though a road runs round it,
  which costs a hull some coastal rides a rotor or the walk then takes.
- **A ferry spends no pick.** The crossing belongs to an order the pick already bought, and a scored Ferry row spent
  a pick of its own and could leave a low-value rider stranded for many ticks. Each tick, after the task step, every
  stranded unit takes the best lift it can have now (`DUWS_fnc_opcom_ferryDispatch`): a free boat or helicopter, or a
  hire of one that the wallet covers, ranked on the unit's committed Value. With neither, it asks again next tick, so
  a rider stranded at 0 AP crosses the tick the wallet covers a boat. The stage is off while the pick is, so a
  commander switched off spends nothing. The debug page's Ferry binds a stranded unit to the nearest free boat or
  helicopter that reaches it, by hand.
- **Garrison banks units into a zone.** Any free combatant, healthy or worn, or a hire raised at the zone itself, is
  a source. The unit rests in `garrison` and feeds the zone's reserve pool (`fnc_opcom_garrison.sqf`), so a survivor
  of any order is banked when the defense it adds outscores its other jobs, and a worn one heals there.
- **A unit heals only at rest in its zone.** Only the `garrison` order heals: never on guard, never on the march in,
  and never while the zone is contested, since a zone under assault is no rest. The heal resumes when the contest
  lifts, and the contested ticks bank nothing. A boat rests and heals at its zone's port, even where the port lies
  outside the zone's radius.
- **OPCOM builds up in AP, not in units.** Bank and the savings goal hold the AP an attack will hire with.
- **Only the pick hires**, and the ferry stage, which lifts a unit the pick already sent. The attack runner never
  spends: an open sends a package toward the ideal bar, and an attack still short stays a target of its row until
  later picks send it more, from free units or hires ([§Attack](#attack-phase-5)).
- **`fnc_opcom_recruit` stays the one hire.** Every source hires through it, and the debug page's Recruit list still
  calls it by hand.

Phase 4D settles in play `OPCOM_AP_PER_KM` against the delay for a unit that marches rather than drives, whether
Patrol should hire land combatants or only recon, and whether Garrison hires crowd zone Reinforce out of the
defense AP.

## Commitment: orders are sticky

A chosen action lands as a buy, or as an order on the unit it sends. The order carries a `hold`, `DUWS_opcom_tick` at
commit + `OPCOM_COMMIT_HOLD`, the earliest tick OPCOM may re-issue that unit's order. An Attack's units also carry a
binding to their attack record ([§Attack](#attack-phase-5)).

- **The hold is an absolute anti-flap lock** (KISS), not a success deadline: a committed unit is held the full span
  no matter what; a target that dies mid-hold is re-evaluated once it expires. Resting `garrison`/`guard` are
  unheld. Re-scoring fills free capacity and may re-task a unit only past its hold — a de-virtualised unit included
  (a new order pushes onto the live group), a live water crossing included; only a *bound* ferry carry is off-limits.
- **There is no retreat.** The engine owns a group in `COMBAT` and ignores a commanded withdrawal
  ([`arma_engine_gotchas.md`](../../info/architecture/arma_engine_gotchas.md#a-group-in-combat-behaviour-ignores-a-commanded-move-order)).
  A group that wins drops to `moving` and re-virtualises on clearing; one that loses dies. Recovery is winning.
- **An attack musters, then launches as one wave** (Phase 5). A muster is what buildup does: it binds
  force across ticks at a safe rally short of the target, one cell a bucket, then advances all together — it never dribbles units into contact,
  which no-retreat would turn into defeat in detail. It launches the tick its bound force reaches the archetype's
  **ideal** ratio over believed BLUFOR force at the target (1.5:1 baseline). At `OPCOM_MUSTER_EXPIRY` it launches if
  it holds at least the archetype's **minimum** (0.75:1 baseline), and is otherwise abandoned, its units returning to
  rest, so a player who keeps reinforcing cannot hold it forever. The baseline sits below an attacker's usual 3:1
  because a sighted player already counts as 1 + `OPCOM_PLAYER_WORTH`, so a believed 1.5:1 is already a hard fight
  for the players, and a 3:1 wave is one they can only survive. Both bars read believed force, so a mid-muster
  reinforcement raises them, and a Probe that refreshes the target moves them to whatever is actually there
  ([§Value](#value)). An attack in buildup commits below the odds it launches at, so the minimum bar is its floor
  at launch and `OPCOM_MUSTER_HOLD` (0.5:1) its floor at commit. Buildup is also how a force-short attack waits for
  units: an attack short of the ideal bar stays a target of its row, and a later pick sends it more from free units
  and hires ([§Sourcing](#sourcing-hire-on-demand-phase-4d)). A QRF musters on the same bars, where its units stand
  and over `OPCOM_QRF_EXPIRY` instead ([§QRF](#qrf-an-attack-on-a-moving-cluster)).

## Attack (Phase 5)

**Shipped**.

Attack is the one action that sends more than one unit, and it is three action rows, `attack_assault`, `attack_flank`
and `attack_qrf` ([§QRF](#qrf-an-attack-on-a-moving-cluster)). Each commits an attack record (`DUWS_opcom_attacks`,
`taskings/fnc_opcom_attack.sqf`) that runs two phases. **Buildup** places the units; **execution** runs the orders
that already ship. Assault and flank differ only in data — which roles each binds, where each one's lane ends and
what it waits on (`DUWS_opcom_attackRoles`) — so neither adds tasking code, and the QRF adds only what a moving target
needs. A one-unit Attack is the smallest `attack_assault`
([§Release](#release-the-stagger-lives-on-the-role-not-in-a-third-state)). Every other action sends one unit on one
order and binds nothing: the order ends on its own predicate, which frees the unit.

| State | Every bound unit is | Orders it uses | Ends on |
|---|---|---|---|
| `buildup` | staging or standing still. Nothing fights | `move`, settling to `guard` on arrival; none for a QRF, whose units hold where they stand | the launch predicate: every required bucket holding a unit, every bound unit at rest on its rally and the ideal bar met, or the minimum bar at `OPCOM_MUSTER_EXPIRY`, `OPCOM_QRF_EXPIRY` for a QRF ([§Commitment](#commitment-orders-are-sticky)) |
| `execution` | fighting for the target | `capture`, after `move` up its lane for a side bucket; `intercept` for a QRF | `resolve`: every bound unit back at rest, and no side bucket still on its lane |
| `done` | released back to the roster | — | — |

Buildup is where a muster happens: the ideal and minimum ratios and the expiry are its launch predicate, and a
force-short attack sits in buildup until later picks fill its buckets.

**This is what `move` is for.** A staging leg has to march to a point and hold it without fighting, without healing
and without stamping the staleness layer, which is `move` and no other order: a buildup's staging leg and a side
bucket's lane are its callers beside the debug page (`taskings/fnc_opcom_orders.sqf` is the table that knows every order).

**The runner**, each tick over every live attack (`DUWS_fnc_opcom_attackStep`): refresh each bound
unit's status; in buildup, any bound unit `dead` or lost → **abort** (release the survivors, no AP refund), because a
loss at the rally means BLUFOR found it; in execution a lost unit leaves the rest to finish; else test the current
state's transition, and each side bucket's wait and close. A unit a hand order takes over from the debug page counts as
lost. The runner sequences the states; the route and streaming machinery moves the units. There is
no planner: a new way to attack is a new entry of roles rather than a new subsystem.

### Ownership: the roster has to skip a bound unit

The free pool is every uncommitted `garrison`ed or `guard` unit, except one garrisoned in a contested zone. A unit
that reaches its rally settles to `guard`, which puts it straight back in that pool, and the next pick would send it
somewhere else mid-buildup. A `boundTo` key on the tasking record, holding its attack's id, is what
the roster's drawable test filters on (`DUWS_fnc_opcom_drawable`, `taskings/fnc_opcom_tasking_init.sqf`). `OPCOM_COMMIT_HOLD` cannot do this job: it
is an anti-flap lock of a fixed span, and a buildup outlives it.

One unit, one owner. Binding pulls a unit from the pool and a `garrison`ed draw strips that zone's reinforcement;
release returns it. An attack row is offered only when its band fits and the geometry holds; short a role, it
commits in buildup and waits.

### Release: the stagger lives on the role, not in a third state

Every bucket sets off at launch, but a side bucket closes on the target per role. A role may name another it
**waits on**, and a bucket of it holds `guard` at the end of its lane until that role reads `engaged`, has lost every
unit or has ended its fight (`DUWS_fnc_opcom_converge`). It never waits again after, since a lull in the fix's fight
would otherwise park a hook at its jump-off. The assault waits on nothing. The flank's `maneuver` waits on `fix`,
since an envelopment is worth nothing if it arrives before the defenders are committed to the front.

A per-role gate rather than a third state, because the alternative is one phase list per row and a runner that has
to know all of them.

| Row | Offered when | Roles | Release |
|---|---|---|---|
| `attack_assault` | every band from 0.5 | `attacker` in 1–3 buckets on a 3×1 line, one per cell | every bucket at once — one wave, never a dribble |
| `attack_flank` | band 0.5–2, a dry rally and a dry jump-off on some side | `fix` at the centre of a 3×1 line, `maneuver` in 1–2 buckets beside it | every bucket at launch; each `maneuver` hooks to its jump-off and closes once `fix` reads `engaged`, is lost or has ended its fight |
| `attack_qrf` | a sighting cluster with no QRF on it | `attacker` in 1 bucket, with no rally | at once, on `intercept` |

Each row's roles are an entry of `DUWS_opcom_attackRoles` (`taskings/fnc_opcom_attack.sqf`), keyed by the record's
kind, `assault` or `flank`. A QRF's one bucket is written by its sweep (`DUWS_fnc_opcom_qrfSweep`), since it has no
rally to stage. A flank needs no count of mobile units at commit: its enveloping
buckets are filled by later picks like any other, and a flank whose hooks stay empty leaves the fix to launch
alone on the minimum bar at `OPCOM_MUSTER_EXPIRY`.

- **Water decides who goes and how.** Every rally sits on the target's landmass (`DUWS_opcom_grid_mass`, a flood
  fill over the grid's land cells at init), so no bucket stages across water from its fight and a flank never takes
  a side the water cuts off. A source across water from its target reaches it only by ferry, which carries men alone
  and lands them a trip at a time, so it is offered only if it is transportable, and only to `attack_assault`: a
  flank's timing does not survive a landing by trips. An island with no dry cell on its landmass `OPCOM_RALLY_K`
  cells out gives no rally, so its assault stages where its units stand and crosses at launch.
- **A role is a bucket of units.** A bucket stages at one rally and holds any number of units, up to
  `OPCOM_ATTACK_UNITS` (10) across the attack (`DUWS_fnc_opcom_joinBucket`). An empty required bucket takes a join at
  any odds. Past that, a join comes only while the muster is short of the ideal bar, and goes to the bucket with the
  least force, so the frontage and the sides fill evenly. The ideal bar, not the bucket count, is what sizes an
  attack.
- **One pick sends a package.** An open or a join sends the best sources in score order until the bound force meets
  the ideal bar, the attack holds `OPCOM_ATTACK_UNITS`, or the wallet runs out (`DUWS_fnc_opcom_attackPackage`,
  `appraisal/fnc_opcom_sources.sqf`). One unit per pick left a muster to trickle in over picks that the rest of the
  action list competes for, and a QRF's window closed first. A hire row is raised again while the wallet and
  `OPCOM_CAP_UNITS` allow; a free unit serves once, as a member or as another member's lift. Each unit stages at the
  bucket `DUWS_fnc_opcom_joinBucket` would name for it. The package scores as one candidate: its Value is its weakest
  member's, since the attack goes only once its last unit is in, its `P(win)` is the whole package's, and its price
  and Cost are the members' sums. A member that cannot be raised or routed is refunded before the pick charges the
  rest. With nothing affordable the best source is offered alone, so the pick can save toward it.

- **An attack stages on one bearing measured from the target,** 0° being the bearing to the first unit's start, the
  side the attack comes from, so every bucket starts on the same side of the fight. A rally is a cell centre at least
  `OPCOM_RALLY_K` (4) cells from the target's, 2 km at `OPCOM_GRID_CELL` 500 m, and every distance a rally keeps is
  Chebyshev cells from the target's cell.
- **An attack stages on a 3×1 line**, one bucket a cell across the bearing, which at `OPCOM_GRID_CELL` 500 m is a
  1.5 km frontage. Its roles take the line's cells in order, centre first: an `assault`'s `attacker` takes all three
  (`OPCOM_ASSAULT_CELLS`), and a `flank` puts `fix` at the centre and a `maneuver` bucket either side. A single cell
  holding the whole wave is one fire mission's worth of ground, and leaves the attackers no frontage to advance on.
  The line grows a cell at a time from the rally on alternate sides. A side that meets water, another landmass or a
  cell inside `OPCOM_RALLY_K` closes, and the line grows on along the other, so a blocked side slides the line rather
  than breaking it. A bucket stacks on the rally only where the ground holds no three cells. A diagonal bearing lays
  a diagonal line. The buckets fill from the centre out, so an assault of one or two units uses one or two of its
  cells.
- **A `flank`'s hooks go round the fight.** At launch `fix` goes straight at the target on `capture`, to engage early
  and hold the defenders there. Each `maneuver` bucket marches on `move` to its jump-off, `OPCOM_HOOK_K` (2) cells
  abreast of the target on its own side of the line, the nearest ground outside the 3×3 block the fix fights in. Its
  route pays `OPCOM_ROUTE_AVOID_PENALTY` to enter that block, so it crosses the fight only where no way round exists
  ([§Routes](#routes-threat-is-what-a-role-asks-for)). It waits at the jump-off on `fix`
  ([§Release](#release-the-stagger-lives-on-the-role-not-in-a-third-state)), then closes on the target with
  `capture` once out of contact, as an assault's side bucket does. Leaving at launch lets the longer hook cover
  ground while the fix closes.
- **Belief orders a flank's hooks.** The side with the least believed BLUFOR in the 3×3 block about its jump-off,
  outside the target's, takes the required `maneuver` bucket, so a lone hook goes where the defenders are thinnest.
  The target's own block is left out because it is the fight the fix draws, alike from every side. A side whose
  jump-off is water or another landmass gets no hook, and a flank with no dry jump-off is not offered. A line that
  slides hooks both buckets round its open side, the further one a cell further out.
- **An `assault` advances as a wave, then converges.** At launch each side bucket marches its own lane on `move`,
  parallel to the centre's advance, to the cell abreast of the target (`DUWS_fnc_opcom_converge`). Closing straight
  from the line would bunch the wave onto one fire mission's worth of ground and leave the cells beside the fight
  unswept. The centre bucket goes straight at the target on `capture`, since only `capture` garrisons the attacker
  into the ground it takes. A side bucket closes on the target with `capture` once every unit of it stands on its
  lane out of contact. That test reads the engine's fight, not belief: only recon clears a sighting, so a stale one
  in the lane's cell would park the bucket until it expired. A virtual unit renders near any real BLUFOR, so one
  that stands unrendered has no fight in its cell. A lane on water or on another landmass is dropped, and that
  bucket goes straight at the target.
- **A lone attacker at the ideal ratio launches alone.** `attack_assault` is also the one-unit Attack, so Attack keeps
  no one-shot path beside it. When the one unit OPCOM binds already meets the ideal ratio at commit, the assault
  launches with that one unit once it reaches its rally, so every assault keeps one shape. A lone unit below the ideal
  ratio musters like any other assault.
- **`attack_assault` is offered in every band.** Its band has to overlap `attack_flank`'s, or the archetype's lean
  toward it never bites: an action weight only scales what the sweep offers ([§Archetype](#archetype-phase-7)).
  From band 2 (`OPCOM_BAND_CRUSH`), read off the package the open sends, only the assault is offered, because at
  crushing odds an envelopment buys a setup leg and nothing else. The muster band, 0.5–1, offers both, since the
  muster is what raises the odds before either launches.
- **The pick chooses assault or flank once, at commit**, and a buildup launches what it chose whatever `r` it
  reaches, so a plan never flips mid-buildup even when the muster ends in another band. Where the band offers both,
  they compete on the one weighted roll like any two actions, each under its own `actionWeight`.
- **`resolve`** is the transition that frees an attack's units: every bound unit back at rest and no side bucket
  still on its lane, since each order already ends on its own predicate ([§Shipped](#shipped-the-substrate-the-loop-drives)): **Attack** — OPFOR take the zone by the mirror of BLUFOR's capture rule
  (`DUWS_fnc_siteTaken`): an OPFOR unit inside the radius, the zone's BLUFOR garrison beaten, tier 0 (none built)
  counting as beaten, and OPFOR outnumbering BLUFOR over the streaming ring, all for `DUWS_captureHold`. A live fight flips through the retake
  trigger; a virtual attacker flips it on the OPCOM tick against stored state once it has held the radius for
  `DUWS_captureHold`, **and only at tier 0** — a zone the player has garrisoned has to be beaten, and the site
  poller standing those men up is what renders the attacker to fight them. OPCOM sends that attack's contact
  report itself. The attacker garrisons the zone once it is virtual.
  A **town** is attacked on the same terms with one difference: it changes hands only by having its garrison
  cleared through its own trigger, so it has no virtual shortcut and no undefended case — a town with no tier is
  never a target, since reputation rather than a fight is what owns it. The attacker that takes one guards the
  ground instead of garrisoning into it, because the clear took the tier with it and left no pool to home to. **QRF** (`intercept`) — at the sighting's last known position the unit
  reads truth within its own K: nothing there, it drops to `guard` in place; BLUFOR there, it fights them live and
  guards once none remain, until its QRF moves on to another group ([§QRF](#qrf-an-attack-on-a-moving-cluster)). It
  never returns to garrison. **Probe** — the target's 3×3 block reads fresher than
  `OPCOM_PROBE_FRESH`, at which point the unit drops to `guard` where it stands (`DUWS_fnc_opcom_stepProbe`), or it
  arrives. **Rapport** — courier delivers or dies.

### QRF: an attack on a moving cluster

`attack_qrf` is an attack whose target is BLUFOR in the open rather than ground. It replaces the Intercept action,
which sent one unit per sighting. That unit could not mass: its `P(win)` read the whole 3×3 block, so against a
cluster no single unit could beat, nothing went. Several sightings in one block drew one unit each, arriving one at a
time, and no-retreat turns that into defeat in detail.

- **A cluster is every sighting within a cell of the strongest,** which is the 3×3 block that `P(win)` and the
  muster bars already read (`DUWS_fnc_opcom_qrfSweep`, `appraisal/fnc_opcom_commit.sqf`). The strongest sighting
  keys the record, and the attack follows it each tick (`DUWS_fnc_opcom_qrfFollow`). A lead that is no longer
  believed drops a QRF still in buildup. A sighting within a cell of a standing QRF draws no second one.
- **A QRF musters where its units stand.** A rally about a target that moves is stale before the units reach it.
  It musters on the same bars as any attack, over `OPCOM_QRF_EXPIRY` (6 ticks, 30 s) in place of
  `OPCOM_MUSTER_EXPIRY`. Its open sends a package filled to the ideal bar, so where the sources exist it launches on
  the next tick, and a cluster one unit beats draws a one-unit answer.
- **Every unit releases at launch on `intercept`** after the lead sighting. Units arrive in the order of their
  distance: the release does not stagger launches by ETA.
- **The QRF hunts as one.** Each unit's look on arrival still reads the group nearest it, but the QRF moves only once
  a look disproves the lead. The group a unit found then becomes the whole QRF's target, and every unit re-keys onto
  it, one already back on `guard` included (`DUWS_fnc_opcom_qrfRekey`). While the lead stands, a unit that finds a
  nearer group fights it, because pulling it back would re-order the QRF every tick two units' looks disagree.
- **Air joins a QRF** and not an assault, because it hunts a group in the open rather than holding ground. A land
  unit across water from the cluster stays out: a ferry lands men a trip at a time, and the target moves.
- **No creep and no probe.** A creep's box is laid at commit on an objective that stands still, and a probe's stake is
  stale belief, where a QRF's target is a fresh sighting.

### Chained fires: a creep rides an attack

`arty_creeping` cannot stand alone: a creep is a barrage walked ahead of someone, so it needs an attack to walk it
for, an assault or a flank alike, never a QRF. A creep is therefore a field on the attack record rather than a record
of its own. The row offers each attack in buildup or execution with no creep yet, and its rounds walk ahead of that
attack's advance (`DUWS_fnc_opcom_creepTargets`, `appraisal/fnc_opcom_fire.sqf`): an `OPCOM_ARTY_CREEP_WIDTH` ×
`OPCOM_ARTY_CREEP_LENGTH` box (150 × 200 m) walked forward through the objective along the wave's approach. The creep
holds its battery from commit, so no Saturate finds its guns mid-mission, and fires once the attack launches and the
guns are free. An attack that ends first takes the creep with it, its AP spent.

`arty_saturate` needs no parent. Where it fires for a muster the two overlap rather than sequence: the offensive
gathers while the rounds land, and the fires lift as it launches, because fires that stop before the wave starts hand
the players a window to reposition in.

Nothing else chains. A Probe that refreshes belief at an objective moves that objective's muster bars by itself, since
both bars read believed force ([§Commitment](#commitment-orders-are-sticky)), so no edge is needed to sequence one
ahead of an offensive and the row chosen at commit stands. Each link pays its own price at its own commit, so a
chain that runs out of AP, or whose next gate has lapsed, stops where it is.

### Routes: threat is what a role asks for

**Avoiding threat is opt-in.** λ 0 is distance only, which is what an assault wants: a detour arrives late at the
fight the order exists for. λ is therefore a field on the role binding (`DUWS_opcom_attackRoles`), falling back to the
order's default, which is 1 for an `errand` and a `return` and 0 for every other order (`taskings/fnc_opcom_task.sqf`).
The order alone cannot carry it, because `flank`'s `fix` and `maneuver` both run `capture` and take opposite values.
The tasking keeps its λ, so every re-plan of the march bends alike, and a lift takes its rider's. High is λ 1, and
`OPCOM_ROUTE_LAMBDA` (200 m of detour per unit of believed force in a cell crossed) sets how high that is.

| Role or order | λ | Why |
|---|---|---|
| `capture` — an `assault` attacker, and `flank`'s `fix` | 0 | the fight is the point of the march |
| `move` and `capture` — `flank`'s `maneuver` | high | arriving unseen is the whole worth of the role |
| `intercept` — a QRF's attacker | 0 | the threat is the target |
| `patrol` | 0 | ground is often stale because it is dangerous, so avoidance defeats the sweep |
| `probe` | 0 | closing is how the block gets read |
| `errand` | high | a truck lost is the goods lost, and no `P(win)` prices that risk |
| `return` | high | a unit going to rest has nothing to win from contact |
| `move` | its role's own | a staging leg inherits what the role will need |

- **A hook goes round the fight whatever belief holds.** λ bends a route only around force belief already places,
  and the target's block can read empty before the fix finds its defenders. A `maneuver` hook therefore also names
  the target's 3×3 block to avoid (`fnc_opcom_task`'s `_avoid`, kept on the tasking as λ is), and the route pays
  `OPCOM_ROUTE_AVOID_PENALTY` to enter each cell of it: far above any detour, so it is crossed only where no way
  round exists. A road route pays it on each road step in the block and ends its road leg on a road outside it.
- **Negative λ is not available.** The cell chain's octile heuristic is admissible only at λ ≥ 0
  (`taskings/fnc_opcom_route.sqf`): a negative edge weight stops A* returning the best path and leaves the pop cap as
  the only bound on a pathological re-open. A `probe` needs no such price: closing at λ 0 until the block reads fresh
  already walks it into whatever is there.
- **A `return` at high λ is the cheap half of an open question.** Garrison asks whether a withdrawal needs a
  `P(win)` of its own, since a unit sent to rest through a BLUFOR advance is worse off than one holding. Routing around
  the advance answers it without a second odds term.

**Routes read threat on the road.** A wheeled or tracked route takes the same threat term as the foot cell chain,
`OPCOM_ROUTE_LAMBDA` × the role's λ × `_ene`, pro rata to each road step's length, so a hull takes a flanking road
rather than drive through a threatened stretch. `fnc_convoy_path` takes the term as an optional cost hook, and a route
at λ 0 passes none, so the convoy side missions route as before. A priced search may pop four times as many nodes
without closing on the destination before it gives up, since a detour runs away before it turns back, and a priced
route that ends wet falls back to the length-only road: a march through the threat beats no march. A supply truck's
route is planned at departure and again only after a stow, so the truck skirts the threat believed then and drives on
into any threat that appears after.

**A hull leaves the road only where the road ends.** At λ > 0 a hull's road leg stops at the road nearest its
destination, and the leg past it takes the threat-priced cell chain a foot unit uses instead of a straight stub
(`taskings/fnc_opcom_route.sqf`). A chain that crosses navigable water leaves the straight stub in place, because no
lift carries a hull. A hull never leaves the road mid-route to go around a threat: the road term already prices a
threatened stretch.

**A live group walks its route at λ > 0.** It takes a `MOVE` waypoint a cell apart along the rest of its route before
its order's own waypoint (`DUWS_fnc_opcom_routeVia`, `taskings/fnc_opcom_stream.sqf`), so a role that streams live
near the players still closes by the route its λ bent. At λ 0 a live group takes one waypoint at its target and the
engine paths it. A group in combat ignores a move waypoint, so the route holds only on the approach.

### Chunks

| Chunk | Builds |
|---|---|
| **5.1** Ownership | **Shipped** (`taskings/fnc_opcom_attack.sqf`) — the attack record and `boundTo` honoured by `DUWS_fnc_opcom_drawable`. This chunk touches the pool every action draws from |
| **5.2** Buildup | **Shipped** (`taskings/fnc_opcom_attack.sqf`) — one rally cell at least `OPCOM_RALLY_K` (4) cells from the target's, outside the 3×3 block the muster bars read, on the bearing the first unit comes from, `move` staging with each unit's land-taxi sourced for its staging leg, a Join row while the bound force is short of the ideal bar, up to `OPCOM_ATTACK_UNITS`, the launch predicate, `OPCOM_MUSTER_EXPIRY` (240 ticks), and abort on a unit lost while staging |
| **5.3** Assault and flank | **Shipped** (`DUWS_opcom_attackRoles`) — `attack_assault` across its 1–3 cells, the one-unit Attack among them, and `attack_flank`, its `maneuver` buckets waiting on `fix`, and the landmass rule that keeps every rally on the target's ground and sends only infantry, as an assault, across water |
| **5.4** Route λ | **Shipped** — the role's λ threaded through `fnc_opcom_task` into `fnc_opcom_route`, the threat term on road segments, the threat-priced cell chain past the road's end, and a live group's waypoints along its route |
| **5.5** Probe | **Shipped** (`DUWS_fnc_opcom_probeSweep`, `appraisal/fnc_opcom_commit.sqf`) — the action, sourced from Patrol's rows, its staleness Value, a `probe` order row and the fresh-block resolve. It lands after 5.2, because the muster bars are what a sharper reading is worth anything to |
| **5.6** Chained fires | **Shipped** (`appraisal/fnc_opcom_fire.sqf`) — Arty split into `arty_saturate`, the shipped action renamed, and `arty_creeping`, a creep on an attack record and the only chain edge |
| **5.7** QRF | **Shipped** (`DUWS_fnc_opcom_qrfSweep`) — `attack_qrf` in place of the Intercept action: a sighting cluster as the target, the muster where the units stand over `OPCOM_QRF_EXPIRY`, and release on `intercept` |
| **5.8** Packages | **Shipped** (`DUWS_fnc_opcom_attackPackage`) — an open or a join sends as many units as the ideal bar needs in one pick, repeat hires included, each staged at the bucket it fills |
| **5.9** Wave | **Shipped** (`DUWS_fnc_opcom_converge`) — an `assault`'s 3×1 line that slides along a blocked side, and its side buckets marching their own lanes abreast of the target, each closing on it once out of contact |
| **5.10** Hook | **Shipped** (`DUWS_fnc_opcom_converge`, `fnc_opcom_route`'s `_avoid`) — a `flank` staged on the 3×1 line from one bearing, its `maneuver` buckets hooking round the target's 3×3 block to a jump-off on each side at launch and closing once `fix` engages, and the rally standoff at 4 cells |

5.1 lands alone. Every chunk after it reads the pool it changes.

Phase 5 settles in play the band thresholds and their overlap, each role's λ and how often a route is re-planned,
the longest off-road leg a hull drives without stalling, `OPCOM_MUSTER_EXPIRY`, `OPCOM_QRF_EXPIRY`, how far
short of the target a rally has to sit to be safe enough to be worth the extra march (`OPCOM_RALLY_K`),
`OPCOM_MUSTER_HOLD`, how far out a `flank`'s hook waits (`OPCOM_HOOK_K`), `OPCOM_ATTACK_UNITS`, `OPCOM_PROBE_SHARE`, `OPCOM_PROBE_FRESH`, `OPCOM_ARTY_CREEP_SHARE` and the creep's box.

## What AP buys

**WIP.**

Three levels: **Action** (what AP commits to, scored and held), **Sink** (how it's paid — tier / strength / build /
tasking-spawn / bought fire mission), **Tasking** (orders emitted: 0 economic, 1 simple, N an Attack). One actor
shares `WARCOM_opfor_ap`; every sink competes in the one appraisal, except a ferry, which finishes an order the
appraisal already bought ([§Sourcing](#sourcing-hire-on-demand-phase-4d)). Spends call
`["OPF", -_cost, _reason] call fnc_ap_adjust` (server-side, single writer, no race).

| Action | Target | Sink | Taskings |
|---|---|---|---|
| Attack | a BLU-held zone | tasking-spawn | 1–N (assault or flank) |
| QRF | a cluster of BLUFOR sightings inside OPFOR's area of influence | tasking-spawn | 1–N |
| Rapport | a town above −15 and below +10 inside OPFOR's area of influence (needs `supply`) | tasking-spawn | 1 courier |
| Reinforce | an own depleted zone / town garrison | strength purchase | 0 zone / 1 truck town |
| Patrol | a recon's or a land combatant's line over stale valuable cells | tasking-spawn | 1 |
| Probe | an Attack target whose block reads stale | tasking-spawn | 1 |
| Garrison | an open zone under the garrison cap | tasking-spawn | 1 |
| Ferry, automatic | a unit stopped at a water leg | tasking-spawn | 1 lift |
| Arty saturate | an observed target in gun range | bought fire mission | 0 |
| Arty creeping | a bound offensive's target in gun range | bought fire mission | 0 |
| Fortify | an own town / zone | tier purchase | 0 zone / 1 truck town |
| Build | an own zone ring or band cell, one action per unlocked type | hardpoint build | 0 zone / 1 truck standalone |
| Tower Build | a band cell | hardpoint build | 1 truck |
| OP Build | a band cell | hardpoint build | 1 truck |
| Mortar Build | a band cell | hardpoint build | 1 truck |
| Battery Build | a band cell | hardpoint build | 1 truck |
| Minefield | a band cell (AT, AP) | mine lay | 1 truck |
| Bank | — | none | 0 |

- **A unit is hired for the action that sends it** — a tasking-spawn sink hires only when no free unit scores
  better ([§Sourcing](#sourcing-hire-on-demand-phase-4d)), so OPCOM builds up in AP rather than in units, and a lost
  unit is lost AP. The archetype leans on a kind through its `recruitMix`. A row the faction cannot field now is no
  source.
  Units spawn only from OPFOR-held ground; taking the zone cuts what it can raise.
- **A unit's force is a token composition** — a row in `DUWS_opcom_recruitMenu` (`fnc_opcom_tasking_init.sqf`): an
  id, a **bare**-token composition (`none` posture, so OPCOM commands it), and capability flags. `OPCOM_AP_UNIT`
  prices the row by its id, so the menu carries no price column.
- **Capability flags decide what a unit unlocks; there is no unit "type".** `recon` → a certain sighting of
  every BLUFOR group within `OPCOM_RECON_K` cells, stamped every tick it travels, where a unit without the flag
  stamps only that it looked ([§Value](#value)); `supply` → a delivery run, `transport` → carry another
  unit, `transportable` → ride a ferry across water; `noncombat` keeps a row out of a zone's reserve pool
  (regardless of armament — the boat is armed). A row may carry several.

Prices, first-pass defaults set against OPFOR's income of roughly 40–80 AP per 30 min (`fnc_zonesundercontrol.sqf`):

| Purchase | Price |
|---|---|
| Unit hire | `OPCOM_AP_UNIT` by menu row: rifles 10, weapons team 5, recon foot 5, truck 3, recon car 10, boat 3, car 5, APC 15, IFV 25, MBT 40, recon helicopter 20, transport helicopter 10, attack helicopter 50, jet 80 |
| Zone Reinforce / Fortify | `OPCOM_AP_REINFORCE` 15 / `OPCOM_AP_FORTIFY` 25, flat |
| Town Reinforce / Fortify | the same flat price, plus its truck's source price |
| Zone hardpoint | `OPCOM_AP_HARDPOINT`: roadblock 8, MG 12, GMG 16, AT 16, AA 20 |
| Standalone hardpoint | as a zone hardpoint, plus its truck's source price |
| Radio tower / OP / mortar pit / artillery battery | `OPCOM_AP_TOWER` 30 / `OPCOM_AP_OP` 15 / `OPCOM_AP_MORTAR` 25 / `OPCOM_AP_ARTY` 50, plus its truck's source price |
| Minefield | `OPCOM_AP_MINEFIELD` 1 per 50 m square, so 30 to 90 for a belt, plus its truck's source price |
| Rapport | `OPCOM_AP_RAPPORT` 10, the goods the courier carries, plus its truck's source price |
| Unit source | a hire's `OPCOM_AP_UNIT`, or 0 for a free unit; `OPCOM_AP_PER_KM` 0.5 × distance is scored on every source and charged on none ([§Sourcing](#sourcing-hire-on-demand-phase-4d)) |
| Fire mission | `OPCOM_AP_PER_ROUND` per round: 1 for a mortar, 2 for a battery |

- **A garrison step is flat-priced.** Reinforce and Fortify cost the same wherever they land and whatever they buy
  back, and a zone and a town charge the same rate for the same order; a town adds only its truck, which is the
  delivery rather than the step. Pricing the step on the tokens owed made the cost a lottery on whatever happened
  to die there. Fortify is the dearer of the two because a tier raise is permanent where a refill is consumed.
- **Price is its own table, keyed by what OPCOM buys** — a recruit menu row id, a hardpoint type, a garrison step.
  Never derived from force, and never read off the composition: force answers who wins a fight, which is a
  different question from what a thing is worth buying, and two menu rows that share a composition (the recon and
  transport helicopter) must still be able to cost different amounts. Deriving price from force also broke the
  score outright — with price equal to force, a garrison action's `gain ÷ price` cancelled to worth × exposure ÷
  full force, so every zone action tied at every zone and the archetype had nothing to tilt. Infantry is cheap so
  the commander can always hold ground, every hull carries a premium and air the steepest.
- **Force still converts to AP in three places** — the `Cost` of staking a unit on a commitment, the fire missions' Value in
  kills, and the traffic layer's contribution to need. `OPCOM_AP_PER_FORCE` is 1, infantry's rate and the cheapest
  force OPCOM buys.

**Supply gates the town-side builds.** A `supply` truck drives from OPFOR ground to its target and is spent on
arrival, behind four actions: Rapport, standalone Build, and *town* Reinforce / Fortify
([§Shipped](#shipped-the-substrate-the-loop-drives)). The action takes a free truck, or hires one and tasks it in the same commit,
whichever source scores better ([§Sourcing](#sourcing-hire-on-demand-phase-4d)). A town takes one supply truck at a time: while one drives to it, no supply action
targets it. At most `OPCOM_CAP_SUPPLY` (10) trucks are out on an errand at once ([§Caps](#caps)). The AP is paid at commit but the result lands only when the *specific* bound truck
arrives — **kill it en route and the order fails, no refund** (interdiction is the counterplay). **Arrival is the
only test**: the contest gate keeps OPCOM from ordering a buy into a fight, but a truck already driving is never
recalled, so a town that turns contested behind it still takes the delivery. A Reinforce landing there returns its
lost tokens to the ledger and the reserve pool, and the reserve pass favours the sites players stand on, so those
men feed into the engagement — the commander reinforcing a fight it did not know about when it paid. A town that
falls first loses it. **Zones need no supply** — zone Reinforce,
Fortify and hardpoint Build resolve on AP alone the tick they commit, reading as OPFOR trucking matériel outward
from its zones to the towns.

## What the commander builds

**WIP.**

The escalation ladder and indirect-fire assets, once the commander spends on them. Hardpoints generate at scenario
init and through the Build actions.

**Build is scored like any other action** ([§Value](#value)). A zone hardpoint builds in the zone's ring through the
existing in-zone draw; a standalone one takes its spot from the shared terrain siting around the band cell its truck
delivers to (`fnc_hardpoint_spawn_sited`). Every unlocked type is its own action row and no type is rolled before the
pick, so the pick draws "an AT nest" or "a battery", never "a build", and the score weighs one against the other. The
per-type prior is the archetype's `hpMix` ([§Value](#value)), and its one `build` weight scales every type in it
alike, where an asset build keeps its own weight ([§Archetype](#archetype-phase-7)); campaign generation rolls its own weight
tables, `DUWS_hardpointWeightZone` for a ring and `DUWS_hardpointWeightSolo` for the standalone lines. An asset
hardpoint is its own candidate, never stands in a zone's ring, and picks its band cell by its own rule ([§Asset
siting](#asset-siting)). A minefield is laid, not built: a belt of 50 m squares per action
(`fnc_hardpoint_minefield_grid`), AT and AP each their own candidate, with the size rolled onto the target so the
price the pick weighs is the belt's own footprint. Its squares are planned rather than laid, and made and unmade by
the site poller as players reach them, so a belt costs its stream ring and not its length
([`hardpoints.md`](../../info/gameplay/hardpoints.md#siting)). A build cannot be a *typed* counter (AT under armour)
until belief carries a threat category ([§Appraisal](#appraisal-phase-4)).

Construction is an AP sink; a cleared build refunds nothing (clearing pays the player CP only), and only a build that
finds no ground is refunded, in full, its truck included. Unlocks (`DUWS_hardpointTier`) key off `WARCOM_opfor_tier`,
which climbs the earned-AP rungs (`DUWS_ap_tier_rungs`), never the spendable wallet; each cap counts a seeded
hardpoint and a build still on its truck:

| Tier (earned AP) | Types a build may place |
|---|---|
| 1 Infantry (0) | radio tower (max `AOI_OPFOR_TOWER_CAP` alive, 5), OP, MG, roadblock |
| 2 Motorised (60) | + AT, minefield |
| 3 Mechanised (150) | + GMG, AA, mortar pit (max 2 alive) |
| 4 Armour (350) | + artillery battery (max 1 alive) |
| 5 Jets (600) | nothing new |

The tower, the mortar pit and the battery cap flat: the tower cap is also the reputation amplifier's, and the guns'
is the resident AI's. AT, AA and OP cap at 2 a campaign zone, GMG and minefield at 1 (`OPCOM_CAP_HP_TYPE_PER_ZONE`).
MG and roadblock carry no cap of their own. All types together, the flat-capped three included, cap at
`OPCOM_CAP_HP_PER_ZONE` (12) a zone ([§Caps](#caps)).

Hardpoint garrisons stay fixed per type (`DUWS_hardpointGarrison`). Knobs (all tune): seed subset 2–3 at init; no
live cap (bounded by player proximity).

### Asset siting

Each build type picks its band cell by the rule below, which ranks cells on the same coverage its Value measures
([§Value](#value)) — the siting pass is the Value run over several cells instead of one. Each pick samples
`OPCOM_SITE_SAMPLES` (8) band cells from the need field's band mask ([§Need and cover fields](#need-and-cover-fields)),
and every type takes the best of the same sample; `random` mode samples one, so it stays the unscored draw. The pass
runs scheduled, ahead of the pick's unscheduled pass, and keeps a cell's tower and gun Value until the
area-of-influence inputs or the type's own assets change. A tower's Value reads every OPFOR hardpoint through
defend, so its memo also resets on any build. The truck drives to the cell's centre, and inside the cell
the shared terrain siting picks the spot (`fnc_hardpoint_score`,
[`info/hardpoints.md`](../../info/gameplay/hardpoints.md#siting)).

| Build | Band cell |
|---|---|
| Radio tower | the most town worth brought newly under OPFOR's area of influence × defend, outside every other tower's `AOI_TOWER_REACH` (the campaign-generation rule, `fnc_hardpoint_seed_radio`) |
| OP | the most cells within `OP_OBSERVE_K` that no other OP's ring already covers |
| Mortar pit | the most OPFOR ground within `OPCOM_MORTAR_REACH` (5 km) that no other mortar reaches, with no pit within `OPCOM_GUN_STANDOFF` (1 km) |
| Artillery battery | the same over `OPCOM_ARTY_REACH` (20 km), against the other batteries |
| Standalone hardpoint | the most cover Value: need × the cover it adds over its 5×5 block |
| Minefield | the band cell holding the most traffic, cover Value breaking a tie, since a field is worth what it denies and denies nothing on ground nobody crosses |

A gun's true range depends on the faction's gun and is read only at fire time (`inRangeOfArtillery`), so siting and
Value both use a fixed reach per type.

### Indirect-fire hardpoints

Persistent enemy assets, two tiers sharing one fire-mission implementation. An AI gunner executes `doArtilleryFire`
reliably, so the guns fire for real rather than needing shells spawned over them. A zone's own mortar is separate and
stays autonomous (`fnc_static_resolve`), uncapped here.

| | Mortar pit | Artillery battery |
|---|---|---|
| Core | static `opfor_TURRET_MORTAR` | self-propelled `opfor_ARTY_X` |
| Unlocks at | tier 3 (150 earned AP) | tier 4 (350 earned AP) |
| Rounds per gun | 4–8 | 6–10 |
| Spread | tighter (base 50 m) | wider (base 100 m) |

- **A fire mission is an Arty action** — scored and committed like any other, `Cost` scaling with the rounds it
  fires; it fires only when that action wins its phase, never on a schedule. An owned gun in range, not already
  firing and off cooldown is the availability gate. **AP is the ammunition** — the guns rest empty and are loaded per
  mission, so there is no finite store.
- **Each gun rests `OPCOM_ARTY_COOLDOWN` after it fires** — 360 ticks (30 min), saturate and creep alike, so a full
  wallet cannot keep a battery shelling without pause. The cooldown is per gun: a gun that did not bear on the
  mission stays ready, and the next mission's `Cost` counts only the guns that are ready. The debug `fire` verb zeroes
  the cooldown before it fires.
- **Belief is the only trigger** — a gun fires on a fresh sighting in the belief store and on nothing else. Ground
  OPFOR merely owns eyes near is not a target: an OP post is a sensor like any other, and feeding the guns a channel
  outside belief would make them see what the commander does not. The guns are exactly as blind as the sensors are.
- **Guns are for a mass** — Value sums the believed force within `lethal × √rounds` of the aim point, the radius the
  rounds' lethal areas tile, and then weights it by that force's share of every fresh sighting OPCOM holds. Three
  squads standing together are worth three times one, and worth more again when they are most of what is known to
  be out there; a pattern that catches one squad of many is a poor use of the guns.
- **Rounds buy footprint, spread buys nothing** — where the rounds fall is a property of the gun and the range, so
  the spread prices no kills. It sizes the pattern the mission lays and the telegraph's marker, and bounds the
  friendly force that comes off the Value, and that is all. Pricing kills by the spread would make the same squad
  worth less at range for a reason that says nothing about the squad, and would ignore that a wider pattern also
  covers a stale sighting's drift.
- **`P(win)` is the sighting's freshness**, because a fading sighting has probably moved.
- **Never onto OPFOR's own ground** — a target inside a zone OPFOR holds is refused outright, and the force of
  OPCOM's own units inside the pattern comes off the Value, so the commander does not shell its own men.
- **HQ exclusion** — no mission *aimed* inside 100 m of `PosOfBLUHQ` (rounds may still stray there from a barrage
  aimed elsewhere). The target grid is latched `[x,y,0]` at order time (never an object ref that would follow a
  respawn into the circle), and re-checked against the circle immediately before firing.
- **Spread** is the radius the action hands the shipped saturate: base by type, +25 m per km range, never below
  `OPCOM_ARTY_MIN_SPREAD`.
- **Two actions over one implementation.** `arty_saturate` fires on a fresh sighting; `arty_creeping` walks its
  rounds ahead of a bound offensive, so it gates on that offensive standing and rides its attack record
  ([§Chained fires](#chained-fires-a-creep-rides-an-attack)). They score apart because they buy different things
  — saturate buys kills, a creep buys the wave's survival — and one Value cannot price both. The debug step still
  asks for a walked pattern of any size by hand.
  Telegraph: an Allseer line and a marker on the aim point `OPCOM_ARTY_WARN` seconds before the first round lands,
  timed off `getArtilleryETA`. The marker stands until the last round lands: one flight time after the battery's
  last shot.
- **Capped campaign-wide** — one battery and two mortar pits alive at once across the map. These are the only
  permanent-crew hardpoints (~6 units that never despawn); making AA resident would add a fourth and needs its own
  cap.

## Archetype (Phase 7)

**WIP.**

One archetype per campaign, a campaign setting chosen at start (Defensive, Balanced, Aggressive or Random), sets the
`archWeight[archetype][action]` factor — it *multiplies* an action's score, never removes an action, and cannot
override the ladder (an Aggressive commander with no armour tier fields none). It is stored in the persistence
snapshot and never re-rolled. A Random pick stays hidden: the config diary note shows "Random", and nothing in play
reveals it. The OPCOM debug page overrides it for testing. It is not difficulty (`opfor_ai_skill` sets aim). The table
is each record's `actionWeight`, one flat weight per action (`fnc_opcom_actions`), Bank included. No class groups the
actions, because a class ties together actions an archetype must weigh apart: one that attacks often but spends its
units on build-up needs `attack_assault` and `attack_flank` high and `attack_qrf` and Rapport low. Every zone,
standalone and minefield build shares one weight, `build`: the weight sets how often OPCOM builds, and the `hpMix`
alone picks the type ([§Value](#value)), because a per-type weight would fight the mix for the same lean. A hire has
no weight of its own: it scores inside the action that sends it, under that action's weight, and the `recruitMix`
alone leans on its row. A tower, OP, mortar or battery build keeps its own weight and stays out of the mix, so its
weight sets how soon it builds. The table is relative: weighting every action alike changes no pick, so Balanced's 1
everywhere is the baseline. 7.1 builds the setting.

| Archetype | Weights toward | Attack lean |
|---|---|---|
| Defensive | Fortify, Reinforce, Build, `attack_qrf`, Patrol, Probe, Garrison | `attack_flank`: shape the fight, stake little |
| Balanced | no strong lean — the baseline | no lean — the baseline |
| Aggressive | Attack, Rapport, Arty saturate; leaves ground thin | `attack_assault`: direct, no setup leg |

**An archetype leans between assault and flank through their action weights.** `attack_assault` and
`attack_flank` are two rows of the action table ([§Attack](#attack-phase-5)), so their sum against the rest sets how
often OPCOM attacks and their ratio sets how. The band is the gate and the weight is the lean, so a weight neither
offers a row the band withholds nor takes an offered one away, and `attack_assault` is offered in every band for that
reason. Only the band overlap gives the ratio room, so the band thresholds and the two weights settle against each
other in play.

Each archetype is one record in `DUWS_opcom_archetypes` (`appraisal/fnc_opcom_archetypes.sqf`) holding its
`actionWeight`, `hpMix` and `recruitMix` ([§Value](#value)), and `DUWS_opcom_archetype` names the
one the commander plays. Only Balanced's record stands until 7.1 adds the others and sets the archetype from the
campaign setting; an archetype with no record weighs every action at 1 and builds and hires with
no mix.

Beyond its weights and mixes, an archetype sets the commander's patience: the muster ideal, minimum and expiry,
`OPCOM_SAVE_HORIZON` and `OPCOM_VALUE_HALFLIFE`. A patient, strategic commander musters and saves longer for a
properly executed attack; a flexible, aggressive one launches sooner at lesser odds. The Balanced baseline (a
1.5:1 muster ideal, a 0.75:1 minimum) is what Phase 5 musters against, and it applies until 7.2 builds the rest.

| Chunk | Builds |
|---|---|
| **7.1** Records and the setting | the campaign setting, the records the other archetypes need, the debug-page override, and `DUWS_opcom_archetype` set from the setting. The action table is already wired as each record's `actionWeight` |
| **7.2** Patience | the muster ideal, minimum and expiry per archetype, and `OPCOM_SAVE_HORIZON` and `OPCOM_VALUE_HALFLIFE` per archetype in place of the one global figure |

Phase 7 settles in play each archetype's action weights, Bank's included, its assault and flank weights against the band
thresholds Phase 5 sets, the patience figures, and the set of archetypes itself, which is not final. Phase 5 ships
the muster on one global set of bars, and 7.2 is what splits them per archetype
([§Attack](#attack-phase-5)).

## Town & zone garrisons

The OPFOR town ladder (tiers 0–IV in `DUWS_townSpawnTiers`, per-town `DUWS_townGarrisonTier` via
`fnc_town_garrison_setTier`) and the zone tiers are shipped and documented in
[`info/zones_and_civilians.md`](../../info/gameplay/zones_and_civilians.md#garrison-tiers-0-to-iv). Reputation
decides *whether* a town garrisons (crossing −10 writes tier I); AP decides *how hard*. Clearing a town drops it to
tier I at strength 0 (no refund), and it cannot be cleared again until OPCOM resupplies it.

BLUFOR garrisons are shipped on the same model
([`info/garrison_and_reserves.md`](../../info/gameplay/garrison_and_reserves.md#whose-garrison-it-is)): both sides
field the same tier rows through their own hulls and their own AP rungs, a flip in either direction zeroes the tier
and forgets the ledger, and buying tier I at held ground *creates* a garrison at a tenth of that tier rather than
inheriting anything. The presence latch carries over; the `Mobilising` hold does not, since a BLUFOR garrison never
arrives on ground it owns. A BLUFOR-held site also wakes for an OPCOM attacker, live or virtual, inside its ring, so
its garrison renders and renders the attacker in turn.

Not built:

- **What the player pays for one.** `fnc_zone_garrison_fortify` / `_reinforce` and the town pair charge nothing —
  the price is the caller's, as it is for OPCOM. Only the debug surface calls them for BLUFOR today, so the
  currency, the price and where the player spends it are open. OPCOM's own candidate lists skip BLUFOR-held sites,
  so nothing it buys can reach them.

## Random events: what a turned town does

Shipped separately, not an OPCOM build phase. A turned town — reputation `<= -10`, inside the OPFOR band — acts on
its own, free and rolled off reputation: IEDs on approach roads, ambushes on passing patrols, sabotage against
nearby FOBs, planned outside the town's presence trigger so it can mine a road ahead of the player.

## Rejected: the OPFOR spawners this replaces

WARCOM's three OPFOR threads (roaming patrols, attack waves, random air) are deleted, and the commander **must not
reproduce their shape**: `CYCLE` routes that never despawned, unconditional cadence, AP read but never spent, and
spawns over 1500 m from every player, so contact happened only when a player drove into them. One of their
behaviours is still worth rebuilding as a commander decision: **dismounts**, a second infantry team `joinSilent`ed
into a vehicle group, which belongs in a composition a hire raises. Target selection is replaced by belief, and the
ammo truck by Reinforce.

## Persistence (Phase 6)

OPCOM's store is shaped to serialise but implements no save/load, and today persistence is the engine's
`saveGame`. The snapshot owns the save and the load, and the whole contract — which of OPCOM's keys it carries, what
a restore clears before it replays them, and why belief is not among them — is
[`campaign_persistence_plan.md` §The commander](../campaign_persistence_plan.md#the-commander).

It follows the Attack so the contract is written once. Phase 5 added the attack records (`DUWS_opcom_attacks`, with
`DUWS_opcom_attackSeq` beside it) and the `boundTo` key on the taskings they own, which are stored state on the same
terms as a tasking, so a contract written before it would be reopened the moment it landed. An attack is numbers,
strings and arrays like everything else here, and its roles name their units by tasking id, which the taskings group
already restores — so a buildup comes back mid-muster rather than collapsing, and what clears on restore is the live
half a tasking already clears: the group handle, the status and any carry binding. A tasking's `boundTo` names its
attack by id, so the attack counter rides with the attacks as `DUWS_opcom_taskSeq` rides with the taskings, and a
buildup's `since` counts against `DUWS_opcom_tick` as a commit hold does.

The phase ends in play rather than in code: a campaign is run past a save and a reload, and the commander has to
pick up where it left off. That play pass is also what settles Phase 4's tuning list
([§Settles in play](#settles-in-play)) — until it lands, a tuning pass lives and dies inside one session.

## Naming: OPCOM sits inside WARCOM

OPCOM is a component of WARCOM, not a replacement; prefixes split by ownership, nothing mass-renamed. Shared
war-economy state stays `WARCOM_` (`WARCOM_opfor_ap`/`_tier`); OPCOM's own state takes `OPCOM_`; the belief store
keeps `DUWS_` with an `opcom_` owner tag.
