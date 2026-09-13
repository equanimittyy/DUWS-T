# Side-mission siting: collapse the two-layer re-site

A side mission is placed twice. The strategic-map picker sites it at offer time through
`fnc_mission_findSite` (the per-type `fnc_<name>_site` finder), and then roughly half the mission threads
site it *again* at spawn time through `fnc_mission_site` → `fnc_missionTargetPos`. The second pass re-rolls
within a wide radius, ignores the constraint the finder just satisfied, and falls back to open ground behind
a player-facing "finding a safe placement" hint and a `sleep 5` (`fnc_missionTargetPos.sqf:17-25`). The
picker's vetted spot is discarded.

This plan makes the **offer authoritative**: the finder resolves the mission's real placement need at offer
time, and the thread trusts that position — recovering a building *object* where it needs one through a tight
local lookup, never a wide re-roll. It does not delete all settling; it bounds it so the objective can no
longer wander out of the vetted area or land on empty ground.

## The intended pipeline

A side mission should be placed exactly once, at offer time, in four steps. `fnc_mission_findSite` already
implements them; the fix is to stop the thread from re-running steps 2–3.

1. **Roll the type.** The strategic-map picker (`fnc_stratmap.sqf`) draws types without replacement, biased by
   the `weight` and `hardEligible` fields of the type's `spawnRule` (`mission_types.hpp:14`).
2. **Survey the map for candidate areas**, by the type's `surveyKind` (spawnRule field 6): `map` samples the
   whole HQ-reach disc, `town` walks `MissionLocations`, `zone`/`capturezone` walk OPFOR zones, `hardpoint`
   lists live emplacements. Each area is scored by the difficulty dial — a frontline bell for easy offers
   (`_fnUrbanWeight`), depth-and-gauntlet for hard (`_fnHardScore`) — and thinned to a ≤16 even-spread
   shortlist (`fnc_mission_findSite.sqf:223-276`). This is where difficulty/frontline weighting lives.
3. **Realise one area within its radius.** Draw an area by score, `findSafePos` an exact point inside the
   area's band, and hand that point to the type's `fnc_<name>_site` finder. The finder validates the mission's
   real placement need (a building in reach, a treeline, a deliverable town) and returns the vetted point, or
   `[]` to reject. A reject drops that area and draws the next — up to `_realizeCap=8` tries
   (`fnc_mission_findSite.sqf:284`). Exhaust the 8 and it returns `[]`; the picker drops the type and rolls a
   different one.
4. **Generate.** The offered point is final. The thread spawns there and, where it needs a building *object*,
   does one tight local `nearestBuilding` bounded to the vetted area — never a second wide re-roll.

Step 4 is what breaks today: roughly half the threads call `fnc_mission_site` and re-run steps 2–3
generically, discarding the finder's vetted point.

## Constraints: mandatory vs optional

A placement rule is one of two kinds, and today only the first exists.

- **Mandatory** — the placement is *invalid* without it, so the finder returns `[]` and the 8-try loop moves
  on. A building for a manhunt/protect objective (`protect_civ_site` demands one building in the cluster), a
  treeline for a patrol camp (`destroy_patrol_camp_site` rejects fewer than 15 trees in 70 m), a deliverable
  town in reach (`fnc_site_town`). Every finder in the tree is pure mandatory accept/reject.
- **Optional / weighted** — a *preference* for **where inside the vetted area** an objective sits: densest
  cover for a camp, the best-viewed knoll for a sniper. This is a spawn-time, in-mission concern, never an
  offer-layer one — the finder stays mandatory and binary. It runs server-side, where the terrain and
  line-of-sight queries it needs are affordable, through one shared scorer (below). Nothing weights *which
  area* a type is offered; that stays the global difficulty dial. "Camps weighted to forests" is two separate
  things: a *mandatory* treeline gate at the offer (already built), and an *optional* densest-cover preference
  within it (the scorer).

## Why

`fnc_missionTargetPos` predates the finder system. It was the single siting path — turn a point into a
point-plus-building — and the per-type finders were added at the offer layer later. The threads never stopped
calling the old path, so both fire: the finder vets a spot, then the old path re-vets the same generic
"near a building" search around a re-rolled point.

