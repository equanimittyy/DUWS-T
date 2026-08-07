A hardpoint is a small garrisoned emplacement — one composition, a gun, a handful of defenders —
the player clears on foot. Two flavours, differing only in where they sit: a **zone hardpoint**
rings an enemy zone; a **standalone hardpoint** sits in the OPFOR-held countryside between zones.
Both are built, streamed, garrisoned and cleared through the same machinery
(`server/init_zones/fnc_hardpoint_place.sqf`, `fnc_hardpoint_siting.sqf`, `fnc_hardpoint_stream.sqf`,
`fnc_hardpoint_minefield.sqf`, `fnc_hardpoint_reveal.sqf`, `hardpoint_compositions.sqf`). They
replaced the old fortification ring — three or four towers scattered on a random bearing at a random
distance, sited and faced by luck alike (`server/init_zones/fnc_createzone.sqf:184-189`).

## Why hardpoints are not zones

`fnc_createZone` writes five campaign registries in its opening block and `fnc_zone_control_set`
moves four more as one atomic transition; every consumer of zone state — the win condition, passive
income, the OPFOR primary-assault target, intel's reveal pool — reads straight off them. A
hardpoint routed through either would inflate all of them at once for an object the player is meant
to clear far more often than a zone changes hands. Hardpoints therefore get their own registry,
`DUWS_hardpoints` (`server/server_var_init.sqf:443`), and touch none of the five.

