// Locality: server -- remoteExec'd to 2 by the Debug menu's force-emission row, which hands over the
// caller and the clicked position. Reports the emitter nearest the click, its OPCOM force-grid deposit
// and where the count came from -- (live) roster, (ledger) surviving tokens, or a fixed (nominal) --
// back to the caller's hint. Reads the same DUWS_fnc_garrisonMen the grid rebuild does, so the readout
// matches the deposit. English-only, like the rest of the debug surface.
if (!isServer) exitWith {};

params [["_pos", [0, 0, 0]], ["_caller", objNull]];
if (isNull _caller) exitWith {};

// Nearest by centre across all zones and standing OPFOR hardpoints -- no radius gate, so a click near a
// point-sized hardpoint still resolves it. One shared nearest test so the closer kind wins outright.
// _pick: ["zone", pos, radius] or ["hp", pos, key, type].
private _best = 1e11;
private _pick = [];

{
	_x params ["", "_zPos", "_zSize"];
	private _d = _pos distance2D _zPos;
	if (_d < _best) then { _best = _d; _pick = ["zone", _zPos, _zSize]; };
} forEach zone_meta_array;

{
	if ((_x select 3) isEqualTo "opfor") then {
		private _d = _pos distance2D (_x select 1);
		if (_d < _best) then { _best = _d; _pick = ["hp", _x select 1, _x select 0, _x select 2]; };
	};
} forEach DUWS_hardpoints;

if (_pick isEqualTo []) exitWith {
	["No zone or OPFOR hardpoint found."] remoteExec ["hint", _caller];
};

_pick params ["_kind", "_epos"];
private _lines = [];

if (_kind isEqualTo "zone") then {
	private _key = [_epos] call fnc_zone_key;
	private _reach = round ((_pick select 2) + OPCOM_GRID_SPREAD);
	if ((WARCOM_zones_controled_by_BLUFOR findIf {(_x distance2D _epos) < 1}) >= 0) then {
		_lines = [
			format ["[FORCE EMISSION] %1", _key],
			"  BLU-held zone -> enemy layer",
			format ["  emitting: %1 men (nominal)", OPCOM_GRID_ZONE_ENEMY_MEN],
			format ["  reach: %1 m   dist: %2 m", _reach, round _best]
		];
	} else {
		private _tag = ["ledger", "live"] select ([_key] call DUWS_fnc_garrisonHeld);
		_lines = [
			format ["[FORCE EMISSION] %1", _key],
			format ["  OPFOR zone, tier %1 -> friendly layer", [_key] call fnc_zone_tier],
			format ["  emitting: %1 men (%2)", [_key] call DUWS_fnc_garrisonMen, _tag],
			format ["  reach: %1 m   dist: %2 m", _reach, round _best]
		];
	};
} else {
	_pick params ["", "", "_key", "_type"];
	_lines = [
		format ["[FORCE EMISSION] %1", _key],
		format ["  OPFOR hardpoint (%1) -> friendly layer", _type],
		format ["  emitting: %1 men (nominal)", OPCOM_GRID_HP_MEN],
		format ["  reach: %1 m   dist: %2 m", OPCOM_GRID_SPREAD, round _best]
	];
};

// To the log for the .rpt trail and to the caller's hint box; the map is closed by the time this returns.
diag_log format ["[DUWS force emission] %1", _lines select 0];
{ diag_log _x } forEach _lines;
(_lines joinString "\n") remoteExec ["hint", _caller];
