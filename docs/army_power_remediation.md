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
    if (_side == "OPF") then {
        WARCOM_opfor_ap = WARCOM_opfor_ap + _delta; publicVariable "WARCOM_opfor_ap";
    } else {
        WARCOM_blufor_ap = WARCOM_blufor_ap + _delta; publicVariable "WARCOM_blufor_ap";
    };
};
```

Define it beside `fnc_cp_adjust` in `duws/init/server_fnc_init.sqf` (server-only, so an
accidental client call fails loud). Callers send `["BLU", _delta] remoteExec
["fnc_ap_adjust", 2]` and never touch the globals directly.

Live read-modify-write sites to convert — cited by file and which write, since these files
are under active edit and line numbers drift:

| Site | Write | Pool | Runs on |
|---|---|---|---|
| `dialog/fnc_convertAPtoCP.sqf` | −15 on convert | BLU | client |
| `misc/fnc_corpse_search_action.sqf` | +1 search bonus | BLU | client |
| `init_zones/fnc_captured.sqf` | first-capture reward | OPF, BLU | server |
| `init_zones/fnc_blufor_cap.sqf` | recapture reward | OPF, BLU | server |
| `init_zones/fnc_opfor_cap.sqf` | zone lost | OPF, BLU | server |
| `misc/fnc_civ_handler.sqf`, `fnc_civ_handler_wbk.sqf` | scorched-earth penalty | BLU, OPF | server |
| `missions/fnc_mission_reward.sqf` | mission reward | BLU | server |

Leave the absolute init/setup assignments alone (single-machine, pre-play):
`init/server_var_init.sqf`, `warcom/fnc_WARCOM_init.sqf`, and the campaign-menu presets in
`dialog/fnc_process_campaign_menu.sqf`.

## Decisions to settle first

- **Only two sites run on a client** (`fnc_convertAPtoCP`, `fnc_corpse_search_action`); the
  rest are already server-side. `WARCOM_opfor_ap` has no client writer at all, so it is
  effectively already safe — routing it too buys uniformity, not correctness. The minimum
  that closes the hole is the two client-side BLU writers.
- **AP has no live HUD counter.** CP leaned on the `commandpointsblu1`
  `publicVariableEventHandler` (control 1000); AP is a WARCOM-internal score shown only
  inside the convert dialog and campaign menu (control 1002). So `fnc_ap_adjust` needs no
  display refresh — simpler than `fnc_cp_adjust` — and adding an AP event handler is not
  warranted.
- **Edit-collision risk.** `fnc_convertAPtoCP.sqf` and `fnc_process_campaign_menu.sqf`
  overlap other in-flight work; sequence the AP change after that settles.

## Verification

Same as the CP change: `sqfvm --parse-only` on each touched file, then `tests/run.sh`. No AP
write lives in the WARCOM `.fsm` files — only `fnc_WARCOM_init.sqf` sets the starting
absolutes. Scope is ~12 live sites plus the one helper, smaller than the CP change.
