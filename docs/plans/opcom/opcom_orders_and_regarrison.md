# OPCOM unit orders and re-garrison

An order is the `order` key on a tasking record. The step stage dispatches through it once per tick
(`taskings/fnc_opcom_task_step.sqf:119`) against the one table that knows every order,
`DUWS_opcom_orders` (`taskings/fnc_opcom_orders.sqf:40`). The commander never picks an order directly: it picks an
action, and the action's run hands `fnc_opcom_task` the order that carries it
([opcom_plan.md §Appraisal](opcom_plan.md#appraisal-phase-4)).

The first half is the flat list of orders. The second is the action that reads against it: sending a worn unit home
to heal.

## Orders

One flat list: every action a unit can be doing, one order apiece, each a row in `DUWS_opcom_orders`.

| Order | What the unit does | Ends on |
|---|---|---|
| `garrison` | rests virtual at its home site, healing, and fields its force through that site's reserve pool | a draw, its home flipping (`siteLost`), or its reserve group being wiped (`defenderLost`) |
| `guard` | holds the point it stands on. No heal, no route | the next action that draws it |
| `patrol` | walks a line over stale ground, stamping the staleness layer as it goes (`fnc_opcom_patrol_sense`) | arrival: settles to `guard` |
| `move` | repositions to a point and holds it. It neither heals nor sweeps, which is exactly what a staging leg needs, so Phase 7's buildup is its caller ([opcom_plan.md §Orchestration](opcom_plan.md#orchestration-phase-7)). Until 5.2 only the debug page issues one | arrival: settles to `guard` |
| `return` | marches to a site and joins its garrison | arrival: `garrisonInto` |
| `errand` | carries goods to a drop and spends them there | delivery: the unit despawns and its record reads `done` |
| `capture` | marches on a BLUFOR-held zone or garrisoned town | the ground changing hands (`captureEnd`): virtual, it garrisons what it took; live, it guards and garrisons when it stows; a cleared town keeps no garrison, so it only guards |
| `intercept` | follows a belief row's position, re-planning past one cell, and hunts what the arrival look finds | nothing within `OPCOM_INTERCEPT_K`: guards and drops the row (`interceptGuard`) |
| `ferry` | fetches a bound rider, carries it over the leg it could not cross, unloads it, then goes home | release (`ferryRelease`): `return` to the nearest uncontested held zone, else `guard` |

**Riding is a binding, not an order.** A rider keeps whatever order it was given and adds `ridingOn`; `task_step`
skips it while it is bound, and the drop resumes its own order. Making it an order would mean stashing the order it
must come back to, which is the binding again by another name.

### Why patrol, return, errand and ferry are their own orders

- **One order, one meaning.** `move` used to carry a site key or an errand and mean three different things, so
  `stepMove` branched on the keys and every caller had to know the key protocol rather than the order. Each of the
  three now has its own step and `fnc_opcom_task` refuses the mismatch: a `return` with no site, an `errand` with no
  goods.
- **A carry is dispatched outside the table.** `fnc_opcom_task_step.sqf:137` short-circuits on `carrying` and hands
  the record to `ferryTick`, so a carrying hull's order is never stepped. It reads `ferry` so the debug pages, the
  map and the roster say what the hull is doing; the phase it is in lives in `ferryPhase` (`topickup` / `carry`).
- **Per-order gating is written as order-string lists**, and they now say what they mean. Land-taxi's rider check
  reads `capture`, `intercept` and `return` (`fnc_opcom_taxi.sqf:22`) — a patrol is deliberately off a lift, since
  covering ground is the point of one, and before the split it was silently on it because Patrol issued `move`.
  `applyOrder` profiles a courier apart from the rest on the same list (`fnc_opcom_stream.sqf:8`), so the `_supply`
  flag it needed is gone.
- **Out on the ground is the complement of the two rests**, not a list of names: `DUWS_fnc_opcom_marching` is
  `!(order in ["guard", "garrison"])`, so an order added to the table is out by default rather than forgotten by the
  overlay and the intel payout that read it.

The split bought naming and dispatch, not behaviour: `patrol` steps as `move` does, and `return` and `errand` are
the two branches `stepMove` had, lifted into their own steps over the shared march (`fnc_opcom_movement_core.sqf`).

- **Only `guard` and `garrison` are drawable** (`fnc_opcom_tasking_init.sqf:80`), and the roster's free list is
  drawable units alone (`appraisal/fnc_opcom_roster.sqf:6`). A unit mid-march is a candidate for nothing: every
  commit action draws from units standing still. A garrison whose home is contested is held back too — it is
  defending.
- **`garrison` is the only order that heals.** `stepGarrison` adds `OPCOM_GARRISON_HEAL_RATE` (0.05) × `fullForce`
  per tick, capped at `fullForce`, so a wrecked unit refits in about 20 ticks once home. `guard` explicitly does
  not heal, so a unit left standing forward keeps its losses for the rest of the campaign.
- **Wear only happens live.** `effForce` is recomputed from the survivors whenever a live group is read
  (`fnc_opcom_stream.sqf:167`, `:189`) and a worn unit spawns weaker on its next render
  (`DUWS_fnc_opcom_matchStrength`, `:127`). A virtual campaign never wears anything, so all of this matters only
  once the players have made contact.
- **A garrisoned unit fights as a reserve token, not as itself.** It contributes one marked token
  `opcomdef<id>:<name>` to its site's reserve pool (`fnc_opcom_garrison.sqf:34`), the pool fields that token's whole
  composition when the site defends, and its group's wipe is the unit's death. The pool spawn does not scale to
  `effForce`, so a worn unit defends at full strength while resting and only carries its wear back out on the next
  order.
- **`status` is not an order.** `virtual` / `moving` / `engaged` / `dead` / `done` say what the record is doing with
  the order it holds; whether it is rendered is the `grp` key, not the status.

### Chunk

| Chunk | Builds | Settles in play |
|---|---|---|
| **4B.8** Order split | **Shipped** (`taskings/`, `appraisal/`, `debug/`) — `patrol`, `return`, `errand` and `ferry` as rows of their own, `stepMove` split into `stepMove` / `stepReturn` / `stepErrand`, `fnc_opcom_task` refusing a `return` with no site or an `errand` with no goods, `applyOrder` profiling each and dropping its `_supply` flag, `DUWS_fnc_opcom_marching` in place of the order-name lists the overlay and the intel payout carried, and the order strings the Patrol row, `captureEnd`, `ferryHome`, `carryBind`, land-taxi and both debug pages issue | Whether `ferry` should take the dispatch back from the `carrying` short-circuit, or stay a stage the table merely names |

## Re-garrison (4B.9)

Nothing sends a worn unit home. A unit that survives an Attack outside its objective, an Intercept that found
nothing, or a Patrol settles to `guard` where it stopped and holds there at whatever strength the fight left it,
because only `garrison` heals and only the home zone's reserve pool can field it. The commander's own force
therefore decays monotonically between hires: it can buy strength but never recover it. This chunk adds the action
that recovers it, and it answers the question 4B.5–6 left open — whether a screen left standing needs a way home.

**The order already exists.** A `return` settles into `garrison` on arrival (`DUWS_fnc_opcom_stepReturn`), which is
how a capture walks its taker home, so this is an appraisal chunk: a sweep, a Value and a row, with no tasking code
of its own.

### Shape

| Part | Decision |
|---|---|
| Pool | the free units (`DUWS_fnc_opcom_free`) whose order is `guard`, carrying no errand, whose `effForce ÷ fullForce` is under `OPCOM_REGARRISON_FRAC` (0.6). Combatants and recon alike; a `noncombat` hull too, since it heals the same way |
| Target | its own `homeZone` when that is still open, else the open zone nearest it (`DUWS_fnc_opcom_nearestOpen` over `DUWS_fnc_opcom_zonesOpen`). A boat homes to a port or `fnc_opcom_task` refuses the order |
| Order | `return`, at the home site's position |
| Run | its own, since `DUWS_fnc_opcom_sendRun` hands `fnc_opcom_task` no site key (`fnc_opcom_commit.sqf:31`). It binds a taxi after the order, as an Attack does, so a lift can carry a broken squad home |
| Value | the larger of the rebuy its heal recovers, `(fullForce − effForce) × OPCOM_AP_PER_FORCE`, and the defense it adds at that zone, `DUWS_fnc_opcom_hireDefense` on its `effForce` — a unit counts once, as a combatant hire does |
| `P(win)` | none: a withdrawal does not fight for its target ([opcom_plan.md §Appraisal](opcom_plan.md#appraisal-phase-4)) |
| Cost | `DUWS_fnc_opcom_commitCost` unchanged: a `guard` unit abandons no garrison, so it stakes its rebuy alone |
| Blocked | nothing. No hire substitutes for the unit that is already bought, so this sweep feeds Recruit no demand |

One row per eligible unit, not one per zone: the target follows from the unit, so there is no contest to resolve and
nothing for a second row on the same zone to crowd out.

### Why the score points the right way

Value rises with wear, because the heal recovers more. Cost falls with wear, because the rebuy is priced on
`effForce`. So the score climbs steeply as a unit is ground down, and a nearly fresh unit scores near nothing —
which is the whole behaviour asked for, without a hard threshold doing the work. `OPCOM_REGARRISON_FRAC` is a floor
on the pool, not the lever: it keeps lightly scratched units off the shortlist entirely.

The delay discount (`DUWS_fnc_opcom_unitDelay`) prices the march, so a worn squad two zones deep chooses to keep
holding and one near home goes back. Nothing needs to stop a rested unit being sent straight out again: `effForce`
is what `pWinSend` and a combatant's Patrol scale both read, so a weak unit loses those contests until it has
healed.

### Chunk

| Chunk | Builds | Settles in play |
|---|---|---|
| **4B.9** Re-garrison | **Shipped** (`appraisal/`) — the `regarrison` row, its sweep and its own run, the Value in `appraisal/value/fnc_opcom_regarrison.sqf`, `OPCOM_REGARRISON_FRAC` and the `regarrison` weight key | `OPCOM_REGARRISON_FRAC` (0.6), and whether the pool floor is needed at all once the score's own slope is played; whether a worn unit crowds the shortlist when a whole wave comes back battered, the fallback shape being the best few rows rather than one per unit; whether paying a lift to carry a broken squad home is worth it, or a re-garrison should ride `sendRun` and walk; whether a withdrawal across believed force needs a `P(win)` after all, since a unit sent home through a BLUFOR advance is worse off than one holding; whether the reserve pool fielding a worn unit's full composition should scale to `effForce` instead, which would make resting a cost rather than a free repair; whether a `guard` unit far from any open zone should be left where it stands |
