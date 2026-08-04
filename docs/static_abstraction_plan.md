# Static emplacement abstraction: implementation plan

Every static weapon the mission places is a hardcoded vanilla classname. Zone prefabs stand
NATO and AAF guns on CSAT ground; a mod faction's own emplacements are never fielded even when
detection has already found them. This plan gives statics the same abstraction infantry and
vehicles have had since the beginning: a **role key** the faction fills, read at the moment
something is placed.

Five roles, chosen because each is a distinct tactical answer rather than a distinct model:

| Role | What it answers | Vanilla representative (what Eden draws) |
|---|---|---|
| Heavy MG | infantry on foot | `B_HMG_01_high_F` and the `HMG_0*` family |
| GMG | infantry behind cover | `B_GMG_01_high_F` |
| AT gun | anything wheeled or tracked | `B_static_AT_F` |
| AA | aircraft | `B_static_AA_F` |
| Mortar | indirect fire inside the zone | `B_Mortar_01_F` |

This is the enabler for the hardpoint tier — four of its five emplacement types are exactly these
roles ([`hardpoint_system_plan.md`](hardpoint_system_plan.md)) — but it is worth doing on its own:
it fixes 41 prefab rows that field the wrong side's guns today.

## The keys

Names follow the existing `<side>_TURRET_<ROLE>` convention.

| Role | OPFOR | BLUFOR | Status |
|---|---|---|---|
| Heavy MG | `opfor_TURRET_HMG` | `blufor_TURRET_HMG` | both exist; the OPFOR one has no reader anywhere |
| GMG | `opfor_TURRET_GMG` | `blufor_TURRET_GMG` | OPFOR new |
| AT gun | `opfor_TURRET_AT` | `blufor_TURRET_AT` | OPFOR new |
| AA | `opfor_TURRET_AA` | `blufor_TURRET_AA` | OPFOR new |
| Mortar | `opfor_TURRET_MORTAR` | `blufor_TURRET_MORTAR` | new both sides |

**AA is one key, not a guided and an unguided one.** Vanilla's crewed static AA is entirely
guided — the Titan launchers `B_static_AA_F` / `O_static_AA_F` / `I_static_AA_F`. The only vanilla
asset that is arguably an AA *gun* is the Praetorian autocannon, a large automated radar
emplacement with no CSAT or AAF counterpart, so an unguided key would resolve to nothing on most
factions and to something the size of a building on one. Splitting the role also costs a split in
detection, since `fnc_parseFaction` returns a single merged AA bucket. A mod faction that fields a
towed AA gun gets it through the same key; what it does not get is the mission choosing a gun over
a launcher deliberately, and nothing in the campaign wants to make that choice.

**The GMG is the role that shows why HMG is the universal stand-in.** `blufor_TURRET_GMG` already
exists and is required today; the OPFOR half is new, and it is the role the largest number of
factions field nothing for. The shipped files have already settled what to do about that: all 122
BLUFOR faction files define the key, and 25 of them fill it with an HMG classname rather than a
grenade launcher, because their faction has no GMG and an MG nest is the same tactical answer.
Resolver rule 2 generalises that hand-written habit to every static role.

## How a placeholder becomes a faction class

**The vanilla classname in the row is the token.** A shared map takes each vanilla static class to
a role, and one resolver consults it at placement. Nothing about a composition changes — no new
column, no re-edit of the 41 rows, and the Eden round trip is untouched.

This is the smallest change that reaches every call site, and it is the one the 3D editor already
implies: an author drags a Mk6 mortar into Eden because a mortar belongs there, not because they
want that specific tube.

Two alternatives, both rejected:

