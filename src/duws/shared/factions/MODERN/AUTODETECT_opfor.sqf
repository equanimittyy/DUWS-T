// Locality: server -- compiled by fnc_factions_check from init/server_init.sqf:31; defines
// faction helpers rather than running logic of its own.
///////////
///////////	"OPF_F", "E X P E R I M E N T A L", "OPF_F_ARID"
///////////

if (!isNil "opfor_autodetect_faction_init") exitWith {};	// prevent duplicate instantiation

// retexture opfor vehicles of a different side and redress crew
addMissionEventHandler ["EntityCreated", {
	params ["_entity"];
	
	if (_entity isKindOf "Car" || {_entity isKindOf "Tank"} || {_entity isKindOf "Air"}) then {
		//systemChat str [ _entity, (typeOf _entity) call BIS_fnc_objectType, _entity isKindOf "LandVehicle"];
		[_entity, east] spawn fnc_vehiclePostInit;
	};
	
}];


// fn_factionAutoDetect.sqf helpers are compiled once at init (fnc_factions_check).


// ========== 新增：过滤飞行员/乘员的通用函数 ==========
fnc_filterPilotCrew = {
	params ["_array", ["_extraKeywords", []]];
	private _keywords = ["pilot", "crew", "driver", "officer", "helipilot", "aircrew", "pilot_", "_pilot", "_crew"] + _extraKeywords;
	[_array, _keywords, false] call fnc_filterByClassName
};


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


opfor_SOLDIER_X =				[_grunt, _infantry] call fnc_selectNonEmpty;					//Basic Soldier  (Patrols, Zone Guard, Team)
opfor_AA_SOLDIER_X =			 [_aa, _lat + _aa, _infantry] call fnc_selectNonEmpty;				//Anti Air   (Patrols, Zone Guard, Team)
opfor_AR_SOLDIER_X =			 [_ar, _ar + _mg, _infantry] call fnc_selectNonEmpty;			   //Auto Rifleman   (Patrols, Zone Guard, Team)
opfor_AT_SOLDIER_X =			 [_hat, _lat + _aa, _infantry] call fnc_selectNonEmpty;				//Anti Tank   (Patrols, Zone Guard, Team)
opfor_GL_SOLDIER_X =			 [_gl, _grunt, _infantry] call fnc_selectNonEmpty;				//Grenadier   (Patrols, Zone Guard, Team)
opfor_LAT_SOLDIER_X =			[_lat, _lat + _aa, _infantry] call fnc_selectNonEmpty;				 //Lt Anti Tank   (Patrols, Zone Guard, Team)
opfor_SL_SOLDIER_X =			 [_sl, _grunt, _infantry] call fnc_selectNonEmpty;				//Squad Leader   (Patrols, Zone Guard, Team)
opfor_TL_SOLDIER_X =			 [_tl, _grunt, _infantry] call fnc_selectNonEmpty;				//Team Leader	(Patrols, Zone Guard, Team)
opfor_MARK_SOLDIER_X =		   [_marksman, _grunt, _infantry] call fnc_selectNonEmpty;				//Marksman, urban   (Patrols, Zone Guard, Team)

opfor_CREW_X =				   [_crew, _grunt, _infantry] call fnc_selectNonEmpty;						//Crew   (mission target)
opfor_ENG_SOLDIER_X =			[_eng, _exp, _infantry] call fnc_selectNonEmpty;					//Engineer   (mission guard)
opfor_SNIPER_SOLDIER_X =		 [_sniper, _marksman, _infantry] call fnc_selectNonEmpty;					//Sniper   (mission target)
opfor_OFFICER_X =				[_officer, _sl, _infantry] call fnc_selectNonEmpty;					//Officer  (mission target)
opfor_OPERATOR_X =			   [_spec, _grunt, _infantry] call fnc_selectNonEmpty;					//Recon	(mission guard)

