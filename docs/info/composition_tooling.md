# The composition TUI

`scripts/duws_eden.ps1`, launched by double-clicking `duws_eden.cmd` at the repo root or by:

```text
powershell -ExecutionPolicy Bypass -File scripts\duws_eden.ps1
```

The mission has two kinds of composition and both used to be hand-edited in source. The tool covers
both over one idea: a **marker fence** in the source that the tool parses and Arma's preprocessor
discards, so marking something up is data-only and costs no runtime.

The top menu is the two kinds, with the unit half split by what a row *is* — a composition, a token,
or a scaling rule.

| Kind | Marker | What the tool does |
|---|---|---|
| **Static** — object layouts (HQ, zone prefabs, killhouse) | `--DUWS-COMPOSITION--` | emits a paste-ready Eden import; writes a new fence from rows pasted back |
| **Unit** — spawn tables (tier compositions, team rosters, the purchasable squads, the scaling rules) | `--DUWS-UNITCOMP--` | edits rows and writes them back to source; adds rows and whole tables |

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

**A static weapon's class is a role token at runtime, not the gun that gets placed.**
`fnc_static_resolve` (`shared/functions/fnc_static_roles.sqf`) reads the class off the row, looks it
up in `DUWS_staticRoles`, and stands whatever the placing side's faction fields for that role — so
swapping a Mk6 mortar for an HMG in Eden changes the role every faction fills there, not just the
silhouette in the 3D view. Rearranging and rotating are free; retyping a class is a design change.
The class still decides what the import draws, which is the point of keeping a vanilla one in the
row: the layout is arranged against the right silhouettes whether or not a mod is loaded. A class
the table does not carry is placed as itself, so an unmapped gun is quietly no longer faction-aware.

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

### Creating one

**New composition** on the static menu takes the same export rows and writes the fence itself: name,
variable, target file, then the pasted rows. The file may be one that already exists or one the tool
creates.

Two things it refuses rather than corrects, both because the failure is silent otherwise:

- **A target the scan above cannot reach**, which would be a fence invisible to the tool that wrote
  it — indistinguishable from the write having done nothing.
- **A name another composition already holds.** The menu selects by name, so a duplicate is an entry
  nobody can open on purpose.

The variable decides who can read the array: a leading underscore makes it a file-scope local, which
only an `#include` can reach — what the killhouse does — and anything else is a global a placer in
another file can read. The suggestion is a global.

**The export writes five columns and no more.** A consumer wanting an `isWeapon` flag or a faction
role reads those off positions the export never emitted, so those columns are added by hand
afterwards and survive later round trips by the match-by-order rule above.

## Unit compositions: edited in place

Two ideas, and keeping them apart is what makes the menus make sense:

