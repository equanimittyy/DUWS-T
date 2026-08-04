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
  the 515 fenced rows in the seven prefabs, the 41 flagged `true` are exactly the static-weapon
  classes and nothing else. But it rewrites all 515 to buy a uniformity the resolver does not need,
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
   (`shared/functions/fnc_faction_pools.sqf:46-54`), which is the state all 254 hand-authored
   faction files will be in for the new keys, forever, and the state of any mod faction fielding
   no mortar or no AA. Substituting the faction's own MG nest keeps the campaign inside the
   faction it detected; standing a vanilla Titan there would put back exactly the wrong-side gun
   this plan removes. A faction with no static MG either is warned about once at init and its rows
   stand as themselves. Neither branch needs the 254 files swept.
3. **The replacement must be `isKindOf "StaticWeapon"` or it is refused.** Three systems key off
   that type test — the zone manning hook (`init_zones/fnc_zone_stream_init.sqf:212`), its
   crew-out counterpart (`:256`), and the empty-vehicle cleanup's exemption
   (`misc/fnc_repetitive_cleanup.sqf:122`). A mod "static" that is configured as a car would be
   placed, never crewed, never crewed out, and swept as an abandoned vehicle. Fail closed: keep
   the placeholder.
4. **Drawn through `fnc_faction_pick`, not read off the global.** Detection finds several statics
   per role and keeps them in `DUWS_factionPool_<role>`; picking per object is what makes two MG
   nests in one zone different guns, exactly as it already does for infantry and vehicles.

**The whole fallback chain is these two rules and nothing else** — no vanilla tail per key, no
per-side table of stand-in classes. Any role but HMG resolves to HMG when the faction has none;
HMG itself resolves to the placeholder, warned. It lives in the resolver rather than in the
AutoDetect chains for two reasons. The chains only cover auto-detected factions, so a rule written
there would miss the 254 hand-authored files and every custom paste — the paths most likely to
leave a static key empty. And a chain bakes the substitution into the key, which then reads as a
real AA gun when it is a stand-in; a consumer that must tell those apart, such as the hardpoint
director choosing which emplacement types a faction can field, has nothing left to test.

What this costs is real and is the point: a faction with no mortar fields no mortar. The seven AA
rows and seven mortar rows across the prefabs become MG nests on any faction lacking those guns,
which includes all 254 hand-authored files, since they define `opfor_TURRET_HMG` alone. Those zones
lose their indirect fire and their air cover, and are easier for it. The alternative is a zone whose
"CSAT" mortar pit is a NATO tube, which is the fault this plan was opened to fix.

Locality is server. Ordering is already safe without a new gate: faction init completes at
`server_init.sqf:66-88` and every prefab runs behind the `createzone_server` wait at `:109`.

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
is what it does not have today — `fnc_fortifyFOB.sqf:106-110` and `fnc_BluHQinit.sqf:302-311` both
read the global directly, which is the pool's stable representative, so a FOB's four guns are
identical every campaign and a mod static configured as a car is placed unchecked. Routing them
through the resolver gives the fence the same per-object draw and the same type test as everything
else, and leaves one place where a static's class is decided rather than two.

## Detection needs nothing new

`fnc_parseFaction` already buckets all five roles and returns them. The OPFOR generator uses none
of them — it hardcodes the HMG at `AUTODETECT_opfor.sqf:121` — and the BLUFOR one uses all but the
mortar. So the detection half of this is reading values that have been computed and discarded
since the generator was written.

| Role | Bucket | Where |
|---|---|---|
| HMG | `_turretHMG` | `shared/factions/MODERN/fn_factionAutoDetect.sqf:605` |
| GMG | `_turretGMG` | `:606` |
| Mortar | `_turretMortar` | `:607` |
| AA | `_turretAA` | `:608` |
| AT | `_turretAT` | `:609` |

The return array is positional and destructured by a `params` string in each of the three wrappers
(`AUTODETECT_opfor.sqf:41` and the same line in the other two). Nothing is added to it, so those
strings do not change.

