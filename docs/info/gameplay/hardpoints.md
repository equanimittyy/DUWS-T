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
phase (`server/warcom/fnc_init_OPFOR_WARCOM.sqf:61-128`, [below](#siting)), reading `zone_meta_array`
— data the zone already published — rather than the zone builder's own locals. And a hardpoint's
garrison is never appended to a zone's own roster
([`zones_and_civilians.md#what-captures-a-zone`](zones_and_civilians.md#what-captures-a-zone)):
clearing a zone hardpoint has no effect on the zone's break test, which reads only the zone's own
groups and never references `DUWS_hardpoints`. A hardpoint's men still count in the capture's numbers
test while they stand inside the zone's streaming ring, since that test is owner-blind.

## Hardpoint types

One core weapon or structure per hardpoint; garrison and streaming are per type, not per instance.

| Type | Core | Garrison | Notes |
|---|---|---|---|
| `MG` | `opfor_TURRET_HMG` | one team | backbone of both weight tables |
| `AT` | `opfor_TURRET_AT` | one team | covers a road |
| `GMG` | `opfor_TURRET_GMG` | one team | rare supporting weapon |
| `AA` | `opfor_TURRET_AA` | one team | wakes on a 5,000 m air ring, not just its ground ring |
| `ROADBLOCK` | gate flanked by two `opfor_TURRET_HMG` nests | one team | faces along the road, toward the approach |
| `OP` | vanilla bunker/tower prop | security team + wide recon patrol | standalone recon screen, seeded at generation; see [below](#observation-posts) |
| `MORTAR` | `opfor_TURRET_MORTAR` | one team | resident (never streams); cleared by destroying the tube |
| `ARTY` | `opfor_ARTY_X` | one team | resident; cleared by destroying the piece |
| `MINEFIELD` | 50 m mine squares, no core weapon | none | AT or AP variant; cleared when no armed mine remains |
| `RADIO` | live comms mast + 7 frozen HMG/AA nests | rifle team + 2 weapons teams | see [`opfor_area_of_influence.md`](opfor_area_of_influence.md#radio-towers) |

Tables: `DUWS_hardpointGarrison`, `DUWS_hardpointName`, `DUWS_hardpointStreaming`
(`server/server_var_init.sqf:377-441`). Classnames resolve through the same `opfor_*_X` faction
globals and the static-role table every zone and town garrison uses
([`faction_system.md#static-weapons-resolve-at-placement`](faction_system.md#static-weapons-resolve-at-placement))
— hardcoding a unit or turret classname is the one change that breaks mod-free operation and faction
auto-detection. `opfor_ARTY_X` is the one core that is a vehicle rather than a static, resolved and
crewed on a separate path in `fnc_hardpoint_garrison` (`fnc_hardpoint_place.sqf:54-104`): thawed and
crewed in place rather than dropped and settled, because it already sits on its own tracks.

`MG`, `AT`, `GMG`, `AA` and `ROADBLOCK` are the types the weight tables roll
(`DUWS_hardpointWeightZone` / `_Solo`, `server_var_init.sqf:405-410`). `OP` sits in no weight table
but is seeded standalone at generation, one per zone on a coin flip
([Observation posts](#observation-posts)). `MORTAR`, `ARTY` and `MINEFIELD` are fully implemented —
composition, garrison, streaming, clearance — but campaign generation never places them. All three come
from OPCOM's standalone builds (`appraisal/fnc_opcom_buy_build.sqf`), which lay a `MINEFIELD` one 50 m square at a
time, AT or AP. A `MINEFIELD` also comes from the debug hardpoint spawner
(`client/debug/fnc_debug_hardpoint_menu.sqf`), from the Eliminate Recon Patrol side mission, which
registers it as a standalone hardpoint, and from the Clear Minefield civilian mission, which registers a
thinned field and reveals it at once ([`side_mission_catalogue.md`](side_mission_catalogue.md)).
OPCOM's builds roll only the types OPFOR's tier has unlocked (`DUWS_hardpointTier`), and cap three types
campaign-wide: `RADIO` at `AOI_OPFOR_TOWER_CAP` (5), `MORTAR` at `OPCOM_CAP_MORTAR` (2) and `ARTY` at
`OPCOM_CAP_ARTY` (1), counting a build still on its truck. Campaign generation rolls every type and caps none.

Compositions are fenced `--DUWS-COMPOSITION--` arrays, one per type, authored in Eden through the
composition TUI ([`composition_tooling.md#static-compositions-the-eden-round-trip`](../architecture/composition_tooling.md#static-compositions-the-eden-round-trip)).
Offsets sit in a frame whose +Y is the hardpoint's facing, so a heading rotates cover and core
together rather than turning the core inside a fixed ring of props.

## Siting

Two shared primitives decide where a hardpoint goes and what it becomes, both in
`server/init_zones/fnc_hardpoint_siting.sqf` and both pure — no engine calls — so the arithmetic is
unit-tested independently of the terrain read that feeds it:

- **`fnc_hardpoint_survey [_pos]`** (`:33-132`) reads the ground: local relief and slope off an
  eight-point ring, a fall-line bearing and magnitude (which way the ground drops, and how
  decisively), distance and drop to the nearest road, tree and building counts at several radii, and
  distance to the nearest already-placed hardpoint.
- **`fnc_hardpoint_score [_facts, _type, _variant]`** (`:141-233`) turns that row into a multiplier for
  one type: 0 means the site cannot hold it (water, or a per-type veto — artillery needs level ground,
  a roadblock needs a road within 8 m, every other type is kept 100 m clear of any road, and
  a minefield's footprint must be clear of trees and buildings). `_variant` is the minefield's, and an
  `AT` field is the second exception to the road standoff: buried mines are not spotted from the verge,
  and `fnc_hardpoint_best_ground` snaps one onto a road when it draws within reach of one, since mines off
  the road stop nothing that drives. Unlike a roadblock it is not bound to a road, and lays where it fell
  when none is near. An `AP` field keeps the standoff.
  Otherwise the multiplier rewards what that type wants — high ground and a road below for MG/AT,
  flat and open for AA, defilade for a mortar, a symmetric crest for a radio mast — plus a mutual-support
  bonus for sitting within interlock range of a hardpoint already down.

**Type is rolled before ground is read.** `fnc_hardpoint_lay` (`fnc_hardpoint_place.sqf:169-197`)
draws the whole slate of types for a pass up front from the pass's base-weight map, then hunts each
rolled type a handful of candidate sites (`HP_TYPE_DRAWS` = 18, `:108`), scores each with
`fnc_hardpoint_score`, and weight-picks among whatever scored above zero. A type that finds no site
in its draw budget is dropped, logged, and never swapped for another. This inverts an earlier order
that scored ground first and rolled a type for the winning site: that let the highest-scoring
terrain — the rise MG and AT already favour — win nearly every placement and starved AA and
roadblock of the flat or roaded ground they need. Rolling type first means the realised mix is the
base weights, and terrain decides only *where* a type lands, never *whether* it is the one placed.

**Facing has no separate registry field.** `fnc_hardpoint_facing [_type, _aspectDir, _aspectMag,
_radialDir, _roadDir]` (`fnc_hardpoint_siting.sqf:246-255`) picks a heading per type — a roadblock stays
square across its road and takes whichever of its two headings faces the approach (`_radialDir`: outward
for a zone ring, toward BLU HQ for the corridor pass and for an OPCOM truck build, which the siting loop
places within half a grid cell of where it is delivered, `DUWS_fnc_opcom_buildCand`), MG/AT/GMG face down the fall line when one is
pronounced enough to trust, everything else keeps the outward-radial bearing the siting loop hands in. `fnc_hardpoint_build`
(`fnc_hardpoint_place.sqf:10-48`) then rotates every composition offset around that heading
(`fnc_hardpoint_rotate`, `:5-8`) before placing each object, so the heading is baked into each
prop's own position and direction at creation rather than stored beside it. Stowing a hardpoint later
records that same per-object transform — `[typeOf, getPosWorld, [vectorDir, vectorUp], ...]`
(`server/misc/fnc_composition_stream_init.sqf:121-123`) — and redeploy recreates it verbatim, so a
hardpoint that streams out and back in faces exactly where it did without being sited again.

**Zone ring.** `fnc_hardpoint_site_zone [_zonePos, _radius, _zoneKey, _count]`
(`fnc_hardpoint_place.sqf`) caps a zone's ring at `fnc_hardpoint_zone_cap`: `round(_radius / 250) max 1`
plus one per tier above I. It stores the radius half the first time it runs for that zone and refuses to
run again — a rebuild through `fnc_createZone` lays no second ring. The tier bonus is re-added live at
every count decision rather than baked into the stored cap, so a zone OPCOM later buys up to a higher
tier earns a higher ceiling with no rewrite. At campaign generation a random count up to the cap
(`round (random _cap)`, which can be zero) is laid, candidates drawn anywhere inside the zone on land
clear of steep slope, facing radially out from the centre. The cap is the free-slot limit OPCOM's zone
Build reads, less the standing ring and any build still siting (`DUWS_opcom_buildsPending`).

**Minefields are generated, not composed.** `fnc_hardpoint_minefield`
(`server/init_zones/fnc_hardpoint_minefield.sqf`) lays one 50 m square of vanilla mine objects —
`ATMine` for the AT variant, `APERSMine` for AP. Each 10 m cell of the square gets
one mine, so an AT square holds 25 mines. AP runs at 1.1 mines a cell: each cell has a 10% chance of a
second mine, so an AP square averages 27.5. A mine lands anywhere within 10 m of its cell's centre, up to
5 m past the cell edge. The spans of neighbouring cells overlap, so mines clump and leave gaps as a
hand-laid field does, and the square's edge blurs by up to 5 m.
One or two warning signs sit inside the field as dressing. A larger field is several squares, laid by
the caller. Every mine is `east revealMine`d so OPFOR AI does not walk its own field, leaving detection and
clearance to BLUFOR. Every player has the `explosiveSpecialist` trait (`client/client_init.sqf`), so any player
can disarm a mine with the engine's own action. It has no fence to place through `fnc_hardpoint_lay`, and no
garrison: the score function vetoes any candidate with a tree, building or hardpoint already on the footprint.

A block of squares is laid from `fnc_hardpoint_minefield_grid`, which returns the square centres for a
given width and depth. Squares laid under one site key add to one mine list, so they clear as one field.
The debug hardpoint spawner lays a field from three map clicks: both ends of the front, then the depth.
It snaps each measure to the nearest whole square, with one square as the minimum.

**Standalone band and radio towers.** Most standalone hardpoints are sited by sampling the OPFOR-positive
area-of-influence band; the roadblock net is the exception, drawing each block on the line from BLU HQ to
a zone (kept where the OPFOR field is positive) and snapping it to a road, a main road preferred. The two
flank lines and the observation posts sample the band their own way. `fnc_hardpoint_band_pool`
(`fnc_hardpoint_place.sqf:265`) draws band points uniformly over the whole map, once, after the radio
towers widen the band. A per-zone draw would give a small zone's band as many sites as a large one's. The
flank lines split the pool at its median distance to BLU HQ: the backline takes the far half and the
frontline the near half, one nest per zone each. Every pool site keeps `HP_POOL_ZONE_GAP` (300 m) clear of
every zone's edge, so it does not clump onto a zone's own ring. Radio
towers are their own hardpoint type, scored for hilltop crests and spaced off each other's coverage radius. Both the band sampler and the campaign's radio-tower economics —
`DUWS_opforRadioLevel` and its cap — belong to
[`opfor_area_of_influence.md`](opfor_area_of_influence.md#band-siting): this file owns the
terrain survey, per-type score, facing and spacing every band placement shares with the zone ring;
that one owns what the band *is* and what a tower buys the enemy.

All of it — the zone ring, radio-tower seeding, and the standalone band (the two flank lines, an AA
net, the observation-post net and the roadblock net) — runs in one generation phase between zone
build-out finishing and civilians starting (`fnc_init_OPFOR_WARCOM.sqf:61-128`), under the same
progress banner the other phases use. `fnc_hardpoint_plan_counts` (`fnc_hardpoint_place.sqf:405`)
rolls every zone's ring, both flank-line counts, the observation-post count and the roadblock targets
before any of it is laid, so the banner totals real hardpoints rather than counting zones.

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
(`fnc_hardpoint_garrison`, `fnc_hardpoint_place.sqf:54-104`), a fixed per-type token — the same team
composition and size whether the hardpoint is razed and rebuilt in hour one or hour five. Nothing in
the codebase scales hardpoint garrison size to `WARCOM_opfor_ap`.

## Observation posts

An `OP` is a lookout, not a strongpoint: it fields a close security team on the post and a recon
patrol screening wide, and while it stands it runs a recon screen against the player. Standalone OPs
are seeded at generation on a per-zone coin flip (`HP_OBS_P` = 0.5, `fnc_hardpoint_place.sqf:404`) —
at most one OP out in the band per zone — counted into the generation banner and sited off the flank
lines' uniform band pool (`fnc_hardpoint_site_obs`, `:316`), facing away from the nearest zone. They are
not rolled from any weight table.

`DUWS_fnc_hardpointOPSense` (`fnc_hardpoint_stream.sqf`) is swept once per OPCOM perception tick
alongside the belief sensors, not on a per-post clock: each standing OPFOR post rolls a per-tick
chance (`OP_OBSERVE_CHANCE`, 0.02 — roughly one fix every four to five minutes at the 5 s tick) and on a hit fires
`DUWS_fnc_hardpointOPBurst`. The burst pins OPFOR's knowledge of every live BLUFOR within
`OP_OBSERVE_K` Chebyshev grid cells (k = 2, ~1,000 m on axis) to a full identification — `reveal
[_unit, 4]` run against every live EAST group, since `reveal` writes knowledge onto a group, not a
side — stamps each caught group into OPCOM belief for certain, and red-cards each compromised *player*
on their own machine. Convoy groups (`DUWS_convoy_handled`) are skipped, or the reveal would promote a
scripted column out of SAFE and false-trip a mission's under-attack test. The per-tick roll makes the
ring a risk, not a certain reveal, and the belief stamp lands whether the post is deployed or stowed:
a post left alive keeps feeding its sector to the enemy, so the player kills it or routes around its
ring.

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
(`:169-227`) deletes the row from `DUWS_hardpoints` outright (`:178`) rather than marking it cleared
in place, so a re-manned gun cannot un-clear what the player already took. Survivors are left where
they fell, flagged for the cleanup sweep once the player is clear (`DUWS_binMe`, `:196`, on the
default lifetime) rather than deleted in front of anyone — a radio tower in particular can fall with
defenders still alive, since its clear condition is the mast, not the garrison. The composition is
released through `fnc_duws_release` (`:201`) like any other, so wrecks stay for the sweep rather than
vanish with the clear.

## Reveal

Every hardpoint gets a marker on registration: shape `"ICON"`, type `"loc_Bunker"`, coloured by side,
with the type token as its text (`fnc_hardpoint_stream.sqf:334-341`) — one icon shape for every type,
distinguished by label rather than by symbol. The marker's alpha and the revealed flag start at the rule
in [`intel_system.md`](intel_system.md#what-is-hidden-depends-on-when-it-came-into-existence): a hardpoint
laid by campaign generation is shown outside hardcore and hidden under it, and one built in play
(registered after `mission_init_complete`) starts hidden in both modes. `fnc_hardpoint_reveal` (`fnc_hardpoint_reveal.sqf`)
is the sole writer of the revealed flag — index 5 of a `DUWS_hardpoints` row — keyed on the
hardpoint's own key rather than position, the way `fnc_zone_reveal` owns its flag and
`fnc_civ_town_reveal` owns `civ_visible`. It announces each reveal as an Allseer line on SUB-NET, naming
the type (`DUWS_hardpointName`) and the nearest zone or town (`DUWS_fnc_hardpointNearestPlace`).

Two ways a hidden hardpoint is found. **Proximity**: the streaming tick checks every player within
100 m (`HP_REVEAL_RADIUS`, `fnc_hardpoint_stream.sqf:15`) of a still-hidden hardpoint whose parent
zone (if any) is itself already revealed, and reveals it — a zone-child hardpoint cannot be found
before its zone is. **Intel**: `fnc_intel_payout` draws `"HP"` as one of its kinds whenever the
eligible set is non-empty — unrevealed, and either standalone or whose parent zone is already
revealed (`server/search/fnc_intel_payout.sqf:48-60`) — matched by `fnc_zone_key`, the same key both a
revealed zone and a hardpoint row carry.

A minefield is also found when its first mine is gone: set off, disarmed or destroyed. The clear check
reads its mine list every tick, and reveals the field once fewer mines are armed than were laid. Revealing
a minefield runs `west revealMine` on every mine, on every machine and in the JIP queue, so the engine
marks each mine for BLUFOR with its own mine icons, on the map and in 3D, wherever the difficulty's
detected-mines option allows. BLUFOR AI then also steers clear of the field. Clearing the field removes
the JIP entry.

## Clear economy

Clearing pays the player CP, and for the heaviest emplacements AP as well; it never pays OPFOR
anything back. Every hardpoint except a minefield pays, zone and standalone alike, a per-type bounty read from
`DUWS_hardpointBounty` (`server_var_init.sqf:437-439`): `5 CP` by default, `10 CP` for a radio,
artillery or mortar hardpoint, of which a radio also pays `10 AP` and artillery `5 AP`. CP runs
through `fnc_cp_adjust` and any AP through `fnc_ap_adjust`, each on its own carded notification naming
the type and nearest zone or town — a single combined card buried the AP gain in the CP badge
(`DUWS_fnc_hardpointClear`, `fnc_hardpoint_stream.sqf:209-225`; `notifications.hpp`, `HPdestroyed` /
`HPdestroyedAP`). A zone hardpoint's bounty is paid on top of the zone's own capture bounty. A minefield
pays nothing, a hazard removed rather than a garrison beaten, but its clear is still carded without a
bounty badge (`HPcleared`).

An OPCOM hardpoint build is an Army Power sink, and nothing refunds AP when the player clears one. A
refund would be farmable — build, clear, refund, repeat — and the enemy's pool would never reach
whatever escalation the commander prices against it. Only a build that finds no ground is refunded, since
nothing stands; a truck-delivered build refunds in full, the truck included. Build prices and the build decision are
[`opcom_plan.md`](../../plans/opcom/opcom_plan.md#what-the-commander-builds)'s.
