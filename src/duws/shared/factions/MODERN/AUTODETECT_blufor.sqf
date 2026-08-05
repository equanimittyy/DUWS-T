// Locality: server -- compiled by fnc_factions_check from server/server_init.sqf:31; defines
// faction helpers rather than running logic of its own.
///////////
///////////	"BLU_F", "E X P E R I M E N T A L", "BLU_F_ARID"
///////////

// The retexture handler is installed once and never removed; the generation below re-runs every
// time the player re-picks a faction in the setup screens. Guarding the whole file instead would
// pin the first pick, and installing the handler per pass would retexture each spawned vehicle
// once per pass.
if (isNil "blufor_autodetect_handler_init") then {
	blufor_autodetect_handler_init = true;

	// retexture opfor vehicles of a different side and redress crew
	addMissionEventHandler ["EntityCreated", {
		params ["_entity"];

		if (_entity isKindOf "Car" || {_entity isKindOf "Tank"} || {_entity isKindOf "Air"}) then {
			//systemChat str [ _entity, (typeOf _entity) call BIS_fnc_objectType, _entity isKindOf "LandVehicle"];
			[_entity, west] spawn fnc_vehiclePostInit;
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

	// The armed-boat key wants a boat with a gun on it, which no detection bucket separates out.
	private _boatArmed = [_boat, true] call fnc_filterByWeapons;


// Every role key resolves through one ladder: the first bucket holding anything wins, gated on
// the schema's kind so a class detection dropped in the wrong bucket cannot reach a spawner.
// A rung is skipped when the faction has nothing in it, so the ladder reads as what the role
// degrades through. Fallbacks are vanilla NATO and apply only to a faction that fields nothing
// for the role at all. Trailing notes say what reads the key.
//
// Operators draw from the suppressed-weapon sets the role parser fills, then from the plain role.
// The old spelling was `_spec arrayIntersect _sl`, recomputed here per key; where it summed
// buckets it also rated, say, anti-air men equal to light AT for an anti-tank slot.
{ _x call fnc_faction_resolve } forEach [
	["blufor_SOLDIER_X",          [_grunt, _sl, _gl, _infantry],                          "B_Soldier_F"],      //patrol, fortify, paradrop
	["blufor_AA_SOLDIER_X",       [_aa, _hat, _lat, _grunt, _infantry],                   "B_soldier_AA_F"],   //shared team rosters
	["blufor_AR_SOLDIER_X",       [_ar, _mg, _grunt, _infantry],                          "B_Soldier_AR_F"],   //supports\fnc_paradrop, init_hq\fnc_HQguards
	["blufor_AT_SOLDIER_X",       [_hat, _lat, _aa, _grunt, _infantry],                   "B_soldier_AT_F"],   //shared team rosters
	["blufor_GL_SOLDIER_X",       [_gl, _grunt, _infantry],                               "B_Soldier_GL_F"],   //init_hq\fnc_HQguards, supports\fnc_paradrop
	["blufor_LAT_SOLDIER_X",      [_lat, _hat, _aa, _grunt, _infantry],                   "B_Soldier_LAT_F"],  //init_hq\fnc_HQguards, supports\fnc_paradrop
	["blufor_SL_SOLDIER_X",       [_sl, _tl, _officer, _grunt, _infantry],                "B_Soldier_SL_F"],   //Comms voice, Multiplayer slot
	["blufor_TL_SOLDIER_X",       [_tl, _sl, _grunt, _infantry],                          "B_Soldier_TL_F"],   //init_hq\fnc_HQguards
	["blufor_MARK_SOLDIER_X",     [_marksman, _sniper, _grunt, _infantry],                "B_soldier_M_F"],    //init_hq\fnc_HQguards
	["blufor_SNIPER_SOLDIER_X",   [_sniper, _marksman, _grunt, _infantry],                "B_sniper_F"],       //shared team rosters
	["blufor_OFFICER_X",          [_officer, _sl, _tl, _grunt, _infantry],                "B_OFFICER_F"],      //init_hq\fnc_BluHQinit

	["blufor_ARMED_CAR1_X",       [_carArmed, _apcWheeled, _carTransport],                "B_MRAP_01_hmg_F"],             //random patrol
	["blufor_APC1_X",             [_apcTracked, _apcWheeled, _carArmed],                  "B_APC_Tracked_01_rcws_F"],     //random patrol
	["blufor_APC2_X",             [_apcWheeled, _apcTracked, _carArmed],                  "B_APC_Wheeled_01_cannon_F"],   //random patrol
	["blufor_MBT_TANK1_X",        [_tank, _apcTracked, _apcWheeled],                      "B_MBT_01_cannon_F"],           //random patrol
	["blufor_TRANS_HELI_X",       [_heliTransport, _heliArmed],                           "B_Heli_Transport_03_unarmed_F"],   //random patrol
	["blufor_ATTACK_HELI_X",      [_heliArmed, _droneAir, _heliTransport],                "B_Heli_Attack_01_F"],          //dialog\fnc_request_hcATTchop, random patrol
	["blufor_MISC_AIR_X",         [_planeArmed, _droneAir],                               "B_Plane_CAS_01_F"],            //dialog\fnc_request_hcCAS, random patrol

	["blufor_TURRET_AA",          [_turretAA, _turretAT, _turretHMG],                     "B_static_AA_F"],
	["blufor_TURRET_AT",          [_turretAT, _turretAA, _turretHMG],                     "B_static_AT_F"],
	["blufor_TURRET_HMG",         [_turretHMG, _turretGMG],                               "B_HMG_01_high_F"],
	["blufor_TURRET_GMG",         [_turretGMG, _turretHMG],                               "B_GMG_01_high_F"],
	// The GMG rung before the MG one: a grenade launcher is the nearest thing a faction with no
	// tube has to arcing HE. Read by fnc_static_resolve, like the four above.
	["blufor_TURRET_MORTAR",      [_turretMortar, _turretGMG, _turretHMG],                "B_Mortar_01_F"],

	["blufor_SPECOPS_X",          [_spec_sl, _spec, _sl, _grunt, _infantry],              "B_recon_F"],
	["blufor_SPECOPS_GL_X",       [_spec_gl, _gl, _grunt, _infantry],                     "B_Soldier_GL_F"],
	["blufor_SPECOPS_LAT_X",      [_spec_lat, _lat, _hat, _grunt, _infantry],             "B_recon_LAT_F"],
	["blufor_SPECOPS_HAT_X",      [_spec_hat, _hat, _lat, _grunt, _infantry],             "B_soldier_AT_F"],
	["blufor_SPECOPS_AA_X",       [_spec_aa, _aa, _hat, _grunt, _infantry],               "B_soldier_AA_F"],
	["blufor_SPECOPS_MG_X",       [_spec_mg, _spec_ar, _mg, _ar, _grunt, _infantry],      "B_Soldier_AR_F"],
	["blufor_SPECOPS_MEDIC_X",    [_spec_medic, _medic, _grunt, _infantry],               "B_recon_medic_F"],
	["blufor_SPECOPS_MARK_X",     [_spec_marksman, _marksman, _sniper, _grunt],           "B_recon_M_F"],
	["blufor_SPECOPS_SNIPER_X",   [_spec_sniper, _sniper, _marksman, _grunt],             "B_sniper_F"],
	["blufor_SPECOPS_EXP_X",      [_spec_exp, _exp, _eng, _grunt, _infantry],             "B_recon_exp_F"],
	["blufor_SPECOPS_ENG_X",      [_spec_eng, _eng, _exp, _grunt, _infantry],             "B_engineer_F"],

	["blufor_HELI_PILOT_X",       [_pilot, _crew, _grunt],                                "B_Helipilot_F"],    //Rescue Pilot mission
	["blufor_BOAT_ARMED_X",       [_boatArmed],                                           "B_Boat_Armed_01_minigun_F"],   //supports\taxi\fnc_boatTaxi
	["blufor_BOAT_CREW_X",        [_crew],                                                "C_Man_UtilityWorker_01_F"],    //supports\taxi\fnc_boatTaxi
	["blufor_HELI_TRANS_ARM_X",   [_heliArmed, _heliTransport],                           "B_Heli_Transport_01_F"]        //supports\taxi\fnc_helotaxi
];




/////////////////////////////////////////////////////////////////
// REQUEST Units/Vehicles
//
// Ordered lists, no padding and no fixed length: the menus offer every entry in the order
// written here, so position in the list is the display order. A faction may list as many
// or as few as it has.
//
/////////////////////////////////////////////////////////////////

// REQUEST MENU defines labels/index for all request menu units/vehicles (not Operators)

// request_vehicle, request_vehicle_fob, request_unit, request_unit_fob 
// - these files contain the classnames referenced by the label/index


///////////////////////////////
// dialog\fnc_request_unit
//   _index = lbCurSel 2100;
// dialog\fnc_request_unit_fob
//   _index = lbCurSel 2120;
///////////////////////////////


// One class per menu row, or "" when the faction fields nothing for it: selectRandom on an empty
// list is nil, and a nil classname in a request row is an entry the player can buy and no spawner
// can raise. The empty rows are dropped below rather than offered.
private _pick = {
	private _c = _this call fnc_selectNonEmpty;
	if (_c isEqualType "") exitWith {_c};
	if (_c isEqualTo []) exitWith {""};
	selectRandom _c
};

blufor_RQST_UNITS = [
	[[_grunt, _infantry] call _pick,             "Rifleman (2CP)",2],
	[[_gl, _grunt, _infantry] call _pick,        "Grenadier (3CP)",3],
	[[_ar, _mg, _infantry] call _pick,           "Automatic Rifleman (3CP)",3],
	[[_mg, _ar, _infantry] call _pick,           "Heavy Gunner (4CP)",4],
	[[_medic, _grunt, _infantry] call _pick,     "Medic (4CP)",4],
	[[_lat, _hat, _infantry] call _pick,         "AT Rifleman (3CP)",3],
	[[_hat, _lat, _infantry] call _pick,         "AT Specialist (4CP)",4],
	[[_aa, _hat, _lat, _infantry] call _pick,    "AA Specialist (4CP)",4],
	[[_eng, _exp, _infantry] call _pick,         "Engineer (4CP)",4],
	[[_marksman, _grunt, _infantry] call _pick,  "Marksman (3CP)",3],
	[[_sniper, _marksman, _infantry] call _pick, "Sniper (4CP)",4]
];
blufor_RQST_UNITS = blufor_RQST_UNITS select { (_x select 0) != "" };


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////

blufor_RQST_VEHICLES = [["C_Quadbike_01_black_F","ATV (1CP)",1]];	// default first vehicle

_civilianVeh = ["C_Heli_Light_01_civil_F","C_Plane_Civil_01_F"
		,"C_Rubberboat","C_Boat_Transport_02_F"
		,"C_Offroad_01_F","C_Offroad_02_unarmed_F","C_SUV_01_F","C_Van_01_transport_F","C_Van_02_transport_F","C_Van_02_vehicle_F"
		,"C_Van_01_fuel_F","C_Offroad_01_repair_F","C_Van_02_medevac_F","C_Van_02_service_F","C_UAV_06_F","C_UAV_06_medical_F"]; // vehicles for factions without, appended to very end

requestAssets = [];
requestAssets append _droneAir;
requestAssets append _droneLand;
requestAssets append _carArmed;
requestAssets append _carTransport;
requestAssets append _carRearm;
requestAssets append _carRepair;
requestAssets append _carRefuel;
requestAssets append _apcWheeled;
requestAssets append _apcTracked;
requestAssets append _tank;
requestAssets append _antiAir;
requestAssets append _arty;
requestAssets append _heliTransport;
requestAssets append _heliArmed;
requestAssets append _planeArmed;
requestAssets append _planeTransport;
requestAssets append _boat;
requestAssets append _submersible;
requestAssets append _civilianVeh;
requestAssets = requestAssets arrayIntersect requestAssets;	// remove potential duplicates, very unlikely but...all the same


{
	
	_typeName = _x;
	_typeCost = _typeName call fnc_enumCost;
	_typeDisplayName = getText (configFile >> "CfgVehicles" >> _typeName >> "displayName");
	_typeCostFormatted = [_typeName, _typeDisplayName + ' (' + str(_typeCost) + 'CP)', _typeCost];
	blufor_RQST_VEHICLES pushBack _typeCostFormatted;
	
} forEach requestAssets;


// make vars public - dedicated server compat
//
// Named from the schema rather than matched on name fragments. The fragment list this replaces
// asked whether "blufor_soldier" appeared in the lowercased name, which silently stopped covering
// six keys the moment a role was spelled AR_SOLDIER_X rather than SOLDIER_AR_X -- a key that fails
// to publish leaves a dedicated server's clients holding whatever they had.
// The two request catalogues are appended because they are the one thing the schema deliberately
// does not carry: variable-length lists no one-row-per-key table can express.
_publish = ((["blufor"] call fnc_faction_schema) apply {_x select 0}) + ["blufor_RQST_UNITS", "blufor_RQST_VEHICLES"];
{ missionNamespace setVariable [_x, missionNamespace getVariable [_x, []], true] } forEach _publish;


}; // end of function: fnc_factionGen
publicVariable "fnc_factionGen";
//selectRandom factionList select 1 call fnc_factionGen;

// The faction was chosen during setup (fnc_startup_faction_resolve) and broadcast
// as selectedFaction_BLU; generate its data now, at the deferred commit.
waitUntil { sleep 0.1; !isNil "selectedFaction_BLU" };
selectedFaction_BLU call fnc_factionGen;
sleep 0.5;

b_arraysToRandomize = (["blufor"] call fnc_faction_schema) apply {_x select 0};

// Pools published, not collapsed by a timer. See fnc_faction_pools for what the thread per
// role that used to sit here got wrong.
[b_arraysToRandomize] call fnc_faction_pools_publish;
sleep 1;
// The five-minute squad rebuild that used to sit here went with the re-pick it was chasing: it
// existed to fold newly drawn role classnames into the purchasable squads. server_init calls
// fnc_BLUFOR_squad_init once, which is right for a catalogue -- a price list that reshuffles under
// the player mid-purchase is worse than a stable one.
