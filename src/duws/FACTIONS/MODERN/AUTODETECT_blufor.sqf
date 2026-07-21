///////////
///////////	"BLU_F", "E X P E R I M E N T A L", "BLU_F_ARID"
///////////

if (!isNil "blufor_autodetect_faction_init") exitWith {};	// prevent duplicate instantiation

// retexture opfor vehicles of a different side and redress crew
addMissionEventHandler ["EntityCreated", {
	params ["_entity"];
	
	if (_entity isKindOf "Car" || {_entity isKindOf "Tank"} || {_entity isKindOf "Air"}) then {
		//systemChat str [ _entity, (typeOf _entity) call BIS_fnc_objectType, _entity isKindOf "LandVehicle"];
		[_entity, west] spawn fnc_vehiclePostInit;
	};
	
}];


#include "fn_factionAutoDetect.sqf"


// ========== 新增：过滤飞行员/乘员的通用函数 ==========
fnc_filterPilotCrew = {
	params ["_array", ["_extraKeywords", []]];
	private _keywords = ["pilot", "crew", "driver", "officer", "helipilot", "aircrew", "pilot_", "_pilot", "_crew"] + _extraKeywords;
	[_array, _keywords, false] call fnc_filterByClassName
};


_factions = (call BIS_fnc_getFactions) select {
	getNumber (configFile >> "CfgFactionClasses" >> _x >> "side") in [0,1,2] &&  
	!(getNumber (configFile >> "CfgFactionClasses" >> _x >> "priority") in [4])
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

	// ========== 过滤掉所有普通步兵角色中的飞行员/乘员 ==========
	private _filter = {
		params ["_arr"];
		if (_arr isEqualTo []) exitWith {[]};
		[_arr] call fnc_filterPilotCrew
	};

	_grunt = [_grunt] call _filter;
	_medic = [_medic] call _filter;
	_sl = [_sl] call _filter;
	_tl = [_tl] call _filter;
	_ar = [_ar] call _filter;
	_mg = [_mg] call _filter;
	_gl = [_gl] call _filter;
	_aa = [_aa] call _filter;
	_lat = [_lat] call _filter;
	_hat = [_hat] call _filter;
	_officer = [_officer] call _filter;
	_spec = [_spec] call _filter;
	_diver = [_diver] call _filter;
	_marksman = [_marksman] call _filter;
	_sniper = [_sniper] call _filter;
	_eng = [_eng] call _filter;
	_exp = [_exp] call _filter;
	_uavOp = [_uavOp] call _filter;

	_spec_medic = [_spec_medic] call _filter;
	_spec_sl = [_spec_sl] call _filter;
	_spec_tl = [_spec_tl] call _filter;
	_spec_ar = [_spec_ar] call _filter;
	_spec_mg = [_spec_mg] call _filter;
	_spec_gl = [_spec_gl] call _filter;
	_spec_aa = [_spec_aa] call _filter;
	_spec_lat = [_spec_lat] call _filter;
	_spec_hat = [_spec_hat] call _filter;
	_spec_marksman = [_spec_marksman] call _filter;
	_spec_sniper = [_spec_sniper] call _filter;
	_spec_eng = [_spec_eng] call _filter;
	_spec_exp = [_spec_exp] call _filter;
	// ========== 过滤结束 ==========

	_grunt = [_grunt, ["pilot", "crew", "camo", "officer"], false] call fnc_filterByClassName;

	diag_log format ["Populating faction data: %1", _grunt];

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				[_grunt, _sl + _gl, _infantry] call fnc_selectNonEmpty;					//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =		[_lat, _hat, _aa + _infantry] call fnc_selectNonEmpty;				//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			[_gl, _grunt, _infantry] call fnc_selectNonEmpty;				//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			[_tl, _sl, _grunt] call fnc_selectNonEmpty;				//initHQ\fnc_createpatrolFOB, initHQ\fnc_HQguards
blufor_SOLDIER_SL_X =			[_sl, _tl, _grunt] call fnc_selectNonEmpty;				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			[_ar, _mg, _infantry] call fnc_selectNonEmpty;				//supports\fnc_paradrop, initHQ\fnc_HQguards
blufor_MARKSMAN_X =			 [_marksman, _grunt, _infantry] call fnc_selectNonEmpty;				//initHQ\fnc_HQguards
blufor_OFFICER_X =				[_officer, _sl, _infantry] call fnc_selectNonEmpty;					//initHQ\fnc_BluHQinit
blufor_HELI_PILOT_X	=			[_pilot, _crew, "C_Man_pilot_F"] call fnc_selectNonEmpty;				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"_boat_Armed_01_hmg_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"C_Man_UtilityWorker_01_F";		//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		[_heliArmed, _heliTransport, ["I_Heli_light_03_unarmed_F", "I_Heli_light_03_unarmed_F"]] call fnc_selectNonEmpty;		//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		[_heliTransport, _heliTransport, ["I_Heli_light_03_unarmed_F", "I_Heli_light_03_unarmed_F"]] call fnc_selectNonEmpty;		   //random patrol
blufor_HELI_ATTACK_X =			[_heliArmed, _heliArmed, ["I_C_Heli_Light_01_Civil_F", "I_C_Heli_Light_01_Civil_F", "I_C_Heli_Light_01_Civil_F"]] call fnc_selectNonEmpty;	//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			[_planeArmed, _planeArmed, ["I_C_Plane_Civil_01_F", "I_C_Plane_Civil_01_F", "I_C_Plane_Civil_01_F"]] call fnc_selectNonEmpty;		//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			[_carArmed, _apcWheeled, ["I_G_Offroad_01_armed_F", "I_G_Offroad_01_armed_F", "I_G_Offroad_01_armed_F", "I_G_Offroad_01_armed_F"]] call fnc_selectNonEmpty;						//random patrol
blufor_APC_PATROL1_X =			[_apcTracked, _apcWheeled, ["I_C_Offroad_02_LMG_F"]] call fnc_selectNonEmpty;			//random patrol
blufor_APC_PATROL2_X =			[_apcWheeled, _apcTracked, ["I_C_Offroad_01_AT_F"]] call fnc_selectNonEmpty;			//random patrol
blufor_TANK_PATROL1_X =			[_tank, _tank, ["I_C_Offroad_02_AT_F"]] call fnc_selectNonEmpty;					//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA =				[_turretAA, "B_static_AA_F"] call fnc_selectNonEmpty;
blufor_TURRET_AT =				[_turretAT, "B_static_AT_F"] call fnc_selectNonEmpty;
blufor_TURRET_HMG =				[_turretHMG, "B_HMG_01_high_F"] call fnc_selectNonEmpty;
blufor_TURRET_GMG =				[_turretGMG, "B_GMG_01_high_F"] call fnc_selectNonEmpty;


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =			[_spec arrayIntersect _sl,  _sl, _infantry] call fnc_selectNonEmpty;					//operator
blufor_SPECOPS_GL_X =			[_spec arrayIntersect _gl,  _gl, _infantry] call fnc_selectNonEmpty;				//operator
blufor_SPECOPS_LAT_X =			[_spec arrayIntersect _lat,  _hat, _infantry] call fnc_selectNonEmpty;				//operator
blufor_SPECOPS_HAT_X =			[_spec arrayIntersect _hat,  _hat, _infantry] call fnc_selectNonEmpty;				//operator
blufor_SPECOPS_AA_X =			[_spec arrayIntersect _aa,  _aa, _infantry] call fnc_selectNonEmpty;				//operator
blufor_SPECOPS_MG_X =			[_spec arrayIntersect _mg,  _mg, _infantry] call fnc_selectNonEmpty;				//operator
blufor_SPECOPS_MEDIC_X =		[_spec arrayIntersect _medic,  _medic, _infantry] call fnc_selectNonEmpty;				//operator
blufor_SPECOPS_MARK_X =			[_spec arrayIntersect _marksman,  _marksman, _infantry] call fnc_selectNonEmpty;					//operator
blufor_SPECOPS_SNIPER_X =		[_spec arrayIntersect _sniper, _sniper, _infantry] call fnc_selectNonEmpty;					//operator
blufor_SPECOPS_EXP_X =			[_spec arrayIntersect _exp, _exp, _infantry] call fnc_selectNonEmpty;				//operator
blufor_SPECOPS_ENG_X =			[_spec arrayIntersect _eng, _eng, _infantry] call fnc_selectNonEmpty;					//operator




/////////////////////////////////////////////////////////////////
// REQUEST Units/Vehicles
//
// THESE HAVE FIXED AMOUNTS -fill the ends with ["empty",0,0];
//
// - Units =				 14
// - Vehicles/Statics =	 50
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


blufor_RQST_UNIT_01_X =				[selectRandom flatten [[_grunt, _grunt, _infantry] call fnc_selectNonEmpty],"Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				[selectRandom flatten [[_gl, _grunt, _infantry] call fnc_selectNonEmpty],"Grenadier (3CP)",3];
blufor_RQST_UNIT_03_X =				[selectRandom flatten [[_ar, _mg, _infantry] call fnc_selectNonEmpty],"Automatic Rifleman (3CP)",3];
blufor_RQST_UNIT_04_X =				[selectRandom flatten [[_mg, _ar, _infantry] call fnc_selectNonEmpty],"Heavy Gunner (4CP)",4];
blufor_RQST_UNIT_05_X =				[selectRandom flatten [[_medic,  _grunt, _infantry] call fnc_selectNonEmpty],"Medic (4CP)",4];
blufor_RQST_UNIT_06_X =				[selectRandom flatten [[_lat, _hat, _infantry] call fnc_selectNonEmpty],"AT Rifleman (3CP)",3];
blufor_RQST_UNIT_07_X =				[selectRandom flatten [[_hat, _lat, _infantry] call fnc_selectNonEmpty],"AT Specialist (4CP)",4];
blufor_RQST_UNIT_08_X =				[selectRandom flatten [[_aa, _hat + _lat, _infantry] call fnc_selectNonEmpty],"AA Specialist (4CP)",4];
blufor_RQST_UNIT_09_X =				[selectRandom flatten [[_eng, _exp, _infantry] call fnc_selectNonEmpty],"Engineer (4CP)",4];
blufor_RQST_UNIT_10_X =				[selectRandom flatten [[_marksman, _grunt, _infantry] call fnc_selectNonEmpty],"Marksman (3CP)",3];
blufor_RQST_UNIT_11_X =				[selectRandom flatten [[_sniper, _marksman, _infantry] call fnc_selectNonEmpty],"Sniper (4CP)",4];
blufor_RQST_UNIT_12_X =				["empty",0,0];
blufor_RQST_UNIT_13_X =				["empty",0,0];
blufor_RQST_UNIT_14_X =				["empty",0,0];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////

blufor_RQST_VEHICLE_01_X =			["C_Quadbike_01_black_F","ATV (1CP)",1];	// default first vehicle

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
	_requestName = "blufor_RQST_VEHICLE_" + ((_forEachIndex + 2) call fnc_padZero) + "_X";
	missionNamespace setVariable [_requestName, _typeCostFormatted];
	
} forEach requestAssets;


// make vars public - dedicated server compat
allVariables missionNamespace select {
	"blufor_rqst" in toLowerANSI _x || 
	{"blufor_soldier" in toLowerANSI _x} || 
	{"blufor_marksman" in toLowerANSI _x} || 
	{"blufor_officer" in toLowerANSI _x} || 
	{"blufor_heli" in toLowerANSI _x} || 
	{"blufor_plane" in toLowerANSI _x} || 
	{"blufor_boat" in toLowerANSI _x} || 
	{"blufor_car" in toLowerANSI _x} || 
	{"blufor_apc" in toLowerANSI _x} || 
	{"blufor_tank" in toLowerANSI _x} || 
	{"blufor_turret" in toLowerANSI _x} || 
	{"blufor_specops" in toLowerANSI _x} 
} apply { missionNamespace setVariable [_x, missionNamespace getVariable [_x, []], true] };


}; // end of function: fnc_factionGen
publicVariable "fnc_factionGen";
//selectRandom factionList select 1 call fnc_factionGen;

