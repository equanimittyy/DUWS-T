// Locality: server only -- server/supports/fnc_fob_server.sqf on build, fnc_redeployFOBUnits on
// rebuild. A FOB's turrets are campaign property, so spawning them on the rebuilding client
// would leave them simulated there and orphaned on disconnect.

if (!isServer) exitWith {};

params ["_centerPos", "_fob", ["_refortify", false]];

// One rebuild at a time. The scroll action lives on every machine, so two players can fire it
// at once; without this the second would spawn a duplicate ring over the first. No refund arm any
// more -- fnc_redeployFOBUnits reads this flag before it charges, so a second caller is turned
// away rather than paid back.
if (_fob getVariable ["FOB_fortify_busy", false]) exitWith {};
_fob setVariable ["FOB_fortify_busy", true];

// Refortify replaces the previous ring rather than adding to it. The current turrets are read
// off the FOB instead of passed in, so no copy of the scroll action can hold stale references
// after another player rebuilds. Server-local: only this machine ever reads them.
{ { deleteVehicle _x } forEach (crew _x); deleteVehicle _x; } forEach (_fob getVariable ["FOB_turrets", []]);


playSound "loadgun";

// Everything this FOB owns is filed under one key, so tearing the FOB down can hand the whole
// ring to the cleanup at once -- the turrets and the sandbags around them alike.
_fobKey = format ["FOB_%1", netId _fob];

// Two fences rather than one, because the halves have different lifetimes: the perimeter is placed
// on the first fortify and left standing, while a refortify -- misc/fnc_redeployFOBUnits.sqf calling
// back in with _refortify true -- replaces every turret. A single array would have to carry a
// permanent/rebuilt flag, and the Eden export does not emit anything past the heading column, so the
// flag would survive only by being hand-carried back across 43 rows on every round trip. Lose it and
// a refortify either duplicates the walls or stops replacing the guns.
// The split makes the lifetime the fence rather than a column. Do not merge them into one
// composition; the zone prefabs' single-fence-plus-isWeapon shape works there only because a prefab
// is built once and never rebuilt.
//
// Rows are [class, X, Y, Z, heading], offsets from the FOB centre, which is what lets the layout
// round-trip through the 3D editor (docs/info/composition_tooling.md).
// --DUWS-COMPOSITION BEGIN name="FOB Perimeter" schema=A--
private _perimeterData = [
	["Land_HBarrier_1_F",         -10.0,   4.5, 0,  0.0],
	["Land_HBarrier_1_F",         -10.0,   3.0, 0,  0.0],
	["Land_HBarrier_1_F",         -10.0,   1.5, 0,  0.0],
	["Land_HBarrier_1_F",         -10.0,   0.0, 0,  0.0],
	["Land_HBarrier_1_F",         -10.0,  -6.0, 0,  0.0],
	["Land_HBarrier_1_F",         -10.0,  -7.5, 0,  0.0],
	["Land_HBarrier_1_F",          -6.0, -11.5, 0, 90.0],
	["Land_HBarrier_1_F",          -4.5, -11.5, 0, 90.0],
	["Land_HBarrier_1_F",          -3.0, -11.5, 0, 90.0],
	["Land_HBarrier_1_F",          -1.5, -11.5, 0, 90.0],
	["Land_HBarrier_1_F",           0.0, -11.5, 0, 90.0],
	["Land_HBarrier_1_F",           1.5, -11.5, 0, 90.0],
	["Land_HBarrier_1_F",           3.0, -11.5, 0, 90.0],
	["Land_HBarrier_1_F",           4.5, -11.5, 0, 90.0],
	["Land_HBarrier_1_F",           6.0, -11.5, 0, 90.0],
	["Land_HBarrier_1_F",           7.5, -11.5, 0, 90.0],
	["Land_HBarrier_1_F",          11.0,  -7.0, 0,  0.0],
	["Land_HBarrier_1_F",          11.0,  -5.5, 0,  0.0],
	["Land_HBarrier_1_F",          11.0,  -4.0, 0,  0.0],
	["Land_HBarrier_1_F",          11.0,  -2.5, 0,  0.0],
	["Land_HBarrier_1_F",          11.0,  -1.0, 0,  0.0],
	["Land_HBarrier_1_F",          11.0,   0.5, 0,  0.0],
	["Land_HBarrier_1_F",          11.0,   2.0, 0,  0.0],
	["Land_HBarrier_1_F",          11.0,   3.5, 0,  0.0],
	["Land_HBarrier_1_F",          11.0,   5.0, 0,  0.0],
	["Land_HBarrier_1_F",          11.0,   6.5, 0,  0.0],
	["Land_HBarrier_1_F",           6.5,  10.0, 0, 90.0],
	["Land_HBarrier_1_F",           5.0,  10.0, 0, 90.0],
	["Land_HBarrier_1_F",           3.5,  10.0, 0, 90.0],
	["Land_HBarrier_1_F",           2.0,  10.0, 0, 90.0],
	["Land_HBarrier_1_F",           0.5,  10.0, 0, 90.0],
	["Land_HBarrier_1_F",          -1.0,  10.0, 0, 90.0],
	["Land_HBarrier_1_F",          -5.5,  10.0, 0, 90.0],
	["Land_HBarrier_1_F",          -7.0,  10.0, 0, 90.0],
	["Land_Camping_Light_F",        5.5,  -5.5, 0,  0.0],
	["Land_Camping_Light_F",       -5.5,   3.5, 0,  0.0],
	["Land_Camping_Light_F",        5.5,   3.5, 0,  0.0],
	["Land_Camping_Light_F",       -5.5,  -5.5, 0,  0.0],
	["Land_Camping_Light_F",       -2.75, -2.75, 0, 0.0],
	["Land_Camping_Light_F",       -2.75,  2.75, 0, 0.0],
	["Land_Camping_Light_F",        2.75,  2.75, 0, 0.0],
	["Land_Camping_Light_F",        2.75,  2.75, 1, 0.0]
];
// --DUWS-COMPOSITION END--