- **A role column at index 6 of a prefab row.** Index 5 already means two different things —
  `isWeapon` on the zone prefabs (`prefabs/modern/fnc_modern_reconOutpost.sqf:116`), the role name
  on the HQ and FOB fences (`init_hq/fnc_fortifyFOB.sqf:105`) — so the role would sit at index 5 in
  one convention and 6 in the other, which is the positional trap
  [`info/composition_tooling.md`](info/composition_tooling.md) warns about. It also means 41 rows
  hand-edited now and re-edited after every Eden round trip, because the export emits five columns
  and nothing past them.
- **Replace `isWeapon` with the role at index 5.** Uniform, and the flag looks redundant — across
  the 380 fenced rows in the seven prefabs, the 41 flagged `true` are exactly the static-weapon
  classes and nothing else. But it rewrites all 380 to buy a uniformity the resolver does not need,
  and it deletes a flag each prefab's two placement passes read to split props from guns.

### The resolver

`shared/functions/fnc_static_roles.sqf`, compiled by `[] call compile` from
`server_fnc_init.sqf` beside `fnc_faction_pools.sqf` at `server_fnc_init.sqf:370` — the same idiom,
one file defining the table, the function that reads it, and the placer that acts on the answer.

```sqf
[_class, _side, _role] call fnc_static_resolve   // _side is "opfor" or "blufor"
```

`_role` is optional and empty for every caller but the two fences. A row that names its key skips
the class-token lookup and resolves that key; every other caller passes the class alone and the map
decides. One entry point rather than two, so the fallback and the type test below are written once.

Four rules, each covering a way this fails silently otherwise:

1. **A class the map does not carry comes back unchanged.** That is every `Land_*` prop, every
   ammo box, and any static an author added that nobody has mapped. Passing the row through is
   what keeps a prefab working when the map is incomplete.
2. **An empty key falls to the side's HMG, and an empty HMG falls to the row's own class.**
   `fnc_faction_pick` returns `""` for a role nothing defined
   (`shared/functions/fnc_faction_pools.sqf:104-112`), which is the state all 254 hand-authored
   faction files will be in for the new keys, forever, since they define `opfor_TURRET_HMG` and
   the four BLUFOR turrets alone. Substituting the faction's own MG nest keeps the campaign inside
   the faction the file names. A faction with no static MG either is warned about once at init and
   its rows stand as themselves. Neither branch needs the 254 files swept.
   This rule does not fire for an auto-detected faction: the ladders below carry a vanilla tail on
   every static key, so a detected faction's key is never empty. Hand-authored files and custom
   pastes are what it covers, which is the majority path.
3. **The replacement must be `isKindOf "StaticWeapon"` or it is refused.** Three systems key off
   that type test — the zone manning hook (`init_zones/fnc_zone_stream_init.sqf:212`), its
   crew-out counterpart (`:256`), and the empty-vehicle cleanup's exemption
   (`misc/fnc_repetitive_cleanup.sqf:122`). A mod "static" that is configured as a car would be
   placed, never crewed, never crewed out, and swept as an abandoned vehicle. Fail closed: keep
   the placeholder. It fires on values from faction files and pastes only — the AutoDetect ladders
   and the confirmation screen's key editor both gate on the same test already.
4. **Drawn through `fnc_faction_pick`, not read off the global.** Detection finds several statics
   per role and keeps them in `DUWS_factionPool_<role>`; picking per object is what makes two MG
   nests in one zone different guns, exactly as it already does for infantry and vehicles.

**There is no per-side table of stand-in classes.** Rule 2 is the whole of the resolver's fallback:
any role but HMG resolves to HMG when the faction has none; HMG itself resolves to the placeholder,
warned. It lives in the resolver rather than in the AutoDetect ladders because the ladders only
cover auto-detected factions, so a rule written there would miss the 254 hand-authored files and
every custom paste — the paths that actually leave a static key empty.

Between the ladders' vanilla tail and rule 2, the same missing role gets two different answers
depending on which path resolved the faction. A detected faction with no mortar fields a vanilla
CSAT tube; a hand-authored one fields its own MG nest. Both are on the right side, which is what
this plan was opened to fix — today that pit holds a NATO tube whatever the faction is. Closing the
split would mean sweeping 254 files, which is the cost this plan exists to avoid.

