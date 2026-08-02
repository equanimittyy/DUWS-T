# The composition TUI

`scripts/duws_eden.ps1`, launched by double-clicking `duws_eden.cmd` at the repo root or by:

```text
powershell -ExecutionPolicy Bypass -File scripts\duws_eden.ps1
```

The mission has two kinds of composition and both used to be hand-edited in source. The tool covers
both from one menu, over one idea: a **marker fence** in the source that the tool parses and Arma's
preprocessor discards, so marking something up is data-only and costs no runtime.

| Kind | Marker | What the tool does |
|---|---|---|
| **Static** — object layouts (HQ, zone prefabs, killhouse) | `--DUWS-COMPOSITION--` | read-only; emits a paste-ready Eden import |
| **Unit** — spawn tables (tier compositions, radius multipliers, the category map, group rosters, the purchasable squads) | `--DUWS-UNITCOMP--` | edits rows and writes them back to source |

Static compositions round-trip through the 3D editor because they are *layout* — you want to see
them. Unit compositions are *data*, so there is nothing to look at in Eden and the tool edits them
directly.

## Static compositions: the Eden round-trip

The load-bearing trap: `create3DENEntity` **only runs in Eden's own debug console** — the `{ }`
console in the 3D editor toolbar, not the in-game debug console. Run it in-game and it silently
no-ops.

Objects take their heading from the yaw slot of the `rotation` attribute (`[pitch, roll, yaw]`,
degrees) — a bare number sets pitch, not heading. Pick a flat `_origin`; it only decides where the
composition lands.

**Import** — select a composition and the tool normalizes the rows, writes `temp\eden_import.sqf` and
copies the import to the clipboard. Paste that into the Eden console. It reports `created N of M
objects` and warns if any row-like line failed to parse, so a silent drop is visible. There is also a
"paste your own array" option.

The origin is one coordinate for the whole run, shown at the top of the menu and changed with `O`
(default `23100 18700`; it accepts `X Y` or a pasted `[x,y,z]`, whose Z is ignored). It is session
state rather than a per-import prompt because the export subtracts the same origin back out — answer
it differently on a second import and the rows come back offset by the difference.

### The front marker

The import also raises a `FlagPole_F` named **`DUWS_FRONT`**, standing clear of the composition
along **+Y**.

A composition's rows are offsets in a frame whose +Y is the way the whole thing faces once placed,
and nothing in the 3D view shows where that frame points — so a rearrange is done blind, and the
layout can come back rotated with the mistake only surfacing in play. The pole is that frame's
bearing, made visible.

Its distance is measured from the composition rather than fixed: the furthest row's offset plus 15 m,
so a 300-object base and a five-prop outpost each get a marker that reads as *outside* rather than as
one more prop.

**It is not part of the composition, and the export below drops it by name.** So `Ctrl+A` is safe —
select everything and the pole still will not reach the array. The filter matches `DUWS_FRONT`
rather than `FlagPole_F` because a composition may legitimately hold a flagpole and the killhouse
already carries a flag; the name is the marker's identity, its class is not.

That makes the marker safe to leave in place while rearranging, which is the point — it has to stay
visible for as long as you are working, and a marker you must remember to delete is one that ends up
in a source array putting a flagpole in every zone that builds that prefab.

Two constraints the scan imposes on where a composition may live, both of which fail by finding
nothing rather than by erroring:

- **It enumerates `*.sqf` only.** A composition moved into an `.hpp` becomes invisible to the tool,
  so a data file split out of a builder has to keep the `.sqf` extension even when it holds nothing
  but an array. `server/misc/killhouse_composition.sqf` is named that way for this reason.
- **`zbase=` is resolved by regex against the file holding the fence.** The constant it names has to
  be declared in that same file. Split the array away from its `_centerSpawnZ` and the attribute
  matches nothing, the origin silently falls back to zero, and the import lands on the terrain
  instead of at altitude — a round trip that looks like it worked.

### Marking a static composition

```sqf
// --DUWS-COMPOSITION BEGIN name="My Thing" schema=A--
private _allObjectsData = [ ... ];
// --DUWS-COMPOSITION END--
```

| Attr | Meaning |
|---|---|
| `name="..."` | label shown in the TUI |
| `schema=A` | the row format; the only one there is |
| `anchor=hqInComp` | HQ only: its array stores original composition coords, so the tool subtracts `_hqInCompX/Y`. Omit elsewhere (offsets are already relative to `[0,0]`) |
| `z=snap\|keep` | optional; default `snap` |
| `zbase=<var>` | reads that source constant as the origin's Z, so the composition keeps its native altitude instead of ground. Killhouse uses `zbase=_centerSpawnZ` |

Every row is `[class, X, Y, Z, dir°]`, degrees, position flat at indices 1-3. A row may carry extra
trailing fields for its own consumer — the HQ and zone prefabs append `isWeapon` — and the tool
ignores anything past index 4.

`snap` drops objects onto the terrain (ground layouts); `keep` preserves each object's Z. The
killhouse is a multi-floor structure that would collapse if snapped, so it declares `z=keep`
alongside `zbase=_centerSpawnZ` to sit at its original off-map altitude (~1000).