// Column 5 is the faction role holding the classname and column 0 is what that role resolves to on
// the stock faction. fnc_static_resolve prefers the role, so a mod's own GMG stands here rather than
// a vanilla one; the class is what the Eden import draws, so the ring is rearranged against the
// right silhouettes instead of against nothing. A row whose role the faction never fields falls to
// that faction's MG nest and then to its own class, which is what keeps this working mod-free.
// A gun added here in Eden carries no role column and is resolved by its class instead, so the ring
// follows the faction without anyone remembering to hand-add a sixth column after a round trip.
//
// The headings used to be computed radially from the centre. They are rows now because the export
// emits a heading per object: computed, a turret turned in the 3D editor would come back facing
// wherever the formula put it, and the round trip would silently drop half the edit.
// --DUWS-COMPOSITION BEGIN name="FOB Turrets" schema=A--
private _turretData = [
	["B_GMG_01_high_F",   9.0,   9.5, 0,  43.5],
	["B_GMG_01_high_F",  -8.5,   7.5, 0, 311.4],
	["B_static_AT_F",    -8.0,  -9.0, 0, 221.6],
	["B_HMG_01_high_F",   9.5,  -9.5, 0, 135.0]
];
// --DUWS-COMPOSITION END--

// One perimeter row, one object. The turrets go through fnc_static_place instead: a wall is the same
// wall whoever built it, while a gun is whatever the faction fields, and the perimeter stays
// simulated and invulnerable where the ring is frozen until it is crewed.
// Position is written twice around the rotation for the reason the composition deploy states:
// setDir displaces the object, so the heading has to be applied between two writes.
private _fnc_place = {
	params ["_row", "_key"];
	_row params ["_class", "_ox", "_oy", "_oz", "_dir"];
	private _pos = [(_centerPos select 0) + _ox, (_centerPos select 1) + _oy, _oz];
	private _obj = createVehicle [_class, [0,0,0], [], 0, "CAN_COLLIDE"];
	[_obj, _key] call fnc_duws_keep;
	_obj allowDamage false;
	_obj setPos _pos;
	_obj setDir _dir;
	_obj setPos _pos;
	_obj setDamage 0;
	_obj
};

private _turrets = [];
switch (VERSION_X) do {
	case "MODERN": {
		{
			// Invulnerable from the moment it stands up rather than from when its gunner arrives,
			// which is why the caller applies this and the placer does not: the ring is what the
			// player paid for, and the perimeter and roof AA below want their own answers.
			private _turret = [_x, _centerPos, "blufor", _fobKey, "pos"] call fnc_static_place;
			_turret allowDamage false;
			_turret setDamage 0;
			_turrets pushBack _turret;
		} forEach _turretData;

		// The one turret that is not a row: it stands on the FOB building's own roof, and
		// buildingPos is the only thing that knows where that is. A flat offset would put it at
		// ground level the first time the building were replaced with anything else.
		// Filed under the FOB key like the rest, so a teardown hands the whole ring over at once.
		// Its class still goes through the resolver, so the roof gun is drawn from the same pool and
		// gets the same type test as the ring; only its placement is its own.
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

sleep 50;
{ _x allowDamage false } forEach _turrets;

[_groupGuard, _centerPos] call bis_fnc_taskDefend;

_fob setVariable ["FOB_turrets", _turrets];

// Filed under the site as its emplacement occupant, so the freeze reaches the ring and not only the
// guards standing beside it. A turret is a vehicle with a full FSM, so five of them per FOB at up to
// floor(zones x 0.7) FOBs is the larger half of what a base costs while nobody is there.
//
// The FOB building and its props are deliberately not registered. Freezing a static building buys
// almost nothing, and it is the object carrying the base's action menu and its respawn point --
// a saving worth nothing is not worth putting those behind enableSimulationGlobal.
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
