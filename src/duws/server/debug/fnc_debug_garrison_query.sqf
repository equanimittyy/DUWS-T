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
private _tier = 0;
private _tierMax = 0;
private _best = 1e11;

{
	_x params ["", "_zPos", "_zSize"];
	private _d = _pos distance2D _zPos;
	if (_d < _zSize && {_d < _best}) then {
		_key = [_zPos] call fnc_zone_key;
		_what = "zone";
		_radius = _zSize;
		_tier = [_key] call fnc_zone_tier;
		_tierMax = count DUWS_zoneSpawnTiers;
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
		_tier = [_forEachIndex] call fnc_town_garrison_tierAt;
		_tierMax = count DUWS_townSpawnTiers;
		_best = _d;
	};
} forEach _locations;

if (_key isEqualTo "") exitWith {
	["No zone or town under the marked spot."] remoteExec ["hint", _caller];
};

private _rows = [_key] call DUWS_fnc_garrisonDebug;
_rows insert [1, [["Tier", format ["%1 / %2", _tier, _tierMax]]]];
// A zone also carries a hardpoint ring; a town raises none, so its readout is the ledger alone.
if (_what isEqualTo "zone") then { _rows append ([_key, _radius] call fnc_hardpoint_debug) };

// The map is closed by the time this returns, so the hint is not drawn under it.
diag_log format ["[DUWS garrison debug] %1", _what];
private _markup = format ["<t size='1.3' color='#00ffff'>Garrison ledger</t><br/><t size='0.85' color='#b0b0b0'>%1</t><br/>", _key];
{
	if (_x isEqualType "") then {
		diag_log format ["[%1 %2]", toUpper _x, _key];
		_markup = _markup + format ["<br/><t color='#ffcc66'>%1</t><br/>", toUpper _x];
	} else {
		_x params ["_label", "_value", ["_detail", ""]];
		diag_log format ["  %1: %2  %3", _label, _value, _detail];
		_markup = _markup + format ["<t align='left'>%1</t><t align='right'>%2</t><br/>", _label, _value];
		if (_detail isNotEqualTo "") then {
			_markup = _markup + format ["<t align='left' size='0.8' color='#b0b0b0'>%1</t><br/>", _detail];
		};
	};
} forEach _rows;

// hint takes no duration; each re-issue restarts its fade. Stops on a newer readout, which it would paint over.
[_markup, {
	DUWS_debugLedgerHint = _this;
	hint parseText _this;
	for "_i" from 1 to 3 do {
		sleep 10;
		if (DUWS_debugLedgerHint isNotEqualTo _this) exitWith {};
		hintSilent parseText _this;
	};
}] remoteExec ["spawn", _caller];
