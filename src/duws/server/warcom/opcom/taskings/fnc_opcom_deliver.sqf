// Locality: server, [] call'd at load. A supply run's delivery and OPCOM's hardpoint build. The caller spends the
// truck whatever a writer answers, so a refused errand is lost (docs/plans/opcom/opcom_plan.md §Shipped).
if (!isServer) exitWith {};

// One hardpoint of _type: in _zoneKey's ring, or standalone in the band near _pos when _zoneKey is "". -> false if
// refused. The siting runs spawned: the builder sleeps in its crew drop, and the tick must never sleep.
DUWS_fnc_opcom_build = {
    params ["_type", ["_zoneKey", ""], ["_pos", []]];
    if (([_type] call fnc_hardpoint_comp) isEqualTo [] && {_type isNotEqualTo "MINEFIELD"}) exitWith {
        ["WARN", "OPCOM", format ["build: no composition for hardpoint type %1", _type]] call fnc_log; false
    };
    private _cand = fnc_hardpoint_band_cand;
    private _anchor = [_pos, 0, []];
    if (_zoneKey isNotEqualTo "") then {
        private _site = [_zoneKey] call fnc_site_at;
        _cand = fnc_hardpoint_zone_cand;
        _anchor = [_site getOrDefault ["pos", []], _site getOrDefault ["radius", 0]];
    };
    if ((_anchor select 0) isEqualTo []) exitWith {
        ["WARN", "OPCOM", format ["build: %1 has no ground to site on (zone %2)", _type, _zoneKey]] call fnc_log; false
    };
    private _seq = missionNamespace getVariable ["DUWS_hpOpcomSeq", 0];
    missionNamespace setVariable ["DUWS_hpOpcomSeq", _seq + 1];
    [_type, _cand, format ["hpopcom_%1", _seq], _zoneKey, _anchor] spawn {
        params ["_type", "_cand", "_key", "_zoneKey", "_anchor"];
        private _res = [_type, _cand, _key, _zoneKey, _anchor] call fnc_hardpoint_spawn_sited;
        [["INFO", "WARN"] select (_res isEqualTo []), "OPCOM", format ["build: %1 %2 as %3 (zone %4 near %5)",
            _type, ["sited", "found no ground"] select (_res isEqualTo []), _key, _zoneKey, (_anchor select 0) apply { round _x }]] call fnc_log;
    };
    true
};

DUWS_fnc_opcom_deliver = {
    params ["_t"];
    (_t get "errand") params [["_kind", ""], "_arg", ["_type", ""]];
    ["INFO", "OPCOM", format ["deliver: tasking %1 lands %2 at %3", _t get "id", _t get "errand", _t get "target"]] call fnc_log;
    switch (_kind) do {
        case "reinforce": { [_arg, "opcom_reinforce"] call fnc_town_garrison_reinforce };
        case "fortify": {
            // Reputation, not AP, decides whether a town garrisons, so a fortify never raises one from tier 0.
            private _tier = [_arg] call fnc_town_garrison_tierAt;
            if (_tier < 1) exitWith { ["INFO", "OPCOM", format ["deliver: town %1 has no garrison to fortify", _arg]] call fnc_log };
            [_arg, _tier + 1, "opcom_fortify"] call fnc_town_garrison_setTier;
        };
        case "rapport": { [_arg, -3, "opcom_rapport"] call fnc_town_rep_adjust };
        case "build": { [_type, "", _arg] call DUWS_fnc_opcom_build };
    };
};
