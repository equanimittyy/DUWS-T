# OPFOR spawn helpers

`fnc_garrisonBuildings` was extracted from nine identical mission copies and deliberately left
narrow. Two neighbours were examined for folding into it and refused, on the grounds that they
differ on four axes at once. Reading them properly showed the refusal was right and the conclusion
wrong: they are not one routine with more parameters, they are **four routines built from the same
three primitives**, and it is the primitives that want extracting.

## What the four routines are

`server/init_zones/fnc_createopfortified.sqf` alone is four spawn passes, not one:

| Pass | Lines | Shape |
|---|---|---|
| Defending squad | `14-35` | A role list multiplied by `enemyunitMultiplier`, a squad leader inserted at the head, `BIS_fnc_taskDefend` |
| Mortar team | `39-46` | Two soldiers, backpacks assigned by index, `taskDefend` |
| Building garrison | `49-133` | Eight buildings, three each, stance `UP`, held by `doMove` |
| Fortification garrison | `135-203` | Tower and bunker classes within 300 m, 2–4 each, held by **teleport** |

The last two are both "put OPFOR in buildings" and still differ: one picks a random building
position and nudges units back with `doMove`, the other assigns a fixed position by index and
`setPosATL`s the unit back whenever it drifts past 3 m. A tower garrison that wanders is a tower
garrison that has left the tower, which is why it is pinned rather than herded.

`clearthearea_cqb` is the nine's routine plus bookkeeping: it keeps the per-building unit lists so
a monitor thread can announce each house as it is cleared and delete that building's marker. The
garrison is incidental; the per-building split *is* the mission.

## The primitive worth extracting first

**Building the OPFOR role list is hand-copied four times.** Three of the four carry an identical
six-role list; `intel_gathering` adds two more:

| Site | Roles |
|---|---|
| `fnc_createopfortified.sqf:59` | SOLDIER, AA, AR, AT, LAT, SL |
| `fnc_garrisonBuildings.sqf:33` | the same six |
| `clearthearea_cqb:66` | the same six |
| `intel_gathering:41` | those six plus GL, MARK |

Each copy walks the list dropping entries that are `nil` or `""`, then falls back to
`[opfor_SOLDIER_X]` if nothing survived. That guard is not decoration: a faction table that omits a
role leaves its global undefined, and an undefined name inside an array literal cannot be filtered
after the fact — which is why every copy walks rather than uses `select`.

**A fifth list has no guard at all.** `_fortPossibleUnitTypes` (`fnc_createopfortified.sqf:153-159`)
names SOLDIER, AR, GL, LAT and MARK and goes straight into `selectRandom` with no filter and no
fallback. A faction missing any one of those five feeds `nil` to `BIS_fnc_spawnGroup`. This is the
strongest argument for the helper: the guard exists four times and is missing exactly where nobody
copied it.

```sqf
// fnc_opforRoles.sqf -- returns a spawnable list, never empty
params [["_roles", []]];
private _out = [];
{ if (!isNil "_x" && {_x != ""}) then { _out pushBack _x } } forEach _roles;
if (_out isEqualTo []) then { _out = [opfor_SOLDIER_X] };
_out
```

Callers pass the literal array they already write. Five sites lose ~12 lines each and the fifth
gains the guard it never had.

## The second primitive: holding a unit in place

Two variants, and the difference is intentional rather than drift:

| Variant | Used by | Mechanism |
|---|---|---|
| Herd | the nine, `clearthearea_cqb`, `fnc_createopfortified`'s building pass | `doMove` to a random building position, re-issued when the unit drifts past 15 m |
| Pin | `fnc_createopfortified`'s fortification pass | `setPosATL` back to one fixed position when it drifts past 3 m |

One `fnc_holdBuildingPost [_unit, _building, _positions, _mode]` covers both, and the mode is a
genuine behavioural choice a caller makes rather than a flag invented to make a fold work.

## Sequence

Each step is independently useful, and none of them requires the next.

- [ ] `fnc_opforRoles`. Convert the four guarded copies and the unguarded `_fortPossibleUnitTypes`.
      Verify: garrisons still spawn a mix under a stock faction, and a faction table with a role
      commented out spawns riflemen rather than erroring.
- [ ] `fnc_holdBuildingPost`, both modes. Convert the four sites. Verify: mission garrisons still
      wander and return; tower garrisons stay in their towers.
- [ ] Only then reconsider `fnc_garrisonBuildings`. With the two primitives out, what remains of
      each caller is a handful of lines choosing counts, stance and hold mode — at which point a
      shared spawner may be worth it, or may be small enough not to be. Decide on the code that
      exists then, not on this paragraph.

The third step is deliberately conditional. The reason the original fold was rejected is that it
would have added four parameters serving one caller; extracting the primitives first is what makes
that question answerable rather than a guess.

## What stays out

`clearthearea_cqb`'s per-building unit lists are not a spawner concern. Whatever it uses to build
its garrison, the mission still needs the units grouped per building to run its clear-the-house
announcements, and no other caller wants that. It consumes the primitives; it does not fold.