Three consequences, from the picker audit:

- **The finder's work is thrown away.** `destroy_patrol_camp` vets a wooded treeline, then re-sites via
  `fnc_mission_site` (`fnc_destroy_patrol_camp_mission.sqf:169`) into a building-biased spot — the treeline is
  lost. `destroy_cache` and `destroy_radar` vet level ground for their fenced composition, then re-roll ±400 m
  off it (`fnc_destroy_cache_mission.sqf:116`) onto whatever slope the re-roll lands on.

- **No-constraint types wander furthest.** `rescue_pilot`, `steal_supply`, `steal_builder`, `target_sniper`,
  `target_recon`, `target_armor`, `deny_armor`, `destroy_air` have no positional finder; the map dot is
  advisory and the thread re-rolls ±600–1000 m into the open-ground fallback. `target_sniper` and
  `target_recon` *do* find a vantage — but by hand-rolling an elevation/LOS (sniper) or tree-density (recon)
  search in the thread, anchored on that re-rolled point, so the offer the player saw is unrelated to the final
  spot and the vantage logic is trapped in one thread instead of a shared scorer.

- **The offer pipeline can't carry the answer.** `fnc_mission_findSite` flattens the finder's return to a bare
  `[x,y]` (`fnc_mission_findSite.sqf:325-326`), so even a finder that resolved a building cannot hand the
  *building object* forward. That is why the thread re-derives — and why the fix is a tight local lookup at the
  offered position, not a change to what the offer carries.

## Optional placement: a shared terrain scorer

Every type with a terrain preference uses one server-side helper at spawn time. It never touches the offer
layer, so it carries no picker-safety constraint and may use the expensive queries (line of sight, elevation
sampling) the finder cannot.

`fnc_score_placement` (proposed). Given the offered centre, a small search radius, and a weighted list of
terms, it samples candidate points in the radius, scores each, and returns the best-scoring point. On a tie or
an all-zero score it returns the point nearest the centre — so a type that lists no useful term degrades to
the plain tight settle rather than wandering.

Contract: `[_center, _radius, _criteria] -> _bestPos`, where `_criteria` is a list of `[name, weight, arg?]`:

- `forest` — tree density around the point (`nearestTerrainObjects` TREE / SMALL TREE count). Picks the
  densest cover inside the treeline the camp finder already required.
- `high` — local prominence, always relative: the point's height above a ring of samples around it, so it
  rewards ground that stands above its surroundings, never raw altitude. This is the sniper's whole terrain
  preference — take the highest ground relative to the nearby terrain.
- `los` — clear line of sight from the point to `arg` (the objective or watched area), via
  `lineIntersectsSurfaces`. A vantage with no view of the target scores zero on this term.

The camp's forest gate (mandatory, client-side, offer) and the scorer's `forest` term (optional, server-side,
spawn) share the engine primitive but not code — a client finder cannot call a server helper. That overlap is
intended: one decides whether the area is eligible at all, the other picks the best spot within it.

A type without a terrain *preference* (`destroy_cache`, `destroy_radar`) never calls the scorer: its only
placement need is level ground for a fenced composition, a mandatory gate the offer finder handles
(`fnc_site_terrain`), so the thread just trusts the offered dot. On open ground its building garrison finds
little, so the collapse trades that empty garrison budget for extra patrols and statics; it needs no cluster.

## New shared finder: the terrain gate

One shared helper answers every "does the ground here suit this site?" question, mirroring `fnc_site_cluster`
and `fnc_site_town`. It runs client-side in the picker — terrain queries only (`surfaceIsWater`,
`getTerrainHeightASL`, `nearRoads`), never server state.

**`fnc_site_terrain`** — gates the offered dot by cheap terrain predicates and returns it *unchanged*; it never
snaps, so the offered icon and the built site stay together. Any exact snap (a tank onto the road, a truck onto
its pad) stays a thread tight-settle. Predicates:

- **Level ground** (built, in use): rejects a footprint whose edge lies more than `_maxDrop` off the centre — a
  slope would leave a fenced composition or a parked vehicle floating or tilted. Serves `destroy_cache` and
  `destroy_radar` now; `steal_supply`, `steal_builder` and `rescue_pilot` in Phase 2.
