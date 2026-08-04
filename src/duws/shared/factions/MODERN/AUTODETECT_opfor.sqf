// Locality: server -- compiled by fnc_factions_check from server/server_init.sqf:31; defines
// faction helpers rather than running logic of its own.
///////////
///////////	"OPF_F", "E X P E R I M E N T A L", "OPF_F_ARID"
///////////

// The retexture handler is installed once and never removed; the generation below re-runs every
// time the player re-picks a faction in the setup screens. Guarding the whole file instead would
// pin the first pick, and installing the handler per pass would retexture each spawned vehicle
// once per pass.
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

	// Pilots and crew are kept out of the combat buckets by fnc_unitParseRoles, which tests for
	// them first. This line is only about the basic rifleman: an officer or a parade-dress
	// variant is a poor stand-in for the man who fills out a patrol.
	_grunt = [_grunt, ["camo", "officer"], false] call fnc_filterByClassName;


// One ladder table for every role key, shared with AUTODETECT_RANDOM_opfor so the two cannot
// drift apart, and gated on the schema's kind so a class detection dropped in the wrong bucket
// cannot reach a spawner that will only ever createUnit a man or createVehicle a vehicle.
{ _x call fnc_faction_resolve } forEach [
#include "..\..\includes\autodetect_roles_opfor.hpp"
];


// make vars public - dedicated server compat
allVariables missionNamespace select { 
	"soldier_x" in toLowerANSI _x || 
	{"opfor_officer" in toLowerANSI _x} || 
	{"opfor_operator" in toLowerANSI _x} || 
	{"opfor_crew" in toLowerANSI _x} || 
	{"opfor_armed" in toLowerANSI _x} || 
	{"truck_x" in toLowerANSI _x} || 
	{"heli_x" in toLowerANSI _x} || 
	{"air_x" in toLowerANSI _x} || 
	{"apc_x" in toLowerANSI _x} || 
	{"opfor_apc" in toLowerANSI _x} || 
	{"opfor_mbt" in toLowerANSI _x} || 
	{"opfor_turret" in toLowerANSI _x} || 
	{"opfor_specops" in toLowerANSI _x} 
} apply { missionNamespace setVariable [_x, missionNamespace getVariable [_x, []], true] };

}; // end of function: fnc_factionGen
publicVariable "fnc_factionGen";

//selectRandom factionList select 1 call fnc_factionGen;

// The faction was chosen during setup (fnc_startup_faction_resolve) and broadcast
// as selectedFaction_OPF; generate its data now, at the deferred commit.
waitUntil { sleep 0.1; !isNil "selectedFaction_OPF" };
selectedFaction_OPF call fnc_factionGen;
sleep 0.5;

o_arraysToRandomize = (["opfor"] call fnc_faction_schema) apply {_x select 0};

// Pools published, not collapsed by a timer. See fnc_faction_pools for what the thread per
// role that used to sit here got wrong.
[o_arraysToRandomize] call fnc_faction_pools_publish;
sleep 1;
