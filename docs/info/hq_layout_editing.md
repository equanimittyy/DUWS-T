# Editing the HQ layout

The player's Main Base is built once, server-side, by
`src/duws/server/init_hq/fnc_BluHQinit.sqf` (compiled at
`src/duws/server/server_fnc_init.sqf:199`, spawned at `src/duws/server/server_init.sqf:108`).
It anchors on `PosOfBLUHQ`, the base spot chosen during placement
(`fnc_HQ_random_place.sqf:43` or `fnc_HQ_manual_place.sqf:65`).

All **static props** (the HQ building, walls, towers, tents, crates, lights, furniture)
come from one data array. Everything else — weapons and the garrison — is code-driven and
is *not* editable through that array. This doc covers how to rearrange the static layout,
including a round-trip through the Eden editor, and where the line is drawn.

## The composition array is the layout

`_allObjectsData` (`fnc_BluHQinit.sqf:34-175`) is an Eden-exported object list. Each row:

```text
[classname, X, Y, Z, direction, isWeapon]
     0      1  2  3      4          5
```

A loop (`fnc_BluHQinit.sqf:211-248`) walks it: `createVehicle`, then
`setPosATL [X, Y, 0]`, then `setDir`. Two traps in that row format:

- **The Z column (index 3) is ignored.** Every object snaps to terrain via
  `setPosATL` with z=0 (`:218`). You cannot float a prop by editing the array; elevated
  objects (tower MGs and the like) are placed separately, see below.
- **Direction is index 4, not 3.** Z sits between position and direction, so an
  off-by-one lands the angle in the ignored column.

## The anchor math

The `_compCenterX/Y` constants (`fnc_BluHQinit.sqf:7-8`, the `1041.x / 6115.x` values)
look load-bearing but **cancel out algebraically**. The placement reduces to:

```text
object world pos = PosOfBLUHQ + (row X/Y  -  HQ-building row X/Y)
```

So the `Land_Cargo_HQ_V1_F` row (`:36`) lands exactly on `PosOfBLUHQ` and every other
object is positioned relative to it. The array numbers are a local grid where the HQ
building sits at ~(10, 11).

One invariant holds this together: **`_hqInCompX/_hqInCompY` (`:5-6`) must equal the
`Land_Cargo_HQ_V1_F` row's X/Y.** They are the reference the offsets subtract from; if they
drift apart, the whole base mis-anchors. Keep them in lockstep when replacing the array.

## Rearranging: two paths

**Small nudges** (shift a tent, rotate a wall): edit the row numbers directly. Change
indices 1/2 to move, index 4 to rotate. Nothing else to touch.

**A real re-layout**: build it visually in the Eden editor and round-trip through the array
with the tooling below, rather than hand-typing coordinates.

## Eden round-trip

The load-bearing trap: `create3DENEntity` **only runs in Eden's own debug console** — the
`{ }` console in the 3D editor toolbar, not the in-game debug console. Run it in-game and it
silently no-ops.

Objects take their heading from the yaw slot of the `rotation` attribute (`[pitch, roll,
yaw]`, degrees) — a bare number sets pitch, not heading. Pick a flat `_origin`; it only
decides where the composition lands.

**Import** — run the composition TUI at the repo root (double-click `duws_eden.cmd`, or):

```text
powershell -ExecutionPolicy Bypass -File scripts\duws_eden.ps1
```

It scans `src/` for marked compositions (below), lists all of them, and on selection prompts
for an origin, normalizes the rows, writes `temp\eden_import.sqf`, and copies a paste-ready
import to the clipboard. Paste that into the Eden console. There is also a "paste your own
array" option. It reports `created N of M objects` and warns if any row-like line failed to
parse, so a silent drop is visible.

Two constraints the scan imposes on where a composition may live, both of which fail by finding
nothing rather than by erroring:

- **It enumerates `*.sqf` only.** A composition moved into an `.hpp` becomes invisible to the tool,
  so a data file split out of a builder has to keep the `.sqf` extension even when it holds nothing
  but an array. `server/misc/killhouse_composition.sqf` is named that way for this reason.
- **`zbase=` is resolved by regex against the file holding the fence.** The constant it names has to
  be declared in that same file. Split the array away from its `_centerSpawnZ` and the attribute
  matches nothing, the origin silently falls back to zero, and the import lands on the terrain
  instead of at altitude — a round trip that looks like it worked.

### Marking a composition

The TUI discovers compositions by scanning for marker comments; adding one is data-only, no
code change. Wrap the array literal in the source:

```sqf
// --DUWS-COMPOSITION BEGIN name="My Thing" schema=A--
private _allObjectsData = [ ... ];
// --DUWS-COMPOSITION END--
```

