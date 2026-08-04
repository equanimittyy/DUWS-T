# Static emplacement abstraction: implementation plan

Every static weapon the mission places is a hardcoded vanilla classname. Zone prefabs stand
NATO and AAF guns on CSAT ground; a mod faction's own emplacements are never fielded even when
detection has already found them. This plan gives statics the same abstraction infantry and
vehicles have had since the beginning: a **role key** the faction fills, read at the moment
something is placed.

Four roles, chosen because each is a distinct tactical answer rather than a distinct model:

| Role | What it answers | Vanilla representative (what Eden draws) |
|---|---|---|
| Heavy MG | infantry on foot | `B_HMG_01_high_F` and the `HMG_0*` family |
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

**`blufor_TURRET_GMG` is deliberately not in the set.** It exists, it is read by the FOB fence
(`server/init_hq/fnc_fortifyFOB.sqf:94-95`), and it has no OPFOR counterpart. A grenade launcher
is close enough to the HMG in role that adding it would be a sixth key covering the same
tactical answer; it stays as a BLUFOR-only key that the resolver below passes through untouched.

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
`server_fnc_init.sqf` beside `fnc_faction_pools.sqf:357` — the same idiom, one file defining the
table and the function that reads it.

```sqf
[_class, _side] call fnc_static_resolve   // _side is "opfor" or "blufor"
```

Four rules, each covering a way this fails silently otherwise:

1. **A class the map does not carry comes back unchanged.** That is every `Land_*` prop, every
   ammo box, and any static an author added that nobody has mapped. Passing the row through is
   what keeps a prefab working when the map is incomplete.
2. **A resolved key that reads empty comes back as the row's own class.** `fnc_faction_pick`
   returns `""` for a role nothing defined (`shared/functions/fnc_faction_pools.sqf:46-54`), which
   is the state all 254 hand-authored faction files will be in for the new keys, forever. The
   placeholder is the fallback, so those files need no sweep.
3. **The replacement must be `isKindOf "StaticWeapon"` or it is refused.** Three systems key off
   that type test — the zone manning hook (`init_zones/fnc_zone_stream_init.sqf:212`), its
   crew-out counterpart (`:256`), and the empty-vehicle cleanup's exemption
   (`misc/fnc_repetitive_cleanup.sqf:122`). A mod "static" that is configured as a car would be
   placed, never crewed, never crewed out, and swept as an abandoned vehicle. Fail closed: keep
   the placeholder.
4. **Drawn through `fnc_faction_pick`, not read off the global.** Detection finds several statics
   per role and keeps them in `DUWS_factionPool_<role>`; picking per object is what makes two MG
   nests in one zone different guns, exactly as it already does for infantry and vehicles.

Locality is server. Ordering is already safe without a new gate: faction init completes at
`server_init.sqf:63-79` and every prefab runs behind the `createzone_server` wait at `:91`.

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
| `I_GMG_01_high_F` | 1 | not mapped — there is no OPFOR GMG key, so it stands as itself |

No AT gun appears in any composition today. That role exists for the hardpoint tier and for mod
factions that field one; it has no migration.

### The explicit role column still wins

The HQ and FOB fences name their key in the row (`init_hq/fnc_BluHQinit.sqf:203`,
`init_hq/fnc_fortifyFOB.sqf:94-97`) and that must keep taking priority over the map. A Titan on
the HQ roof is a decision about that position, not a lookup. `_fnc_place` at
`fnc_fortifyFOB.sqf:103-110` changes only in its empty-role branch: instead of standing as its own
class, an unroled row falls through to the resolver, so a gun added to the fence in Eden follows
the faction without anyone remembering to hand-add a sixth column.

## Detection needs nothing new

`fnc_parseFaction` already buckets all four roles and returns them. The OPFOR generator uses none
of them — it hardcodes the HMG at `AUTODETECT_opfor.sqf:121` — and the BLUFOR one uses all but the
mortar. So the detection half of this is reading values that have been computed and discarded
since the generator was written.

| Role | Bucket | Where |
|---|---|---|
| HMG | `_turretHMG` | `shared/factions/MODERN/fn_factionAutoDetect.sqf:581` |
| Mortar | `_turretMortar` | `:583` |
| AA | `_turretAA` | `:584` |
| AT | `_turretAT` | `:585` |

The return array is positional and destructured by a `params` string in each of the three wrappers
(`AUTODETECT_opfor.sqf:35` and the same line in the other two). Nothing is added to it, so those
strings do not change.

One line is worth changing while here. `_turretCannon` (`:586`) is parsed and then dropped from
the return at `:613-617`; a towed AA gun that a mod types as a cannon rather than as
`StaticAAWeapon` falls into it and disappears. Extending `_turretAA`'s existing
`fnc_selectNonEmpty` chain with the air-threat members of `_turretCannon` recovers those factions
without touching the return array's shape.

## What each faction path has to fill

