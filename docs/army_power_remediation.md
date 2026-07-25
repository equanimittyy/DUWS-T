# Army Power: server-authority remediation

Army Power (AP) is the war-momentum score the WARCOM director reads to decide attack and
patrol waves. It lives in two globals, `WARCOM_blufor_ap` and `WARCOM_opfor_ap`, earned and
lost through zone capture, side missions, and civilian actions; the one player-facing spend
is the AP→CP converter (`fnc_convertAPtoCP.sqf`). AP is a sibling of the command-point
economy — see [`cp_economy.md`](cp_economy.md) for how the two meet.

Command points were made server-authoritative to close a co-op concurrency bug; AP still
carries the same latent bug. This doc is the plan to give AP the same treatment. It is not
yet implemented.

## The hazard

Both AP pools are written as `x = x ± n; publicVariable "x"` from whichever machine runs the
code. `publicVariable` broadcasts an absolute value and there is no network lock, so two
machines that each read, adjust, and re-broadcast a pool drop one another's change — the
same read-modify-write trap CP was moved off of, detailed in the gotchas entry *"A shared
global mutated as `x = x - c; publicVariable` loses concurrent writes"*
([`arma_engine_gotchas.md`](arma_engine_gotchas.md)). In co-op this silently loses or
duplicates AP, and a save persists the corrupted value.

## Remediation

One server-only writer, applied as a signed delta. Because AP has two pools and capture
logic moves both at once, parameterise by side:

```sqf
fnc_ap_adjust = {
    if (!isServer) exitWith {};
    params ["_side", ["_delta", 0]];
    switch (_side) do {
        case "OPF": { WARCOM_opfor_ap  = WARCOM_opfor_ap  + _delta; publicVariable "WARCOM_opfor_ap"; };
        case "BLU": { WARCOM_blufor_ap = WARCOM_blufor_ap + _delta; publicVariable "WARCOM_blufor_ap"; };
    };
};
```

A `switch` with no default rather than `if (_side == "OPF") ... else ...`: an unrecognised
side string must be a no-op, not a silent credit to the wrong pool. No clamp on the result —
`fnc_opfor_cap` legitimately drives BLU AP down, so the function takes any signed delta just
as `fnc_cp_adjust` does.

Define it beside `fnc_cp_adjust` in `duws/init/server_fnc_init.sqf` (server-only, so an
accidental client call fails loud). Callers send `["BLU", _delta] remoteExec
["fnc_ap_adjust", 2]` and never touch the globals directly.

Thirteen live read-modify-write statements convert, across seven files — cited by file and
which write, since these files are under active edit and line numbers drift:

| Site | Write | Pool |
|---|---|---|
| `dialog/fnc_convertAPtoCP.sqf` | −15 on convert | BLU |
| `misc/fnc_corpse_search_action.sqf` | +1 search bonus | BLU |
| `init_zones/fnc_captured.sqf` | first-capture reward | OPF, BLU |
| `init_zones/fnc_blufor_cap.sqf` | recapture reward | OPF, BLU |
| `init_zones/fnc_opfor_cap.sqf` | zone lost | OPF, BLU |
| `misc/fnc_civ_handler.sqf`, `fnc_civ_handler_wbk.sqf` | scorched-earth penalty | BLU, OPF |
| `missions/fnc_mission_reward.sqf` | mission reward | BLU |

Only `fnc_convertAPtoCP` and `fnc_corpse_search_action` run on a client, so those two are the
live hole — `WARCOM_opfor_ap` has no client writer at all. The remaining sites convert for
uniformity, which is the point: *nothing but `fnc_ap_adjust` writes these globals* is a rule a
reviewer can grep for, where *these two sites are special* is not. It also covers an
uncertainty in the locality claim — the zone-capture bodies fire from a trigger that
`fnc_createzone.sqf` builds with `createTrigger`, whose `makeGlobal` argument defaults to
true, so their server-only execution is inferred from the surrounding idioms
(`remoteExec [..., [0,-2] select isDedicated]`, and CP already routed to the server) rather
than proven.

Leave the absolute init/setup assignments alone (single-machine, pre-play):
`init/server_var_init.sqf`, `warcom/fnc_WARCOM_init.sqf`, and the campaign-menu presets in
`dialog/fnc_process_campaign_menu.sqf`.

Out of scope, and deliberately so: the converter gates on `WARCOM_blufor_ap < 15` read from
the client's own copy, so two players can both clear the check against a pool that funds only
one conversion. A delta writer fixes lost updates, not double-spends. CP carries the identical
client-side affordability check, so closing this properly means changing both currencies
together.

## The convert dialog needs a local display update

AP needs no `publicVariableEventHandler`. CP leaned on the `commandpointsblu1` handler to
repaint its HUD counter (control 1000), but AP has no live counter — it is a WARCOM-internal
score shown only inside the convert dialog and campaign menu (control 1002). One consequence
is easy to miss. `fnc_convertAPtoCP.sqf` repaints 1002 from `WARCOM_blufor_ap` on the line
after mutating it; once that write becomes a `remoteExec` to the server, the local copy still
holds the old value at that instant, and with no AP event handler nothing repaints when the
broadcast lands — a remote client would keep showing the pre-spend figure. Set 1002 from the
expected post-spend value instead: it is display-only, and the broadcast reconciles it. The
FOB and HQ request menus read AP when their dialog opens, so they need no change.

## Verification

`bash tests/run.sh`. The python lint walks every touched file for bracket/string balance and
path resolution, and the unit layer must stay green. Do not reach for `sqfvm --parse-only` as
a syntax check: the pinned 1.3.2 build false-positives on the `#` selector the mission uses,
which is why the suite carries a python balancer instead — see
[`testing.md`](testing.md#sqf-vm).

`fnc_ap_adjust` itself is not unit-testable. It touches `isServer` and `publicVariable`, and
the VM harness runs only pure helpers, so the concurrency behaviour needs a co-op playthrough
to confirm — as `fnc_cp_adjust` did. No AP write lives in the WARCOM `.fsm` files; only
`fnc_WARCOM_init.sqf` sets the starting absolutes.