- A **composition** is a list of tokens, sometimes with a price. A zone tier, a town tier, a
  purchasable squad. Contract for what the tier tables mean:
  [`zones_and_civilians.md`](zones_and_civilians.md#zone-tiers). A garrison composition writes each
  entry as `posture:token` — one A3 group, its orders and its roster. Typed as one string rather
  than a pair because the row editor below splits on commas and would cut a nested list in half.
- A **token** is what one name raises, and there are three tables of them under the Tokens menu: a
  team of men (`sniper` is two snipers until you say otherwise), one vehicle, or a placer that
  garrisons ground by a rule rather than from a roster.

Compositions name tokens; a token is edited in one place and referred to from many. **The unit of
work is a row, not the table it lives in** — which file a composition sits in is not something the
person editing it should have to know — so the menu lists every zone tier, town tier and squad
together and opening one shows its configuration. A field naming a token shows what that token
raises beside it, so a reference is never a dead end.

Scaling rules — the radius multipliers — get their own menu. They are how a composition is scaled
rather than what is in one, and a radius band is only meaningful beside the bands above and below
it, so those are still edited as whole tables.

The category vocabulary is deliberately not in the tool. Its rows are positionally locked to the
multiplier table's columns, and every token names a category from its own row in one of three other
tables, so neither a rename nor an addition is an edit one row editor can complete.

```sqf
// --DUWS-UNITCOMP BEGIN name="Zone tiers" kind=composition rowname="Tier %1" row="tier I..IV"--
DUWS_zoneSpawnTiers = [
    ["patrol", "team", "car"],
    ...
];
// --DUWS-UNITCOMP END--
```

| Attr | Meaning |
|---|---|
| `name="..."` | label in the menu, and the key a write matches on |
| `kind=` | `composition`, `team` (the Tokens menu) or `rule` — which menu its rows appear under. Anything unlabelled falls to `rule`, so a table nobody classified is still reachable |
| `row="..."` | what one row means, since a row is a tier in one table and a radius band in another |
| `rowname="Tier %1"` | how a row is named in the menu, `%1` being its index in roman. Without it the first column names the row, which is what a team and a squad already do |
| `fields="a, b, c"` | the row's columns, for a table whose rows are fixed-shape rather than a free-length list. Its presence is what switches the editor into field mode |
| `prefix=opfor_` | the faction prefix this table's role names carry: stripped for display, re-applied on write |

A row without `fields=` is a plain list — add an entry, drop one, or retype the row. Entries are
typed unquoted (`patrol, team, car`) and the tool quotes anything that is not a bare number, so a
multiplier row stays numeric and a token row stays strings.

### Field mode

A row of a `fields=` table is a thing with named parts — a team, a purchasable squad — so it is
picked apart by column instead of by entry index. Pick a row, pick a field, and the current value is
**already in the line** for editing rather than retyped from scratch; Escape backs out.

Each field keeps the kind it already had, inferred from the value rather than declared: a list stays
a list, a quoted name stays quoted, and a number or boolean field refuses anything else instead of
writing a table that will not compile. Booleans matter more than they look: a placer's parameter
list carries them, and SQF's `params` substitutes its own default for an argument of the wrong type,
so a quoted `"false"` reads at runtime as a parameter that quietly stopped taking effect.

Two vocabularies are checked before a row is changed, and both catch a write that compiles and then
says nothing at runtime:

- **Role names**, against the slots the faction files under `shared/factions/` actually define. The
  count is the point rather than a yes/no: every faction file fills the same slots, so a name none
  of them defines would spawn nothing, and one only some of them define is a roster that quietly
  thins on the rest — which is the failure the faction auto-detection exists to prevent.
- **Names beginning `fnc_`**, against the globals `server_fnc_init.sqf` compiles. A placer is named
  by global, and the spawn path falls back to `{grpNull}` for a name nothing defines, so a typo is a
  row that raises nothing.

A row holding a nested list belongs in a `fields=` table. The flat editor splits typed input on
commas, which would cut a nested list in half.

### Adding a token

The Tokens menu can append a row. A **team** or a **vehicle** added there is spawnable as it stands —
nothing in the mission has to learn the new name:

- A team row is a roster and nothing else. What the group *does* is the posture a composition names
  beside it, applied by `fnc_apply_posture`, so the same five men are a patrol on one row and a
  building garrison on the next. Before this the orders were a column here, and fielding those men
  under different orders took a second row with an identical roster.
- The spawn path asks the tables what a token is rather than switching on known names, so a token
  no table claims is a classname a faction file named directly and stands as itself.
- `category` is which radius multiplier scales it, held on the row so adding a token is one edit
  rather than two tables that can disagree. It is column 1 in all three token tables, which is what
  lets one lookup ask whichever table claims the token.

A **special** is the exception to spawnable-as-it-stands: its `placer` column names code, so the
function has to exist before the row does. The tool prompts on a name nothing compiles rather than
letting the row through to raise nothing.

The values already in a column are offered while typing, so the categories on offer are the ones the
tables actually use rather than a list in a doc that rots. A duplicate name is refused: the
first column is what compositions refer to, so a second row of the same name could never be reached.

Adding a **BLUFOR** team is the same, minus the category column — a squad references it by name and
`fnc_BLUFOR_squad_init` resolves it.

**Add** is on every menu, not only Tokens: a zone tier, a town tier and a purchasable squad are rows
like any other. A row of a table that declares no `fields=` is typed as one comma-separated list;
one of a fixed-column table is walked field by field, each blanked from the row above so it keeps
its kind. The one row that buys nothing on its own is a *squad*: the request dialog switches on a
hardcoded listbox index (`client/dialog/fnc_request_squad.sqf:16`), so a sixth squad needs a case
written there before anything can purchase what the table now offers.

### Adding a table

**New table** writes an empty fenced table and prompts for the attributes above, because every one of
them fails quietly when it is wrong: an unknown `kind=` files the rows under the scaling rules, a
missing `row=` leaves them described as "row", and a `fields=` that does not match what the rows hold
switches the editor into field mode against columns that are not there.

Two are refused outright rather than left to be edited later, because neither is recoverable from
inside the tool: a **name** another fence already carries, since a write matches a fence by name and
would rewrite both bodies; and a **variable** already assigned somewhere under `src/`, since whichever
file the mission compiles last wins and the table being edited need not be the one that is live.

A new table arrives empty, and the first row typed into it goes through the flat prompt whatever its
`fields=` says — the field walk reads each column's kind off the row above, and a table created a
moment ago has no row to read.

**A new row is live; a new table is not.** The spawn path asks the tables what a token is rather than
switching on known names, so a team or vehicle added to an existing table spawns without any code
changing. A new table is inert until something reads its global.

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
`<var> = [ <row>, … ];` and splits rows by bracket depth, so a row holding a nested array — a team's
role lists — survives intact. Set `kind=` so its rows land in the right menu, add `fields=` when
every row has the same columns, and `prefix=` when its names are faction slots.