opfor_COVERED_TRUCK_X =		 [_carTransport, _carTransport + _carArmed, ["C_Truck_02_covered_F", "C_Truck_02_transport_F", "C_Van_01_transport_F", "I_G_Van_01_transport_F", "C_Van_02_transport_F"]] call fnc_selectNonEmpty;			//Covered Transport   (static zone)
opfor_TRANS_TRUCK_X =		   [_carTransport, _carTransport + _carArmed, ["C_Offroad_02_unarmed_F", "C_Offroad_01_F"]] call fnc_selectNonEmpty;		//Open Transport   (static zone, R3F logistics)
opfor_AMMO_TRUCK_X =			[_carRearm, _carRearm, ["B_Truck_01_ammo_F"]] call fnc_selectNonEmpty;			//Lrg Ammo Truck   (static zone, R3F logistics)
opfor_REPAIR_TRUCK_X =		  [_carRepair, _carRepair, ["C_Truck_02_box_F", "C_Offroad_01_repair_F", "I_G_Offroad_01_repair_F", "C_Van_02_service_F"]] call fnc_selectNonEmpty;			//Lrg Repair Truck   (static zone)
opfor_APC1_X =				  [_apcWheeled + _apcTracked, _carArmed, ["I_C_Offroad_02_LMG_F"]] call fnc_selectNonEmpty;				//APC unarmed   (static zone, mission vehicle) I_MRAP_03_hmg_F/I_MRAP_03_F
opfor_ARMED_CAR1_X =			[_carArmed, _carTransport + _carArmed, ["I_G_Offroad_01_armed_F", "I_G_Offroad_01_lat_F", "I_C_Offroad_02_LMG_F", "I_C_Offroad_02_lat_F"]] call fnc_selectNonEmpty;			   //Armed Car	  (patrol)

opfor_MBT_TANK1_X =			 [_tank, _tank, ["I_C_Offroad_02_AT_F"]] call fnc_selectNonEmpty;				//Tank	 (mission vehicle)
opfor_APC2_X =				  [_apcWheeled + _apcTracked, _apcWheeled + _apcTracked, ["I_C_Offroad_01_AT_F"]] call fnc_selectNonEmpty;		//APC HMG,GMG	(mission vehicle)
opfor_AA_APC_X =				[_antiAir, _antiAir, ["I_C_Offroad_02_LMG_F"]] call fnc_selectNonEmpty;		   //APC AA  (mission vehicle)
opfor_TRANS_HELI_X =			[_heliTransport, _heliTransport, ["I_Heli_light_03_unarmed_F", "I_Heli_light_03_unarmed_F"]] call fnc_selectNonEmpty;			//Transport Heli	(mission vehicle)
opfor_ATTACK_HELI_X =		   [_heliArmed, _heliArmed, ["I_Heli_light_03_unarmed_F", "I_Heli_light_03_unarmed_F", "I_Heli_light_03_unarmed_F"]] call fnc_selectNonEmpty;				//Opfor Atk Heli	  (Patrol, Zone Guard)
opfor_MISC_AIR_X =			  [_planeArmed, _planeArmed, ["I_C_Plane_Civil_01_F", "I_C_Plane_Civil_01_F", "I_C_Plane_Civil_01_F"]] call fnc_selectNonEmpty;  //Opfor Air Asset	  (Patrol, Zone Guard)


opfor_TURRET_HMG =				"B_G_HMG_02_high_F";				//Zone static	

