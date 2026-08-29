// Locality: server -- compiled by fnc_factions_check from server/server_init.sqf:31; defines
// faction helpers rather than running logic of its own.

// Handler installed once, generation re-runs each re-pick. Guarding the file would pin the first
// pick; installing the handler per pass would retexture each vehicle once per pass.
if (isNil "blufor_autodetect_handler_init") then {
	blufor_autodetect_handler_init = true;

	// retexture opfor vehicles of a different side and redress crew
	addMissionEventHandler ["EntityCreated", {
		params ["_entity"];

		if (_entity isKindOf "Car" || {_entity isKindOf "Tank"} || {_entity isKindOf "Air"}) then {
			[_entity, west] spawn fnc_vehiclePostInit;
		};

	}];
};


// fn_factionAutoDetect.sqf helpers are compiled once at init (fnc_factions_check).


fnc_factionGen = {
	_faction = _this;
	([_faction] call fnc_parseFaction) params ["_infantry","_infantryByRoles","_boat","_droneAir","_droneLand","_droneStatic","_submersible","_turretHMG","_turretGMG","_turretMortar","_turretAA","_turretAT","_apcWheeled","_apcTracked","_tank","_arty","_antiAir","_carArmed","_carTransport","_carRearm","_carRepair","_carRefuel","_heliArmed","_heliTransport","_planeArmed","_planeTransport"];
	
	_infantryByRoles params ["_grunt","_medic","_sl","_tl","_ar","_mg","_gl","_aa","_lat","_hat","_officer","_spec","_diver","_pilot","_crew","_marksman","_sniper","_eng","_exp","_uavOp"] +
							["_spec","_spec_medic","_spec_sl","_spec_tl","_spec_ar","_spec_mg","_spec_gl","_spec_aa","_spec_lat","_spec_hat","_spec_marksman","_spec_sniper","_spec_eng","_spec_exp"];

	// Pilots and crew are kept out of the combat buckets upstream (fnc_unitParseRoles tests them
	// first). This is only the basic rifleman: an officer or parade-dress variant fills a patrol poorly.
	_grunt = [_grunt, ["camo", "officer"], false] call fnc_filterByClassName;

	// The armed-boat key wants a boat with a gun on it, which no detection bucket separates out.
	private _boatArmed = [_boat, true] call fnc_filterByWeapons;

	// Any static the faction fields, the last rung under every turret role: beats the vanilla
	// placeholder when no weapon bucket matched. Deduped -- a combo static lands in more than one bucket.
	private _turretAny = _turretHMG + _turretGMG + _turretMortar + _turretAA + _turretAT;
	_turretAny = _turretAny arrayIntersect _turretAny;


// Every role key resolves through one ladder: first non-empty bucket wins, gated on schema kind so a
// wrong-bucket class can't reach a spawner; empty rungs skip, so the row reads as the degrade path.
// vanillaDefault (NATO fallback) is appended by fnc_faction_resolve, so rows carry none. Operators
// recompute per key, not one `_spec arrayIntersect _sl` -- that would sum buckets and misrate the slot.
{ _x call fnc_faction_resolve } forEach [
	["blufor_SOLDIER_X",          [_grunt, _sl, _gl, _infantry]],      //patrol, fortify, paradrop
	["blufor_AA_SOLDIER_X",       [_aa, _hat, _lat, _grunt, _infantry]],   //shared team rosters
	["blufor_AR_SOLDIER_X",       [_ar, _mg, _grunt, _infantry]],   //supports\fnc_paradrop, init_hq\fnc_HQguards
	["blufor_AT_SOLDIER_X",       [_hat, _lat, _aa, _grunt, _infantry]],   //shared team rosters
	["blufor_GL_SOLDIER_X",       [_gl, _grunt, _infantry]],   //init_hq\fnc_HQguards, supports\fnc_paradrop
	["blufor_LAT_SOLDIER_X",      [_lat, _hat, _aa, _grunt, _infantry]],  //init_hq\fnc_HQguards, supports\fnc_paradrop
	["blufor_SL_SOLDIER_X",       [_sl, _tl, _officer, _grunt, _infantry]],   //Comms voice, Multiplayer slot
	["blufor_TL_SOLDIER_X",       [_tl, _sl, _grunt, _infantry]],   //init_hq\fnc_HQguards
	["blufor_MARK_SOLDIER_X",     [_marksman, _sniper, _grunt, _infantry]],    //init_hq\fnc_HQguards
	["blufor_SNIPER_SOLDIER_X",   [_sniper, _marksman, _grunt, _infantry]],       //shared team rosters
	["blufor_OFFICER_X",          [_officer, _sl, _tl, _grunt, _infantry]],      //init_hq\fnc_BluHQinit

	["blufor_ARMED_CAR1_X",       [_carArmed, _apcWheeled, _carTransport]],             //random patrol
	["blufor_APC1_X",             [_apcTracked, _apcWheeled, _carArmed]],     //random patrol
	["blufor_APC2_X",             [_apcWheeled, _apcTracked, _carArmed]],   //random patrol
	["blufor_MBT_TANK1_X",        [_tank, _apcTracked, _apcWheeled]],           //random patrol
	["blufor_TRANS_HELI_X",       [_heliTransport, _heliArmed]],   //random patrol
	["blufor_ATTACK_HELI_X",      [_heliArmed, _droneAir, _heliTransport]],          //dialog\fnc_request_hcATTchop, random patrol
	["blufor_MISC_AIR_X",         [_planeArmed, _droneAir]],            //dialog\fnc_request_hcCAS, random patrol

	["blufor_TURRET_AA",          [_turretAA, _turretAT, _turretHMG, _turretAny]],
	["blufor_TURRET_AT",          [_turretAT, _turretAA, _turretHMG, _turretAny]],
	["blufor_TURRET_HMG",         [_turretHMG, _turretGMG, _turretAny]],
	["blufor_TURRET_GMG",         [_turretGMG, _turretHMG, _turretAny]],
	// The GMG rung before the MG one: a grenade launcher is the nearest thing a faction with no
	// tube has to arcing HE. Read by fnc_static_resolve, like the four above.
	["blufor_TURRET_MORTAR",      [_turretMortar, _turretGMG, _turretHMG, _turretAny]],

	["blufor_SPECOPS_X",          [_spec_sl, _spec, _sl, _grunt, _infantry]],
	["blufor_SPECOPS_GL_X",       [_spec_gl, _gl, _grunt, _infantry]],
	["blufor_SPECOPS_LAT_X",      [_spec_lat, _lat, _hat, _grunt, _infantry]],
	["blufor_SPECOPS_HAT_X",      [_spec_hat, _hat, _lat, _grunt, _infantry]],
	["blufor_SPECOPS_AA_X",       [_spec_aa, _aa, _hat, _grunt, _infantry]],
	["blufor_SPECOPS_MG_X",       [_spec_mg, _spec_ar, _mg, _ar, _grunt, _infantry]],
	["blufor_SPECOPS_MEDIC_X",    [_spec_medic, _medic, _grunt, _infantry]],
	["blufor_SPECOPS_MARK_X",     [_spec_marksman, _marksman, _sniper, _grunt]],
	["blufor_SPECOPS_SNIPER_X",   [_spec_sniper, _sniper, _marksman, _grunt]],
	["blufor_SPECOPS_EXP_X",      [_spec_exp, _exp, _eng, _grunt, _infantry]],
	["blufor_SPECOPS_ENG_X",      [_spec_eng, _eng, _exp, _grunt, _infantry]],

	["blufor_HELI_PILOT_X",       [_pilot, _crew, _grunt]],    //Rescue Pilot mission
	["blufor_BOAT_ARMED_X",       [_boatArmed]],   //supports\taxi\fnc_boatTaxi
	["blufor_BOAT_CREW_X",        [_crew]],    //supports\taxi\fnc_boatTaxi
	["blufor_HELI_TRANS_ARM_X",   [_heliArmed, _heliTransport]]        //supports\taxi\fnc_helotaxi
];




// REQUEST Units/Vehicles -- ordered, variable-length lists (written order = display order): labels/index
// for request-menu units/vehicles, not Operators; the request_(vehicle|unit)(_fob) globals hold the classnames.


// One class per menu row, or "" when the faction fields nothing: selectRandom on [] is nil, and a nil
// classname is a buyable row no spawner can raise, so the empty rows are dropped below, not offered.
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


// dialog\fnc_request_vehicle uses _index = lbCurSel 2102; dialog\fnc_request_vehicle_fob uses lbCurSel 2122.

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
	_typeCost = [_typeName] call DUWS_fnc_vehPrice;
	_typeDisplayName = getText (configFile >> "CfgVehicles" >> _typeName >> "displayName");
	_typeCostFormatted = [_typeName, _typeDisplayName + ' (' + str(_typeCost) + 'CP)', _typeCost];
	blufor_RQST_VEHICLES pushBack _typeCostFormatted;
	
} forEach requestAssets;


