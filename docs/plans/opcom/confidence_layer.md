# OPCOM confidence layer — where the commander has looked

A perception extension to [`opcom_plan.md`](opcom_plan.md), building on the Phase 3 recon sensor and the
Phase 1 influence grid. It adds the second half of OPCOM's perception model: the force belief answers *what
force is where*, this answers *how sure the commander is it looked there recently*. It lands with **Phase 4b**
(Scout is its first reader) and is extended by **Phase 5** (the flank / encircle route term); it is not a
numbered phase of its own ([§Build order](opcom_plan.md#build-order)).

This is the implementation spec; the design it serves — Scout Value and the flank route — is in
`opcom_plan.md` and is referenced, not restated.

## The gap it closes

The force belief store is keyed by subject and records only *positive* sightings — a group / zone / HQ and the
force seen there ([§Shape](opcom_plan.md#shape)). Absence of a row cannot distinguish two states that must be
told apart: ground **swept clear** a moment ago, and ground **never observed**. Both read as "no entry". Two
consumers need the distinction and cannot get it from the force belief:

- **Scout** ([§Value](opcom_plan.md#value-the-worth-of-the-ground-in-play)) values ground by `cell worth ×
  staleness`, but `staleness` has no per-cell source. With no memory of where the commander looked, valuable
  ground reads maximally stale forever and OPCOM re-scouts the same empty corridor every tick.
- **The flank route** ([§Routing](opcom_plan.md#routing-a-cost-field-over-the-grid)) bends around
  `DUWS_opcom_grid_ene`. That force layer *decays* — an aging sighting's weight falls to 0 at expiry
  ([§Decay](opcom_plan.md#decay)). So the ground the commander has watched least recently reads as the
  emptiest, hence the safest. Without a confidence layer the flank routes through exactly the ground it knows
  least, mistaking ignorance for safety.

A confidence layer is the minimum representation that separates *clear* from *unknown*, because that
distinction is not derivable from the force belief — it must be stored. One number per cell, the tick it was
last swept, is the whole of it.

## The layer: `DUWS_opcom_grid_seen`

One flat numeric array, one entry per grid cell, holding the `DUWS_opcom_tick` at which that cell was last
swept by a **guaranteed** sensor bubble. Server-local, numbers only, handle-free — the same discipline as
`DUWS_opcom_grid_fri` / `_ene` and the belief arrays ([§Shape](opcom_plan.md#shape)). It indexes
`_cy * DUWS_opcom_grid_w + _cx`, the absolute cell index every grid reader already uses.

It differs from the two force layers in one way that governs everything else: **it is not rebuilt each tick.**
`fnc_opcom_grid_rebuild` zeroes and refills `_fri` / `_ene` from live holdings and belief every tick;
`_seen` instead *accumulates* — a stamp persists until a later sweep overwrites it or decay ages it out. It is
stateful memory, like belief, that happens to be cell-indexed. It is therefore allocated once at init and
never touched by the rebuild.

Cells are never individually cleared. No never-seen sentinel is needed: every cell inits to `seen =
-OPCOM_COVER_SPAN`, an age past the span, so an unswept cell reads maximum staleness through the same formula a
long-expired one does — the readers cannot tell never-seen from expired and never need to, since both mean "go
look". No coarser resolution either: it reuses the one force-grid cell size, so the sweep footprints and the
box are exactly the grid's, and there is no second world↔cell map to keep aligned.

### Staleness: linear over one span

The read the two consumers share — one clamped line, no sentinel branch:

```
staleness(cell) = (0 max ((DUWS_opcom_tick - seen) / OPCOM_COVER_SPAN)) min 1
```

0 the tick a cell is swept, rising linearly to 1 over `OPCOM_COVER_SPAN` ticks, then held at 1 — and an unswept
cell, inited a full span in the past, is already at 1. `OPCOM_COVER_SPAN` is a **separate** trust horizon from belief's `FRESH` / `EXPIRE` — how long a
*clear* sweep stays trusted is a different question from how long a *force* sighting does, so it takes its own
constant rather than borrowing either belief threshold.

Counted in ticks off `DUWS_opcom_tick`, the one clock belief also ages on — never `time` or `diag_tickTime`
([§Decay](opcom_plan.md#decay)).

## Stamping: guaranteed bubbles clear, sightings point-stamp

Two things stamp a cell, for two different reasons.

A **clear sweep** stamps its whole footprint *whether or not it caught a group* — only a sensor that detects
*for certain* within a defined cell box can make "found nothing" mean "clear". Both qualifying sensors already
sweep a Chebyshev box each perception tick and now stamp it unconditionally:

| Sensor | Stamps | Where |
|---|---|---|
| Recon detection | every cell within `OPCOM_RECON_K` (by platform) of each recon tasking's point | [`fnc_opcom_recon_sense.sqf`](../../../src/duws/server/warcom/opcom/belief/fnc_opcom_recon_sense.sqf) — the box it already walks to test group cells |
| Observation post | every cell within `OP_OBSERVE_K` of a post, on each tick the post's chance fires | `DUWS_fnc_hardpointOPSense` ([`fnc_hardpoint_stream.sqf:282`](../../../src/duws/server/init_zones/fnc_hardpoint_stream.sqf)) |

A **positive sighting** stamps the one cell it was seen in. A belief write is itself proof the commander
observed that ground, so `fnc_opcom_belief_upsert` — the single writer every sensor records a sighting through
— stamps a `k = 0` point at the sighted cell. This is what lets the fallible `nearTargets` sweep contribute:
its "saw nothing" is still not a clear (line of sight, defeatable by stealth, no clean footprint —
[§Sensors](opcom_plan.md#sensors)), but its "saw *this*" is proof of a look, so a detection stamps its cell
even though a miss stamps nothing. The point stamp never widens to a bubble: seeing an enemy at a cell proves
that cell was looked at, never that the sector around a known threat is clear. The area-of-influence and
zone-flip sensors stamp presence, not a sweep, so they add no clear; routing a sighting through the writer
would point-stamp it like any other.

Both are a write of `DUWS_opcom_tick` into each in-box cell of the `(2k+1)` box around the point, clamped to
the grid — the same bounded box scan the force-grid deposit uses
([§Rebuild](opcom_plan.md#rebuild-deposit-each-source-with-a-linear-falloff)), never a pass over the whole
array. A clear bubble's `k` is small (a few cells) and a sighting's is 0, so the cost is tens of writes per
recon tasking per tick plus one per sighting.

## Reading: two consumers

| Reader | Uses staleness as | Phase |
|---|---|---|
| **Scout Value** | the `staleness` term in `Σ cell worth × staleness` over the recon footprint ([§Value](opcom_plan.md#value-the-worth-of-the-ground-in-play)) | 4b |
| **Flank / encircle route** | an added per-step cost `OPCOM_ROUTE_MU × staleness(cell)` on the `λ = 1` templates, so a flank prefers recently-swept ground and the risk knob decides when to cross unknown ground ([§Routing](opcom_plan.md#routing-a-cost-field-over-the-grid)) | 5 |

**Scout** now values never-seen ground (staleness 1) as well as aging-clear ground, and the loop is bounded,
not endless: a scout's own recon bubble stamps every cell it sweeps, so the cells that drew it read fresh next
tick and stop scoring until `OPCOM_COVER_SPAN` ages them back. This is the capability the force-belief-age
alternative had to forgo — that cheaper fix could only *re-verify known contacts* and had to forbid blind
exploration to avoid the endless loop; the coverage layer lets OPCOM explore blind ground *and* remember it
did, which is why it is worth the state.

**The flank route** reads it as uncertainty. `DUWS_opcom_grid_ene` decay lowers the *force* weight on
unwatched ground (it looks emptier); `OPCOM_ROUTE_MU × staleness` raises the *route* cost on that same ground
(it is treated as uncertain). The two together give the three-way distinction the maneuver needs:
known-clear ground is cheap, known-enemy ground is expensive via `λ · gridEne`, and unknown ground is
expensive via `μ · staleness`. `OPCOM_ROUTE_MU` scaled by the target's prize is the "take risks where needed"
dial — a rich objective tolerates routing through uncertainty, a cheap one detours to verified-clear ground or
commits a Scout first. Only the flank / encircle templates read it; the direct routes (`λ = 0`, Assault and
rapport) ignore uncertainty as they ignore force ([§Routing](opcom_plan.md#routing-a-cost-field-over-the-grid)).

**Arty is not a reader.** Its saturation scales with the *belief entry's* age — the positional uncertainty of
the one sighting it is shelling ([§Value](opcom_plan.md#value-the-worth-of-the-ground-in-play)), read from
`DUWS_opcom_belief_time`, not this layer. Ground coverage and target-sighting age are different staleness; do
not wire Arty to `_seen`.

## Constants

In `server_var_init.sqf`, `OPCOM_` prefix, plain globals, beside the existing OPCOM constants. Both tune in
play:

| Constant | Is |
|---|---|
| `OPCOM_COVER_SPAN` | ticks a clear sweep stays trusted — staleness runs 0 → 1 over this span |
| `OPCOM_ROUTE_MU` | flank route uncertainty weight; the risk-tolerance knob, scaled by prize at the route call (Phase 5) |

## Files

Under `src/duws/server/warcom/opcom/`, one function per file, each registered by a compile-path string in
`server_fnc_init.sqf` beside the other OPCOM functions (the misc-loader convention — callers use the variable
name, not `CfgFunctions`).

New, in `belief/`:

| File | Responsibility |
|---|---|
| `fnc_opcom_cover_stamp` | `[point, k]` → stamp `DUWS_opcom_tick` into each in-box cell of the `k` box around `point`, clamped to the grid. One shared writer so every faucet — clear bubble and sighting point — stamps identically |
| `fnc_opcom_cover_stale` | `[cell]` → the staleness read above, single-sourcing the formula both consumers call |

Extended in place:

| File | Change |
|---|---|
| `fnc_opcom_grid_init` | Allocate `DUWS_opcom_grid_seen` (full-width lattice, all `-OPCOM_COVER_SPAN`) once, beside the static land / component arrays it already builds. Never touched by `fnc_opcom_grid_rebuild` |
| `fnc_opcom_recon_sense` | After (or within) the box walk it already runs, call `fnc_opcom_cover_stamp` for each recon point's `k` box — unconditional on catching a group |
| `DUWS_fnc_hardpointOPSense` | On each tick a post's chance fires, stamp its `OP_OBSERVE_K` box (cross-subsystem — the OP sensor lives with the hardpoint code) |
| `fnc_opcom_belief_upsert` | After the store write, `k = 0` point-stamp the sighted cell, so every faucet's positive sightings (recon, `nearTargets`, any future sensor) refresh coverage through the one writer |
| `fnc_opcom_route` *(P5)* | Add `OPCOM_ROUTE_MU × (cell call fnc_opcom_cover_stale)` to the per-step cost on the `λ = 1` branch |
| Scout Value in `fnc_opcom_actions` *(P4b)* | Read `fnc_opcom_cover_stale` per footprint cell as the `staleness` term |

## Persistence

Do not persist `_seen`. It is cell-keyed, so unlike the netId-keyed belief store it *could* serialise safely
([`opcom_plan_audit.md`](opcom_plan_audit.md)), but a cold rebuild on restore is the correct behaviour, not a
loss: after a reload the commander genuinely does not know the current picture, so treating all ground as
unknown for the first `OPCOM_COVER_SPAN` — re-scouting and routing cautiously until it re-observes — is right.
`fnc_opcom_grid_init` refills the array to all-`-OPCOM_COVER_SPAN` on the first tick like the live force layers.

## The one trap

`DUWS_opcom_box` fixes the cell↔world mapping, and it is computed **once at init**
([`fnc_opcom_grid_init.sqf`](../../../src/duws/server/warcom/opcom/belief/fnc_opcom_grid_init.sqf)), so a
stamp's cell index means the same ground for the life of the mission and there is nothing to reindex. Should
the box ever be made to recenter or resize at runtime, `_seen` — which the rebuild does not refresh — would
then point stamps at the wrong cells, and must be reset to all-`-OPCOM_COVER_SPAN` on the change. Not a
concern while the box is init-fixed; noted so a future box change does not silently corrupt coverage.

## Debug overlay: staleness as text over the dot

The Phase 1 overlay draws one force dot per non-empty cell, its text the `f/e` force balance
([`fnc_debug_opcom_grid_draw.sqf:39-54`](../../../src/duws/client/debug/fnc_debug_opcom_grid_draw.sqf)).
Coverage rides as a second per-cell label floating just **above** the force dot — offset north of the cell
centre, not overlapping it — the cell's staleness age in ticks at 30% opacity:

- **`{n}t`** — swept `n` ticks ago, `n` under the span (`0t` the tick it is stamped, climbing each tick).
- **`-1t`** — no live coverage: never swept, or last swept a full `OPCOM_COVER_SPAN` ago.

Raw tick age, not the clamped staleness: the debug view wants the true age up to the span. Past the span a cell
is worthless to Scout and the flank alike, so it reads `-1t` — never-seen and long-expired both, since the
readers treat them the same. The sentinel labels `-1t`, uniform with the real ages, rather than a special
`N/A` string. A label on **every** box cell, not only the swept ones: a fresh map has stamped nothing, and a
blank overlay reads as broken rather than as "no coverage yet", so the layer paints `-1t` across the grid
until sweeps flip cells to `{n}t`. This is a dev view, so the full lattice of labels is worth the markers;
**on by default** (`DUWS_dbgOpcomCoverOn`, its own menu sub-toggle).

| Layer | Change |
|---|---|
| Server gather `fnc_debug_opcom_grid` | Emit each cell's age in the `_cells` payload — a sixth tuple element: `DUWS_opcom_tick - (DUWS_opcom_grid_seen select _i)`, or `-1` once that reaches `OPCOM_COVER_SPAN`, so the client needs no span |
| Client draw `fnc_debug_opcom_grid_draw` | A `duws_opcom_stale_%1` marker per box cell: text `{n}t` (the sentinel `-1` prints `-1t` like any age), `setMarkerAlphaLocal 0.3`, the `loc_search` icon type at `[0.5, 0.5]`, positioned north of the cell centre so it sits above the dot. A stale draw that lands after the overlay is toggled off is dropped (it re-checks `DUWS_dbgOpcomOn`), else it would rebuild the torn-down lattice. Reconciled and torn down by the `duws_opcom_` prefix like the other layers; the toggle off deletes the set |

The label carries a visible icon: the invisible `"Empty"` marker type paints no text, so a real icon type is
required ([`arma_engine_gotchas.md`](../../info/architecture/arma_engine_gotchas.md#a-label-needs-a-real-icon-marker-type-the-invisible-empty-type-paints-no-text)).

## Verification

Checkable against a live player with the Phase 1 grid overlay, its staleness text layer up
([§Debug overlay](#debug-overlay-staleness-as-text-over-the-dot)):

- Deploy a recon unit by hand (the Phase 3 debug harness) and watch its footprint cells' labels reset to
  `0t`, then climb tick by tick.
- With Scout live (4b), OPCOM stops re-committing a scout to a corridor a recon just swept, and re-commits only
  once the span has aged it.
- With the flank template live (P5), an equal-force route bends toward recently-swept cells over never-seen
  ones; raising the prize (or `OPCOM_ROUTE_MU`) makes it accept the uncertain shortcut instead.

## What this implies for `opcom_plan.md`

Two one-line consistency edits the plan needs when this lands, kept out of this doc so the design spec stays
single-sourced:

- [§Value](opcom_plan.md#value-the-worth-of-the-ground-in-play) — define Scout's `staleness` as
  `fnc_opcom_cover_stale`, pointing here.
- [§Routing](opcom_plan.md#routing-a-cost-field-over-the-grid) — note the `OPCOM_ROUTE_MU × staleness` flank
  term, pointing here.