opfor_SPECOPS_X =				[_spec arrayIntersect _sl,  _sl, _infantry] call fnc_selectNonEmpty;					//operator
opfor_SPECOPS_GL_X =			 [_spec arrayIntersect _gl,  _gl, _infantry] call fnc_selectNonEmpty;				//operator
opfor_SPECOPS_LAT_X =			[_spec arrayIntersect _lat + _aa,  _lat + _aa, _infantry] call fnc_selectNonEmpty;				//operator
opfor_SPECOPS_HAT_X =			[_spec arrayIntersect _lat + _aa,  _lat + _aa, _infantry] call fnc_selectNonEmpty;		//operator
opfor_SPECOPS_AA_X =			 [_spec arrayIntersect _aa,  _aa, _infantry] call fnc_selectNonEmpty;				//operator
opfor_SPECOPS_MG_X =			 [_spec arrayIntersect _ar + _mg,  _ar + _mg, _infantry] call fnc_selectNonEmpty;		//operator
opfor_SPECOPS_MEDIC_X =		  [_spec arrayIntersect _medic,  _medic, _infantry] call fnc_selectNonEmpty;				//operator
opfor_SPECOPS_MARK_X =		   [_spec arrayIntersect _marksman,  _marksman, _infantry] call fnc_selectNonEmpty;					//operator
opfor_SPECOPS_SNIPER_X =		 [_spec arrayIntersect _sniper, _sniper, _infantry] call fnc_selectNonEmpty;					//operator
opfor_SPECOPS_EXP_X =			[_spec arrayIntersect _exp, _exp, _infantry] call fnc_selectNonEmpty;				//operator
opfor_SPECOPS_ENG_X =			[_spec arrayIntersect _eng, _eng, _infantry] call fnc_selectNonEmpty;			//operator


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

// use predefined array for improved performance
o_arraysToRandomize = [
    "opfor_SOLDIER_X",
    "opfor_AA_SOLDIER_X",
    "opfor_AR_SOLDIER_X",
    "opfor_AT_SOLDIER_X",
    "opfor_GL_SOLDIER_X",
    "opfor_LAT_SOLDIER_X",
    "opfor_SL_SOLDIER_X",
    "opfor_TL_SOLDIER_X",
    "opfor_MARK_SOLDIER_X",
    "opfor_CREW_X",
    "opfor_ENG_SOLDIER_X",
    "opfor_SNIPER_SOLDIER_X",
    "opfor_OFFICER_X",
    "opfor_OPERATOR_X",
    "opfor_COVERED_TRUCK_X",
    "opfor_TRANS_TRUCK_X",
    "opfor_AMMO_TRUCK_X",
    "opfor_REPAIR_TRUCK_X",
    "opfor_APC1_X",
    "opfor_ARMED_CAR1_X",
    "opfor_MBT_TANK1_X",
    "opfor_APC2_X",
    "opfor_AA_APC_X",
    "opfor_TRANS_HELI_X",
    "opfor_ATTACK_HELI_X",
    "opfor_MISC_AIR_X",
    "opfor_TURRET_HMG",
    "opfor_SPECOPS_X",
    "opfor_SPECOPS_GL_X",
    "opfor_SPECOPS_LAT_X",
    "opfor_SPECOPS_HAT_X",
    "opfor_SPECOPS_AA_X",
    "opfor_SPECOPS_MG_X",
    "opfor_SPECOPS_MEDIC_X",
    "opfor_SPECOPS_MARK_X",
    "opfor_SPECOPS_SNIPER_X",
    "opfor_SPECOPS_EXP_X",
    "opfor_SPECOPS_ENG_X"
];

// 随机化循环
{
    private _factionUnitVarName = _x;
    private _factionUnitVarData = missionNamespace getVariable _factionUnitVarName;
    if (typeName _factionUnitVarData == "ARRAY") then {
        [_factionUnitVarData, _factionUnitVarName] spawn {
            params ["_factionUnitVarData", "_factionUnitVarName"];
            while {true} do {
                private _randomSelection = selectRandom _factionUnitVarData;
                missionNamespace setVariable [_factionUnitVarName, _randomSelection, true];
                sleep 300;
            };
        };
    };
} forEach o_arraysToRandomize;
sleep 1;

opfor_autodetect_faction_init = true;
publicVariable "opfor_autodetect_faction_init";