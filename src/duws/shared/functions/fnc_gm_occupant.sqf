// Display name of whoever holds the game_master slot, or the localised "no-one" when it sits empty.
// game_master is an array in MP but a bare string in SP (client_init.sqf), so normalise before param.
private _gml = missionNamespace getVariable ["game_master", []];
if (_gml isEqualType "") then { _gml = [_gml] };
private _gm = _gml param [0, ""];
private _name = "";
{ if (vehicleVarName _x == _gm) exitWith { _name = name _x } } forEach allPlayers;
if (_name isEqualTo "") then { localize "STR_DUWS_T_GM_SEAT_NOONE" } else { _name }
