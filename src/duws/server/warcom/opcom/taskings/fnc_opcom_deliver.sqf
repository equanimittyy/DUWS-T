// Locality: server, [] call'd at load. The caller spends the truck whatever a writer answers: a refused errand is lost.
if (!isServer) exitWith {};

// [key, type, zoneKey] per build still siting, so the zone Build action cannot overfill a zone's slots.
DUWS_opcom_buildsPending = [];

// _refund goes back to the wallet when no ground holds the build; spendable only, so it never moves the ladder.
DUWS_fnc_opcom_build = {
    params ["_type", ["_zoneKey", ""], ["_pos", []], ["_refund", 0]];
    if (([_type] call fnc_hardpoint_comp) isEqualTo [] && {_type isNotEqualTo "MINEFIELD"}) exitWith {
        ["WARN", "OPCOM", format ["build: no composition for hardpoint type %1", _type]] call fnc_log; false
    };
    private _anchor = [_pos];
    if (_zoneKey isNotEqualTo "") then {
        private _site = [_zoneKey] call fnc_site_at;
        _anchor = [_site getOrDefault ["pos", []], _site getOrDefault ["radius", 0]];
    };
    if ((_anchor select 0) isEqualTo []) exitWith {
        ["WARN", "OPCOM", format ["build: %1 has no ground to site on (zone %2)", _type, _zoneKey]] call fnc_log; false
    };
    private _seq = missionNamespace getVariable ["DUWS_hpOpcomSeq", 0];
    missionNamespace setVariable ["DUWS_hpOpcomSeq", _seq + 1];
    private _key = format ["hpopcom_%1", _seq];
    DUWS_opcom_buildsPending pushBack [_key, _type, _zoneKey];
    // Spawned: the builder sleeps in its crew drop, and the tick must never sleep.
    [_type, _key, _zoneKey, _anchor, _refund] spawn {
        params ["_type", "_key", "_zoneKey", "_anchor", "_refund"];
        private _at = _anchor select 0;
        private _res = if (_zoneKey isEqualTo "") then {
            // No terrain bearing: face where BLUFOR comes from, as a frontline nest does.
            private _radial = if (PosOfBLUHQ isEqualTo []) then { random 360 } else { _at getDir PosOfBLUHQ };
            [_type, _at, _key, "", _radial] call fnc_hardpoint_spawn_at
        } else {
            [_type, fnc_hardpoint_zone_cand, _key, _zoneKey, _anchor] call fnc_hardpoint_spawn_sited
        };
        DUWS_opcom_buildsPending deleteAt (DUWS_opcom_buildsPending findIf { (_x select 0) isEqualTo _key });
        [["INFO", "WARN"] select (_res isEqualTo []), "OPCOM", format ["build: %1 %2 as %3 (zone %4 near %5)",
            _type, ["sited", "found no ground"] select (_res isEqualTo []), _key, _zoneKey, _at apply { round _x }]] call fnc_log;
        private _refunded = _res isEqualTo [] && {_refund > 0};
        if (_refunded) then { ["OPF", _refund, "opcom_build_refund"] call fnc_ap_adjust };
        [format ["Build %1 at %2 %3%4", DUWS_hardpointName getOrDefault [_type, _type],
            [[_zoneKey] call DUWS_fnc_opcom_zoneLabel, mapGridPosition _at] select (_zoneKey isEqualTo ""),
            ["sited", "found no ground"] select (_res isEqualTo []), ["", format ["  %1 AP back", _refund]] select _refunded]] call DUWS_fnc_opcom_aiEvent;
    };
    true
};

DUWS_fnc_opcom_deliver = {
    params ["_t"];
    (_t get "errand") params [["_kind", ""], "_arg", ["_type", ""]];
    ["INFO", "OPCOM", format ["deliver: tasking %1 lands %2 at %3", _t get "id", _t get "errand", _t get "target"]] call fnc_log;
    switch (_kind) do {
        case "reinforce": { [_arg, "opcom_reinforce"] call fnc_town_garrison_reinforce };
        case "fortify": { [_arg, "opcom_fortify"] call fnc_town_garrison_fortify };
        case "rapport": { [_arg, -3, "opcom_rapport"] call fnc_town_rep_adjust };
        case "build": { [_type, "", _arg] call DUWS_fnc_opcom_build };
    };
};