The markers are a cross-system contract the TUI parses; Arma's preprocessor strips `//`
comments, so they are inert at runtime. Attributes:

| Attr | Meaning |
|---|---|
| `name="..."` | label shown in the TUI |
| `schema=A\|B\|C` | which row format (below) — explicit, since A and B look alike |
| `anchor=hqInComp` | HQ only: its array stores original composition coords, so the tool subtracts `_hqInCompX/Y`. Omit elsewhere (offsets are already relative to `[0,0]`) |
| `z=snap\|keep` | optional override; default `keep` for schema B, `snap` otherwise |
| `zbase=<var>` | reads that source constant as the origin's Z, so the composition keeps its native altitude instead of ground. Killhouse uses `zbase=_centerSpawnZ` |

The adapters normalize all three row formats to `[class, offX, offY, offZ, dir°]`:

| Schema | Row shape | Used by |
|---|---|---|
| A | `[class, X, Y, Z, dir°, isWeapon]` | HQ + the 7 clean zone prefabs |
| B | `[class, dX, dY, dZ, yaw_rad, atl, isTarget]` — **yaw in radians** | killhouse objects/targets |
| C | `[class, [x,y,z], dir°, 1,0,[],"","",true,false]` — position nested at index 1 | `simple_zone` + 4 mission statics |

`snap` drops objects onto the terrain (ground layouts); `keep` preserves each object's Z. The
killhouse is a multi-floor structure that would collapse if snapped, so it pairs `keep` with
`zbase=_centerSpawnZ` to sit at its original off-map altitude (~1000). Fifteen compositions
are marked today.

**Export** — after rearranging, copies a schema-agnostic block of `[class, dx, dy, dz, dir°]`
rows (offsets from the import origin) to re-integrate into the composition's source array:

```sqf
// Set _origin to the SAME origin you imported at (the TUI default is shown).
private _origin = [23100, 18700, 0];

private _objs = get3DENSelected "Object";
if (_objs isEqualTo []) exitWith { systemChat "Select the composition: click an object in the 3D view, then Ctrl+A."; };

private _rows = _objs apply {
    private _p = getPosWorld _x;
    format ["[""%1"", %2, %3, %4, %5]",
        typeOf _x,
        (_p select 0) - (_origin select 0),
        (_p select 1) - (_origin select 1),
        (_p select 2) - (_origin select 2),
        getDir _x]
};
copyToClipboard (_rows joinString ("," + endl));
systemChat format ["Copied %1 objects.", count _objs];
```

`getDir` reads each heading in the convention the import wrote (`[0,0,dir]` yaw), so rotation
round-trips. Fold the rows back into the composition's array by these rules:

- **Match by order.** The export returns rows in source order (creation order), so line them up
  1:1 with the existing array by index, confirm the class matches at each row, and change only
  the rows whose X/Y (or dir) actually moved.
- **X/Y** are the source coordinates (X/Y for schema A; the nested `[x,y,z]` for C). For the
  **HQ**, add `_hqInComp` (10.0413, 11.3066) to X/Y — its array stores original composition
  coordinates, not offsets.
- **Direction** stays in degrees for A/C; for the **killhouse** (B) convert back to radians
  (`dir * pi / 180`).
- **Ignore the exported Z for ground layouts.** It is just the terrain baseline of wherever you
  dropped the composition in Eden, not a real coordinate — keep each row's original Z (the
  runtime ignores the Z column anyway). Only the **killhouse** uses Z, as the floor offset:
  export it with `_origin`'s Z set to its `_centerSpawnZ` (1000) so the values come back raw.
- **Keep the flags.** Carry each row's `isWeapon` / `isTarget` / Eden-export tail from the
  original row; a rearrange never changes them.

Verify once by import -> export -> re-import and confirming the layout is identical.

## What the array does not govern

Weapons (HMG, AA gun) and the whole garrison — tower guards, med-tent medics, the officer
with the laptop, the patrol — are placed by code (`fnc_BluHQinit.sqf:254-632`) at
`modelToWorld` offsets *off the spawned structures*, not from array rows. Consequences:

- Rows flagged `isWeapon` carry coordinates but are skipped by the placement loop (`:213`);
  moving them in Eden and re-exporting changes nothing in-game.
- To move a weapon or unit, move its **anchor structure** (the sandbag, HQ building, or a
  tower) in the array — dependents follow — or edit its inline block.
- The redeploy/rebuild path reads `HQ_redeploy_*` mission-namespace variables set in this
  same file (e.g. `:630-632`) and consumed by
  `src/duws/server/misc/fnc_redeployHQUnits.sqf`, so editing here keeps rebuild consistent.

Player-deployed FOBs are a separate system (`src/duws/server/init_hq/fnc_fortifyFOB.sqf`,
inline offset calls, no shared array) and share nothing with the Main Base layout.
