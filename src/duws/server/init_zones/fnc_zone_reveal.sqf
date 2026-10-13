// Locality: server. Sole writer of the revealed flag in zone_namePOS_pairs.
//
// Returns true only when this call changed something, so a caller can tell "revealed a zone"
// from "that zone was already on the map" without re-reading the array.
//
// A single reveal is announced to every player whatever its source, since the zone lands on every
// map. _quiet hands the reporting to a caller that speaks its own line over the reveal.
params ["_mode", ["_zonePos", []], ["_quiet", false]];

if (!isServer) exitWith {false};

// Markers are created through str(), which wraps a string in literal quote characters
// (fnc_createzone.sqf:45,59), so every later access has to spell the name the same way or it
// addresses a marker that does not exist.
private _fnc_paint = {
    params ["_pos"];
    private _icon = format ["%1%2", round (_pos select 0), round (_pos select 1)];
    private _ellipse = format ["%1%2ellipse", round (_pos select 0), round (_pos select 1)];
    // A landlocked zone owns no port, so that name addresses nothing -- a no-op, not an error.
    private _port = format ["%1%2port", round (_pos select 0), round (_pos select 1)];
    str(_icon) setMarkerAlpha 1;
    str(_ellipse) setMarkerAlpha 0.3;
    str(_port) setMarkerAlpha 1;
};

private _revealed = false;

switch (_mode) do {

    case "ONE": {
        private _i = zone_namePOS_pairs findIf {str (_x select 1) == str _zonePos};
        if (_i > -1 && {!((zone_namePOS_pairs select _i) select 2)}) then {
            (zone_namePOS_pairs select _i) set [2, true];
            [_zonePos] call _fnc_paint;
            ["ZONE", [_zonePos] call fnc_zone_key] call fnc_hardpoint_reveal;
            _revealed = true;
            if (!_quiet) then {
                private _name = (zone_namePOS_pairs select _i) select 0;
                ["zone_discovered", [_name]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];
                [localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_INTEL_REVEAL_ZONE_LINE",
                    _name, [_zonePos] call fnc_place_name]] remoteExec ["fnc_duws_dialogue", 0];
            };
        };
    };

};

// The repaint follows the flag rather than running beside it, so a caller cannot leave the map
// and the array disagreeing about what the player has found.
if (_revealed) then {
    publicVariable "zone_namePOS_pairs";
};

_revealed
