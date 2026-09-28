// Locality: server only -- server/supports/fnc_fob_server.sqf on build, fnc_redeployFOBUnits on
// rebuild. A FOB's turrets are campaign property, so spawning them on the rebuilding client
// would leave them simulated there and orphaned on disconnect.

if (!isServer) exitWith {};

params ["_centerPos", "_fob", ["_refortify", false]];

// Marks the rebuild in progress and is cleared at the end of this pass. fnc_redeployFOBUnits raises
// it before it charges and reads it to turn a second click away rather than pay it back, so the
// gate is held from the charge through to completion; the build path (fnc_fob_server) raises it here
// on first fortify.
_fob setVariable ["FOB_fortify_busy", true];

// Refortify replaces the previous ring rather than adding to it. The current turrets are read
// off the FOB instead of passed in, so no copy of the scroll action can hold stale references
// after another player rebuilds. Server-local: only this machine ever reads them.
{ { deleteVehicle _x } forEach (crew _x); deleteVehicle _x; } forEach (_fob getVariable ["FOB_turrets", []]);

// Refortify only: a load restores the builds and mans them itself (fnc_campaign_restore).
private _buildKey = _fob getVariable ["DUWS_buildKey", ""];
if (_refortify) then {
	{
		private _gun = _x;
		{ _gun deleteVehicleCrew _x } forEach ((crew _gun) select { !alive _x });
	} forEach (DUWS_compositions getOrDefault [_buildKey, []]);
};


playSound "loadgun";

// Everything this FOB owns is filed under one key, so tearing the FOB down can hand the whole
// ring to the cleanup at once -- the turrets and the sandbags around them alike.
_fobKey = format ["FOB_%1", netId _fob];

// Two layers of one composition, not one list: the halves have different lifetimes. The perimeter is
// placed on first fortify and left standing; a refortify replaces every turret. Offsets are from the FOB
// centre.
private _perimeterData = ["duws_fob", "perimeter"] call fnc_composition_rows;

// A gun's class is a placeholder: fnc_static_resolve stands whatever the faction fields for its role, so the
// ring is arranged in Eden against vanilla silhouettes and stays mod-free. Headings are rows, not computed
// radially from the centre, so a turret turned in Eden keeps its heading.
private _turretData = ["duws_fob", "turrets"] call fnc_composition_rows;

// One perimeter row, one object -- the turrets go through fnc_static_place instead: a wall is the
// same wall whoever built it, while a gun is whatever the faction fields; the perimeter stays
// simulated and invulnerable while the ring is frozen until it's crewed. Position is written twice
// around the rotation because setDir displaces the object, so the heading must land between two
// writes.
private _fnc_place = {
	params ["_row", "_key"];
	_row params ["_class", "_ox", "_oy", "_oz", "_dir"];
	private _px = (_centerPos select 0) + _ox;
	private _py = (_centerPos select 1) + _oy;
	// A row's Z is the model centre over the ground, as Eden saves it.
	private _pos = [_px, _py, (getTerrainHeightASL [_px, _py]) + _oz];
	private _obj = createVehicle [_class, [0,0,0], [], 0, "CAN_COLLIDE"];
	[_obj, _key] call fnc_duws_keep;
	_obj allowDamage false;
	_obj setPosWorld _pos;
	_obj setDir _dir;
	_obj setPosWorld _pos;
	_obj setDamage 0;
	_obj
};

