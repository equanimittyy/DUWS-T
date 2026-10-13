// Locality: server. Sole writer of the revealed flag (index 5) in DUWS_hardpoints, the way
// fnc_zone_reveal owns the flag in zone_namePOS_pairs and fnc_civ_town_reveal owns civ_visible.
//
// Keyed on the hardpoint's own key rather than a position: every row carries a unique key already,
// so there is no pos-matching and no str() marker-name dance -- the marker is named hpm_<key>.
//
// Returns true only when this call changed something, so a caller can tell "found it" from "already
// on the map". _quiet follows fnc_zone_reveal's rule.
//
// "ZONE" takes a zone key and speaks no line: it runs under fnc_zone_reveal's own announcement.
params ["_mode", ["_key", ""], ["_quiet", false]];

if (!isServer) exitWith {false};

private _fnc_paint = {
    params ["_k"];
    (format ["hpm_%1", _k]) setMarkerAlpha 1;
    private _mines = missionNamespace getVariable [format ["DUWS_hpMines_%1", _k], []];
    if (_mines isNotEqualTo []) then {
        [_mines] remoteExec ["fnc_hardpoint_minefield_reveal", 0, format ["DUWS_hpMineReveal_%1", _k]];
    };
    // A streamed field's squares are made and unmade as players move, so its mines cannot ride a JIP queue.
    // The squares standing right now are marked here -- the field is usually revealed by a mine going off
    // under somebody, who is therefore inside one -- and every later square marks itself as it is made.
    private _standing = [];
    { _standing append (_x select 2) } forEach (missionNamespace getVariable [format ["DUWS_hpMineSquares_%1", _k], []]);
    if (_standing isNotEqualTo []) then {
        [_standing] remoteExec ["fnc_hardpoint_minefield_reveal", 0];
    };
};

private _revealed = false;

switch (_mode) do {

    case "ONE": {
        private _i = DUWS_hardpoints findIf { (_x select 0) isEqualTo _key };
        if (_i > -1 && {!((DUWS_hardpoints select _i) select 5)}) then {
            (DUWS_hardpoints select _i) set [5, true];
            [_key] call _fnc_paint;
            _revealed = true;
            if (!_quiet) then {
                (DUWS_hardpoints select _i) params ["", "_pos", "_type"];
                [localize "STR_DUWS_T_ALLSEER", format [localize "STR_DUWS_T_INTEL_REVEAL_HP_LINE",
                    DUWS_hardpointName getOrDefault [_type, _type], [_pos] call DUWS_fnc_hardpointNearestPlace]]
                    remoteExec ["fnc_duws_dialogue", 0];
            };
        };
    };

    case "ZONE": {
        {
            if ((_x select 4) isEqualTo _key && {!(_x select 5)}) then {
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