- **Road proximity** (a `_roadMode` of `avoid` / `require`, on its own radius): `avoid` keeps a crash site off
  the grid (`rescue_pilot`); `require` gates that a road is in reach for a stalled tank (`deny_armor`). This is
  what a separate road finder would have done — but because the tank's exact road-snap stays in its thread, the
  offer layer only needs the gate, so it folds into this helper instead of a second one. The road radius is
  independent of the level-ground footprint (a crash site avoids roads at a wider range than the patch it needs
  flat).

Every predicate is a pure gate on the offered point, so they share one helper and a caller lists only the ones
it needs. These threads never touch a building object, so `fnc_site_cluster` is the wrong tool for them.

## The pattern to copy

Two in-mission shapes already trust the offer, and both keep the objective inside the vetted spot. Both are
distinct from the `fnc_mission_site` anti-pattern — an *unbounded* re-roll that ignores the finder entirely.

- **Trust-offer.** The finder's position is used as-is, with at most one tight local lookup to recover a
  building *object*. `protect_civ` re-finds its building within 30 m of the offer; `sabotage_laptop` re-scans
  the very `ACCEPT_RADIUS` the finder vetted, at the same centre, and never re-picks the centre.
- **Proxy-confirm.** The finder is a *coarse client-side proxy*: `fnc_site_cluster` vets a cluster against a
  fixed seat floor because the picker cannot read the live squad size or `fnc_civ_townAt` (both server-only).
  The thread then re-derives the exact building within the finder's `ACCEPT_RADIUS` (350 m) using that
  server-only data. `rescue_squad` and `rescue_hostage` are this shape. The re-derive is load-bearing, not the
  anti-pattern: it is bounded to the vetted cluster and only *narrows* the finder's choice with data the finder
  could not see. Do not force it into a bare `nearestBuilding`.

  `rescue_hostage` has a real defect inside this shape: its re-derive filters by seat count alone
  (`fnc_rescue_hostage_mission.sqf:14-16`), dropping the finder's town-policy and zone-standoff, so it can
  re-pick a building inside a side-held town the offer was built to avoid — breaking its own covert invariant.
  Fix by re-applying those two filters in the thread, bundled into rescue_hostage's own conversion rather than
  landed as a separate change.

Every two-layer type converts to one of these shapes:

1. The finder resolves the mission's real need and returns a constraint-satisfying position (add a finder where
   one is missing). Some finders are pure *eligibility gates* — `target_armor` and `destroy_air` gate on enemy
   AP tier, not on ground — and need no placement work; the thread only stops re-rolling.
2. The thread reads that position and trusts it: a tight `nearestBuilding` at the offer (trust-offer) or a
   bounded `ACCEPT_RADIUS` re-derive with server-only filters (proxy-confirm).
3. The wide `fnc_mission_site` re-roll and the open-ground fallback come out of that thread's path. Every
   `fnc_mission_site` caller also destructures a `_Building` it never uses — delete the dead param in the same
   edit.

## Per-type application

Each thread consumes the site result differently (`[_randomPos, _Building, _targetpos]`), so every conversion
must preserve which of those the thread actually reads before deleting the call.

