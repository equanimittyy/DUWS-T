# OPCOM grid: delta processing

The grid stage (`src/duws/server/warcom/opcom/belief/fnc_opcom_grid_rebuild.sqf`) zeroes both layers and
deposits every source on every tick. This plan splits the sources in two. Static sources live in a cached
layer that changes only for a source marked dirty. Dynamic sources are deposited on every tick. The cost of a
tick then follows what changed, per the rule in
[`performance.md`](../../info/architecture/performance.md#an-opcom-stage-costs-what-changed-not-what-exists).
Readers see the same two layers, `DUWS_opcom_grid_fri` and `DUWS_opcom_grid_ene`, with the same values.

The one-thread, one-tick cadence ([`opcom_plan.md`](opcom_plan.md)) does not change.

## Sources

A source's class is decided when the source is processed as dirty, and it holds until the next mark.

| Source | Layer and weight | Class | Inputs that change it |
|---|---|---|---|
| BLUFOR-held zone | `_ene`, `OPCOM_GRID_ZONE_ENEMY_FORCE` | static | zone ownership |
| OPFOR zone, garrison not live and composition stowed | `_fri`, `DUWS_fnc_garrisonForce` | static | ownership, the garrison ledger, the live flag, stow and deploy, earned OPFOR AP |
| OPFOR zone, garrison live or composition deployed | `_fri`, `DUWS_fnc_garrisonForce` | dynamic | men and statics die between ticks |
| Banded town, garrison not live | `_fri`, `DUWS_fnc_garrisonForce` | static | the garrison ledger, the live flag, earned OPFOR AP |
| Banded town, garrison live | `_fri`, `DUWS_fnc_garrisonForce` | dynamic | men die between ticks |
| OPFOR hardpoint row | `_fri`, `DUWS_fnc_hpForce` | static | register, clear |
| Belief stamp | `_ene`, strength × age decay | dynamic | decays every tick |
| Tasking | `_fri`, stored `effForce` | dynamic | moves every tick |

Source keys are the existing site keys: `zone_<x>_<y>` (`fnc_zone_key`), `town_<n>` (`fnc_town_site_key`) and
the hardpoint registry key (`hp…`). The three forms cannot collide. A zone's composition key is its zone key.

## State

All state is server-side and derived, so the planned campaign save
([`campaign_persistence_plan.md`](../campaign_persistence_plan.md)) stores none of it. OPCOM init rebuilds it
with a dirty-all.

| Global | Shape | Holds |
|---|---|---|
| `DUWS_opcom_gridStaticFri`, `DUWS_opcom_gridStaticEne` | full-width lattice, the published layers' indexing | the deposits of every static source |
| `DUWS_opcom_gridSrc` | HashMap, key → `[layer, pos, weight, reach]` | each static source exactly as deposited. An absent key has no static deposit |
| `DUWS_opcom_gridAwake` | HashMap, key → `[pos, reach]` | the dynamic sites |
| `DUWS_opcom_gridDirty` | HashMap used as a set | keys marked since the last tick |
| `DUWS_opcom_gridDirtyAll` | bool | a mark for every source |

## The tick

1. If `DUWS_opcom_gridDirtyAll` is set, zero both static lattices inside `DUWS_opcom_box`, then empty
   `DUWS_opcom_gridSrc` and `DUWS_opcom_gridAwake`. Mark every zone, banded town and OPFOR hardpoint dirty, then
   clear the flag.
2. Process each dirty key:
   1. If the key is in `DUWS_opcom_gridSrc`, deposit its cached record again with the weight negated, then remove
      the record. Remove the key from `DUWS_opcom_gridAwake`.
   2. Classify the source as it stands now. A static source with a weight above 0 is deposited into its static
      lattice and cached. A dynamic source goes into `DUWS_opcom_gridAwake`. A source that is gone (a cleared
      hardpoint, a forgotten garrison) gets nothing.
   3. Clear the dirty set.
3. Publish: `DUWS_opcom_grid_fri = +DUWS_opcom_gridStaticFri` and `DUWS_opcom_grid_ene = +DUWS_opcom_gridStaticEne`.
4. Deposit into the published copies: each site in `DUWS_opcom_gridAwake` at its live `DUWS_fnc_garrisonForce`,
   each belief stamp, and each tasking.

Step 3 assigns new arrays and never writes into the old ones in place. A reader that holds a layer across a
yield, such as the router (`fnc_opcom_route.sqf`), keeps one consistent grid.

A removal in step 2.1 negates a cached record. It never recomputes the weight, because the inputs have
already changed by then. Float drift from repeated add and remove is cleared on every dirty-all.

## Dirty marks

`DUWS_fnc_opcom_gridDirty` (`[key]`) and `DUWS_fnc_opcom_gridDirtyAll` are defined at load, in a file that
`server_fnc_init.sqf` executes before zone generation. Both do nothing until the grid exists: the first tick
is a dirty-all.

| Chokepoint | File | Marks |
|---|---|---|
| `fnc_zone_control_set` | `server/init_zones/fnc_zone_state_init.sqf` | the zone |
| every write to `DUWS_garrisonFull_<key>` or `DUWS_garrisonLost_<key>`: `DUWS_fnc_garrisonSetFull`, `DUWS_fnc_garrisonRecordLoss`, `DUWS_fnc_garrisonSeed`, `DUWS_fnc_garrisonUnlose`, `DUWS_fnc_garrisonBuyTier`, `DUWS_fnc_garrisonForget` | `server/garrison/fnc_garrison_strength_init.sqf` | the site |
| `DUWS_fnc_garrisonSetLive` | `server/garrison/fnc_garrison_strength_init.sqf` | the site |
| `fnc_duws_stow`, `fnc_duws_deploy` | `server/misc/fnc_composition_stream_init.sqf` | the composition key |
| `fnc_hardpoint_register`, `DUWS_fnc_hardpointClear` | `server/init_zones/fnc_hardpoint_stream.sqf` | the hardpoint |
| the earned branch of the OPFOR AP adjust | `server/warcom/fnc_economy_init.sqf` | all |
| `fnc_debug_clear_hardpoints`, which replaces the registry | `server/debug/fnc_debug_clear_hardpoints.sqf` | all |
| OPCOM init | `server/warcom/opcom/belief/fnc_opcom_grid_init.sqf` | all |

Earned AP marks everything because `DUWS_fnc_tokenLocked` reads it, so every garrison's full can change at
once.

**Invariant:** new code that writes a garrison ledger, zone ownership, the hardpoint registry or a
composition's stow state marks the key dirty. A missed mark leaves the old deposit on the grid until the
next dirty-all, and the drift check below reports it.

## Verification

| Check | How | Pass |
|---|---|---|
| Deposit is reversible | sqf-vm unit test on `DUWS_fnc_opcom_deposit`: a deposit and its negation, then a sequence of adds and removes against a scratch build of the survivors | every cell within 1e-6 |
| No missed mark | Debug menu OPCOM page action: build both layers from scratch into scratch lattices with the full build, then log the largest absolute difference per layer against the published grid | below 0.05, the cell threshold the tick log counts by |
| Cost | `ms[… grid=…]` in the OPCOM tick line, quiet map and firefight | a few ms on a quiet map |

`DUWS_fnc_opcom_deposit` holds no HashMap access, so the unit harness can load it (`tests/unit/functions.txt`).

## Chunks

| Chunk | Builds | Settles in play |
|---|---|---|
| **1** Deposit and publish | `DUWS_fnc_opcom_deposit` extracted from the rebuild's inline `_deposit`. The stage builds into fresh arrays and assigns them at its end. The unit test | Nothing: the output is identical, so the drift is 0 by construction |
| **2** Static layer | The state, the dirty API, the marks at every chokepoint and the tick above. The current rebuild stays as the full build, which serves dirty-all and the drift check. The drift-check action on the Debug menu's OPCOM page | Whether several live zones in one firefight keep `grid=` to a few ms. The largest drift over a 3-4 h session: above 0.05 means a missed mark, and the check names the layer |