| Path | Change |
|---|---|
| `fnc_faction_schema.sqf` | three new OPFOR rows, one new BLUFOR, all `STATIC`/`static` |
| `AUTODETECT_opfor.sqf:121` | one hardcoded HMG line becomes four `fnc_selectNonEmpty` chains |
| `AUTODETECT_RANDOM_opfor.sqf:90` | the same four |
| `AUTODETECT_blufor.sqf:124-127` | one line added for the mortar; `_AA`'s chain widened |
| 254 files in `factions/MODERN/` | **none** — resolver rule 2 covers them |
| Custom paste | see below; it does not work without a schema change |

`o_arraysToRandomize` / `b_arraysToRandomize` need no edit: both derive from the schema
(`AUTODETECT_opfor.sqf:164`, `AUTODETECT_RANDOM_opfor.sqf:110`, `AUTODETECT_blufor.sqf:262`), so
a schema row reaches `fnc_faction_pools_publish` for free.

The OPFOR fallbacks are the CSAT statics rather than the NATO ones the prefabs draw with —
`O_HMG_01_high_F`, `O_static_AT_F`, `O_static_AA_F`, `O_Mortar_01_F`. The fallback is what a
mod-free campaign fields, so it should be the enemy's own gun; the placeholder in the row only
decides what Eden draws.

### Adding a required key breaks every existing custom faction

`fnc_custom_faction_parse.sqf:28` derives its required-key set straight from the schema and
reports any key that is missing or resolves to a non-existent class. Add the four static rows and
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
gains a column, and the section becomes 5 BLUFOR / 4 OPFOR, so it pads by one row instead of by
three. Sequence this after that screen lands, or fold it in — either works, but the two must not be
written against each other's old shape.

## Call sites

| File | Rows | Change |
|---|---|---|
| `init_zones/prefabs/modern/fnc_modern_Outpost2.sqf` | 9 | resolve in the weapon pass |
| `.../fnc_modern_outpost1.sqf` | 7 | same |
| `.../fnc_modern_reconOutpost.sqf` | 7 | same (`:148-163`) |
| `.../fnc_modern_CommStation.sqf` | 6 | same |
| `.../fnc_modern_FieldHospital.sqf` | 5 | same |
| `.../fnc_modern_StorageBunker.sqf` | 4 | same |
| `.../fnc_modern_vehfittingstation.sqf` | 3 | same |
| `.../fnc_modern_simple_zone.sqf` | 3 | inline `createVehicle` at `:53,77,101`, not rows |
| `init_hq/fnc_fortifyFOB.sqf` | 5 | empty-role branch of `_fnc_place` only |
| `init_hq/fnc_BluHQinit.sqf` | 2 | `:302-311`, where the fence's roles resolve into `HQ_redeploy_weaponData` — `fnc_placeHQUnits.sqf` places an already-resolved class and needs no change |
| `missions/.../fnc_holdposition_mission.sqf` | 1 | `:124`, a NATO mortar on an enemy hold position |
| `missions/.../fnc_destroy_radar_mission.sqf` | 2 | `:68,76`, NATO AA guarding an enemy radar |

The seven prefab weapon passes are separate inlined copies of one loop. Each takes a single line —
the resolver call between the row's `params` and its `createVehicle`. Consolidating those seven
copies into one shared placer is worth doing and is **not** this change: the hardpoint plan needs
a rotating placer anyway, and merging the two rewrites is how one of them ends up untested.

**`fnc_garrisonMortar.sqf:23-24` stays hardcoded.** Its tube is two backpacks on two men
(`O_Mortar_01_support_F` / `_weapon_F`), not a static, and there is no faction key for a mortar
backpack — inventing one to cover a single call site is a fifth key for one consumer. It is
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
(`fn_factionAutoDetect.sqf:584-585`), which reads one `threat` array and returns whichever of
soft/armor/air is largest (`:291-299`) — so a gun equally threatening to infantry and air resolves
to whichever `selectMax` hits first. A misbucketed static is a gun that never fires at aircraft
rather than an error. The `fnc_selectNonEmpty` chains keep a key from being empty; nothing keeps it
from being wrong. Worth checking against two or three mod factions once the keys are readable.

## Task list

1. `fnc_faction_schema.sqf`: `required` column, plus the four new static rows.
2. `fnc_custom_faction_parse.sqf`: filter `_requiredKeys` on `required`.
3. Fill the keys in `AUTODETECT_opfor.sqf`, `AUTODETECT_RANDOM_opfor.sqf`, `AUTODETECT_blufor.sqf`,
   and widen `_turretAA`'s chain with the air-threat members of `_turretCannon`.
4. `shared/functions/fnc_static_roles.sqf`: the fenced `DUWS_staticRoles` table and
   `fnc_static_resolve`, registered in `server_fnc_init.sqf`.
5. Insert the resolver at the twelve call sites above.
6. Update [`info/faction_system.md`](info/faction_system.md) (the static-weapon row of the schema
   table) and [`info/composition_tooling.md`](info/composition_tooling.md) (a static row's class is
   a role token at runtime, so a placeholder swapped in Eden changes what the faction fields).

Steps 1-3 are inert on their own: the keys resolve and nothing reads them, so they can land and be
verified against a faction readout before any composition changes. Step 4 is inert without step 5.