| type | real placement need | offer-layer fix | thread change |
|---|---|---|---|
| destroy_patrol_camp | wooded treeline | finder already vets it | trust offer; scored settle (`forest`) for densest cover |
| destroy_cache | level ground for a fenced composition | `fnc_site_terrain` (level-ground) | trust offer; drop ±400 m roll; swap empty building garrison for extra patrols/statics |
| destroy_radar | level ground for a fenced composition | `fnc_site_terrain` | same as cache |
| target_sniper | near the target; prefers relative-high ground with LOS | finder gates proximity only (terrain is soft) | scored settle (`high`+`los`); drop roll |
| target_recon | near the target; prefers woodline cover | finder gates proximity only (terrain is soft) | scored settle (`forest`); drop roll |
| steal_supply | open flat (parked truck) | `fnc_site_terrain` (level-ground) | tight settle; drop 600 m roll + dead `_Building` |
| steal_builder | open flat (parked truck) | `fnc_site_terrain` (level-ground) | tight settle; drop 600 m roll + dead `_Building` |
| rescue_pilot | open flat, road-avoiding (crash site) | `fnc_site_terrain` (level + road-avoid) | tight settle; drop ±1000 m roll |
| target_armor | open / drivable | finder is an AP-tier gate, no ground vetting | trust offer; drop 1500 m roll (optional `fnc_site_terrain` require-road) |
| deny_armor | road (derelict tank) | `fnc_site_terrain` (require-road mode) | trust offer; keep its tight road-snap |
| transport_IDAP | truck on drivable ground near the delivery ring | finder already town-rings | trust offer; drop 600 m re-derive drift |
| destroy_air | open flat (aircraft) | finder is an AP-tier + heli gate | trust offer; drop 5000 m roll |

## Sequencing

1. **Free wins** — thread-only edits. `destroy_patrol_camp` already has its treeline vetted and only has to stop
   discarding it; `destroy_cache` and `destroy_radar` now vet level ground through the shared `fnc_site_terrain`
   (built here, replacing their old cluster snap), so they just trust the offered dot and drop the ±400 m
   re-roll. Prove the trust-the-offer shape here.
2. **Placement-needers** — add a finder, then convert. `steal_supply`, `steal_builder` and `rescue_pilot` need
   open ground for a parked vehicle, so reuse `fnc_site_terrain` here, adding its road-avoid mode for `rescue_pilot`.
   `target_sniper` and `target_recon` have no mandatory terrain gate — their finder only anchors them near the
   target, and the scorer's soft `high`+`los` / `forest` terms pick the best spot at spawn (sniper takes the
   ground highest relative to its surroundings), so build `fnc_score_placement` here too. Both
   scorer types already hand-roll this exact math in-thread (24-sample elevation + LOS, 40-sample tree
   density), so the build is extraction, not new logic.
3. **Vehicle / open specials** — `target_armor` and `destroy_air` already gate on AP tier, so they only stop
   re-rolling and trust the offer. `transport_IDAP` trusts its `fnc_site_town` ring. `deny_armor` needs
   `fnc_site_terrain`'s require-road mode for the tank anchor; its convoy destination is already met by
   `spawnRule` / `needDest`, just move it out of the thread.

Each step is verifiable by diffing the offered position against the objective's final position: after
conversion they should differ only by the tight local settle, and the "finding a safe placement" hint should
stop firing for that type.

## Out of scope

- **Placement rules beyond the scorer's terms.** The scorer covers forest, local elevation and line of sight.
  A rule needing anything else — road proximity, cover from a specific bearing, a water's edge — is a new term
  or helper, not this fix. Adding a term is cheap, but each is its own change with its own tuning.

- **Terrain-weighted area selection.** The scorer places *within* an already-vetted area; it never chooses
  the area. The offer layer stays mandatory accept/reject plus the global difficulty dial — a type cannot bias
  which town or zone it is offered by forestation or elevation. That is a heavier, picker-side change and is
  not part of this work.
- **Deleting `fnc_missionTargetPos`.** Its wide re-roll and fallback come out of each thread's path as that
  thread converts; the function itself is removed only once no caller uses it. Flag it, do not delete early.
- **The INVERT town types.** `escort_informant`, `deliver_supplies` and `informant` survey all towns then snap
  to the valid subset; the coherent fix is to enumerate deliverable towns up front via the finder's `["ALL"]`
  mode (as `capture_zone` does), an offer-layer change independent of the two-layer re-site. Their thread-side
  double-pick is already removed (the town index is resolved from the offered position, not re-searched).

- **Two-position missions.** `target_hvt` (spawn + destination) and `recon_observe` (target + overwatch) offer
  one anchor and compute the second themselves, because the offer pipeline flattens to a single `[x,y]`
  (`fnc_mission_findSite.sqf:325-326`) and cannot carry a pair. The audit cleared both: each calls a shared
  deterministic pick at both layers, so the offer and the launch agree. No collapse work — noted only so the
  25-type list is complete.
