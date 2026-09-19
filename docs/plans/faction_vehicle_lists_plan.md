# Faction vehicle lists

On the faction confirmation screen, each vehicle role becomes a list that the player edits. The list opens with
the classes that detection found. The player can drop a detected class, add a class from any faction, and choose
the main class. Infantry and static roles keep the single pick that SELECT gives today, because
`fnc_faction_poolable_keys` (`shared/faction_lib/fnc_faction_pools.sqf:107`) holds them to one class.

A role's edits are stored as intent, not as a finished list. A later detection (a new session, or a restore
after a mod update) then rebuilds the detected part, and the edits apply on top of it. The campaign save stores
these edits ([`campaign_persistence_plan.md`](campaign_persistence_plan.md#identity-and-settings)).

## The edit model

A vehicle role's edits are one record: `[main, added, dropped]`.

| Field | Holds |
|---|---|
| `main` | The class the player made main, or `""` for the class that resolution chose |
| `added` | Classes the player added that are not in the detected part |
| `dropped` | Detected classes the player removed |

**Main is the parent.** Detection expands a role from its main class only:
`fnc_faction_pool_for_class` (`shared/factions/MODERN/fn_factionAutoDetect.sqf:558`) returns the class plus the
tightest bucket that holds it in its own faction. The pre-screen augment pass, the key editor and the commit all
use it. The base of a role is therefore:

- `main` is `""`: the role's pool as resolution left it. For every faction except CUSTOM, this is the pool that
  augment built from the representative. For CUSTOM, it is the pasted list, because augment skips CUSTOM.
- `main` is set: `fnc_faction_pool_for_class` of `main`, for every faction.

**The resolved list** is the main class first, then the base minus `dropped`, then `added`, with duplicates
removed. `fnc_faction_pools_publish` takes the first entry as the representative, so the single-class readers
(taxi, paradrop, intro, readouts) get the main class.

| Operation | Effect on the record |
|---|---|
| Add a class | If the class is in `dropped`, remove it from `dropped`. Otherwise, if it is not in the list, append it to `added` |
| Remove a class | If the class is in `added`, remove it from `added`. Otherwise append it to `dropped`. The main class cannot be removed |
| Make main | Set `main` to the class and remove it from `added`. If the previous `main` was player-set, append it to `added` |
| Reset | Set the record to `["", [], []]` |

Make main re-parents the role. If the new main is in a different bucket or faction, the detected part becomes
that class's bucket. Drops still apply by name, and adds stay. A player-set main that is replaced stays in the
list, because the player chose it. The detected main that is replaced leaves with the rest of its bucket.

The main class cannot be removed because a removal would re-parent the role to the next entry without a word.
To replace the main class, the player makes another class main first.

## Functions

One new file, `shared/faction_lib/fnc_faction_lists.sqf`, defines four functions. `server_fnc_init.sqf` runs it
with `[] call compile`, as it does `fnc_faction_pools.sqf`. The editor calls the first three on the client, so
each of them is `publicVariable`'d in the same place (`tests/lint/check_broadcast.py` checks this).

| Function | Locality | Does |
|---|---|---|
| `fnc_faction_list_edit` | any, pure | `[record, operation, class]` to a new record, per the operation table |
| `fnc_faction_list_resolve` | any, pure | `[base, record]` to the resolved list |
| `fnc_faction_list_base` | any | `[key, record, currentPool, parsed]` to the base: `currentPool` when `main` is `""`, else `fnc_faction_pool_for_class` of `main` with a cached parse |
| `fnc_faction_edits_apply` | server | `[rows]`, each row `[key, main, added, dropped]`: resolves each key, gates the list through `fnc_faction_keep` with kind `vehicle`, writes the key and publishes its pool with `fnc_faction_pools_publish`, and stores the rows in `DUWS_factionListEdits` |

`fnc_faction_keep` (`fnc_faction_pools.sqf:28`) is the gate that every pool source passes through. Today the
locked table bypasses it. When the gate empties a list, `fnc_faction_edits_apply` keeps the pool that
resolution built for the key and logs a WARN.

`DUWS_factionListEdits` is an array of `[key, main, added, dropped]` rows, strings and arrays only, so that it
serialises. It holds only the keys that the player edited.

The two pure functions load into the unit harness (`tests/unit/functions.txt`).

## The editor

`fnc_faction_key_edit` opens a new dialog, `startup_faction_key_list`, for a key of kind `vehicle`. It opens the
existing `startup_faction_key_edit` for other kinds, so infantry and static rows do not change.

`startup_faction_key_list` (`shared/includes/faction_confirm.hpp`) inherits `startup_faction_key_edit`. It widens
the background and the frame, and adds these controls:

| Control | IDC | Place |
|---|---|---|
| List box: the resolved list, with the main class marked | 8633 | a right-hand column |
| Add | 8634 | under the class combo; adds the class that the browser shows |
| Remove | 8635 | under the list box |
| Make main | 8636 | under the list box |
| Reset | 8637 | under the list box |

The class browser offers only `scope` 2 classes (`fnc_faction_key_edit.sqf:51,53` offer 1 and 2 today). This is
the gate that `fnc_faction_keep` applies, so a player cannot pick a class that the commit then drops. The
change applies to the single-pick dialog too.

**Working state.** The confirmation screen keeps a record per edited key in `duws_faction_edits`, a
`uiNamespace` HashMap that `fnc_faction_confirm` resets on each visit, as it does the parse cache. The editor
works on a copy of the key's record. CONFIRM writes the copy to `duws_faction_edits` and writes the resolved
list to the row in `duws_faction_table`. CANCEL discards the copy.

**Base on the client.** When `main` is `""`, the base is the key's entry in `DUWS_factionPreviewPools`, which is
the pool that the server built before the screen. When `main` is set, the base comes from
`fnc_faction_pool_for_class` with the per-screen parse cache. Make main can start a faction parse, so it runs
spawned and shows the existing working line, as `fnc_faction_key_apply` does now.

**The confirmation rows.** A vehicle row's button reads EDIT, and other rows keep SELECT
(`client/dialog/fnc_faction_confirm_rows.sqf:90`). The `(+N)` count from `fnc_faction_row_paint` does not
change. CLEAR on a vehicle row also deletes the key's record (`client/dialog/fnc_faction_prompts.sqf`), or the
commit would resolve the record and fill the cleared role again.

New stringtable keys, English only: `STR_DUWS_T_faction_edit_list`, `STR_DUWS_T_faction_edit_add`,
`STR_DUWS_T_faction_edit_remove`, `STR_DUWS_T_faction_edit_main`, `STR_DUWS_T_faction_edit_reset`,
`STR_DUWS_T_faction_confirm_edit`. `STR_DUWS_T_faction_edit_pool` is rewritten for the list dialog.

## The commit

1. `fnc_faction_confirm` (`client/dialog/fnc_faction_confirm.sqf:107`) publishes the locked table with a third
   element on each vehicle row: the key's record, or `[]` when the player did not edit it.
2. `fnc_faction_apply_locked` reads each row as `[key, value, record]`. On a client, it writes the value as
   today. On the server, it does not write the value of a row that carries a record. It collects those rows
   and calls `fnc_faction_edits_apply` with them after it publishes the other pools. The server resolves from
   the record rather than trusting the client's list, so the commit and the restore share one path.
3. The commit's augment pass (`server/server_init.sqf:165`) runs only when `duws_faction_locked` is empty. A
   locked table already holds the full pool of every row, because the screen builds its rows from
   `DUWS_factionPreviewPools`. Another augment pass would rebuild each pool from its representative, which
   restores dropped classes and removes added ones. The debug quickstart
   (`client/debug/fnc_debug_quickstart.sqf`) publishes no table, so it still gets the augment pass.

## Persistence

The snapshot stores `DUWS_factionListEdits` as an input. On restore, the server calls `fnc_faction_edits_apply`
with the saved rows after faction init and augment have built the pools. A new detection supplies the base, so
a vehicle that a mod update added still joins its role.

A saved row can name a class that this session lacks:

| Missing | Result |
|---|---|
| `main` | The base falls back to the pool that resolution built, as if `main` were `""` |
| A class in `added` | `fnc_faction_keep` removes it |
| A class in `dropped` | Nothing: there is nothing to remove |
| Every class in the resolved list | The key keeps the pool that resolution built, and a WARN names the key |

## Docs and headers updated with the code

| File | Change |
|---|---|
| `docs/info/gameplay/faction_system.md` | The confirmation-screen paragraph that says an edited key is a pool rebuilt from the picked class: replace it with the list editor and the edit record |
| `shared/faction_lib/fnc_faction_augment.sqf` header | It runs at the commit only when there is no locked table |
| `client/dialog/fnc_faction_key_apply.sqf` header | It serves the single-pick dialog only |
| `docs/info/architecture/campaign_save_format.md` | With the persistence work: the save stores the list edits as well as the faction identity |

## Verification

| Check | How | Pass |
|---|---|---|
| Edit operations | sqf-vm unit tests on `fnc_faction_list_edit` and `fnc_faction_list_resolve`: drop, add, re-add of a dropped class, a remove of an added class, Make main with a player-set previous main, Reset, a duplicate add | Each record and list is exact |
| A drop survives the commit | Drop a class from `opfor_ATTACK_HELI_X`, confirm, then read `DUWS_factionPool_opfor_ATTACK_HELI_X` in the debug console | The class is absent |
| An add survives the commit | Add a class from another faction, confirm, read the pool | The class is present |
| Untouched rows do not change | Confirm with no edits, compare each vehicle pool with its `DUWS_factionPreviewPools` entry | Equal |
| Quickstart | Debug quickstart, read the pools | The same as before this change |
| Clear | Edit a row, clear it, confirm | The key is empty |

## Chunks

| Chunk | Builds | Settles in play |
|---|---|---|
| **1** Resolver and commit | `fnc_faction_lists.sqf` and its unit tests, the record element in `fnc_faction_apply_locked`, the augment gate in `server_init.sqf`. The screen sends no records yet, so the output does not change | An untouched confirm and the quickstart give the same pools as before |
| **2** Editor | `startup_faction_key_list` and its handlers, the scope-2 browser, the EDIT label, CLEAR deleting the record, the stringtable keys | Drops, adds and Make main survive the commit. Whether the faction parse behind Make main holds the dialog too long on a heavy mod set |
| **3** Persistence | Done inside the campaign persistence work: `DUWS_factionListEdits` in the snapshot, `fnc_faction_edits_apply` in the restore | A restore applies the edits over a new detection. A class that a removed mod supplied is skipped, per the table in [Persistence](#persistence) |