What the tail costs is a distinction the key can no longer draw: a detected faction's mortar key
always answers with a class, so nothing downstream can ask whether the faction really fields a
mortar or is standing in a vanilla one. The hardpoint tier is the consumer that would want to.

Locality is server. Ordering is already safe without a new gate, but the gate that matters is not
the obvious one. Resolution runs per pass inside the confirmation loop (`server_init.sqf:52-100`) and
the player may then edit or clear any key on that screen; the `fnc_faction_apply_locked` call at
`:114` is what lays those edits over the resolved globals and republishes the pools. A static
resolved before it would field the detected class rather than the confirmed one. Nothing does today
— the HQ is spawned at `:126` and zone siting at `:146`, both behind it — and any new site has to stay
behind it too. The `createzone_server` wait at `:106` is two gates earlier and proves nothing about
the edits.

### The map is a fenced table

`DUWS_staticRoles` lives inside a `--DUWS-UNITCOMP--` fence with `kind=rule` and
`fields="class, role"`, so adding a placeholder is a TUI edit rather than a code edit
([`info/composition_tooling.md`](info/composition_tooling.md#adding-a-table-to-the-tool)).

It must carry every side's variant of each family, not only the eight classes the prefabs use
today. An author who drags an `O_HMG_01_high_F` into Eden gets a row that resolves; one who
drags a class nobody listed gets a row that stands as itself, which is rule 1 and is quiet
either way. The eight in use now:

| Placeholder | Rows | Role |
|---|---|---|
| `I_HMG_02_high_F` | 19 | HMG |
| `I_G_HMG_02_high_F` | 5 | HMG |
| `I_HMG_01_high_F`, `B_HMG_01_high_F` | 1 each | HMG |
| `B_static_AA_F` | 7 | AA |
| `B_Mortar_01_F` | 6 | mortar |
| `I_Mortar_01_F` | 1 | mortar |
| `I_GMG_01_high_F` | 1 | GMG |

No AT gun appears in any composition today. That role exists for the hardpoint tier and for mod
factions that field one; it has no migration.

### The explicit role column still wins

The HQ and FOB fences name their key in the row (`init_hq/fnc_BluHQinit.sqf:203`,
`init_hq/fnc_fortifyFOB.sqf:94-97`) and that must keep taking priority over the map. A Titan on
the HQ roof is a decision about that position, not a lookup.

Both branches go through the resolver. An unroled row falls through to the class-token lookup, so a
gun added to the fence in Eden follows the faction without anyone remembering to hand-add a sixth
column; a roled row hands its key over and the map is never consulted. What the named branch gains
is what it does not have today — `fnc_fortifyFOB.sqf:108-110` and `fnc_BluHQinit.sqf:302-311` both
read the global directly, which is the pool's stable representative, so a FOB's four guns are
identical every campaign and a mod static configured as a car is placed unchecked. Routing them
through the resolver gives the fence the same per-object draw and the same type test as everything
else, and leaves one place where a static's class is decided rather than two.

## Detection needs nothing new

`fnc_parseFaction` already buckets all five roles and returns them. The OPFOR ladder reads three of
them for its one static key (`shared/includes/autodetect_roles_opfor.hpp:50`) and the BLUFOR one
reads all but the mortar (`AUTODETECT_blufor.sqf:78-81`). So the detection half of this is reading
values that have been computed and discarded since the generator was written.

| Role | Bucket | Where |
|---|---|---|
| HMG | `_turretHMG` | `shared/factions/MODERN/fn_factionAutoDetect.sqf:630` |
| GMG | `_turretGMG` | `:631` |
| Mortar | `_turretMortar` | `:632` |
| AA | `_turretAA` | `:633` |
| AT | `_turretAT` | `:634` |

The return array is positional and destructured by a `params` string in each of the three wrappers
(`AUTODETECT_opfor.sqf:33`, `AUTODETECT_blufor.sqf:33`, `AUTODETECT_RANDOM_opfor.sqf:51`). Nothing is
added to it, so those strings do not change.

One line is worth changing while here. `_turretCannon` (`:635`) is parsed and then dropped from
the return at `:659-675`; a towed AA gun that a mod types as a cannon rather than as
`StaticAAWeapon` falls into it and disappears. Extending `_turretAA`'s existing
`fnc_selectNonEmpty` chain with the air-threat members of `_turretCannon` recovers those factions
without touching the return array's shape.

## What each faction path has to fill

| Path | Change |
|---|---|
| `fnc_faction_schema.sqf` | four new OPFOR rows, one new BLUFOR, all `STATIC`/`static` |
| `includes/autodetect_roles_opfor.hpp:50` | four ladder rows added beside the HMG one; shared by both OPFOR wrappers, so neither is edited |
| `AUTODETECT_blufor.sqf:78-81` | one ladder row added for the mortar; `_AA` and `_GMG` ladders widened |
| 254 files in `factions/MODERN/` | **none** — resolver rule 2 covers them |
| Custom paste | see below; it does not work without a schema change |

`o_arraysToRandomize` / `b_arraysToRandomize` need no edit: both derive from the schema
(`AUTODETECT_opfor.sqf:80`, `AUTODETECT_RANDOM_opfor.sqf:73`, `AUTODETECT_blufor.sqf:223`), so
a schema row reaches `fnc_faction_pools_publish` for free.

**Every new key carries a vanilla tail, like every other ladder row.** A static row is
`[key, [buckets in preference order], fallback]` and the fallback is that side's vanilla class —
CSAT on the OPFOR ladder, NATO on the BLUFOR one — so a detected faction fielding no mortar stands a
vanilla tube rather than nothing. The alternative, leaving the new keys tailless so rule 2 could
substitute the faction's own HMG, was rejected for the reason the ladder has tails at all: one row
shaped unlike the other forty is a row the next edit "corrects".

`fnc_faction_resolve` gates each rung on the schema's `kind`, so a static key only ever takes a
class that is `isKindOf "StaticWeapon"` — resolver rule 3 already enforced for this path. Nothing
here needs to assign `""`: with every rung and the fallback empty, resolve writes `[]` and
`fnc_faction_pick` reads it back as `""`.

### Adding a required key breaks every existing custom faction

`fnc_custom_faction_parse.sqf:28` derives its required-key set straight from the schema and
reports any key that is missing or resolves to a non-existent class. Add the five static rows and
**every paste a player already has fails validation** — including one copied out of a
`factions/MODERN/` file, since none of those define the new keys either.

**Add a fourth column to the schema tuple: `required`.** The new statics are `false`; every
existing key stays `true`. `fnc_custom_faction_parse` filters on it before building `_bad`. The
confirmation screen still renders the rows — as `-- MISSING --`, which is accurate and is the
information the screen exists to give (`client/dialog/fnc_faction_row_paint.sqf:35-41` paints the
empty row red and disables its CLEAR button).

**The filter narrows validation only — the clear loop keeps every key.** `_requiredKeys` is used
twice: once to blank the globals before the paste is compiled (`:36`), once to build `_bad` (`:50`).
The blanking is what stops a value left over from a previously pasted faction being read as one this
paste defines. Narrow that loop along with the validation and the five static keys survive a
re-paste, so faction B fields faction A's guns. Stepping back into the faction screen re-picks and
re-pastes as a normal navigation path now, so this is a routine sequence rather than an edge case.
Clear the full schema, validate the required subset.

The alternative, excluding the whole `STATIC` group from the required set, also drops the four
BLUFOR turrets that are required today and do real work in the FOB ring.

`fnc_faction_schema.sqf` returns `[key, group, kind]` today, and its `STATIC` group is 4 BLUFOR
against 1 OPFOR — a gap the confirmation screen pads so the section below it starts on the same line
in both columns. Both change here: the tuple gains a column, and the section becomes 5 BLUFOR /
5 OPFOR, so it stops padding one column against the other entirely.

Nothing else on that screen needs touching, and two of its existing behaviours are load-bearing
here. Its key editor already filters a `static` row to `isKindOf "StaticWeapon"`
(`fnc_faction_key_edit.sqf:50`), which is resolver rule 3 enforced at the point of choice — so rule
3 only ever fires on values coming from faction files and pastes, never from the screen. And an
edited key is written back as a pool rebuilt from the matching `fnc_parseFaction` bucket
(`fnc_faction_key_apply.sqf:60-72`); all five turret buckets are in that function's return, so a
player editing a static key keeps the per-object variety rule 4 draws on. A class the parse returns
no bucket for — a cannon-typed AA gun, which the return drops — yields a pool of one and nothing
worse.

## Call sites

Fifty-eight placements across thirteen files. Fifty-two go through the placer below, so an OPFOR
zone gun and a BLUFOR FOB gun differ in the `_side` argument and nothing else. The six that do not
place from a row at all — the HQ's two, `simple_zone`'s three and the FOB's roof AA — resolve their
class the same way and keep the placement they have.

| File | Statics | Change |
|---|---|---|
| `init_zones/prefabs/modern/fnc_modern_Outpost2.sqf` | 9 | weapon pass calls the placer |
| `.../fnc_modern_outpost1.sqf` | 7 | same |
| `.../fnc_modern_reconOutpost.sqf` | 7 | same (`:146-163`) |
| `.../fnc_modern_CommStation.sqf` | 6 | same |
| `.../fnc_modern_FieldHospital.sqf` | 5 | same |
| `.../fnc_modern_StorageBunker.sqf` | 4 | same |
| `.../fnc_modern_vehfittingstation.sqf` | 3 | same |
| `.../fnc_modern_simple_zone.sqf` | 3 | `:53,77,101`, resolve only — see below |
| `init_hq/fnc_fortifyFOB.sqf` | 5 | `_fnc_place` becomes a call to the placer (`:103-119`), roof AA at `:133` |
| `init_hq/fnc_BluHQinit.sqf` | 2 | `:302-311`, resolve only — see below |
| `missions/mission_threads/holdpos/fnc_holdposition_mission.sqf` | 3 | `:110,117` HMG and `:124` mortar, hand-written blocks |
| `missions/mission_threads/destroy_radar/fnc_destroy_radar_mission.sqf` | 2 | `:68,76`, NATO AA guarding an enemy radar |
| `missions/mission_threads/destroy_cache/fnc_destroy_cache_mission.sqf` | 2 | `:134,141`, and the side is wrong — see below |

### One placer, both sides

The six real prefabs carry the same loop six times: a ground pass, a weapon pass that restores each
gun's absolute Z, and a gunner step over the objects the weapon pass collected. The FOB fence is
that loop again with ground Z and a role column. Rather than thread a resolver call through seven
copies of code that should not have been seven copies, the placement itself moves into one function
and the copies become calls to it.

`fnc_static_place`, in `fnc_static_roles.sqf` beside the resolver — one file, so the decision about
which class a static is and the only sanctioned way to put one down cannot drift apart:

```sqf
[_row, _origin, _side, _key, _mode] call fnc_static_place   // returns the object
```

`_row` is `[class, offsetX, offsetY, offsetZ, dir, role]` with `role` optional, which is the shape
both fences already use. `_mode` is `"world"` or `"pos"`, and which one a caller passes follows from
whether its rows carry a height:

- **`"world"`** — the row states a Z, so the gun is written at `_origin`'s Z plus that offset with
  `setPosWorld`. This is what holds a gun off the ground: Outpost2's four tower rows at Z 19.71-20.85
  stand on a structure, and `setPosATL` measures from terrain and would drop them through it. All 41
  prefab weapon rows carry a non-zero Z, so all 41 take this mode.
- **`"pos"`** — the row's Z is 0, meaning "on the ground", written with `setPos`. That is the FOB's
  four rows and, once they are fenced, the seven mission guns.

The mode is passed rather than inferred from the Z, because a row genuinely authored at absolute
zero is indistinguishable from one that omitted the column, and the caller knows which it wrote.
There is no third mode; adding one is how this function starts growing flags for each caller's
quirks. The FOB's roof AA keeps its own `setPosATL`: its height comes from `buildingPos`, not from a
row, so it is not a placer call at all.

Inside: resolve, `createVehicle`, position written either side of `setDir` (which displaces the
object — the reason both existing placers write it twice), `fnc_duws_keep` under `_key`, and
`enableSimulationGlobal false`.

**The heading is the row's, always.** Six prefabs and all three mission files currently discard it
and turn the gun to face away from the composition centre — `_obj setDir (_centerSpawn getDir
[_newX, _newY])` in the weapon passes, and a second `setDir` over the crewed pair at
`fnc_holdposition_mission.sqf:139-140`, `fnc_destroy_radar_mission.sqf:92-93` and
`fnc_destroy_cache_mission.sqf:157-158`. Those go. The
argument is the one `fnc_fortifyFOB.sqf:89-92` already settled for the FOB ring: a computed heading
means a turret turned in Eden comes back facing wherever the formula put it, and the round trip
silently drops the edit. It also makes a facing something a composition can state, which is what the
hardpoint tier needs to put an MG on a road rather than on a bearing.

**The placer freezes, the crew step thaws.** `enableSimulationGlobal false` at creation is what makes
an elevated row hold — an unsimulated object placed in the air stays there, a simulated one falls
([`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md)) — and the freeze has to be the
`Global` variant or every client keeps simulating a gun the server has parked. The prefabs already
do both halves (`fnc_modern_reconOutpost.sqf:158` and `:184`); the FOB and the three missions do
neither today and gain the thaw in the step that crews their guns. One rule, so a site that forgets
it fails the same recognisable way rather than a new one.

The gunner step stays with each caller, since what it crews is the list that caller collected.

**`fnc_BluHQinit.sqf` cannot use it and calls the resolver directly.** Its fence is not placed at
build time at all — it is resolved into `HQ_redeploy_weaponData` for `fnc_placeHQUnits.sqf`, which
runs again on every redeploy against whatever is standing there now. A placer that creates an object
is the wrong tool for a site whose product is data.

**Mission statics become fenced rows.** The three mission files write each gun as a hand-numbered
`_vehicle_9 = createVehicle [...]` block with its own `setDir` and `setPosATL`. They become rows in
a `--DUWS-COMPOSITION--` fence and go through the placer in `"pos"` mode like everything else, which
is what puts those seven guns inside the Eden round trip the prefabs already have. Each keeps the
`allowDamage false` or `setVehicleAmmo 0.3` it carries today, applied by the caller to the object
the placer returns: the radar's two AA guns are invulnerable by design, and the holdpos mortar is
deliberately short of ammunition.

**`simple_zone`'s three guns are resolve-only.** Its mortar and two AA guns are not offset
placements — each runs a twenty-attempt `isFlatEmpty` search up to 300 m from the zone centre
(`:36-58`, `:60-83`, `:85-107`) and then levels itself with `setVectorUp [0,0,1]`. That scatter is
the zone type: it fits itself to whatever ground it was sited on. Only the classname goes through
`fnc_static_resolve`; the placement stays where it is, `setPosATL` included.

**`destroy_cache` guards an enemy objective with the player's own gun.** `:134,141` spawn
`blufor_TURRET_HMG` on a mission whose whole subject is an OPFOR cache, so a mod-equipped BLUFOR
faction currently defends the enemy's supplies. It resolves as OPFOR with the rest of them.

**`misc/fnc_garrisonMortar.sqf:23-24` stays hardcoded.** Its tube is two backpacks on two men
(`O_Mortar_01_support_F` / `_weapon_F`), not a static, and there is no faction key for a mortar
backpack — inventing one to cover a single call site is a sixth key for one consumer. It is
listed here so its absence reads as a decision.

## Risks

**Footprint and height.** A row's Z was authored against one silhouette. Ground rows re-snap, but
four of `Outpost2`'s statics sit on a tower at Z ≈ 19.7-20.9, the HQ's AA rides an anchor class
and a measured offset (`fnc_BluHQinit.sqf:203`), and the FOB's stands on `buildingPos 5`
(`fnc_fortifyFOB.sqf:131`). A taller replacement clips or floats at all three. This is inherent to
any substitution scheme and the FOB has accepted it since its role column was added; the elevated
rows are where to look first if something reads wrong.

**A pool of one is not variety.** Most factions define one static per role, so `fnc_faction_pick`
returns the same class every time and the per-object draw costs nothing and buys nothing. It is
still the right call: the sites that do have a pool get variety for free, and doing it the same
way as infantry and vehicles is one fewer special case.

**Detection quality is the real ceiling.** The AA and AT buckets fall back to `fnc_isThreatTo`
(`fn_factionAutoDetect.sqf:633-634`), which reads one `threat` array and returns whichever of
soft/armor/air is largest (`:295-304`) — so a gun equally threatening to infantry and air resolves
to whichever `selectMax` hits first. A misbucketed static is a gun that never fires at aircraft
rather than an error. The ladders and their vanilla tails keep a key from being empty; nothing keeps
it from being wrong. Worth checking against two or three mod factions once the keys are readable.

## Task list

1. `fnc_faction_schema.sqf`: `required` column, plus the five new static rows.
2. `fnc_custom_faction_parse.sqf`: validate against the `required` subset, clear against the whole
   schema.
3. Fill the keys in `includes/autodetect_roles_opfor.hpp` and `AUTODETECT_blufor.sqf` — own buckets
   in preference order, side-appropriate vanilla tail on every one — and widen `_turretAA`'s chain
   with the air-threat members of `_turretCannon`. Warn at faction init when a side's HMG key comes
   back empty, since rule 2 rests on it for the hand-authored path.
4. `shared/functions/fnc_static_roles.sqf`: the fenced `DUWS_staticRoles` table, `fnc_static_resolve`
   and `fnc_static_place`, registered in `server_fnc_init.sqf`.
5. Convert the call sites: six prefab weapon passes and the FOB fence to placer calls, the three
   mission files to fenced rows plus a thaw in their crew steps, and `fnc_BluHQinit.sqf` and
   `simple_zone` to resolve-only.
6. Update [`info/faction_system.md`](info/faction_system.md) (the static-weapon row of the schema
   table) and [`info/composition_tooling.md`](info/composition_tooling.md) (a static row's class is
   a role token at runtime, so a placeholder swapped in Eden changes what the faction fields).

Steps 1-3 are inert on their own: the keys resolve and nothing reads them, so they can land and be
verified against a faction readout before any composition changes. Step 4 is inert without step 5.

Step 5 is where the risk sits, because it is a placement rewrite rather than an inserted line. Land
it one caller at a time against a zone built from the same seed before and after: same count, same
positions, same guns crewed, and every gun simulated once its gunner is in. Headings are the one
thing expected to change — roughly fifty guns turn from computed-outward to whatever their row says,
which is the point of the change and not a fault. A gun that moves, hangs in the air, loses its
gunner or stays frozen has had its mode or its row shape mistranslated, and those are the only
faults this step can introduce.
