# Editing the HQ layout

The player's Main Base is built once, server-side, by `src/duws/server/init_hq/fnc_BluHQinit.sqf`
(compiled at `src/duws/server/server_fnc_init.sqf:31`, spawned at `src/duws/server/server_init.sqf:108`).
It anchors on `PosOfBLUHQ`, the base spot chosen during placement (`fnc_HQ_random_place.sqf:43` or
`fnc_HQ_manual_place.sqf:65`).

All **static props** (the HQ building, walls, towers, tents, crates, lights, furniture) come from one data
array. Everything else — weapons and the garrison — is code-driven and is *not* editable through that
array.

## The composition array is the layout

`_allObjectsData` (`fnc_BluHQinit.sqf:34-175`) is an Eden-exported object list. Each row:

```text
[classname, X, Y, Z, direction, isWeapon]
     0      1  2  3      4          5
```

A loop (`fnc_BluHQinit.sqf:211-248`) walks it: `createVehicle`, then `setPosATL [X, Y, 0]`, then `setDir`.
Two traps in that row format:

- **The Z column (index 3) is ignored.** Every object snaps to terrain via `setPosATL` with z=0 (`:218`).
  You cannot float a prop by editing the array; elevated objects (tower MGs and the like) are placed
  separately, see below.
- **Direction is index 4, not 3.** Z sits between position and direction, so an off-by-one lands the angle
  in the ignored column.

## The anchor math

The `_compCenterX/Y` constants (`fnc_BluHQinit.sqf:7-8`, the `1041.x / 6115.x` values) look load-bearing
but **cancel out algebraically**. The placement reduces to:

```text
object world pos = PosOfBLUHQ + (row X/Y  -  HQ-building row X/Y)
```

So the `Land_Cargo_HQ_V1_F` row (`:36`) lands exactly on `PosOfBLUHQ` and every other object is positioned
relative to it. The array numbers are a local grid where the HQ building sits at ~(10, 11).

One invariant holds this together: **`_hqInCompX/_hqInCompY` (`:5-6`) must equal the `Land_Cargo_HQ_V1_F`
row's X/Y.** They are the reference the offsets subtract from; if they drift apart, the whole base
mis-anchors. Keep them in lockstep when replacing the array.

## Rearranging: two paths

**Small nudges** (shift a tent, rotate a wall): edit the row numbers directly. Change indices 1/2 to move,
index 4 to rotate. Nothing else to touch.

**A real re-layout**: build it visually in the Eden editor and round-trip through the array with the
tooling below, rather than hand-typing coordinates.

## Eden round-trip

The HQ array is one of the marked static compositions, so a re-layout goes through the composition TUI
rather than through hand-typed coordinates: [`composition_tooling.md`](composition_tooling.md#static-compositions-the-eden-round-trip).

Two things in that workflow are HQ-specific:

- The HQ fence carries `anchor=hqInComp`, because its array stores original composition coordinates
  rather than offsets from `[0,0]`. The tool subtracts `_hqInCompX/Y` on import; on the way back in, **add**
  `_hqInComp` (10.0413, 11.3066) to the exported X/Y.
- `_hqInCompX/_hqInCompY` must stay equal to the `Land_Cargo_HQ_V1_F` row's X/Y, per the invariant above.

## What the array does not govern

Weapons (HMG, AA gun) and the whole garrison — tower guards, med-tent medics, the officer with the laptop,
the patrol — are placed by code (`fnc_BluHQinit.sqf:254-632`) at `modelToWorld` offsets *off the spawned
structures*, not from array rows. Consequences:

- Rows flagged `isWeapon` carry coordinates but are skipped by the placement loop (`:213`); moving them in
  Eden and re-exporting changes nothing in-game.
- To move a weapon or unit, move its **anchor structure** (the sandbag, HQ building, or a tower) in the
  array — dependents follow — or edit its inline block.
- The redeploy/rebuild path reads `HQ_redeploy_*` mission-namespace variables set in this same file (e.g.
  `:630-632`) and consumed by `src/duws/server/misc/fnc_redeployHQUnits.sqf`, so editing here keeps rebuild
  consistent.

Player-deployed FOBs are a separate system (`src/duws/server/init_hq/fnc_fortifyFOB.sqf`, inline offset
calls, no shared array) and share nothing with the Main Base layout.
