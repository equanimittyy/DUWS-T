# Garbage Cleanup button

A "Garbage Cleanup" button in the request menu's COMMAND AND CONTROL column runs the map cleanup at
once, at the HQ and at every FOB. Only the Game Master sees it, and confirms before it runs. Paths are
relative to `src/`.

The button calls the same server function as the debug menu's "Force garbage clean":
`fnc_duws_forceCleanup` sets `DUWS_cleanup_force`, and the next pass of
`server/misc/fnc_repetitive_cleanup.sqf` starts within 0.5 s and treats every deadline as elapsed. The
keep radius (300 m from a player), the persistent flag, the in-use check and the base-parked rule still
apply. There is no global timer to reset: each object keeps its own deadline, and an object that the
sweep spares keeps the deadline it had.

Build this after [`gc_rebalance_plan.md`](gc_rebalance_plan.md), which edits two of the same comments.

## Phase 1: the button

In `client/dialog/fnc_command_fill.sqf`, add one row directly before the redeploy `if` (`:48`), so it
sits above the redeploy at the HQ and at a FOB:

```sqf
[localize "STR_DUWS_T_GARBAGE_CLEANUP_ACTION", { … }, [], false, COST_COLOUR]
```

The row code:

1. Opens `BIS_fnc_guiMessage` with the confirm text, the button label as the title, and OK and Cancel.
2. On Cancel, exits.
3. On OK, runs `[] remoteExec ["fnc_duws_forceCleanup", 2]` and shows the started hint.

The modal wait is safe. The column's buttons spawn `fnc_command_select`
(`shared/includes/request_menu.hpp`), and `client/dialog/fnc_depot_recycle_confirm.sqf` shows the same
prompt over an open dialog. `closes` is false, so the menu stays up, as it does for the redeploy.

The column has seven slots. The HQ uses 6 for a squad leader and a FOB uses 5, so the `.hpp` does not
change.

**Orange.** The header comment (`:15-17`) defines orange as "costs money". The button costs nothing,
but it deletes shared world state for every player and cannot be undone. The comment defines orange as
"spends, or acts on the whole map and cannot be undone".
`docs/info/gameplay/player_text_style_guide.md:270-277` lists the column's buttons in order; add the
cleanup before the redeploy.

**Access.** Game Master only. The row is added only when `(vehiclevarname player) in game_master`, the
same test that gates rest and the debug menu. Other players do not see the row: the column leaves out an
entry that cannot apply, as it does the squad manager for a player who is not a squad leader. The
button costs nothing and has no cooldown.

The server does not check the caller again. Rest (`client/dialog/fnc_rest_menu.sqf:9`) is also gated on
the client only, and the worst a client that reaches `fnc_duws_forceCleanup` can do is delete distant
litter early.

## Phase 2: strings

Three keys in the "Base Services" container, beside `STR_DUWS_T_REDEPLOY_ACTION`
(`stringtable.xml:2077`). English only.

| Key | English |
|---|---|
| `STR_DUWS_T_GARBAGE_CLEANUP_ACTION` | Garbage Cleanup |
| `STR_DUWS_T_GARBAGE_CLEANUP_CONFIRM` | Are you sure you want to run garbage cleanup now? |
| `STR_DUWS_T_GARBAGE_CLEANUP_STARTED` | Garbage cleanup running. Anything within 300 m of a player stays. |

The hint names the keep radius because the player presses the button at a base, so the litter around
that base survives.

## Phase 3: server function

- `server/misc/fnc_composition_stream_init.sqf:185-190`: the comment calls `fnc_duws_forceCleanup` the
  debug-menu entry point. It becomes the entry point for the request-menu button and the debug menu.
  The reason a client call is safe still holds: the worst a client can do is delete distant litter
  early.
- The log line at `:193`, "Forced sweep requested from the debug menu.", becomes "Forced sweep
  requested."
- `server/server_var_init.sqf:193-196`: remove "A testing tool" from the `DUWS_cleanup_force` comment.
- No `publicVariable`: the client only sends it to the server by `remoteExec`, and the server defines
  it. `CfgRemoteExec` runs in mode 2 (`shared/includes/remoteExec.hpp`).

The debug menu's "Force garbage clean" (`client/debug/fnc_debug_menu.sqf:118`) stays, because it works
anywhere, not only at a base.

## Verification

- Run `tests/run.sh` and the sqf-vm parse check on `fnc_command_fill.sqf` and
  `fnc_composition_stream_init.sqf`.
- Each key that `fnc_command_fill.sqf` uses is in `stringtable.xml`.
- In play, the button asks first. On OK, the RPT shows
  `[CLEANUP] forced sweep: N deleted, M held inside 300 m`.