**Export** — after rearranging in Eden, run this in the same console to copy schema-agnostic
`[class, dx, dy, dz, dir°]` rows (offsets from the import origin):

```sqf
// Set _origin to the SAME origin you imported at (the TUI menu shows it; the default is below).
private _origin = [23100, 18700, 0];

// Dropped by Eden name, not by class: a composition may legitimately contain a flagpole, and the
// killhouse already carries a flag. The name is the marker's identity; its class is not.
private _objs = (get3DENSelected "Object") select {
    ((_x get3DENAttribute "name") param [0, ""]) != "DUWS_FRONT"
};
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
round-trips. `Copied N objects` should match what the import reported; a mismatch means rows were
added or lost in Eden, since the marker is already excluded.

Fold the rows back into the source array by these rules:

- **Match by order.** The export returns rows in creation order, so line them up 1:1 with the
  existing array by index, confirm the class matches at each row, and change only the rows whose X/Y
  or dir actually moved.
- **X/Y and direction** drop straight in. For the **HQ**, add `_hqInComp` (10.0413, 11.3066) to X/Y —
  its array stores original composition coordinates, not offsets.
- **Ignore the exported Z for ground layouts.** It is the terrain baseline of wherever you dropped
  the composition in Eden, not a real coordinate, and the runtime ignores the Z column anyway. Only
  the **killhouse** uses Z, as a floor offset: export it with `_origin`'s Z set to its
  `_centerSpawnZ` (1000) so the values come back raw.
- **Keep the trailing fields.** Carry each row's `isWeapon` flag over; a rearrange never changes it
  and the export does not emit it.

Verify once by import → export → re-import and confirming the layout is identical.

## Unit compositions: edited in place

The spawn tables — what a zone or town garrison of each tier fields, how a zone's radius multiplies
each category, which tokens belong to which category, what men a group kind is made of, and what the
player can buy. Contract for what the tier tables mean:
[`zones_and_civilians.md`](zones_and_civilians.md#zone-tiers).

```sqf
// --DUWS-UNITCOMP BEGIN name="Zone tiers" row="tier I..IV"--
DUWS_zoneSpawnTiers = [
    ["patrol", "team", "car"],
    ...
];
// --DUWS-UNITCOMP END--
```

| Attr | Meaning |
|---|---|
| `name="..."` | label in the menu, and the key a write matches on |
| `row="..."` | what one row means, since a row is a tier in one table and a radius band in another |
| `fields="a, b, c"` | the row's columns, for a table whose rows are fixed-shape rather than a free-length list. Its presence is what switches the editor into field mode |
| `prefix=opfor_` | the faction prefix this table's role names carry: stripped for display, re-applied on write |

Select one with `U<n>`. A table without `fields=` is a list per row — add an entry, drop one, or
replace the row. Entries are typed unquoted (`patrol, team, car`) and the tool quotes anything that
is not a bare number, so a multiplier row stays numeric and a token row stays strings.

### Field mode

A row of a `fields=` table is a thing with named parts — a group kind, a purchasable squad — so it is
picked apart by column instead of by entry index. Pick a row, pick a field, and the current value is
**already in the line** for editing rather than retyped from scratch; Escape backs out.

Each field keeps the kind it already had, inferred from the value rather than declared: a list stays
a list, a quoted name stays quoted, and a number field refuses text instead of writing a table that
will not compile.

Role names are checked against the slots the faction files under `shared/factions/` actually define,
and the count is the point rather than a yes/no: every faction file fills the same slots, so a name
none of them defines would spawn nothing, and one only some of them define is a roster that quietly
thins on the rest — which is the failure the faction auto-detection exists to prevent. Either
prompts before the row is changed.

A row holding a nested list belongs in a `fields=` table. The flat editor splits typed input on
commas, which would cut a nested list in half.

**Only the fenced body is rewritten.** The reasoning above each table is outside the fence and
survives editing, which is why the fences sit tight around the literal rather than around the whole
block.

Three things the writer refuses rather than guesses at:

- **A body that does not read back as the rows it came from.** The regenerated text is re-split and
  compared row for row before anything touches disk. These files are compiled by the mission, so a
  malformed table is a campaign that does not boot.
- **A file that is not valid UTF-8.** Thirty-five `.sqf` files under `src/modules` carry legacy
  single-byte encodings; reading one is harmless because the fence marker is ASCII, but writing it
  back would replace every non-ASCII byte in the file. No fence lives in one today.
- **A fence name that does not match.** Fences are rewritten by name, not by position, so every other
  table in the same file is returned untouched.

Past those, **git is the undo** — the tool writes into tracked source and you review the diff like
any other change.

### Adding a table to the tool

Wrap the literal in a fence and it appears in the menu; there is no code change. The parser expects
`<var> = [ <row>, … ];` and splits rows by bracket depth, so a row holding a nested array — a group
roster's role lists — survives intact. Add `fields=` when every row has the same columns, and
`prefix=` when its names are faction slots.