private _turrets = [];
switch (VERSION_X) do {
	case "MODERN": {
		{
			// Invulnerable from the moment it stands up, not from when its gunner arrives -- which is
			// why the caller applies this and the placer does not: the ring is what the player paid
			// for, and the perimeter and roof AA below want their own answers.
			// The ring's guns stand on the ground: "pos" mode reads Z as the base's height, and a row carries
			// the model centre's.
			_x set [3, 0];
			private _turret = [_x, _centerPos, "blufor", _fobKey, "pos"] call fnc_static_place;
			_turret allowDamage false;
			_turret setDamage 0;
			_turrets pushBack _turret;
		} forEach _turretData;

		// The one turret that is not a row: it stands on the FOB building's roof, and buildingPos is the only
		// thing that knows where -- a flat offset would put it at ground level if the building were ever
		// replaced. Filed under the FOB key like the rest; its class still goes through the resolver, so the
		// roof gun is drawn from the same pool -- only its placement is its own.
		private _roofPos = _fob buildingPos 5;
		private _aaClass = "B_static_AA_F";
		private _aa = createVehicle [
			[_aaClass, "blufor"] call fnc_static_resolve,
			[0,0,0], [], 0, "CAN_COLLIDE"
		];
		[_aa, _fobKey] call fnc_duws_keep;
		// Seat the base on the roof, not the model origin: a faction swap to a taller AA would sink its
		// base through the roof. Same correction fnc_static_place makes for composition guns.
		private _delta = ([_aaClass] call fnc_static_baseZ) - ([typeOf _aa] call fnc_static_baseZ);
		_aa setPosATL [(_roofPos select 0) - 3, (_roofPos select 1) - 5, (_roofPos select 2) + _delta];
		_turrets pushBack _aa;

		// Permanent, so first fortify only: a refortify replaces the guns above and leaves the
		// walls the player has been fighting behind exactly where they are.
		if !(_refortify) then {
			// With the walls, not with the turrets: 15 m covers a perimeter that reaches 11.5 m from
			// centre, and a refortify is standing the guns back up inside ground already cleared.
			[_centerPos, 15] call fnc_clear_foliage;
			{ [_x, _fobKey] call _fnc_place } forEach _perimeterData;
		};
	};
};

// One gunner per turret, so a ring edited in the 3D editor is crewed by whatever it now holds
// rather than by a hardcoded five.
private _guardTypes = [];
{ _guardTypes pushBack blufor_SOLDIER_X } forEach _turrets;
_groupGuard = [[0,0], WEST, _guardTypes, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
_groupGuard deleteGroupWhenEmpty true;

sleep 10;

// The thaw that undoes fnc_static_place's freeze. It has to happen here and not at placement: the
// freeze is what holds a row where its Z put it, and a gun released before its gunner is in settles
// wherever gravity takes it first. The roof AA was never frozen, so this is a no-op for it.
{
	private _gunner = (units _groupGuard) param [_forEachIndex, objNull];
	if (!isNull _gunner) then {
		_gunner setPos _centerPos;
		_gunner moveInGunner _x;
	};
	_x enableSimulationGlobal true;
} forEach _turrets;

if (_refortify) then { [DUWS_compositions getOrDefault [_buildKey, []], true] call DUWS_fnc_buildCrew };

sleep 50;
{ _x allowDamage false } forEach _turrets;

[_groupGuard, _centerPos] call bis_fnc_taskDefend;

_fob setVariable ["FOB_turrets", _turrets];

// Filed under the site as its emplacement occupant, so the freeze reaches the ring and not only the
// guards beside it. A turret is a vehicle with a full FSM, so five per FOB at up to
// floor(zones / 2) FOBs is the larger half of what an idle base costs.
//
// The FOB building and its props are deliberately not registered: freezing a static building buys
// almost nothing, and it's the object carrying the base's action menu and respawn point -- a saving
// worth nothing isn't worth putting those behind enableSimulationGlobal.
private _emplacements = [_fobKey, "emplacement"] call fnc_site_roster;
[_fobKey, "emplacement"] call fnc_site_roster_clear;
{
	if (!isNull _x) then {
		_emplacements pushBack _x;
		_emplacements append (crew _x);
	};
} forEach _turrets;
_fob setVariable ["FOB_fortify_busy", false];

// No scroll entry added here. Guards and defences are one redeploy action now, added by
// init_hq/fnc_guardsFOB.sqf -- the other half of the same rebuild.
