// Locality: server -- remoteExec'd to 2 by the Debug menu's garrison-ledger row, which hands over the
// clicked map position and the caller. Resolves the site under the click and hints its garrison ledger
// back. English-only, like the rest of the debug surface.
if (!isServer) exitWith {};

params [["_pos", [0, 0, 0]], ["_caller", objNull]];
if (isNull _caller) exitWith {};

// Nearest centre, like the map readout -- but with no reveal or visibility gate: a dev reading the ledger
// wants the hidden zones too, which the player-facing readout deliberately keeps off the map.
private _key = "";
private _radius = 0;
private _best = 1e11;

{
	_x params ["", "_zPos", "_zSize"];
	private _d = _pos distance2D _zPos;
	if (_d < _zSize && {_d < _best}) then {
		_key = [_zPos] call fnc_zone_key;
		_radius = _zSize;
		_best = _d;
	};
} forEach zone_meta_array;

if (_key isEqualTo "") exitWith {
	["No zone under the marked spot."] remoteExec ["hint", _caller];
};

private _rows = [_key] call DUWS_fnc_garrisonDebug;
_rows insert [1, [["Tier", format ["%1 / %2", [_key] call fnc_zone_tier, count DUWS_zoneSpawnTiers],
	format ["%1 holds it", [_key] call DUWS_fnc_garrisonSideOf]]]];
_rows append ([_key, _radius] call fnc_hardpoint_debug);

// The map is closed by the time this returns, so the hint is not drawn under it.
diag_log format ["[DUWS garrison debug] %1", _key];
["Garrison ledger", _key, _rows, _caller] call fnc_ledger_hint;