// Make vars public (dedicated-server compat) from the schema key list, not name-fragment matching (a
// fragment silently drops a role spelled off-pattern). The two request catalogues, which the schema cannot carry, are appended.
_publish = ((["blufor"] call fnc_faction_schema) apply {_x select 0}) + ["blufor_RQST_UNITS", "blufor_RQST_VEHICLES"];
{ missionNamespace setVariable [_x, missionNamespace getVariable [_x, []], true] } forEach _publish;


}; // end of function: fnc_factionGen
publicVariable "fnc_factionGen";

// The faction was chosen during setup (fnc_startup_faction_resolve) and broadcast as
// selectedFaction_BLU; generate its data now, at the deferred commit.
waitUntil { sleep 0.1; !isNil "selectedFaction_BLU" };
selectedFaction_BLU call fnc_factionGen;
sleep 0.5;

b_arraysToRandomize = (["blufor"] call fnc_faction_schema) apply {_x select 0};

// Pools published, not collapsed by a timer. See fnc_faction_pools for what a thread per role gets wrong.
[b_arraysToRandomize] call fnc_faction_pools_publish;
sleep 1;
// No timed squad rebuild folding newly drawn classnames into the purchasable squads: server_init calls
// fnc_BLUFOR_squad_init once -- a price list reshuffling under the player mid-purchase is worse than stable.
