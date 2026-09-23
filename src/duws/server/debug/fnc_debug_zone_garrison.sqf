// Locality: server -- remoteExec'd to 2 by the Debug menu's zone-garrison rows, with the clicked map
// position, the verb and the caller. English-only, like the rest of the debug surface.
//
// Nothing else calls the zone buys for BLUFOR yet, so this is how captured ground gets a garrison.
if (!isServer) exitWith {};

params [["_pos", [0, 0, 0]], ["_verb", "fortify"], ["_caller", objNull]];
if (isNull _caller) exitWith {};

private _zonePos = [];
private _best = 1e11;
{
	_x params ["", "_zPos", "_zSize"];
	private _d = _pos distance2D _zPos;
	if (_d < _zSize && {_d < _best}) then {
		_zonePos = _zPos;
		_best = _d;
	};
} forEach zone_meta_array;

if (_zonePos isEqualTo []) exitWith {
	["No zone under the marked spot."] remoteExec ["hint", _caller];
};

private _key = [_zonePos] call fnc_zone_key;
private _side = [_key] call DUWS_fnc_garrisonSideOf;
private _name = _key;
private _i = zone_namePOS_pairs findIf {
	private _p = _x select 1;
	((_p select 0) == (_zonePos select 0)) && ((_p select 1) == (_zonePos select 1))
};
if (_i >= 0) then { _name = (zone_namePOS_pairs select _i) select 0 };

private _line = "";
switch (_verb) do {
	case "fortify": {
		private _old = [_key] call fnc_zone_tier;
		private _new = [_key, "debug menu"] call fnc_zone_garrison_fortify;
		_line = if (_new <= _old) then {
			format ["%1 is already at the top tier.", _name]
		} else {
			format ["%1 bought tier %2 for %3.\n\nA tier buy fields a tenth of what it adds; the rest is owed,\nand reinforcement is what pays it off.", _name, _new, _side]
		};
	};
	case "reinforce": {
		private _new = [_key, "debug menu"] call fnc_zone_garrison_reinforce;
		_line = if (_new < 0) then {
			format ["%1 holds no garrison to reinforce. Buy a tier first.", _name]
		} else {
			format ["%1 reinforced to %2 strength for %3.\n\nThe men walk in on the next reserve wave.", _name, round (_new * 100), _side]
		};
	};
};

["INFO", "ZONES", format ["debug %1 at %2 (%3)", _verb, _name, _side]] call fnc_log;
[_line] remoteExec ["hint", _caller];