One line is worth changing while here. `_turretCannon` (`:610`) is parsed and then dropped from
the return at `:631-645`; a towed AA gun that a mod types as a cannon rather than as
`StaticAAWeapon` falls into it and disappears. Extending `_turretAA`'s existing
`fnc_selectNonEmpty` chain with the air-threat members of `_turretCannon` recovers those factions
without touching the return array's shape.

## What each faction path has to fill

| Path | Change |
|---|---|
| `fnc_faction_schema.sqf` | four new OPFOR rows, one new BLUFOR, all `STATIC`/`static` |
| `AUTODETECT_opfor.sqf:121` | one hardcoded HMG line becomes five `fnc_selectNonEmpty` chains |
| `AUTODETECT_RANDOM_opfor.sqf:90` | the same five |
| `AUTODETECT_blufor.sqf:124-127` | one line added for the mortar; `_AA` and `_GMG` chains widened |
| 254 files in `factions/MODERN/` | **none** — resolver rule 2 covers them |
| Custom paste | see below; it does not work without a schema change |

`o_arraysToRandomize` / `b_arraysToRandomize` need no edit: both derive from the schema
(`AUTODETECT_opfor.sqf:164`, `AUTODETECT_RANDOM_opfor.sqf:110`, `AUTODETECT_blufor.sqf:262`), so
a schema row reaches `fnc_faction_pools_publish` for free.

**No generator writes a vanilla fallback class.** Each of the ten keys is its own detected bucket or
nothing; the substitution is the resolver's, so a stand-in written here would only hide from it
whether the faction actually has the gun. The HMG keys are the exception worth stating: they keep a
vanilla tail on both sides, because rule 2 leans the other nine keys on them and a side with an
empty HMG loses the whole chain.

Assign `""` explicitly for the nothing case rather than letting the chain produce it.
`fnc_selectNonEmpty` is `_this select {_x isNotEqualTo []} select 0` — with every candidate empty,
`select 0` runs against an empty array and returns **nil**, which deletes the global instead of
emptying it, and a direct reader then throws on an undefined variable rather than reading `""`.

### Adding a required key breaks every existing custom faction

`fnc_custom_faction_parse.sqf:28` derives its required-key set straight from the schema and
reports any key that is missing or resolves to a non-existent class. Add the five static rows and
**every paste a player already has fails validation** — including one copied out of a
`factions/MODERN/` file, since none of those define the new keys either.

**Add a fourth column to the schema tuple: `required`.** The new statics are `false`; every
existing key stays `true`. `fnc_custom_faction_parse` filters on it before building `_bad`. The
confirmation screen still renders the rows — as `-- MISSING --`, which is accurate and is the
information the screen exists to give.

The alternative, excluding the whole `STATIC` group from the required set, also drops the four
BLUFOR turrets that are required today and do real work in the FOB ring.

This lands in the middle of the confirmation-screen work, which documents the tuple as
`[key, group, kind]` and sizes its static section at 4 BLUFOR / 1 OPFOR
([`faction_confirm_screen_plan.md`](faction_confirm_screen_plan.md)). Both change here: the tuple
gains a column, and the section becomes 5 BLUFOR / 5 OPFOR, so it stops padding one column against
the other entirely. Sequence this after that screen lands, or fold it in — either works, but the two
must not be written against each other's old shape.

## Call sites

Fifty-eight placements across thirteen files. Every one of them goes through the placer below,
so an OPFOR zone gun and a BLUFOR FOB gun differ in the `_side` argument and nothing else.

| File | Statics | Change |
|---|---|---|
| `init_zones/prefabs/modern/fnc_modern_Outpost2.sqf` | 9 | weapon pass calls the placer |
| `.../fnc_modern_outpost1.sqf` | 7 | same |
| `.../fnc_modern_reconOutpost.sqf` | 7 | same (`:146-163`) |
| `.../fnc_modern_CommStation.sqf` | 6 | same |
| `.../fnc_modern_FieldHospital.sqf` | 5 | same |
| `.../fnc_modern_StorageBunker.sqf` | 4 | same |
| `.../fnc_modern_vehfittingstation.sqf` | 3 | same |
| `.../fnc_modern_simple_zone.sqf` | 3 | inline `createVehicle` at `:53,77,101`; becomes three rows |
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
both fences already use. `_mode` is `"world"` (prefab weapon rows: `_origin`'s Z plus the row's
offset, written with `setPosWorld`) or `"atl"` (FOB and missions: ground level, `setPosATL`). Both
are behaviour that exists today, lifted rather than redesigned; there is no third mode, and adding
one is how this function starts growing flags for each caller's quirks.