// init selection vars
selectedFaction = nil;
selectionDone = nil;
publicVariable "selectedFaction";
publicVariable "selectionDone";

// Listbox
_admin = objNull;
if (!isDedicated) then {
	["Select Blufor Faction"] call  fnc_factionSelector;
} else {
	diag_log format ["Waiting for adming to select autodetected faction"];
	
	waitUntil { {admin owner _x > 0 || {_x isEqualTo player1}} count allPlayers > 0 };	// wait for admin
	_admin = allPlayers select {admin owner _x > 0 || {_x isEqualTo player1}} select 0;
	diag_log format ["Admin %1 logged in, sending dialog", name _admin];
	sleep 0.5;
	["Select Blufor Faction"] remoteExec ["fnc_factionSelector", _admin];

	diag_log format ["Admin %1 selected blufor faction: %2", name _admin, selectedFaction];
};

waitUntil { !isNil "selectionDone" };	// selectedFaction
sleep 0.5;

// use predefined array for improved performance
b_arraysToRandomize = [
	"blufor_SOLDIER_X",
	"blufor_SOLDIER_LAT_X",
	"blufor_SOLDIER_GL_X",
	"blufor_SOLDIER_TL_X",
	"blufor_SOLDIER_SL_X",
	"blufor_SOLDIER_AR_X",
	"blufor_MARKSMAN_X",
	"blufor_OFFICER_X",
	"blufor_HELI_PILOT_X",
	"blufor_BOAT_ARMED_X",
	"blufor_BOAT_CREW_X",
	"blufor_HELI_TRANS_ARM_X",
	"blufor_HELI_TRANS_UNARM_X",
	"blufor_HELI_ATTACK_X",
	"blufor_PLANE_CAS_X",
	"blufor_CAR_PATROL1_X",
	"blufor_APC_PATROL1_X",
	"blufor_APC_PATROL2_X",
	"blufor_TANK_PATROL1_X",
	"blufor_TURRET_AA",
	"blufor_TURRET_AT",
	"blufor_TURRET_HMG",
	"blufor_TURRET_GMG",
	"blufor_SPECOPS_X",
	"blufor_SPECOPS_GL_X",
	"blufor_SPECOPS_LAT_X",
	"blufor_SPECOPS_HAT_X",
	"blufor_SPECOPS_AA_X",
	"blufor_SPECOPS_MG_X",
	"blufor_SPECOPS_MEDIC_X",
	"blufor_SPECOPS_MARK_X",
	"blufor_SPECOPS_SNIPER_X",
	"blufor_SPECOPS_EXP_X",
	"blufor_SPECOPS_ENG_X"
];

