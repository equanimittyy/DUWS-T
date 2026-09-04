# OPCOM Phase 1 — belief, grid, debug overlay

The first build phase of [`opcom_plan.md`](opcom_plan.md), in that plan's
[§Build order](opcom_plan.md#build-order) sequence. A live perception substrate that can be *seen*, with
no decisions on top: no scoring, no actions, no taskings, no movement, no AP spend. Those are Phase 2+.

## Files

The server code lives flat under `src/duws/server/opcom/` — one file per function, no subfolders. Each
is loaded by a compile-path string in `server_fnc_init.sqf` beside the other server subsystems (misc
functions load this way, not through `CfgFunctions`; callers use the variable name). The overlay is a
client function, extended in place under `client/debug/`.

| File | Responsibility |
|---|---|
| `fnc_opcom_belief_init` | Declare the four belief arrays and the strategic-tick counter (empty). Run once at OPCOM init |
| `fnc_opcom_sense` | The sighting sweep and event sensors; keep-strongest write into the belief arrays ([§Sensors](opcom_plan.md#sensors)) |
| `fnc_opcom_decay` | Age every entry by the tick counter, drop the expired ([§Decay](opcom_plan.md#decay)) |
| `fnc_opcom_grid_init` | Declare the two live grid arrays, then build the static per-cell arrays once — land mask (`surfaceIsWater` per centre) and connectivity flood-fill ([§Geometry](opcom_plan.md#geometry)) |
| `fnc_opcom_grid_rebuild` | Zero both live grid arrays, deposit each source with the linear falloff ([§Rebuild](opcom_plan.md#rebuild-deposit-each-source-with-a-linear-falloff)) |
| `fnc_opcom_perception_run` | The loop thread — see below |
| `client/debug/fnc_debug_opcom_view` | Extend the existing overlay (AoI circles today) to render the grid and belief |

Later phases add their functions to the same flat folder rather than a subfolder per subsystem.

## Constants

In `server_var_init.sqf`, `OPCOM_` prefix, plain global assignment — **not** `#define`. The opcom files
that read them load by compile-path and run later, out of reach of a preprocessor macro scoped to
`server_var_init.sqf`; the existing `OPCOM_*` and `AOI_*` constants are plain globals for the same reason.

- `OPCOM_GRID_CELL` 500
- `OPCOM_GRID_SPREAD` 1000
- `OPCOM_BELIEF_FRESH` 4
- `OPCOM_BELIEF_EXPIRE` 16

The sighting threshold `1.5` already exists as the artillery gate — reuse it, do not add a second
([§Sensors](opcom_plan.md#sensors)).

## State

`DUWS_opcom_` prefix, server-local, numbers and strings only — no handles. Each init owns the state it
declares:

- `belief_init`: the four belief arrays (`_belief_key` / `_pos` / `_time` / `_str`) and the strategic-tick
  counter `DUWS_opcom_tick`.
- `grid_init`: the two live grid arrays (`_grid_fri` / `_grid_ene`), the two static ones
  (`_grid_land` / `_grid_comp`), and the cached cell width `_grid_w` every reader indexes by.

## The runner is the loop skeleton, perception-only

`fnc_opcom_perception_run` is the eventual [§loop](opcom_plan.md#the-loop-against-the-engine) thread with
both cadences already split, so Phase 2 adds the scoring pass into it rather than restructuring — no
throwaway. On start it runs `fnc_opcom_belief_init` and `fnc_opcom_grid_init` once, then loops:

- Fast base pass (~2-5 s): `fnc_opcom_sense`.
- Strategic phase (every 12-18 fast passes): increment `DUWS_opcom_tick`, `fnc_opcom_decay`, then
  `fnc_opcom_grid_rebuild`.

Started by WARCOM init **after** zones exist and after `fnc_zone_state_init` has run — the rebuild reads
`zone_meta_array` / `civ_locations` / `DUWS_hardpoints`, and zone-state init must precede any zone consumer.

## Sensors this phase

Direct sighting (`east knowsAbout _p > 1.5`, one call per player, keep-strongest) and the zone-flip event.
Area-of-influence (`fnc_aoi_opfor_covers`) can be added cheaply since it exists; the OP-hardpoint and
intel-patrol sensors wait on their own systems ([§Sensors](opcom_plan.md#sensors)).

## Grid sources this phase

Friendly = OPFOR zones, banded town garrisons, OPFOR hardpoints; enemy = BLU-held zones and belief entries
([§Rebuild](opcom_plan.md#rebuild-deposit-each-source-with-a-linear-falloff)). The tasking-unit source
lands with Phase 4 — no units exist yet.

The deposited weight is a **men count**, not the firepower-weighted force the spec describes: both layers
must share a metric for the ratio to mean anything, and the enemy layer is fed by `belief_str`, which is
only headcount. The per-source weight expression is the swap point — Phase 2 introduces firepower-weighting
on both sides at once (friendly from a token→class power table, enemy from a belief that carries a type),
alongside the scoring that first reads the ratio. A BLU-held zone and a standing hardpoint have no tracked
men, so they deposit the nominal `OPCOM_GRID_ZONE_ENEMY_MEN` / `OPCOM_GRID_HP_MEN`.

## Overlay

Per-cell `fri`/`ene` magnitude (two tints), a marker at each `belief_pos` tagged with its age, and the
front-line cells (sign change against an orthogonal neighbour,
[§What reads it](opcom_plan.md#what-reads-it)). Behind the existing debug toggle.

## Verification

Sighting a player adds one belief row (`count DUWS_opcom_belief_key` grows) and no more on a co-op stack in
one cell; the row's age climbs each strategic tick and the row drops after `OPCOM_BELIEF_EXPIRE`; the
overlay shows an `ene` bloom on the player fading with distance and decay, `fri` on held ground, and a
front line where they cross. All checkable from the debug console against a live player, no scoring needed.
