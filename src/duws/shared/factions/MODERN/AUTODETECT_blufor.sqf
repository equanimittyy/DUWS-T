// Locality: server -- compiled by fnc_factions_check from server/server_init.sqf:31; defines
// faction helpers rather than running logic of its own.

[west] call fnc_autodetect_watchVehicles;


// fn_factionAutoDetect.sqf helpers are compiled once at init (fnc_factions_check).


fnc_factionGen = {
	_faction = _this;
	private _parsed = [_faction] call fnc_parseFaction;
	_parsed params ["_infantry","_infantryByRoles","_boat","_droneAir","_droneLand","_droneStatic","_submersible","_turretHMG","_turretGMG","_turretMortar","_turretAA","_turretAT","_apcWheeled","_apcTracked","_tank","_arty","_antiAir","_carArmed","_carTransport","_carRearm","_carRepair","_carRefuel","_heliArmed","_heliTransport","_planeArmed","_planeTransport","_heliDoorGun","_boatArmed","_droneAirArmed"];
	
	_infantryByRoles params ["_grunt","_medic","_sl","_tl","_ar","_mg","_gl","_aa","_lat","_hat","_officer","_spec","_diver","_pilot","_crew","_marksman","_sniper","_eng","_exp","_uavOp"] +
							["_spec","_spec_medic","_spec_sl","_spec_tl","_spec_ar","_spec_mg","_spec_gl","_spec_aa","_spec_lat","_spec_hat","_spec_marksman","_spec_sniper","_spec_eng","_spec_exp"];

{ _x call fnc_faction_resolve } forEach (["blufor", _parsed] call fnc_faction_ladders);




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
requestAssets append _heliDoorGun;
requestAssets append _heliArmed;
requestAssets append _planeArmed;
requestAssets append _planeTransport;
requestAssets append _boat;
requestAssets append _boatArmed;
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