// randomise faction data, place holder until duws has similar functionality
{
	// transform vars defined in faction files to str if array
	_factionUnitVarName = _x;													// ex. blufor_SOLDIER_LAT_X
	_factionUnitVarData = missionNamespace getVariable _factionUnitVarName;	    // ex. ["B_Soldier_LAT_F", "B_Soldier_GL_F", "B_Soldier_TL_F"] or "B_Soldier_F"
	if (typeName _factionUnitVarData == "ARRAY") then {

		// schedule var randomization every N sec
		[_factionUnitVarData, _factionUnitVarName] spawn {
			scriptName "Random Unit Type Selector for Units Defined As Arrays";
			params ["_factionUnitVarData", "_factionUnitVarName"];
			while{true} do {
				_randomSelection = selectRandom _factionUnitVarData;
				// blufor randomization broadcast across network incl JIP
				missionNamespace setVariable [_factionUnitVarName, ( if (isNil {_randomSelection}) then [{ "" }, { _randomSelection }] ), true];
				sleep 300; 
			};
		};		
	};
} forEach b_arraysToRandomize;
sleep 1;
[] spawn {
	scriptName "reinit/randomize blufor squads periodically - every 5 minutes";
	while{sleep 300.00; true} do {
		[] call fnc_BLUFOR_squad_init;
	};
};

blufor_autodetect_faction_init = true;
publicVariable "blufor_autodetect_faction_init";