Inside: resolve, `createVehicle`, position written either side of `setDir` (which displaces the
object — the reason both existing placers write it twice), `fnc_duws_keep` under `_key`, and the
placement freeze. The gunner step stays with each prefab, since what it crews is the list the
caller collected.

**`fnc_BluHQinit.sqf` cannot use it and calls the resolver directly.** Its fence is not placed at
build time at all — it is resolved into `HQ_redeploy_weaponData` for `fnc_placeHQUnits.sqf`, which
runs again on every redeploy against whatever is standing there now. A placer that creates an object
is the wrong tool for a site whose product is data.

**Mission statics become fenced rows.** The three mission files write each gun as a hand-numbered
`_vehicle_9 = createVehicle [...]` block with its own `setDir` and `setPosATL`. They become rows in
a `--DUWS-COMPOSITION--` fence and go through the placer like everything else, which is what puts
those five guns inside the Eden round trip the prefabs already have.

**`destroy_cache` guards an enemy objective with the player's own gun.** `:134,141` spawn
`blufor_TURRET_HMG` on a mission whose whole subject is an OPFOR cache, so a mod-equipped BLUFOR
faction currently defends the enemy's supplies. It resolves as OPFOR with the rest of them.

**`fnc_garrisonMortar.sqf:23-24` stays hardcoded.** Its tube is two backpacks on two men
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
(`fn_factionAutoDetect.sqf:608-609`), which reads one `threat` array and returns whichever of
soft/armor/air is largest (`:291-300`) — so a gun equally threatening to infantry and air resolves
to whichever `selectMax` hits first. A misbucketed static is a gun that never fires at aircraft
rather than an error. The `fnc_selectNonEmpty` chains keep a key from being empty; nothing keeps it
from being wrong. Worth checking against two or three mod factions once the keys are readable.

## Task list

1. `fnc_faction_schema.sqf`: `required` column, plus the five new static rows.
2. `fnc_custom_faction_parse.sqf`: filter `_requiredKeys` on `required`.
3. Fill the keys in `AUTODETECT_opfor.sqf`, `AUTODETECT_RANDOM_opfor.sqf` and
   `AUTODETECT_blufor.sqf` — own bucket or `""`, vanilla tail on the HMG keys only — and widen
   `_turretAA`'s chain with the air-threat members of `_turretCannon`. Warn at faction init when a
   side's HMG key comes back empty, since rule 2 rests on it.
4. `shared/functions/fnc_static_roles.sqf`: the fenced `DUWS_staticRoles` table, `fnc_static_resolve`
   and `fnc_static_place`, registered in `server_fnc_init.sqf`.
5. Convert the call sites: seven prefab weapon passes, the FOB fence, the three mission files
   (blocks to fenced rows), and `fnc_BluHQinit.sqf` to resolve-only.
6. Update [`info/faction_system.md`](info/faction_system.md) (the static-weapon row of the schema
   table) and [`info/composition_tooling.md`](info/composition_tooling.md) (a static row's class is
   a role token at runtime, so a placeholder swapped in Eden changes what the faction fields).

Steps 1-3 are inert on their own: the keys resolve and nothing reads them, so they can land and be
verified against a faction readout before any composition changes. Step 4 is inert without step 5.

Step 5 is where the risk sits, because it is a placement rewrite rather than an inserted line. Land
it one caller at a time against a zone built from the same seed before and after: same count, same
positions, same headings, same guns crewed. A prefab whose statics move or lose their gunners has
had its Z mode or its row shape mistranslated, and it is the only class of fault this step can
introduce.
