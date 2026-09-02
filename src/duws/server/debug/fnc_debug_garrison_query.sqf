// Locality: server -- remoteExec'd to 2 by the Debug menu's garrison-ledger row, which hands over the
// clicked map position and the caller. Resolves the site under the click and hints its garrison ledger
// back. English-only, like the rest of the debug surface.
if (!isServer) exitWith {};

params [["_pos", [0, 0, 0]], ["_caller", objNull]];
if (isNull _caller) exitWith {};

// Nearest centre across zones and towns, like the map readout -- but with no reveal or visibility gate:
// a dev reading the ledger wants the hidden sites too, which the player-facing readout deliberately
// keeps off the map. Zone circles and town discs overlap by design, so the nearer centre wins.
private _key = "";
private _what = "";
private _radius = 0;
private _best = 1e11;

{
	_x params ["", "_zPos", "_zSize"];
	private _d = _pos distance2D _zPos;
	if (_d < _zSize && {_d < _best}) then {
		_key = [_zPos] call fnc_zone_key;
		_what = "zone";
		_radius = _zSize;
		_best = _d;
	};
} forEach zone_meta_array;

private _locations = missionNamespace getVariable ["civ_locations", []];
private _radii = missionNamespace getVariable ["civ_radii", []];
{
	private _d = _pos distance2D (getPos _x);
	if (_d < (_radii param [_forEachIndex, 0]) && {_d < _best}) then {
		_key = [_forEachIndex] call fnc_town_site_key;
		_what = format ["town %1", _forEachIndex];
		_best = _d;
	};
} forEach _locations;

if (_key isEqualTo "") exitWith {
	["No zone or town under the marked spot."] remoteExec ["hint", _caller];
};

private _lines = [_key] call DUWS_fnc_garrisonDebug;
// A zone also carries a hardpoint ring; a town raises none, so its readout is the ledger alone.
if (_what isEqualTo "zone") then { _lines append ([_key, _radius] call fnc_hardpoint_debug) };
// To the log for the .rpt trail and to the caller's hint box. The map is closed by the time this
// returns, so the hint is visible; the lines join with \n, which hint renders as line breaks.
diag_log format ["[DUWS garrison debug] %1", _what];
{ diag_log _x } forEach _lines;
(_lines joinString "\n") remoteExec ["hint", _caller];
