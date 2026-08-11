// Locality: server. Sole writer of the revealed flag in zone_namePOS_pairs.
//
// Returns true only when this call changed something, so a caller can tell "revealed a zone"
// from "that zone was already on the map" without re-reading the array.
//
// _audience is who is told. Walking into a zone is everyone's news and takes the default; a zone
// bought with a search belongs to the one player who paid for it, and passing that player also
// puts the line on their screen as a hint -- the dialogue queue can hold it behind other traffic,
// and a result the player acted for should not arrive late or scroll past unread.
//
// _quiet hands the reporting to the caller. Overlord's line here is an AO-wide broadcast, which is
// the wrong voice for a search: that result is the searcher's own, spoken by them and heard only by
// them, so the caller says its piece instead of both of them talking over one reveal.
params ["_one_or_all", ["_zonePos", []], ["_audience", 0], ["_quiet", false]];

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
            if (!_quiet) then {
                [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_zonereveal",
                    _audience] call fnc_duws_report;
            };
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
};

_revealed
