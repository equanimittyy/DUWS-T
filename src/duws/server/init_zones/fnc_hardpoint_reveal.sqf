// Locality: server. Sole writer of the revealed flag (index 5) in DUWS_hardpoints, the way
// fnc_zone_reveal owns the flag in zone_namePOS_pairs and fnc_civ_town_reveal owns civ_visible.
//
// Keyed on the hardpoint's own key rather than a position: every row carries a unique key already,
// so there is no pos-matching and no str() marker-name dance -- the marker is named hpm_<key>.
//
// Returns true only when this call changed something, so a caller can tell "found it" from "already
// on the map". _audience and _quiet follow the same rule the zone and town reveals use: an intel
// search belongs to the one player who paid for it and hands its own reporting back through _quiet.
//
// The parent gate (a zone-child hardpoint is only discoverable once its zone is revealed) lives in
// the intel-draw eligibility filter, not here: this function reveals whatever key it is handed.
params ["_one_or_all", ["_key", ""], ["_audience", 0], ["_quiet", false]];

if (!isServer) exitWith {false};

private _fnc_paint = {
    params ["_k"];
    (format ["hpm_%1", _k]) setMarkerAlpha 1;
    private _mines = missionNamespace getVariable [format ["DUWS_hpMines_%1", _k], []];
    if (_mines isNotEqualTo []) then {
        [_mines] remoteExec ["fnc_hardpoint_minefield_reveal", 0, format ["DUWS_hpMineReveal_%1", _k]];
    };
};

private _revealed = false;

switch (_one_or_all) do {

    case "ONE": {
        private _i = DUWS_hardpoints findIf { (_x select 0) isEqualTo _key };
        if (_i > -1 && {!((DUWS_hardpoints select _i) select 5)}) then {
            (DUWS_hardpoints select _i) set [5, true];
            [_key] call _fnc_paint;
            _revealed = true;
            if (!_quiet) then {
                [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_hpreveal",
                    _audience] call fnc_duws_report;
            };
        };
    };

    case "ALL": {
        {
            if (!(_x select 5)) then {
                _x set [5, true];
                [_x select 0] call _fnc_paint;
                _revealed = true;
            };
        } forEach DUWS_hardpoints;
    };

};

// The repaint follows the flag rather than running beside it, so a caller cannot leave the map and
// the array disagreeing about what the player has found.
if (_revealed) then {
    publicVariable "DUWS_hardpoints";
};

_revealed
