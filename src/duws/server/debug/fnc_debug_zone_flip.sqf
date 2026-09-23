// Locality: server -- remoteExec'd by the Debug menu's zone-flip row. English-only, like the rest of the debug surface.
if (!isServer) exitWith {};

params [["_pos", [0, 0, 0]], ["_caller", objNull]];
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

private _trgVarName = format ["trigger_%1_%2", floor abs (_zonePos select 0), floor abs (_zonePos select 1)];
private _trg = missionNamespace getVariable [_trgVarName, objNull];
if (isNull _trg) exitWith {
	["That zone has no capture trigger filed."] remoteExec ["hint", _caller];
};

private _key = [_zonePos] call fnc_zone_key;
private _toBlufor = !(_zonePos in WARCOM_zones_controled_by_BLUFOR);
private _name = _key;
private _i = zone_namePOS_pairs findIf {
	private _p = _x select 1;
	((_p select 0) == (_zonePos select 0)) && ((_p select 1) == (_zonePos select 1))
};
if (_i >= 0) then { _name = (zone_namePOS_pairs select _i) select 0 };

// Spend the garrison a real capture would have beaten; liveness drops first so the kills call no reserve wave.
if (_toBlufor) then {
	[_key] call fnc_zone_garrison_dropped;
	[_key] call DUWS_fnc_garrisonReserveClear;
	// Men only: a real capture leaves the emplacements and vehicles to the player.
	{ _x setDamage 1 } forEach (([_key] call fnc_zone_roster) select { alive _x });
	[_key, 0] call DUWS_fnc_garrisonSeed;
	// A ring hardpoint's men sit off the zone roster, so the kill above misses them; they still count against the capture's numbers test.
	{
		private _hpKey = _x select 0;
		{ { _x setDamage 1 } forEach (([_hpKey, _x] call fnc_site_roster) select { alive _x }) } forEach ["garrison", "crew"];
		[_hpKey, [_hpKey, "garrison"] call fnc_site_occupant] call DUWS_fnc_hardpointClear;
	} forEach (DUWS_hardpoints select { (_x select 4) isEqualTo _key });
};

// The trigger's armed statement, not a hand-built call: it carries the next handler and its args, so a forced flip cannot drift from an earned one.
call compile ((triggerStatements _trg) select 1);

private _side = ["OPFOR", "BLUFOR"] select _toBlufor;
["INFO", "ZONES", format ["debug flip: %1 handed to %2", _name, _side]] call fnc_log;
private _detail = [
	"Dev tool: runs the zone's armed loss handler, so the zone\nreseeds at tier I as it does in play.",
	"Dev tool: the garrison and ring hardpoints are killed, its\nreserve cleared and every token filed lost, then the zone's\narmed capture handler runs -- so AP, CP, markers and\nnotifications land as in play."
] select _toBlufor;
[format ["%1 handed to %2.\n\n%3", _name, _side, _detail]] remoteExec ["hint", _caller];
