// Locality: server -- compiled by fnc_factions_check from server/server_init.sqf:31; defines
// faction helpers rather than running logic of its own.

// Handler installed once, generation re-runs each re-pick. Guarding the file would pin the first
// pick; installing the handler per pass would retexture each vehicle once per pass.
if (isNil "opfor_autodetect_handler_init") then {
	opfor_autodetect_handler_init = true;

	// retexture opfor vehicles of a different side and redress crew
	addMissionEventHandler ["EntityCreated", {
		params ["_entity"];

		if (_entity isKindOf "Car" || {_entity isKindOf "Tank"} || {_entity isKindOf "Air"}) then {
			//systemChat str [ _entity, (typeOf _entity) call BIS_fnc_objectType, _entity isKindOf "LandVehicle"];
			[_entity, east] spawn fnc_vehiclePostInit;
		};

	}];
};


// fn_factionAutoDetect.sqf helpers are compiled once at init (fnc_factions_check).


fnc_factionGen = {
	_faction = _this;
	//systemChat str _faction;
	([_faction] call fnc_parseFaction) params ["_infantry","_infantryByRoles","_boat","_droneAir","_droneLand","_droneStatic","_submersible","_turretHMG","_turretGMG","_turretMortar","_turretAA","_turretAT","_apcWheeled","_apcTracked","_tank","_arty","_antiAir","_carArmed","_carTransport","_carRearm","_carRepair","_carRefuel","_heliArmed","_heliTransport","_planeArmed","_planeTransport"];
	
	_infantryByRoles params ["_grunt","_medic","_sl","_tl","_ar","_mg","_gl","_aa","_lat","_hat","_officer","_spec","_diver","_pilot","_crew","_marksman","_sniper","_eng","_exp","_uavOp"] +
							["_spec","_spec_medic","_spec_sl","_spec_tl","_spec_ar","_spec_mg","_spec_gl","_spec_aa","_spec_lat","_spec_hat","_spec_marksman","_spec_sniper","_spec_eng","_spec_exp"];

	// Pilots and crew are kept out of the combat buckets upstream (fnc_unitParseRoles tests them
	// first). This is only the basic rifleman: an officer or parade-dress variant fills a patrol poorly.
	_grunt = [_grunt, ["camo", "officer"], false] call fnc_filterByClassName;

	// Any static the faction fields, the last rung under every turret role: beats the vanilla
	// placeholder when no weapon bucket matched. Deduped -- a combo static lands in more than one bucket.
	private _turretAny = _turretHMG + _turretGMG + _turretMortar + _turretAA + _turretAT;
	_turretAny = _turretAny arrayIntersect _turretAny;


// One ladder table for every role key, shared with AUTODETECT_RANDOM_opfor so they cannot drift,
// and gated on the schema kind so a wrong-bucket detection cannot reach a man/vehicle spawner.
{ _x call fnc_faction_resolve } forEach [
#include "..\..\includes\autodetect_roles_opfor.hpp"
];


// Make vars public (dedicated-server compat) from the schema key list, not name-fragment matching
// (a fragment silently drops a role spelled off-pattern). No request catalogue, unlike BLUFOR. Mirrors AUTODETECT_blufor.
_publish = (["opfor"] call fnc_faction_schema) apply {_x select 0};
{ missionNamespace setVariable [_x, missionNamespace getVariable [_x, []], true] } forEach _publish;

}; // end of function: fnc_factionGen
publicVariable "fnc_factionGen";

//selectRandom factionList select 1 call fnc_factionGen;

// The faction was chosen during setup (fnc_startup_faction_resolve) and broadcast
// as selectedFaction_OPF; generate its data now, at the deferred commit.
waitUntil { sleep 0.1; !isNil "selectedFaction_OPF" };
selectedFaction_OPF call fnc_factionGen;
sleep 0.5;

o_arraysToRandomize = (["opfor"] call fnc_faction_schema) apply {_x select 0};

// Pools published, not collapsed by a timer. See fnc_faction_pools for what a thread per role gets wrong.
[o_arraysToRandomize] call fnc_faction_pools_publish;
sleep 1;