That separation runs deeper than shared globals. Zone-ring siting does not run inside
`fnc_createZone` at all: it runs after every zone has finished building, in a dedicated generation
phase (`server/warcom/fnc_init_OPFOR_WARCOM.sqf:52-96`, [below](#siting)), reading `zone_meta_array`
— data the zone already published — rather than the zone builder's own locals. And a hardpoint's
garrison is never appended to a zone's own roster (`DUWS_zoneUnits_<key>`,
[`zones_and_civilians.md#what-captures-a-zone`](zones_and_civilians.md#what-captures-a-zone)):
clearing a zone hardpoint has no effect on `fnc_zone_capture_ready`, which reads only the zone's own
garrison count and never references `DUWS_hardpoints`. A zone hardpoint is built on a zone's ground
and streams with the zone's garrison, but does not gate its capture.

## Hardpoint types

One core weapon or structure per hardpoint; garrison and streaming are per type, not per instance.

| Type | Core | Garrison | Notes |
|---|---|---|---|
| `MG` | `opfor_TURRET_HMG` | one team | backbone of both weight tables |
| `AT` | `opfor_TURRET_AT` | one team | covers a road |
| `GMG` | `opfor_TURRET_GMG` | one team | rare supporting weapon |
| `AA` | `opfor_TURRET_AA` | one team | wakes on a 5,000 m air ring, not just its ground ring |
| `ROADBLOCK` | gate flanked by two `opfor_TURRET_HMG` nests | one team | faces along the road it sits on |
| `OP` | vanilla bunker/tower prop | one team | defined and placeable, not yet rolled by generation or the director |
| `MORTAR` | `opfor_TURRET_MORTAR` | one team | resident (never streams); cleared by destroying the tube |
| `ARTY` | `opfor_ARTY_X` | one team | resident; cleared by destroying the piece |
| `MINEFIELD` | mine lattice, no core weapon | none | AT or AP variant; cleared when no armed mine remains |
| `RADIO` | live comms mast + 7 frozen HMG/AA nests | rifle team + 2 weapons teams | see [`opfor_area_of_influence.md`](opfor_area_of_influence.md#radio-towers) |

Tables: `DUWS_hardpointGarrison`, `DUWS_hardpointName`, `DUWS_hardpointStreaming`
(`server/server_var_init.sqf:377-441`). Classnames resolve through the same `opfor_*_X` faction
globals and the static-role table every zone and town garrison uses
([`faction_system.md#static-weapons-resolve-at-placement`](faction_system.md#static-weapons-resolve-at-placement))
— hardcoding a unit or turret classname is the one change that breaks mod-free operation and faction
auto-detection. `opfor_ARTY_X` is the one core that is a vehicle rather than a static, resolved and
crewed on a separate path in `fnc_hardpoint_garrison` (`fnc_hardpoint_place.sqf:97-155`): thawed and
crewed in place rather than dropped and settled, because it already sits on its own tracks.

`MG`, `AT`, `GMG`, `AA` and `ROADBLOCK` are the only types either weight table rolls
(`DUWS_hardpointWeightZone` / `_Solo`, `server_var_init.sqf:405-410`) or the director builds
([below](#siting)); `OP`, `MORTAR`, `ARTY` and `MINEFIELD` are fully implemented — composition,
garrison, streaming, clearance — but reachable today only through the debug spawner
(`client/dialog/fnc_debug_hardpoint_menu.sqf`). No campaign-wide count is enforced on any type.

Compositions are fenced `--DUWS-COMPOSITION--` arrays, one per type, authored in Eden through the
composition TUI ([`composition_tooling.md#static-compositions-the-eden-round-trip`](composition_tooling.md#static-compositions-the-eden-round-trip)).
Offsets sit in a frame whose +Y is the hardpoint's facing, so a heading rotates cover and core
together rather than turning the core inside a fixed ring of props.

## Siting

Two shared primitives decide where a hardpoint goes and what it becomes, both in
`server/init_zones/fnc_hardpoint_siting.sqf` and both pure — no engine calls — so the arithmetic is
unit-tested independently of the terrain read that feeds it:

- **`fnc_hardpoint_survey [_pos]`** (`:25-98`) reads the ground: local relief and slope off an
  eight-point ring, a fall-line bearing and magnitude (which way the ground drops, and how
  decisively), distance and drop to the nearest road, tree and building counts at several radii, and
  distance to the nearest already-placed hardpoint.
- **`fnc_hardpoint_score [_facts, _type]`** (`:101-181`) turns that row into a multiplier for one
  type: 0 means the site cannot hold it (water, or a per-type veto — artillery needs level ground,
  a roadblock needs a road within 8 m, a minefield's footprint must be clear of trees and buildings).
  Otherwise the multiplier rewards what that type wants — high ground and a road below for MG/AT,
  flat and open for AA, defilade for a mortar, a symmetric crest for a radio mast — plus a mutual-support
  bonus for sitting within interlock range of a hardpoint already down.

**Type is rolled before ground is read.** `fnc_hardpoint_lay` (`fnc_hardpoint_place.sqf:200-279`)
draws the whole slate of types for a pass up front from the pass's base-weight map, then hunts each
rolled type a handful of candidate sites (`HP_TYPE_DRAWS` = 18, `:167`), scores each with
`fnc_hardpoint_score`, and weight-picks among whatever scored above zero. A type that finds no site
in its draw budget is dropped, logged, and never swapped for another. This inverts an earlier order
that scored ground first and rolled a type for the winning site: that let the highest-scoring
terrain — the rise MG and AT already favour — win nearly every placement and starved AA and
roadblock of the flat or roaded ground they need. Rolling type first means the realised mix is the
base weights, and terrain decides only *where* a type lands, never *whether* it is the one placed.

**Facing has no separate registry field.** `fnc_hardpoint_facing [_type, _aspectDir, _aspectMag,
_radialDir, _roadDir]` (`fnc_hardpoint_siting.sqf:184-193`) picks a heading per type — a roadblock
faces along its road, MG/AT/GMG face down the fall line when one is pronounced enough to trust,
everything else keeps the outward-radial bearing the siting loop hands in. `fnc_hardpoint_build`
(`fnc_hardpoint_place.sqf:25-73`) then rotates every composition offset around that heading
(`fnc_hardpoint_rotate`, `:13-16`) before placing each object, so the heading is baked into each
prop's own position and direction at creation rather than stored beside it. Stowing a hardpoint later
records that same per-object transform — `[typeOf, getPosWorld, [vectorDir, vectorUp], ...]`
(`server/misc/fnc_composition_stream_init.sqf:121-123`) — and redeploy recreates it verbatim, so a
hardpoint that streams out and back in faces exactly where it did without being sited again.

**Zone ring.** `fnc_hardpoint_site_zone [_zonePos, _radius, _zoneKey, _count]`
(`fnc_hardpoint_place.sqf:281-304`) stores a per-zone cap, `round(_radius / 250) max 1`, the first
time it runs for that zone and refuses to run again — a rebuild through `fnc_createZone` lays no
second ring. At campaign generation a random count up to that cap (`round (random _cap)`, which can
be zero) is laid, candidates drawn anywhere inside the zone on land clear of steep slope, facing
radially out from the centre. The cap itself is the standing target the director tops zones back
toward later.

**Minefields are generated, not composed.** `fnc_hardpoint_minefield`
(`server/init_zones/fnc_hardpoint_minefield.sqf`) lays a lattice of vanilla mine objects — `ATMine`
for the AT variant, `APERSMine`/`APERSBoundingMine` for AP — with alternating rows offset half a
spacing so no straight lane threads the field untouched, plus a handful of warning signs as dressing.
Every mine is `east revealMine`d so OPFOR AI does not walk its own field, leaving detection and
clearance to BLUFOR. It has no fence to place through `fnc_hardpoint_lay`, and no garrison: the score
function vetoes any candidate with a tree, building or hardpoint already on the footprint.

**Standalone band and radio towers.** Standalone hardpoints are sited by sampling the OPFOR-positive
area-of-influence band rather than a hand-drawn corridor between zone and BLUFOR ground; radio
towers are their own hardpoint type, scored for hilltop crests and spaced off each other's coverage
radius. Both the band sampler and the campaign's radio-tower economics —
`DUWS_opforRadioLevel`, its cap, and the OPCOM director's build priority and AP pricing — belong to
[`opfor_area_of_influence.md`](opfor_area_of_influence.md#band-siting): this file owns the
terrain survey, per-type score, facing and spacing every band placement shares with the zone ring;
that one owns what the band *is* and what a tower buys the enemy.

All of it — the zone ring, radio-tower seeding, and the standalone band — runs in one generation
phase between zone build-out finishing and civilians starting (`fnc_init_OPFOR_WARCOM.sqf:52-96`),
under the same progress banner the other phases use. `fnc_hardpoint_plan_counts`
(`fnc_hardpoint_place.sqf:403-415`) rolls every zone's count and the radio count before any of it is
laid, so the banner totals real hardpoints rather than counting zones.

## Streaming and garrison

A hardpoint registers as a site the same way a zone does — `fnc_site_register`,
`fnc_site_occupant_register`, `fnc_site_hooks_set` (`server/misc/fnc_site_stream_init.sqf:30,66,110`)
— so the shared poller tests it against the same per-pass player list rather than paying a spatial
query per hardpoint (`fnc_hardpoint_register`, `server/init_zones/fnc_hardpoint_stream.sqf:297-341`).
What differs from a zone is the lifecycle: one gun-and-garrison emplacement that wakes, sleeps and
can be cleared, never captured or retaken.

**A zone-child hardpoint mirrors its zone rather than streaming on its own ring.**
`DUWS_fnc_hardpointZoneAwake` (`:32-37`) reads the zone's own garrison occupant and answers awake or
raising; a standalone hardpoint instead wakes on its own presence ring
(`DUWS_hardpointStreaming`'s `spawnRadius`/`grace` per type) and, for `AA`, an additional 5,000 m
*air* ring so a jet is noticed before its ground ring would ever fire — the streaming answer to the
same problem the plan raised for AA (a static gun cannot deploy fast enough to catch what crosses a
600 m ring in seconds), solved here by waking earlier rather than by never sleeping.

**Pinning is `neverStream` only.** `MORTAR`, `ARTY` and `MINEFIELD` are marked `neverStream` in
`DUWS_hardpointStreaming` (`server_var_init.sqf:377-393`) and, on registration, every member of their
composition is re-filed through `fnc_duws_keep` with `_pinned = true`
(`fnc_hardpoint_stream.sqf:319-321`), which sets `DUWS_noStow` and excludes the object from
`fnc_duws_stow`'s crewed-member refusal and its delete pass
(`server/misc/fnc_composition_stream_init.sqf:38-46,93-100`). Every other type stows and redeploys
like an ordinary composition: garrisons are raised fresh from `DUWS_fnc_teamRoster` on each raise
(`fnc_hardpoint_garrison`, `fnc_hardpoint_place.sqf:97-155`), a fixed per-type token — the same team
composition and size whether the hardpoint is razed and rebuilt in hour one or hour five. Nothing in
the codebase scales hardpoint garrison size to `WARCOM_opfor_ap`.

## Clearance

`DUWS_fnc_hardpointClearCheck` (`fnc_hardpoint_stream.sqf:100-141`) runs on the shared per-hardpoint
tick and branches on type family:

| Family | Cleared when |
|---|---|
| `MINEFIELD` | no mine in its filed hazard list is still armed |
| `MORTAR`, `ARTY` | no piece in its composition is alive — crew alone is not enough, since the pieces are pinned resident and a crew killed off an intact gun would otherwise clear a battery that still stands |
| `RADIO` | its mast (the one live, damageable member) is destroyed, whatever the garrison's state |
| everything else | its site roster — gun crew plus loose defenders — is down to zero alive |

Judged only while the hardpoint is deployed (`DUWS_hpPeak_<key>` present), so a stowed emplacement's
empty roster is never read as one beaten — the same guard a zone's own capture test uses.

Clearing is latched and destructive to the record, not a flag: `DUWS_fnc_hardpointClear`
(`:168-211`) deletes the row from `DUWS_hardpoints` outright (`:177`) rather than marking it cleared
in place, so a re-manned gun cannot un-clear what the player already took. Survivors are left where
they fell, flagged for the cleanup sweep once the player is clear (`DUWS_binMe`/`DUWS_binAt`,
`:192-193`) rather than deleted in front of anyone — a radio tower in particular can fall with
defenders still alive, since its clear condition is the mast, not the garrison. The composition is
released through `fnc_duws_release` (`:197`) like any other, so wrecks stay for the sweep rather than
vanish with the clear.

## Reveal

Every hardpoint gets a marker on registration: shape `"ICON"`, type `"loc_Bunker"`, coloured by side,
with the type token as its text (`fnc_hardpoint_stream.sqf:334-341`) — one icon shape for every type,
distinguished by label rather than by symbol. Alpha starts at the generation-visibility rule zones
use: shown outside hardcore, `0` under it (`:341`). `fnc_hardpoint_reveal` (`fnc_hardpoint_reveal.sqf`)
is the sole writer of the revealed flag — index 5 of a `DUWS_hardpoints` row — keyed on the
hardpoint's own key rather than position, the way `fnc_zone_reveal` owns its flag and
`fnc_civ_town_reveal` owns `civ_visible`.

Two ways a hidden hardpoint is found. **Proximity**: the streaming tick checks every player within
100 m (`HP_REVEAL_RADIUS`, `fnc_hardpoint_stream.sqf:15`) of a still-hidden hardpoint whose parent
zone (if any) is itself already revealed, and reveals it — a zone-child hardpoint cannot be found
before its zone is. **Intel**: `fnc_intel_payout` draws `"HP"` as one of its kinds whenever the
eligible set is non-empty — unrevealed, and either standalone or whose parent zone is already
revealed (`server/misc/fnc_intel_payout.sqf:51-63`) — matched by `fnc_zone_key`, the same key both a
revealed zone and a hardpoint row carry.

## Clear economy

Clearing pays the player CP; it never pays OPFOR anything back. Only a *standalone*, non-minefield
hardpoint pays: `5 CP` via `fnc_cp_adjust` (`server/misc/fnc_economy_init.sqf:14`) plus a
carded notification naming the type and the nearest zone or town
(`DUWS_fnc_hardpointClear`, `fnc_hardpoint_stream.sqf:199-208`; `notifications.hpp`, `HPdestroyed`).
A zone hardpoint pays nothing on clear — the zone's own capture bounty already prices its defences —
and neither does a minefield, a hazard removed rather than a garrison beaten.

The director that builds standalone hardpoints (`server/warcom/fnc_WARCOM_opf_hardpoints.sqf`,
spawned unconditionally from `fnc_WARCOM_init.sqf:57`) spends OPFOR Army Power to raise them; nothing
refunds AP when the player clears one. A refund would be farmable — build, clear, refund, repeat —
and the enemy's pool would never reach whatever escalation a future commander loop prices against
it. The director's tick, its three build actions and their AP costs are documented at
[`opfor_area_of_influence.md#band-siting`](opfor_area_of_influence.md#band-siting); the belief store
and archetype weighting that would make its band placement target where the player operates, rather
than sample uniformly, is [`../opfor_commander_loop_plan.md`](../opfor_commander_loop_plan.md)'s to
add.
