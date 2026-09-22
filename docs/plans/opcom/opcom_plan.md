# OPCOM: the opposing commander

OPCOM is one server-side actor that turns the enemy's Army Power into pressure: it garrisons towns, tasks
squads, builds hardpoints, and lets low-reputation towns fight back. Its wallet and faucets are the economy's
([`economy_second_pass.md`](../economy_second_pass.md#army-power)); the hardpoint mechanics it draws from are
[`info/hardpoints.md`](../../info/gameplay/hardpoints.md); the standalone-siting economics are
[`info/opfor_area_of_influence.md`](../../info/gameplay/opfor_area_of_influence.md#band-siting). The published
game AI methods behind the design are in [`opcom_ai_comparison.md`](opcom_ai_comparison.md).

One thread runs on a 5 s tick (`OPCOM_TICK_PERIOD`): **perception** keeps the enemy's belief about BLUFOR,
**appraisal** weighs candidate actions and picks one, and **commitment** turns the pick into a sticky intent.

Phases 1–3, 4A, 4B.1 and 4B.2 are shipped, and the code under `src/duws/server/warcom/opcom/` is the source of truth for
them. This doc specifies what remains. The sections marked **WIP** are first-pass decisions: they change as each chunk
is built and played.

## Status

| Phase | State |
|---|---|
| 1–3, 4A, 4B.1, 4B.2 — Perception, recruitment and tasking, orders driven by hand, the random picker with zone buys, supply trucks, town buys, Rapport and standalone builds | [§Shipped](#shipped-the-substrate-the-loop-drives) — **shipped** |
| 4B — The picker: every action wired, picked at random | [§Appraisal](#appraisal-phase-4) — WIP |
| 4C — Weighting: the pick scored by Value ÷ Cost, over `P(win)` where an order fights for its target, then the archetype over it | [§Appraisal](#appraisal-phase-4) — WIP |
| 5 — Orchestration: multi-unit templates, mustering and threat-aware routes | [§Templates](#templates-phase-5) — WIP |
| 6 — Archetype patience: the muster bars, the savings horizon and the value half-life | [§Archetype](#archetype) — WIP |

The ordering is forced by what the next phase reads. Do not pre-build later phases: the tuning constants and
engine-contact behaviours only settle by running the core.

**4C.2's Values run first, then 4B.3's actions, then the rest of 4C.** Every wired action is scored before any new
one is written: an unappraised row returns its price and scores break-even, so a half-appraised picker quietly
favours whatever it cannot yet judge, and adding actions into that only widens the blind spot. The archetype is
last of all — it multiplies a class's scores, so it has nothing to tilt until the scores mean something.

## Shipped: the substrate the loop drives

The code under `src/duws/server/warcom/opcom/` holds it: `belief/` the perception and the influence grid, whose
layers `_fri` (known OPFOR) and `_ene` (believed BLUFOR) the scoring reads, `taskings/` the orders, streaming and
the ferry, and `appraisal/` the action list and the pick. The debug harness (`fnc_opcom_debug_task.sqf` and the
Debug menu's OPCOM pages) runs the orders by hand and spends no AP. New work holds to:

- **Belief, never truth.** The commander plans against belief; only the sensors read live player state.
- **The engine resolves every fight**, and `P(win)` never dices one.
- **State** is numbers, strings and arrays only, and every time counts in ticks off `DUWS_opcom_tick`.

Not built: whether an idle hull leaves its post to ferry, and whether a rider waits for a lift or walks. Land-taxi,
which lifts a foot unit over dry ground with the same carry, is 4B.3 ([§Appraisal](#appraisal-phase-4)).

Two terms carry one meaning each throughout:

| Term | Applies to | Meaning |
|---|---|---|
| **Contested** | a zone or a town | BLUFOR are assaulting the site: a sighting within one grid cell of its edge (`fnc_opcom_contested.sqf`) |
| **Engaged** | a unit | The unit is live and fighting BLUFOR. A virtual unit, a zone and a town are never engaged |

## Appraisal (Phase 4)

**WIP.** 4B and 4C are decided as a first pass: their weights, Values, prices and constants will change as each chunk
is built and played.

Each tick, enumerate candidate `[action, target]` pairs, gate them cheaply, weight the survivors, shortlist the
best, and pick one by weighted random (`selectRandomWeighted`, the `fnc_createzone.sqf:117` idiom). No search or
lookahead. The pick pass runs inside `isNil { }` (unscheduled, no `sleep`) under a wall-clock budget,
`OPCOM_SCORE_DEADLINE`; the pick executes after it in scheduled space, because an order plans a route and the router
may yield. One pick per tick until 4C.2's difficulty setting. The action list (`fnc_opcom_actions`) holds each
action's class, targets, gate, price and execute, and from 4C.2 its Value and Cost.

- **4B — The picker.** Every action is wired to the pick — its targets, gate, price and execute, and every thread
  they drive — and spends as the weighted commander will. Nothing is weighted: the pick draws an action with a legal
  target uniformly at random, then one of its targets uniformly. It runs only in `random` mode, switched on from the
  Debug menu's OPCOM page ([§OPCOM debug page and overlay](#opcom-debug-page-and-overlay)); the mode is `off` by
  default. Prices are the first-pass figures ([§What AP buys](#what-ap-buys)).
- **4C — Weighting.** 4C.2's balance runs ahead of both 4C.1's archetype and 4B.3's new actions. The score, the
  shortlist and the roll are built first ([§The pick](#the-pick)) with `archWeight` held at 1, then the Values land
  one action class at a time until every wired row is appraised — an unappraised row returns its price as its Value
  and scores break-even, which is a shrug the pick takes too often, so the shrugs are cleared before anything new is
  wired. 4C.1 comes last and adds the archetype on top: `archWeight[archetype][actionClass]`
  ([§Archetype](#archetype)) multiplies a whole class's scores, which is the only change it makes.

The rows run in the order listed, which is not their chunk number: the Values are finished before new actions are
written, and the archetype comes last.

| Chunk | Builds | Settles in play |
|---|---|---|
| **4B.1** Picker + zone buys | **Shipped** (`appraisal/`) | — |
| **4B.2** Trucks + towns + Rapport + standalone builds | **Shipped** (`appraisal/`) | — |
| **4C.2** Balance | **Part shipped** — the score, the shortlist, the roll, the weighted mode, `P(win)`, worth, exposure, the hidden HQ flag, the defensive holdings' Values (`appraisal/fnc_opcom_value.sqf`), the truck hire's Value of 0, and the OP's and the guns' Values. Left, in this order: the radio tower's Value, then Rapport; then the traffic layer and the need and cover fields on a debug overlay before anything reads them, which the standalone builds and the minefields wait on; then the delay discount, the savings goal, the asset siting and the difficulty setting on the OPCOM debug page. The commit Cost lands with 4B.3, the first chunk to stake a unit | `OPCOM_AP_UNIT`, `OPCOM_AP_HARDPOINT`, `OPCOM_AP_REINFORCE` and `OPCOM_AP_FORTIFY`; `OPCOM_BANK_SCORE`; `OPCOM_TRAFFIC_HALFLIFE` and `OPCOM_TRAFFIC_SHARE`; where a mortar pit or artillery battery sites (the gun reach and standoff); the zone prices; whether a Fortify is priced on the whole tier or on the tenth it fields, since a Reinforce buys back the rest; the exposure distances (5 / 10 km, 0.2 floor); `OPCOM_SAVE_HORIZON`; the town worth factor (5); `OPCOM_AP_PER_KM` and `OPCOM_AP_RAPPORT`; `OPCOM_VALUE_HALFLIFE`; the need field's base ratio (2–3); the asset prices; what a radio's reach, an OP's eyes and a gun's fire missions are worth, in place of the coverage stand-ins, and the radio's defend ramp (`OPCOM_DEFEND_NEAR` 500 m, `OPCOM_DEFEND_FAR` 2 km) against its reach; whether belief carries a threat category, so a build sites a typed counter (AT under armour, AA under air); `OPCOM_PWIN_FLOOR`; `OPCOM_GRID_ZONE_ENEMY_FORCE` (8), the force OPCOM believes every BLUFOR zone holds, which sets its baseline caution; what the commander does with a surplus, and whether it must spend rather than only can (absorbers: combatant Recruit, reinforcing over upgrading, mustering); `OPCOM_SCOUT_SHARE`; `OPCOM_PICK_TOP` and `OPCOM_PICK_SHARPNESS` ([§The pick](#the-pick)) |
| **4B.3** Attack, QRF, Scout | Combatant, recon and transport Recruit, land-taxi, the free-unit check, Attack, Intercept (QRF), Scout | `OPCOM_COMMIT_HOLD`; `OPCOM_GARRISON_HEAL_RATE`; whether the player can see the commander act on stale belief, and whether the intel system surfaces it; whether a fast airborne player crosses a recon's K between its once-per-tick samples unsensed, fixed by a larger K against airborne players if it does |
| **4B.4** One-gun Arty | The Arty action over the shipped fire mission — the observation gate and the tracker it reads (the tick each BLUFOR zone and FOB was last observed), the shape and its size, the cooldown and the HQ exclusion ([§Indirect-fire hardpoints](#indirect-fire-hardpoints)) | When the action picks a creep over a saturate; whether a mortar's OP spread bonus survives the 50 m floor |
| **4C.1** Archetype | The campaign setting, the weight table and the archetype override on the OPCOM debug page | Each archetype's weights, Bank's included |

From 4C.2, the score is one number — expected AP returned per AP spent:

```
score = archWeight[archetype][actionClass] × P(win) × Value / Cost
```

`Value` and `Cost` are both Army Power, so the units agree; `archWeight` tilts by action class
([§Archetype](#archetype)); `P(win)` scales to the expected return.

**Only an order that fights for its target carries a `P(win)`** — Attack, Intercept, Scout and Arty. A purchase
does not: Reinforce, Fortify, Build, Rapport and Recruit stock ground OPCOM already holds, and their site is gated
on being uncontested, so the term would read 1 wherever it was legal to spend. A buy scores `Value / Cost`.

- **`P(win)` — Lanchester-square.** `P(win) = r² / (r² + 1)`, with `r` = Σ`_fri` ÷ (Σ`_ene` + 1) over the target's
  3×3 block. Parity is a coin-flip, a 2:1 edge ≈ 0.8, a hopeless ratio floors near 0.
- **A defender's edge is its guns.** Both layers price force off one table (`belief/fnc_opcom_force.sqf`): a man
  is 1, a static MG 2, and a static GMG, AT or AA gun 4. A hardpoint or a zone's centre statics therefore weigh their
  guns on top of their garrison, so `r` reads a dug-in site above its headcount. Infantry in cover counts 1 a man,
  and no posture factor is planned: a higher bar only makes attacks fewer and larger. A sighted player adds
  `OPCOM_PLAYER_WORTH` (3) to their group's firepower, because a player can turn a fight that headcount says is lost.
- **The band** reads the same `r` to pick *how* an offensive runs (`≥2` assault, `1–2` flank/encircle, `0.5–1`
  probe or muster, `<0.5` hold). `P(win)` (whether) and the band (how) are two jobs off one `r`. The band picks
  once, at commit ([§Templates](#templates-phase-5)).

### The pick

From 4C.2 the pick is three steps, run each tick over the gated candidates.

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
  the intent: with a score to rank them, a zone that needs reinforcing three places over is three good buys, not one
  action crowding the list.
- **`random` mode stays the unscored draw** of 4B — uniform over the actions, then over the chosen action's
  targets, never over a shortlist — so the debug page keeps a control to compare the weighted commander against.

### Candidates

| Action | Targets swept | Chunk |
|---|---|---|
| Bank | one null | 4B.1 |
| Zone Reinforce | each uncontested OPFOR zone below full strength | 4B.1 |
| Zone Fortify | each uncontested OPFOR zone below tier IV | 4B.1 |
| Zone hardpoint Build | one action per unlocked ring type, its targets every uncontested OPFOR zone with a free hardpoint slot (`fnc_hardpoint_zone_cap`) | 4B.1 |
| Town Reinforce | each OPFOR-band town below full strength | 4B.2 |
| Town Fortify | each OPFOR-band town below tier IV | 4B.2 |
| Rapport | each town above −15 and below +10 that OPFOR's area of influence covers (`fnc_aoi_opfor_covers`) | 4B.2 |
| Recruit | once per demand group | 4B.2 supply, 4B.3 combatant, recon and transport |
| Standalone hardpoint Build | one action per unlocked standalone type, its target the tick's band cell — drawn at random in 4B and by the highest coverage Value from 4C.2 | 4B.2 |
| Tower / OP / mortar / battery Build | one action each, target the tick's band cell, under the type's cap and sited by its own rule from 4C.2 ([§Asset siting](#asset-siting)) | 4B.2 |
| Minefield | one action per variant (AT, AP), target the tick's band cell, one 50 m square | 4B.2 |
| Intercept (QRF) | each BLUFOR sighting inside OPFOR's area of influence | 4B.3 |
| Attack | each BLUFOR-held zone | 4B.3 |
| Scout | each `recon` unit's route over stale cells | 4B.3 |
| Arty | each observed target in range of an owned gun off cooldown: a fresh belief sighting, or a BLUFOR zone or FOB observed in the last 15 min | 4B.4 |

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
| Recruit, specialist (`supply`, `transport`, `recon`) | the Value of the best action blocked for want of it |
| Recruit, combatant | the larger of that demand and home-zone worth × exposure × unitForce ÷ (the zone's current force + unitForce) |
| Intercept (QRF) | Σ need over the sighting's 5×5 block × min(1, sighting force ÷ (Σ `_fri` over its 3×3 + 1)) |
| Attack | the zone's `_points` |
| Scout | Σ need × staleness × `OPCOM_SCOUT_SHARE` (0.2) over the unique cells within its K of its route |
| Arty | `effForce` killed × `OPCOM_AP_PER_FORCE` |

- **Rapport favours a neutral town.** A town near −10 turns anyway on the free area-of-influence drift, and a −3
  step barely moves one near +10. The skew is 1 at 0, 0.5 at ±5 and 0.1 from ±9 out, so a town between −15 and −10
  scores at the floor; a town at +10 or more is BLUFOR-held and no target.
- **A combatant counts once.** It joins its zone's reserve pool on hire, so it defends at once; its Value is the
  larger of demand and defense, not the sum, because one unit serves one role at a time. Its gain shrinks as the
  zone stacks up, so combatants gather where exposure is high and a QRF pool forms there with no roster table.
- **A truck is worth its transport demand.** Its supply demand is always 0, because every supply action hires its
  own truck in the same commit when none idles, so no action is ever blocked for want of one. A truck is also cheap
  infantry transport, and that demand lands with land-taxi in 4B.3. Until then a truck hire scores 0, and the
  weighted commander hires a truck only inside a supply purchase.
- **The QRF share** is how much of the local defense the sighted group can overwhelm. `P(win)` says whether the QRF
  can win, so a platoon is worth stopping but a small QRF is not thrown at it.
- **Scout staleness** is min(1, ticks since the cell's last sweep in `DUWS_opcom_grid_seen` ÷
  `OPCOM_BELIEF_EXPIRE`). The share holds Scout below the ground it reveals, since scouting takes and protects
  nothing itself.
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
- **Delay.** Value that lands later counts for less: Value × 0.5 ^ (ETA ÷ `OPCOM_VALUE_HALFLIFE`), with ETA in
  ticks from the route length and the unit's per-cell speed (`DUWS_opcom_speed`). A zone action's ETA is 0.
- **No route-risk discount, no emergency reserve.** A truck's odds en route would read threat, so the risk stays
  with the player as counterplay. A QRF stakes roster units, not AP, and combatant Recruit keeps a pool at the
  exposed zones.

### Need and cover fields

A standalone hardpoint's Value comes from cover over the whole map, not over one zone, because a zone's ring already
defends its zone: weighted toward OPFOR's holdings, and rewarding cover over the sparse sectors between them. Need
and cover span every land cell; standalone and minefield candidates are band cells only. Both change when a
hardpoint is built or cleared or ground changes hands, and need also moves with the traffic layer.

- **Need** (AP). Each OPFOR holding spreads worth × exposure over the 5×5 block around its cell, with weights that
  fall with distance and sum to exactly that figure. Every band cell also carries a flat base for the sparse
  sectors: a zone's average pull per cell (worth ÷ 25) ÷ a tunable ratio starting at 2–3, × the cell's exposure, so
  a holding pulls harder than a gap but not so hard that hardpoints cluster around zones. Each standing asset
  hardpoint spreads its build price the same way and becomes an asset worth protecting; assets site by their own
  rules ([§Asset siting](#asset-siting)), so the cover network builds up around them into the gaps.
- **Traffic** (force), a belief layer. Each sighting raises its cell to the larger of the cell's current value and
  the sighting's force; the value halves every `OPCOM_TRAFFIC_HALFLIFE` (360 ticks, 30 min), so a cell BLUFOR
  crosses once fades within the hour and a route they use every trip stays lit. Need adds each cell's traffic ×
  `OPCOM_AP_PER_FORCE` × `OPCOM_TRAFFIC_SHARE` (0.5), so hardpoints site on the ground BLUFOR use as well as around
  what OPFOR holds.
- **Cover** (0–1). Each standing OPFOR hardpoint within 2 cells, zone rings included, covers half of what is left:
  0, 0.5, 0.75, 0.875. Every type shares that reach.
- A first hardpoint at a frontline zone worth 40 earns about 10, beside that zone's Reinforce at 15; one beside
  other hardpoints earns little.

### Cost

- **Spend** actions (Recruit, Reinforce, Fortify, Build, Rapport, Arty) pay fresh AP at the prices in
  [§What AP buys](#what-ap-buys); a supply-gated one adds its truck's source cost.
- **Commit** actions (Attack, Intercept, Scout) stake roster units: `Cost` = the AP to rebuy the force
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
  which is no fight for the players. How often OPCOM attacks is the offensive `archWeight`'s job, not the Cost's.

### Gate and the savings goal

- **Gate.** A zone or town action drops while that site is contested — the same rule and the same reach for both, so a garrison buy reads one answer wherever it lands. A supply-gated action drops only when no truck idles
  and the wallet cannot cover the action plus a hire. A commit action drops when no eligible unit is free, and no
  pool draws a unit garrisoned in a contested zone. Until 4C.2 any action the wallet cannot cover drops. From 4C.2,
  an offensive that does not muster drops below `OPCOM_PWIN_FLOOR` at commit; a mustering one checks the floor at
  launch ([§Commitment](#commitment-intents-are-sticky)).
- **From 4C.2, an unaffordable action is still scored.** When the top scorer is unaffordable and its ETA,
  `(price − wallet) ÷ income rate`, is inside `OPCOM_SAVE_HORIZON`, it is the savings goal and OPCOM banks that
  tick; an action that outscores it later, such as a QRF, still commits. Past the horizon it drops, and the pick
  runs over the affordable top `OPCOM_PICK_TOP`. Without the goal, cheap actions spend every refill and a better,
  dearer one never becomes affordable.
- **Bank** is a candidate, not a policy. In 4B it is one more action in the uniform draw; in 4C.1 its archetype
  weight sets how thrifty the commander is; from 4C.2 it is `OPCOM_BANK_SCORE`, a flat score below the break-even of an
  action that returns exactly what it costs, so it wins when nothing on the shortlist pays for itself, or when a
  savings goal stands.

### OPCOM debug page and overlay

The Debug menu's OPCOM page and the OPCOM AI overlay are shipped (`fnc_debug_menu.sqf`,
`fnc_debug_opcom_ai_overlay.sqf`). 4C fills in the page:

| Row | Does |
|---|---|
| Mode: weighted | Runs the scored pick. Shipped |
| Pick once: weighted | Runs one scored pick, whatever the mode. Shipped |
| Archetype | Overrides the campaign's archetype (4C.1) |
| Difficulty | Sets the picks per tick, below 1 for one pick every few ticks (4C.2) |

## Commitment: intents are sticky

A chosen action becomes an intent record — same shape at every granularity, `roles` empty (economic), one entry
(simple tasking) or several (a template):

| Field | Holds |
|---|---|
| type / target | the action id; the objective (registry index or cell) |
| roles | `[role, unitRef, status]` bindings drawn from the roster |
| phase | index into the template's phase list |
| hold | `DUWS_opcom_tick` at commit + `OPCOM_COMMIT_HOLD` — earliest tick OPCOM may re-issue this unit's order |
| state | mustering / ordered / in progress / done |

- **The hold is an absolute anti-flap lock** (KISS), not a success deadline: a committed unit is held the full span
  no matter what; a target that dies mid-hold is re-evaluated once it expires. Resting `garrison`/`guard` are
  unheld. Re-scoring fills free capacity and may re-task a unit only past its hold — a de-virtualised unit included
  (a new order pushes onto the live group), a live water crossing included; only a *bound* ferry carry is off-limits.
- **There is no retreat.** The engine owns a group in `COMBAT` and ignores a commanded withdrawal
  ([`arma_engine_gotchas.md`](../../info/architecture/arma_engine_gotchas.md#a-group-in-combat-behaviour-ignores-a-commanded-move-order)).
  A group that wins drops to `moving` and re-virtualises on clearing; one that loses dies. Recovery is winning.
- **A multi-unit assault musters, then launches as one wave** (Phase 5, WIP). In `mustering` it binds force across
  ticks at a safe rally short of the target, then advances all together — it never dribbles units into contact,
  which no-retreat would turn into defeat in detail. It launches the tick its bound force reaches the archetype's
  **ideal** ratio over believed BLUFOR force at the target (1.5:1 baseline). At `OPCOM_MUSTER_EXPIRY` it launches if
  it holds at least the archetype's **minimum** (0.75:1 baseline), and is otherwise abandoned, its units returning to
  rest, so a player who keeps reinforcing cannot hold it forever. The baseline sits below an attacker's usual 3:1
  because a sighted player already counts as 1 + `OPCOM_PLAYER_WORTH`, so a believed 1.5:1 is already a hard fight
  for the players, and a 3:1 wave is one they can only survive. Both bars read believed force, so a mid-muster
  reinforcement raises them. A mustering action checks `OPCOM_PWIN_FLOOR` at launch, against its archetype's
  minimum, because it commits below the odds it launches at. Mustering is also how a force-short action waits for
  units — from the roster or from Recruit.

## Templates (Phase 5)

**WIP.**

A template is a unit-dispatching action's execution form — named roles and a phase sequence a single generic
**runner** steps off unit status. It is not separately scored (the action is; the template is *how* it runs), and a
simple tasking is the one-role, one-phase case, so adding a coordinated behaviour is a bigger template, not a new
subsystem. There is no planner.

**The runner**, each tick over every live intent with roles: refresh each bound unit's status; a required role
`dead`/lost → **abort** (release survivors, no AP refund); else advance `phase` when its transition predicate holds
(predicates read child status and geometry only); last phase complete → done, release. The runner sequences phases;
the route/streaming machinery moves the units.

**The roster** is the free-unit pool — every uncommitted `garrison`ed or `guard` unit, except one garrisoned in a
contested zone. Binding pulls a unit (a `garrison`ed draw strips that zone's reinforcement); release returns it.
One unit, one owner. A template applies only when its band fits, enough roles fill, and the geometry holds; short a
role, it commits in `mustering`. The band picks the template once, at commit, and a muster launches that template
whatever `r` it reaches, so a plan never flips mid-muster: the template picked at commit is the one that launches,
even when the muster ends in another band.

| Template | Picked when | Roles | Phases (→ on transition) |
|---|---|---|---|
| `assault` | band ≥ 2 | `attacker` ×1 | approach (direct) → S&D → resolve |
| `flank` | band 1–2, ≥2 mobile, a reachable flank cell | `fix` ×1, `maneuver` ×1+ | form (fix frontal; maneuver → flank cell, λ route) → *(fix engaged)* assault → resolve |
| `encircle` | band 1–2, target pocketed, ≥3 mobile | `blockers` ×N (per escape corridor), `crushers` ×1–2 | deploy (blockers → corridors) → *(in position)* seal → crush (inward) → resolve |
| `probe` | band 0.5–1 | `prober` ×1 (cheapest expendable; never armour/air/recon) | approach → make contact → resolve (survives ⇒ soft, escalate; dies ⇒ confirmed, mass/re-target) |
| `rapport` | a `supply` truck, a Rapport candidate town ([§Candidates](#candidates)) | `courier` ×1 | move → deliver (rep −3) → resolve |
| `scout` | a `recon` unit, a stale valuable area | `recon` ×1 | move (plain `move`; standing recon detection stamps belief as it goes) → resolve |
| `arty` | an observed target in range of an owned gun off cooldown | owned `guns` ×1–3 (hardpoints, 0 roster), `spotter` ×0–1 | mark → salvo (rounds × saturation) → assess (force dropped? re-fire : done) |

- **`probe` is disposable recon-by-fire** — no-retreat forbids poke-and-withdraw, so it converts uncertain belief
  into observed defender strength by drawing fire, reaching what recon cannot (a dug-in town garrison). It minimises
  stake, the inverse of every other commit, which gathers force toward the odds it launches at.
- **Escape corridors** (`encircle`): the target cell's neighbours whose enemy-influence gradient points outward.
- **`resolve`** is the transition that frees the units and writes the outcome, one predicate per action
  ([§Shipped](#shipped-the-substrate-the-loop-drives)): **Attack** — OPFOR take the zone by the mirror of BLUFOR's capture rule
  (`DUWS_fnc_siteTaken`): an OPFOR unit inside the radius, the zone's BLUFOR garrison beaten, tier 0 (none built)
  counting as beaten, and OPFOR outnumbering BLUFOR over the streaming ring, all for `DUWS_captureHold`. A live fight flips through the retake
  trigger; a virtual attacker at an empty zone flips it on the OPCOM tick against stored state once it has held
  the radius for `DUWS_captureHold`, and OPCOM sends that attack's contact report itself. The
  attacker garrisons the zone once it is virtual. **Intercept** — at the sighting's last known position the unit
  reads truth within its own K: nothing there, it drops to `guard` in place; BLUFOR there, it fights them live and
  guards once none remain. It never returns to garrison. **Rapport** — courier delivers or dies.

**Routes read threat on the road and off it.** A wheeled or tracked route takes the same threat term as the foot
cell chain, `OPCOM_ROUTE_LAMBDA` × the order's λ × `_ene`, so a hull takes a flanking road, or leaves the road to
flank, rather than drive through a threatened stretch. One A* runs over road segments and land cells together: a
road segment costs its length plus the threat term over the cells it crosses, and an off-road step costs its length
× `OPCOM_ROUTE_OFFROAD` plus the same term. The route leaves or rejoins the road where a segment crosses a cell. An
off-road stretch is a `gap` segment the hull drives itself, so the water test that rejects a wet gap still applies.
The off-road layer joins the search only when λ > 0, so at λ 0 the search is the length-only road search and the
convoy side missions, which share `fnc_convoy_path`, route as before. Every order routes with λ > 0, a supply truck
included. A supply truck's route is planned once, at departure, and never re-planned, so the truck skirts only the
threat believed when it leaves and drives on into any threat that appears after. Today the road branch is
threat-blind and every caller passes λ 0 (`taskings/fnc_opcom_route.sqf`).

Phase 5 settles in play the band thresholds, the route λ weights and their recompute cadence,
`OPCOM_ROUTE_OFFROAD` and the longest off-road leg a hull drives without stalling, and `OPCOM_MUSTER_EXPIRY`.

## What AP buys

**WIP.**

Three levels: **Action** (what AP commits to, scored and held), **Sink** (how it's paid — tier / strength / build /
tasking-spawn / bought fire mission), **Tasking** (orders emitted: 0 economic, 1 simple, N template). One actor
shares `WARCOM_opfor_ap`; every sink competes in the one appraisal — none runs on its own clock. Spends call
`["OPF", -_cost, _reason] call fnc_ap_adjust` (server-side, single writer, no race).

| Action | Class | Target | Sink | Taskings |
|---|---|---|---|---|
| Attack | offensive | a BLU-held zone | tasking-spawn | 1–N (band → template) |
| Intercept (QRF) | defensive | a BLUFOR sighting inside OPFOR's area of influence | tasking-spawn | 1–N |
| Rapport | offensive | a town above −15 and below +10 inside OPFOR's area of influence (needs `supply`) | tasking-spawn | 1 courier |
| Recruit | buildup | the highest-value demand group | tasking-spawn | 1 (`garrison`, resting) |
| Reinforce | defensive | an own depleted zone / town garrison | strength purchase | 0 zone / 1 truck town |
| Scout | recon | a `recon` unit's route over stale valuable cells | tasking-spawn | 1 |
| Arty | offensive | an observed target in gun range | bought fire mission | 0 |
| Fortify | defensive | an own town / zone | tier purchase | 0 zone / 1 truck town |
| Build | defensive | an own zone ring or band cell, one action per unlocked type | hardpoint build | 0 zone / 1 truck standalone |
| Tower Build | buildup | a band cell | hardpoint build | 1 truck |
| OP Build | recon | a band cell | hardpoint build | 1 truck |
| Mortar Build | indirect | a band cell | hardpoint build | 1 truck |
| Battery Build | indirect | a band cell | hardpoint build | 1 truck |
| Minefield | defensive | a band cell (AT, AP) | mine lay | 1 truck |
| Bank | bank | — | none | 0 |

- **Recruit fills the roster; every other unit-dispatching action drains it** — so OPCOM must build up before it
  strikes, and a lost unit is lost standing strength. It scores **once per demand group** (combatant, `recon`,
  `supply`, `transport`), each valued as [§Value](#value) sets out, so it hires what it is short of.
  Units spawn only from OPFOR-held ground; taking the zone cuts what it can raise.
- **A unit's force is a token composition** — a row in `DUWS_opcom_recruitMenu` (`fnc_opcom_tasking_init.sqf`): an
  id, a **bare**-token composition (`none` posture, so OPCOM commands it), and capability flags. `OPCOM_AP_UNIT`
  prices the row by its id, so the menu carries no price column.
- **Capability flags decide what a unit unlocks; there is no unit "type".** `recon` → Scout (range by platform,
  `OPCOM_RECON_K` cells), `supply` → a delivery run, `transport` → carry another unit, `transportable` → ride a
  ferry across water; `noncombat` keeps a row out of a zone's reserve pool (regardless of armament — the boat is
  armed). A row may carry several.

Prices, first-pass defaults set against OPFOR's income of roughly 40–80 AP per 30 min (`fnc_zonesundercontrol.sqf`):

| Purchase | Price |
|---|---|
| Unit hire | `OPCOM_AP_UNIT` by menu row: rifles 10, weapons team 5, recon foot 5, truck 3, recon car 10, boat 3, APC 15, IFV 25, MBT 40, recon helicopter 20, transport helicopter 10, attack helicopter 60 |
| Zone Reinforce / Fortify | `OPCOM_AP_REINFORCE` 15 / `OPCOM_AP_FORTIFY` 25, flat |
| Town Reinforce / Fortify | the same flat price, plus the truck's source cost |
| Zone hardpoint | `OPCOM_AP_HARDPOINT`: roadblock 8, MG 12, GMG 16, AT 16, AA 20 |
| Standalone hardpoint | as a zone hardpoint, plus the truck's source cost |
| Radio tower / OP / mortar pit / artillery battery | `OPCOM_AP_TOWER` 30 / `OPCOM_AP_OP` 15 / `OPCOM_AP_MORTAR` 25 / `OPCOM_AP_ARTY` 50, plus the truck's source cost |
| Minefield | `OPCOM_AP_MINEFIELD` 15 per 50 m square, plus the truck's source cost |
| Rapport | `OPCOM_AP_RAPPORT` 10, the goods the courier carries, plus the truck's source cost |
| Truck source | the hire price (3), or 0 for an idle truck on hand, plus `OPCOM_AP_PER_KM` 0.5 × distance; the lowest wins |
| Fire mission | `OPCOM_AP_PER_ROUND` 2 per round |

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
- **Force still converts to AP in three places** — the `Cost` of staking a unit on a commitment, Arty's Value in
  kills, and the traffic layer's contribution to need. All are 4B.3 and later, so `OPCOM_AP_PER_FORCE` is defined
  when the first of them lands rather than sitting unread.

**Supply gates the town-side builds.** A `supply` truck drives from OPFOR ground to its target and is spent on
arrival, behind four actions: Rapport, standalone Build, and *town* Reinforce / Fortify
([§Shipped](#shipped-the-substrate-the-loop-drives)). The action takes an idle truck on hand, or hires one and tasks it in the same commit,
whichever source costs less. A town takes one supply truck at a time: while one drives to it, no supply action
targets it. The AP is paid at commit but the result lands only when the *specific* bound truck
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
pick, so the pick draws "an AT nest" or "a battery", never "a build", and the archetype and the score weigh one
against the other. The weight tables —
`DUWS_hardpointWeightZone` (MG, AT, GMG, roadblock) for a ring, `DUWS_hardpointWeightSolo` for the standalone rows — are the
per-type prior the 4C.1 weight multiplies; campaign generation still rolls them. An asset hardpoint is its own
candidate, never stands in a zone's ring, and picks its band cell by its own rule ([§Asset siting](#asset-siting)). A
minefield is laid, not built: one 50 m square per action (`fnc_hardpoint_minefield_grid`), AT and AP each their own
candidate, with the size on the target so a deeper belt costs by its footprint. A build cannot be a *typed* counter
(AT under armour) until belief carries threat category, which 4C.2 settles ([§Appraisal](#appraisal-phase-4)).

Construction is an AP sink; a cleared build refunds nothing (clearing pays the player CP only), and only a build that
finds no ground is refunded, in full, its truck included. Unlocks (`DUWS_hardpointTier`) key off `WARCOM_opfor_tier`,
which climbs the earned-AP rungs (`DUWS_ap_tier_rungs`), never the spendable wallet; each cap counts a build still on
its truck:

| Tier (earned AP) | Types a build may place |
|---|---|
| 1 Infantry (0) | radio tower (max `AOI_OPFOR_TOWER_CAP` alive, 5), OP, MG, roadblock |
| 2 Motorised (60) | + AT, minefield |
| 3 Mechanised (150) | + GMG, AA, mortar pit (max 2 alive) |
| 4 Armour (350) | + artillery battery (max 1 alive) |
| 5 Jets (600) | nothing new |

Hardpoint garrisons stay fixed per type (`DUWS_hardpointGarrison`). Knobs (all tune): seed subset 2–3 at init; no
live cap (bounded by player proximity).

### Asset siting

Each asset type picks its band cell by the rule below, which ranks cells on the same coverage its Value measures
([§Value](#value)) — the siting pass is the Value run over several cells instead of one. Until it lands, and in all
of 4B, an asset scores the one random band cell the tick drew, so a poor cell falls off the shortlist and a good one
is bought. Inside the cell, the shared terrain siting picks the spot (`fnc_hardpoint_score`,
[`info/hardpoints.md`](../../info/gameplay/hardpoints.md#siting)).

| Asset | Band cell |
|---|---|
| Radio tower | the most town worth brought newly under OPFOR's area of influence, outside every standing tower's `AOI_TOWER_REACH` (the campaign-generation rule, `fnc_hardpoint_seed_radio`) |
| OP | the most cells within `OP_OBSERVE_K` that no other OP's ring already covers |
| Mortar pit | the most OPFOR ground within `OPCOM_MORTAR_REACH` (5 km) that no other mortar reaches, with no pit within `OPCOM_GUN_STANDOFF` (1 km) |
| Artillery battery | the same over `OPCOM_ARTY_REACH` (20 km), against the other batteries |
| Minefield | the band cell holding the most traffic, since a field is worth what it denies and denies nothing on ground nobody crosses |

A gun's true range depends on the faction's gun and is read only at fire time (`inRangeOfArtillery`), so siting and
Value both use a fixed reach per type.

### Indirect-fire hardpoints

Persistent enemy assets, two tiers sharing one fire-mission implementation. The order ships
([§Shipped](#shipped-the-substrate-the-loop-drives)) and an AI gunner executes `doArtilleryFire` reliably, so the
guns fire for real rather than needing shells spawned over them; **nothing decides to use it** — no cooldown, shape
choice, observation gate or HQ exclusion. A zone's own mortar is separate and stays autonomous
(`fnc_static_resolve`), uncapped here.

| | Mortar pit | Artillery battery |
|---|---|---|
| Core | static `opfor_TURRET_MORTAR` | self-propelled `opfor_ARTY_X` |
| Unlocks at | tier 3 (150 earned AP) | tier 4 (350 earned AP) |
| Cooldown | 4–8 rounds, then 25–40 min | 6–10 rounds, then 40–60 min |
| Spread | tighter (base 50 m) | wider (base 100 m) |

- **A fire mission is the Arty action** — scored and committed like any other, `Cost` scaling with rounds ×
  saturation; it fires only when that action wins its phase, never on a schedule. The owned gun off cooldown and in
  range is the availability gate, nothing more. **AP is the ammunition** — the guns rest empty and are loaded per
  mission, so there is no finite store and the wallet is the only limit.
- **Observation is the trigger** — nothing is shelled the enemy has not seen. A player above `east knowsAbout ~1.5`
  (shared with the sighting sweep); a BLU zone/FOB an OP covers or an OPFOR element was within ~500 m of in 15 min.
  OPs are the artillery's eyes; killing them blinds guns.
- **HQ exclusion** — no mission *aimed* inside 100 m of `PosOfBLUHQ` (rounds may still stray there from a barrage
  aimed elsewhere). The target grid is latched `[x,y,0]` at order time (never an object ref that would follow a
  respawn into the circle), and re-checked against the circle immediately before firing.
- **Spread** is the size the action hands the shipped shape — a saturate's radius, a creep's width: base by type,
  +25 m per km range, −30 m with direct OP observation, never below `OPCOM_ARTY_MIN_SPREAD`. The Cooldown row's
  rounds are a saturate's; a creep's follow from its width and length. Telegraph: Allseer line + a temporary marker
  ~20 s before impact.
- **Capped campaign-wide** — one battery and two mortar pits alive at once across the map. These are the only
  permanent-crew hardpoints (~6 units that never despawn); making AA resident would add a fourth and needs its own
  cap.

## Archetype

**WIP.**

One archetype per campaign, a campaign setting chosen at start (Defensive, Balanced, Aggressive or Random), sets the
`archWeight[archetype][actionClass]` factor — it weights an action class's draw in 4C.1 and *multiplies* its score
from 4C.2, never removes an action, and cannot override the ladder (an Aggressive commander with no armour tier
fields none). It is stored in the persistence snapshot and never re-rolled. A Random pick stays hidden: the config
diary note shows "Random", and nothing in play reveals it. The OPCOM debug page overrides it for testing. It is not
difficulty (`opfor_ai_skill` sets aim). A single authored per-class table, Bank included: bank, defensive,
offensive, buildup, recon and indirect, the guns' own class, so an archetype leans on indirect fire with no per-type
table; further leans (armour) become rows. 4C.1 builds the setting and the table.

| Archetype | Weights toward |
|---|---|
| Defensive | Fortify, Reinforce, Build, Recruit, Intercept |
| Balanced | no strong lean — the baseline |
| Aggressive | Attack, Rapport; leaves ground thin |

Beyond `archWeight`, an archetype sets the commander's patience: the muster ideal, minimum and expiry,
`OPCOM_SAVE_HORIZON` and `OPCOM_VALUE_HALFLIFE`. A patient, strategic commander musters and saves longer for a
properly executed manoeuvre; a flexible, aggressive one launches sooner at lesser odds. Phase 6 builds that
patience; the Balanced baseline (a 1.5:1 muster ideal, a 0.75:1 minimum) applies until then. Phase 6 settles the set of
archetypes, which is not final.

## Town & zone garrisons

The OPFOR town ladder (tiers 0–IV in `DUWS_townSpawnTiers`, per-town `DUWS_townGarrisonTier` via
`fnc_town_garrison_setTier`) and the zone tiers are shipped and documented in
[`info/zones_and_civilians.md`](../../info/gameplay/zones_and_civilians.md#garrison-tiers-0-to-iv). Reputation
decides *whether* a town garrisons (crossing −10 writes tier I); AP decides *how hard*. Clearing a town drops it to
tier I at strength 0 (no refund), and it cannot be cleared again until OPCOM resupplies it.

Not built:

- **BLUFOR garrisons.** BLUFOR buy garrisons for zones and towns as OPFOR do. The BLUFOR band (`>= 10`) has no
  garrison; buying tier I at a held town *creates* one at zero strength (each reinforcement +30 %), never inherits
  OPFOR's — captured ground carries no tier or strength. The presence latch is still wanted (a BLUFOR garrison
  streams), but the `Mobilising` hold is not (a BLUFOR garrison never arrives on ground it owns). A
  BLUFOR-held site also wakes when an OPCOM attacker, live or virtual, closes within K, so its garrison renders and
  renders the attacker in turn.

## Random events: what a turned town does

Shipped separately, not an OPCOM build phase. A turned town — reputation `<= -10`, inside the OPFOR band — acts on
its own, free and rolled off reputation: IEDs on approach roads, ambushes on passing patrols, sabotage against
nearby FOBs, planned outside the town's presence trigger so it can mine a road ahead of the player.

## Rejected: the OPFOR spawners this replaces

WARCOM's three OPFOR threads (roaming patrols, attack waves, random air) are deleted. The director **must not
reproduce their shape**: routes closed with a `CYCLE` and never despawned, cadence was unconditional, AP was read
but never spent (a one-way ratchet), and spawns sited >1500 m from every player so contact only happened when the
player drove into them. Three behaviours are worth rebuilding as commander decisions: **target selection** (old
distance-sort of BLU zones; a rebuild reaches HQ only through belief); **dismounts** (a second infantry team
`joinSilent`ed into a vehicle group above AP 100 — keep as a composition Recruit buys); the **ammo truck** is not
carried (garrison restoration is now Reinforce).

## Persistence

**WIP.** Planned, not shipped ([`campaign_persistence_plan.md`](../campaign_persistence_plan.md)); today
persistence is the engine's `saveGame`. OPCOM's store is shaped to serialise but implements no save/load —
persisting its state is the snapshot's responsibility. Every field is a number, string or array.

| Saved | Holds |
|---|---|
| **Archetype** (input) | Fed back before the loop, never re-rolled |
| **Standing units & orders** (outcome) | One row per unit: world position; order, target, home and return zone, route mode; `strength`; class — the composition tokens and `spawnClass`, the hull drawn once at hire, so a restored vehicle keeps its hull. Restored as data, streaming to a live group on approach at saved strength |
| **Clock and flags** | `DUWS_opcom_tick`, the count of ticks since the campaign began, which every stored time counts against — a commit `hold` restored against a counter reset to 0 would hold its unit for hours — and the HQ reveal flag |
| **Inputs owned elsewhere** | Tiers (`WARCOM_opfor_tier` and the earned counter, the economy's); zone and town owners, which exposure and the candidate sweep read (the campaign snapshot's BLUFOR-held zone positions and town reputation) |

- **Belief sightings are not saved.** Belief is keyed by group `netId`, which resolves to nothing after a restart,
  and a restart also loses the headless clients and returns players to HQ, so the sightings would describe a
  battlefield that no longer exists. The grid, its coverage layer and the contested set rebuild from the first
  sensor pass, and the traffic layer refills as sightings land.
- `fnc_opcom_belief_init` sets the tick to 0 today; it must initialise the tick and the HQ flag only when they are
  nil, or a restore resets them.
- A saved `spawnClass` the loaded mods no longer define is rerolled from its token against the current faction
  settings (`DUWS_fnc_tokenClass`), with a WARN. A token the current faction cannot field at all drops the unit,
  with a WARN.

## Naming: OPCOM sits inside WARCOM

OPCOM is a component of WARCOM, not a replacement; prefixes split by ownership, nothing mass-renamed. Shared
war-economy state stays `WARCOM_` (`WARCOM_opfor_ap`/`_tier`); OPCOM's own state takes `OPCOM_`; the belief store
keeps `DUWS_` with an `opcom_` owner tag.
