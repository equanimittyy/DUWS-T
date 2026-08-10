// Locality: server -- compiled by fnc_factions_check from server/server_init.sqf:31; defines
// faction helpers rather than running logic of its own.
///////////
///////////	"OPF_F", "E X P E R I M E N T A L", "OPF_F_ARID"
///////////

// Handler installed once, generation re-run every pass -- see AUTODETECT_opfor.sqf. The guard is
// shared with that file because both wrappers install the same handler for the same side.
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


// Same filter the AutoDetect picker applies: the roll draws from the zombie factions in the
// apocalypse mode and from everything else in the others, so a random OPFOR can never be zombies in
// a campaign that is not about them -- nor an army in one that is.
_wantZombies = (missionNamespace getVariable ["duws_gamemode", "duws"]) isEqualTo "apocalypse";

_factions = (call BIS_fnc_getFactions) select {
	getNumber (configFile >> "CfgFactionClasses" >> _x >> "side") in [0,1,2] &&
	!(getNumber (configFile >> "CfgFactionClasses" >> _x >> "priority") in [4]) &&
	{([_x] call fnc_factionIsZombie) isEqualTo _wantZombies}
};

_factions2d = (_factions apply {[getText (configFile >> "CfgFactionClasses" >> _x >> "displayName"), _x]} select { _x#0 != "" });
factionList = [];
{ if !( _x#0 in flatten factionList ) then { factionList append [_x]} } forEach _factions2d;	// sanitize factions with multiple sides (duplicates)
factionList;	// for listbox

//_factionData = ("(gettext (_x >> 'faction') == _faction ) && !('base' in toLower configname _x)" configClasses (configfile >> "CfgVehicles")) apply {configName _x};
//[_faction, [_factionData, "apcs"] call fnc_factionGetFiltered ];

 
fnc_factionGen = {
	_faction = _this;
	//systemChat str _faction;
	([_faction] call fnc_parseFaction) params ["_infantry","_infantryByRoles","_boat","_droneAir","_droneLand","_droneStatic","_submersible","_turretHMG","_turretGMG","_turretMortar","_turretAA","_turretAT","_apcWheeled","_apcTracked","_tank","_arty","_antiAir","_carArmed","_carTransport","_carRearm","_carRepair","_carRefuel","_heliArmed","_heliTransport","_planeArmed","_planeTransport"];
	
	_infantryByRoles params ["_grunt","_medic","_sl","_tl","_ar","_mg","_gl","_aa","_lat","_hat","_officer","_spec","_diver","_pilot","_crew","_marksman","_sniper","_eng","_exp","_uavOp"] +
							["_spec","_spec_medic","_spec_sl","_spec_tl","_spec_ar","_spec_mg","_spec_gl","_spec_aa","_spec_lat","_spec_hat","_spec_marksman","_spec_sniper","_spec_eng","_spec_exp"];

	// Pilots and crew are kept out of the combat buckets by fnc_unitParseRoles, which tests for
	// them first. This line is only about the basic rifleman.
	_grunt = [_grunt, ["camo", "officer"], false] call fnc_filterByClassName;

	// Any static the faction fields, as the last rung under every turret role: a mod static that
	// matched no specific weapon bucket still beats the vanilla placeholder. Deduped -- a combo static
	// can land in more than one bucket.
	private _turretAny = _turretHMG + _turretGMG + _turretMortar + _turretAA + _turretAT;
	_turretAny = _turretAny arrayIntersect _turretAny;


// The same ladder table AUTODETECT_opfor resolves: the two files differ in how the faction is
// chosen, not in what a role means once it is.
{ _x call fnc_faction_resolve } forEach [
#include "..\..\includes\autodetect_roles_opfor.hpp"
];

};


selectRandom factionList select 1 call fnc_factionGen;


o_arraysToRandomize = (["opfor"] call fnc_faction_schema) apply {_x select 0};


// Pools published, not collapsed by a timer. See fnc_faction_pools for what the thread per
// role that used to sit here got wrong.
[o_arraysToRandomize] call fnc_faction_pools_publish;
sleep 1;
