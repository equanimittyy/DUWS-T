# Refactoring: where the structure fights the maintainer

An audit of `src/duws/` for structural debt — duplication, god files, and the places where
adding one feature costs edits in five. Ordered by return on effort, not by severity.

Scope is the owned tree only. `src/modules/` is vendored and frozen
([`info/architecture.md`](info/architecture.md#vendored-frameworks--modules)); nothing here
touches it.

## What SOLID means in SQF

SQF has no classes, no interfaces, no visibility modifiers and no dependency-injection
container, so four of the five principles need restating before they mean anything here. The
translation used throughout:

| Principle | What it maps to in this codebase |
|---|---|
| Single responsibility | A file does one job. `server_fnc_init.sqf` being both a path registry and the home of 50 function bodies is the violation shape. |
| Open/closed | Adding an instance of an existing concept (a side mission, a support, a faction) edits data, not control flow. A `switch` with one case per instance is the violation shape. |
| Liskov substitution | Where N files implement the same implicit contract — same `params`, same lifecycle obligations — every one of them honours it. A copy that silently dropped a step is the violation shape. |
| Interface segregation | A function's `params` contract is narrow and honest. A file that is a function *and* defines three other globals as a side effect is the violation shape. |
| Dependency inversion | Call sites depend on a name, not a path. The registry already does this well; the exceptions are `call compile` and dynamically-named globals. |

Two engine facts constrain every fix below and are the reason some obvious-looking cleanups are
not recommended:

- **Paths are string literals with no resolver.** Moving a file breaks every reference silently
  ([`info/architecture.md`](info/architecture.md#path-references-are-string-literals)). Any
  change that moves files must be followed by `bash tests/run.sh`, whose `check_paths.py` is
  the only automated guard that exists for this.
- **Code blocks do not capture locals.** A block stored now and run later sees only globals and
  its own `_this`. Several of the global-variable findings below are that constraint being
  worked around, not carelessness — the fix has to preserve the deferral, not just delete the
  global.

## How this was measured

A normalised clone detector over `src/duws/` (block and line comments stripped, whitespace
collapsed, blank lines dropped, 8-line seed windows hashed and every line in a repeated window
counted). Two data directories are excluded, since near-identical tables are expected there and
would swamp the result: the 256-file `shared/factions/` tree, and
`server/misc/fnc_factions_check_modern.sqf`, whose BLUFOR and OPFOR roster arrays are identical
by design — its own header says so.

**3,860 of 24,676 non-data lines are duplicated — 15.6%.** `server/missions/mission_threads/`
carries 1,521 of those lines, 39% of all duplication in the tree, which is why that directory
leads the plan.

## The work itself

Each remaining piece has a plan of its own, so a fresh session can pick one up without reading the
others. Everything already done has been removed from them rather than ticked; git carries what the
code used to look like.

| Plan | Covers |
|---|---|
| [`spawn_helpers_plan.md`](spawn_helpers_plan.md) | The OPFOR role-list builder duplicated four times, the two ways a unit is held in a building, and whether `fnc_garrisonBuildings` should widen after those come out |
| [`registry_split_plan.md`](registry_split_plan.md) | The 50 function bodies living inside `server_fnc_init.sqf`, grouped into the subsystem files they name |
| [`refactor_backlog_plan.md`](refactor_backlog_plan.md) | HQ placement implemented twice, the RAVAGE/WBK shared lines, the side-mission definition table, the faction request tables, composition schemas, and three open decisions |

## A convention rather than a task

### Globals have no namespace

`src/duws/` calls `publicVariable` at 538 sites on 394 distinct names, over a global namespace
several times that size. There is no convention separating campaign state from scratch variables,
so nothing prevents a name collision between subsystems and nothing makes it visible when one
happens.

This is not fixable as a refactor, and attempting a sweeping rename would be the single
highest-risk change available in this codebase — `publicVariable` names are matched as strings by
`addPublicVariableEventHandler`, and a missed rename fails silently at runtime. What is worth
doing is bounded: **require a `DUWS_` prefix on new globals**, and prefix on touch. The mission
already has good instances of the discipline (`DUWS_enemyGear_scannedUnits`,
`DUWS_zoneSpawnTiers`) alongside bare ones like `support_count` and `Mission_available`.

## What not to do

- **Do not restructure folders.** Every path is a string literal with no resolver, and the win
  here is negligible against the risk.
- **Do not mass-rename globals or `publicVariable` keys.** Silent runtime failure, no compiler,
  and `addPublicVariableEventHandler` matches on strings.
- **Do not touch `src/modules/`.** Vendored and frozen.
- **Do not put mode branches back on the plain civilian path.** `fnc_civ_handler.sqf` is what
  runs mod-free; RAVAGE and WBK behaviour reaches it through nothing but the handler chosen at
  init.
- **Do not extract `fnc_factions_check_modern.sqf`'s roster arrays.** The clone detector flags
  194 duplicated lines there; they are the BLUFOR and OPFOR tables, which the file's own header
  requires to stay identical in shape.
- **Do not treat `bash tests/run.sh` as sufficient.** It checks bracket balance, path resolution
  and retired names. It does not execute the mission
  ([`info/testing.md`](info/testing.md#why-static-analysis-plus-only-a-thin-unit-layer)). Every
  item below needs an in-game run.
