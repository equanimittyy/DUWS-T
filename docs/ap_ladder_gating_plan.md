# BLUFOR AP-ladder capability gating — implementation plan

Today only the OPFOR side climbs the Army Power earned-tier ladder: zone and town
garrison vehicles resolve through `DUWS_fnc_tokenClass`, which returns `""` for a
token whose rung is unmet (`src/duws/server/init_zones/fnc_zone_spawn_sizes.sqf:129`).
BLUFOR's auto-spawned air and all three player purchase menus (squads, supports,
vehicles) ignore the ladder entirely. This plan gates BLUFOR on the same ladder,
symmetrically, and verifies the BLUFOR garrison path. Persistence is out of scope —
see [`campaign_persistence_plan.md`](campaign_persistence_plan.md). The ladder itself
(rungs, tiers, faucets) is designed in [`economy_second_pass.md`](economy_second_pass.md).

The symmetry rule holds throughout: both sides share `DUWS_ap_tier_rungs` and gate on
raw `WARCOM_<side>_ap_earned`. The tier integer is a display summary, never a gate.

## Decisions

- BLUFOR gains its own vehicle token table and a side-aware `DUWS_fnc_tokenClass`,
  rather than an in-place per-file air fix — both sides field vehicles through one
  framework.
- Gating is a **hard lock on the earned counter**, not a spend: an item below tier is
  unavailable until the rung is earned. It does not consume AP.
- A locked menu row stays visible, greyed, tagged `(Tier N)`. Rows sort unlocked
  alphabetical first, locked alphabetical below.
- A purchasable vehicle's tier comes from a config classifier (`isKindOf`), not
  per-faction data: the vehicle shop pulls arbitrary classnames from
  `blufor_RQST_VEHICLES` across ~40 faction files, and a classifier covers modded and
  auto-detected factions a data column cannot.
- The infantry unit shop (`fnc_request_unit`) stays ungated — infantry is tier 1.

## Tier mapping

Squads (`fnc_request_squad.sqf`, both the High Command and task-force variants):

| Tier | Squad |
|------|-------|
| 1 | Recon, Infantry |
| 2 | Motorised |
| 3 | Mechanised |
| 4 | Armour |

Auto-spawned BLUFOR air (`fnc_random_veh_blu_patrol.sqf`): transport heli T3, attack
heli T4, jet T5 — mirrors the OPFOR vehicle rungs.

Vehicle classifier (`isKindOf`):

| Tier | Kind |
|------|------|
| 1 | utility truck (transport / ammo / repair / fuel); any car with 2 seats or fewer (e.g. quad bike); and any class the classifier cannot place |
| 2 | Car with more than 2 seats |
| 3 | APC, IFV, transport helicopter |
| 4 | Tank, attack helicopter |
| 5 | Plane |

Supports (`fnc_supports_init.sqf`), keyed by support key. The AP wallet cost already
carried by advanced rows (`_def[8]`) is unchanged; the tier lock sits on top of it.

| Tier | Support keys |
|------|--------------|
| 1 | armory, repair, recycle, mobile_HQ, fob, mhq_slot, radio1, radio2, radio3, supply, veh_drop, boattaxi, uav, helotaxi |
| 3 | mortar, jdam, laser, siva, sawp, paradrop, helolift |
| 4 | arty, cluster, napalm, hcAttChop |
| 5 | hcCAS, halo |

## Shared helper

`DUWS_fnc_ap_unlocked {_side, _tier}` returns whether that side has earned the rung for
`_tier`: tier 1 is always true, higher tiers test
`WARCOM_<side>_ap_earned >= (DUWS_ap_tier_rungs select (_tier - 2))`. One rung source
feeds the menus, the classifier gate, and the air split.

## Slice 1 — BLUFOR token framework and air split

Add `DUWS_spawnVehiclesBlu`, a mirror of the OPFOR `DUWS_spawnVehicles` table
(`fnc_zone_spawn_sizes.sqf:209-222`) using `blufor_*_X` role globals at the same rungs.
`DUWS_fnc_tokenClass` and `DUWS_fnc_vehicleRow` take a side parameter defaulting to
`"OPF"`, so every existing OPFOR caller is unchanged; the side selects table and earned
variable. Route `fnc_random_veh_blu_patrol` through `tokenClass "BLU"`: the air pick
becomes a weighted random over the {transheli, attackheli, plane} tokens that resolve
non-`""` at the current BLUFOR earned count, and the patrol air trigger drops to the
transport-heli rung so it appears at tier 3.

## Slice 2 — BLUFOR garrison verification

Search for any BLUFOR garrison raise (`DUWS_fnc_raiseGarrison` / `fnc_zone_spawn` on the
WEST side). If none exists, this slice is a no-op and reports that. If one exists, it is
routed through the side-aware `tokenClass "BLU"` built in slice 1.

## Slice 3 — Vehicle shop gating

Add `DUWS_fnc_vehTier` (the `isKindOf` classifier). The `fnc_request_vehicle` menu build
computes a tier per row from `fnc_faction_rqst_list`, partitions and sorts the rows,
greys and tags the locked ones, and stashes the tier in `lbData`. The buy handler
refuses a locked selection with a hint. Enforcement is client-side: the vehicle spawns
with a client-local `createVehicle`, the same trust surface the existing CP check
already sits on.

## Slice 4 — Support menu gating

Each support gains a tier (a keyed map beside `fnc_support_defs`). The menu build
partitions, sorts, greys and tags exactly as the vehicle shop does. `fnc_support_buy`
refuses a below-tier purchase. The wallet-AP cost path is untouched.

## Slice 5 — Squad menu rebuild

The squad listbox (idc 2101, `request_menu.hpp:237`) is populated dynamically rather
than as fixed rows: each `lbAdd` carries the squad key in `lbData` and is sorted, greyed
and tagged like the other menus. `fnc_request_squad` reads `lbData` instead of the fixed
index switch. The server spawn functions (`fnc_HCsquad_spawn`, `fnc_playerTF_spawn`) gain
a tier guard, so the squad gate is authoritative rather than client-only.

## Strings and localisation

New strings: a `(Tier %1)` row suffix and a tier-locked hint. English and Original only;
the other languages lag by the project's standing localisation debt and are retranslated
later.

## Verification

There is no in-repo compiler or linter. Each slice is checked by brace-balance and
threshold greps, then play-tested. Nothing here is compile-verified.
