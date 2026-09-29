// Locality: server, [] call'd at load. The caller spends the truck whatever a writer answers: a refused errand is lost.
if (!isServer) exitWith {};

// [key, type, zoneKey, pos, refund] per build still siting, so a Build cannot overfill a zone's slots or an asset's cap.
DUWS_opcom_buildsPending = [];

// Key -> "AT" / "AP" per OPFOR field bar a civilian job's thinned one: the registry row carries no variant, and the
// build mix and the caps weigh them apart.
DUWS_opcom_mineVariants = createHashMap;

// Half a cell around the truck's drop, so a build stands where it was delivered; it faces where BLUFOR come from.
DUWS_fnc_opcom_buildCand = {
    private _at = _this select 0;
    private _c = [_at, OPCOM_GRID_CELL / 2, 0, 8, 0.35, []] call fnc_safe_pos;
    if (_c isEqualTo [] || {([_c] call fnc_aoi_field_at) <= 0} || {[_c] call fnc_aoi_in_any_zone}) exitWith { [] };
    [_c, [random 360, _c getDir PosOfBLUHQ] select (PosOfBLUHQ isNotEqualTo [])]
};

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
    DUWS_opcom_buildsPending pushBack [_key, _type, _zoneKey, _anchor select 0, _refund];
    // Spawned: the builder sleeps in its crew drop, and the tick must never sleep.
    [_type, _key, _zoneKey, _anchor, _refund] spawn {
        params ["_type", "_key", "_zoneKey", "_anchor", "_refund"];
        private _at = _anchor select 0;
        private _cand = [DUWS_fnc_opcom_buildCand, fnc_hardpoint_zone_cand] select (_zoneKey isNotEqualTo "");
        private _res = [_type, _cand, _key, _zoneKey, _anchor] call fnc_hardpoint_spawn_sited;
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

// A minefield is laid, not composed: one key over the whole grid, so the player clears the field as one hardpoint.
DUWS_fnc_opcom_mineBuild = {
    params ["_pos", ["_variant", "AT"], ["_size", [1, 1]], ["_refund", 0]];
    // Spawned: the lay walks every square, and the tick must never carry it.
    [_pos, _variant, _size, _refund] spawn {
        params ["_pos", "_variant", "_size", "_refund"];
        // Reads the locals around it, the way fnc_hardpoint_reveal's _fnc_paint does: a belt can fail on
        // the candidate or on every square of the grid, and both owe the same refund and the same line.
        private _fnc_noGround = {
            ["WARN", "OPCOM", format ["mine: no ground for a %1 field near %2", _variant, _pos apply { round _x }]] call fnc_log;
            if (_refund > 0) then { ["OPF", _refund, "opcom_build_refund"] call fnc_ap_adjust };
            [format ["Lay %1 mines at %2 found no ground%3", _variant, mapGridPosition _pos,
                ["", format ["  %1 AP back", _refund]] select (_refund > 0)]] call DUWS_fnc_opcom_aiEvent;
        };
        private _best = ["MINEFIELD", DUWS_fnc_opcom_buildCand, [_pos], true, _variant] call fnc_hardpoint_best_ground;
        if (_best isEqualTo []) exitWith { call _fnc_noGround };
        _best params ["_at", "", "_dir"];
        // Only the centre was scored. A belt runs kilometres past it and crosses ground the one candidate
        // never saw, so every square is tested here. AP keeps the 100 m road standoff its siting gate
        // applies; AT is laid on roads by design.
        private _centres = ([_at, _dir, _size select 0, _size select 1] call fnc_hardpoint_minefield_grid) select {
            !surfaceIsWater _x && {_variant isEqualTo "AT" || {(_x nearRoads 100) isEqualTo []}}
        };
        private _seq = missionNamespace getVariable ["DUWS_hpOpcomSeq", 0];
        missionNamespace setVariable ["DUWS_hpOpcomSeq", _seq + 1];
        private _key = format ["hpopcom_%1", _seq];
        // Planned, not laid: the squares are made and unmade by the site poller as players reach them.
        private _laid = [_centres, _dir, _variant, _key] call fnc_hardpoint_minefield_stream;
        if (_laid < 1) exitWith { call _fnc_noGround };
        [_centres, _dir, _key] call fnc_hardpoint_minefield_signs;
        [_key, "MINEFIELD", _at, "opfor", "", _dir, _size call fnc_hardpoint_minefield_ring] call fnc_hardpoint_register;
        DUWS_opcom_mineVariants set [_key, _variant];
        ["INFO", "OPCOM", format ["mine: %1 belt %2 planned as %3 near %4: %5 mines over %6 of %7 squares",
            _variant, _size, _key, _at apply { round _x }, _laid, count _centres,
            (_size select 0) * (_size select 1)]] call fnc_log;
        [format ["Lay %1 mines at %2 laid", _variant, mapGridPosition _at]] call DUWS_fnc_opcom_aiEvent;
    };
    true
};

DUWS_fnc_opcom_deliver = {
    params ["_t"];
    (_t get "errand") params [["_kind", ""], "_arg", ["_spec", ""], ["_refund", 0]];
    ["INFO", "OPCOM", format ["deliver: tasking %1 lands %2 at %3", _t get "id", _t get "errand", _t get "target"]] call fnc_log;
    private _class = [_kind, _spec] call DUWS_fnc_opcom_supplyClass;
    OPCOM_SUPPLY_COOLDOWN params ["_min", "_max"];
    private _n = _min + floor random (_max - _min + 1);
    DUWS_opcom_supplyReadyTick set [_class, DUWS_opcom_tick + _n];
    ["INFO", "OPCOM", format ["deliver: no %1 truck for %2 ticks", _class, _n]] call fnc_log;
    switch (_kind) do {
        case "reinforce": { [_arg, "opcom_reinforce"] call fnc_town_garrison_reinforce };
        case "fortify": { [_arg, "opcom_fortify"] call fnc_town_garrison_fortify };
        case "rapport": {
            [_arg, -OPCOM_RAPPORT_STEP, "opcom_rapport", true] call fnc_town_rep_adjust;
            if ((missionNamespace getVariable ["civ_visible", []]) param [_arg, true]) then {
                [localize "STR_DUWS_T_ALLSEER", format [localize "STR_DUWS_T_OPCOM_RAPPORT_DELIVERED", [_arg] call DUWS_fnc_opcom_townLabel]]
                    remoteExec ["fnc_duws_dialogue", 0];
            };
        };
        case "build": { [_spec, "", _arg, _refund] call DUWS_fnc_opcom_build };
        case "mine": { [_arg, _spec select 0, _spec select 1, _refund] call DUWS_fnc_opcom_mineBuild };
    };
};
