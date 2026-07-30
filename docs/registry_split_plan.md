# Splitting `server_fnc_init.sqf`

The file reads as a manifest — 288 lines of `fnc_x = compile preprocessFile "..."` — and is also
where **50 function bodies live inline**, among them the most load-bearing code the mission has.
Nobody looks for logic in a table of contents, which is the whole problem: every command-point
mutation in the campaign routes through `fnc_cp_adjust`, and it sits at line 12 of a file whose
apparent job is listing paths.

The registry self-check at the end is good engineering and stays wherever the registry ends up.

## Why it keeps growing

The bodies are there because they had no natural file when they were written, and the registry is
the one place guaranteed to run before anything calls them. That reasoning is still true for a
*new* helper, which is why the file has taken five more inline bodies and fifteen more registry
entries during recent work — each author correctly matched the surrounding style. The file does not
grow by neglect; it grows because it is the path of least resistance, and it will keep doing so
until the bodies are somewhere else.

## The subsystems already present

The 50 bodies fall into groups that name themselves. Nothing here is a judgement call about what
belongs together — the prefixes have been doing that work already.

| Target file | Bodies | Names |
|---|---|---|
| `server/misc/fnc_economy.sqf` | 9 | `cp_adjust`, `ap_adjust`, `escalation_cost`, `coins_count`, `coins_spend`, `pool_try_spend`, `pool_spend`, `pool_reply`, `town_rep_adjust` |
| `server/misc/fnc_civ_state.sqf` | 9 | `civ_townAt`, `civ_playerNear`, `civ_repAt`, `civ_reaction_weights`, `civ_rowPrice`, `civ_townBand`, `civ_townIncome`, `civ_townRender`, `civ_moveToPlayerServer` |
| `server/misc/fnc_composition_stream.sqf` | 7 | `duws_keep`, `duws_stow`, `duws_deploy`, `duws_release`, `duws_disposeAfter`, `duws_forceCleanup`, `duws_toggleNearestZone` |
| `server/supports/fnc_support_claim.sqf` | 4 | `support_try_claim`, `support_claim`, `support_release`, `support_reply` |
| `server/misc/fnc_mapclick.sqf` | 3 | `mapclick_background`, `mapclick_claim`, `mapclick_release` |
| `server/supports/fnc_pylon.sqf` | 3 | `pylon_set_with_cost`, `pylon_hint_nocp`, `pylon_hint_success` |
| `server/misc/fnc_wbk_server.sqf` | 2 | `wbk_survivorKilled_server`, `wbk_unitKilled_server` |
| `server/init_zones/fnc_zone_state.sqf` | 2 | `zone_control_set`, `warcom_set_primary_zone` |
| Existing files, one each | 11 | `mission_begin` beside `fnc_mission_site`; `fob_deregister`, `duws_bluforNear`, `cs`, `duws_dialogue_channel`, `civ_resume`, `recruitSuccessServer`, `intel_search_restore`, `sitrep_fanout`, `apocalypse_buildings`, `removeArsenalAction` to their subsystems |

## Two things that make this safe to do mechanically

**`check_paths.py` is a real guard here.** Every moved body becomes a new `preprocessFile` path, and
a path that does not resolve compiles to an empty `{}` that no-ops silently at every call site. The
linter resolves all of them, and the boot-time registry self-check catches anything it misses by
logging `compiled EMPTY`.

**The function count is a checksum.** The self-check logs `N fnc_* defined`. Note it before and
after; the number must not move.

## What can go wrong that neither catches

**Definition order.** An inline body can reference another function defined above it in the same
file. Once both are `preprocessFile`d, order still holds — the registry runs top to bottom — but a
body moved to a file that is registered *earlier* than something it calls at compile time would
break. In practice these are all called at runtime rather than at compile time, so the risk is low;
confirm by grepping each moved body for `call fnc_` at its top level rather than inside a block.

**Broadcast.** Several bodies are followed by `publicVariable "fnc_x"`. That line must move with the
registration, not with the body. A client-called function that loses its broadcast fails only on
clients, and only at the moment it is called.

## Sequence

One commit per target file keeps each move revertible and keeps the self-check meaningful between
steps.

- [ ] Note the boot log's `N fnc_* defined` figure first; it is the checksum for every step below.
- [ ] `fnc_economy.sqf` — nine bodies, and the one to do first because it is the most load-bearing
      and the easiest to exercise. Verify: buy something, take a zone, watch CP and AP both move.
- [ ] `fnc_composition_stream.sqf` — seven bodies. Verify: stow a zone and deploy it back.
- [ ] `fnc_civ_state.sqf` — nine bodies. Verify: a town renders its band colour and pays income.
- [ ] The remaining five groups, one commit each.
- [ ] The eleven singletons into their existing subsystem files.
- [ ] Confirm the registry is a pure manifest, and the self-check reports the same count it did at
      the start.
