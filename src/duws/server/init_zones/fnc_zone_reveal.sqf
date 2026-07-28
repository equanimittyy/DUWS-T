// Locality: server. Sole writer of the revealed flag in zone_namePOS_pairs.
//
// Returns true only when this call changed something, so a caller can tell "revealed a zone"
// from "that zone was already on the map" without re-reading the array.
params ["_one_or_all", ["_zonePos", []]];

if (!isServer) exitWith {false};

// Markers are created through str(), which wraps a string in literal quote characters
// (fnc_createzone.sqf:45,59), so every later access has to spell the name the same way or it
// addresses a marker that does not exist.
private _fnc_paint = {
    params ["_pos"];
    private _icon = format ["%1%2", round (_pos select 0), round (_pos select 1)];
    private _ellipse = format ["%1%2ellipse", round (_pos select 0), round (_pos select 1)];
    str(_icon) setMarkerAlpha 1;
    str(_ellipse) setMarkerAlpha 0.3;
};

private _revealed = false;

switch (_one_or_all) do {

    case "ONE": {
        private _i = zone_namePOS_pairs findIf {str (_x select 1) == str _zonePos};
        if (_i > -1 && {!((zone_namePOS_pairs select _i) select 2)}) then {
            (zone_namePOS_pairs select _i) set [2, true];
            [_zonePos] call _fnc_paint;
            _revealed = true;
            [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_zonereveal"] remoteExec ["fnc_duws_dialogue", 0];
        };
    };

    case "ALL": {
        {
            if (!(_x select 2)) then {
                _x set [2, true];
                [_x select 1] call _fnc_paint;
                _revealed = true;
            };
        } forEach zone_namePOS_pairs;

        if (_revealed) then {
            [{hint localize "STR_DUWS_T_daqqfq5j"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated, false];
        };
    };

};

// The repaint follows the flag rather than running beside it, so a caller cannot leave the map
// and the array disagreeing about what the player has found.
if (_revealed) then {
    publicVariable "zone_namePOS_pairs";
    call fnc_hardcore_visible_recalc;
};

_revealed
