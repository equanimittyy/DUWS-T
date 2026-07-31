// Locality: server -- compiled by fnc_factions_check from server/server_init.sqf:31; defines
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


// Same filter the AutoDetect picker applies: the roll draws from the zombie factions in the
// zombie mode and from everything else in the others, so a random OPFOR can never be zombies in
// a campaign that is not about them -- nor an army in one that is.
_wantZombies = (missionNamespace getVariable ["duws_gamemode", "duws"]) isEqualTo "zombies";

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
opfor_AMMO_TRUCK_X =			[_carRearm, _carRearm, ["I_Truck_02_ammo_F"]] call fnc_selectNonEmpty;			//Lrg Ammo Truck   (static zone, R3F logistics)
opfor_REPAIR_TRUCK_X =		  [_carRepair, _carRepair, ["C_Truck_02_box_F", "C_Offroad_01_repair_F", "I_G_Offroad_01_repair_F", "C_Van_02_service_F"]] call fnc_selectNonEmpty;			//Lrg Repair Truck   (static zone)
opfor_APC1_X =				  [_apcWheeled + _apcTracked, _carArmed, ["I_MRAP_03_hmg_F"]] call fnc_selectNonEmpty;				//APC unarmed   (static zone, mission vehicle) I_MRAP_03_hmg_F/I_MRAP_03_F
opfor_ARMED_CAR1_X =			[_carArmed, _carTransport + _carArmed, ["I_G_Offroad_01_armed_F", "I_G_Offroad_01_lat_F", "I_C_Offroad_02_LMG_F", "I_C_Offroad_02_lat_F"]] call fnc_selectNonEmpty;			   //Armed Car	  (patrol)

opfor_MBT_TANK1_X =			 [_tank, _tank, ["I_MBT_03_cannon_F"]] call fnc_selectNonEmpty;				//Tank	 (mission vehicle)
opfor_APC2_X =				  [_apcWheeled + _apcTracked, _apcWheeled + _apcTracked, ["I_APC_tracked_03_cannon_F"]] call fnc_selectNonEmpty;		//APC HMG,GMG	(mission vehicle)
opfor_AA_APC_X =				[_antiAir, _antiAir, ["I_LT_01_AA_F"]] call fnc_selectNonEmpty;		   //APC AA  (mission vehicle)
opfor_TRANS_HELI_X =			[_heliTransport, _heliTransport, ["C_Heli_Light_01_civil_F", "I_Heli_light_03_unarmed_F"]] call fnc_selectNonEmpty;			//Transport Heli	(mission vehicle)
opfor_ATTACK_HELI_X =		   [_heliArmed, _heliArmed, ["I_Heli_light_03_dynamicLoadout_F", "B_UAV_02_dynamicLoadout_F", "O_T_UAV_04_CAS_F"]] call fnc_selectNonEmpty;				//Opfor Atk Heli	  (Patrol, Zone Guard)
opfor_MISC_AIR_X =			  [_planeArmed, _planeArmed, ["I_Plane_Fighter_03_CAS_F", "B_UAV_02_dynamicLoadout_F", "O_T_UAV_04_CAS_F"]] call fnc_selectNonEmpty;  //Opfor Air Asset	  (Patrol, Zone Guard)


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
	
};


selectRandom factionList select 1 call fnc_factionGen;


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


// randomise faction data, place holder until duws has similar functionality
{
	// transform vars defined in faction files to str if array
	_factionUnitVarName = _x;													// ex. blufor_SOLDIER_LAT_X
	_factionUnitVarData = missionNamespace getVariable _factionUnitVarName;	    // ex. ["B_Soldier_LAT_F", "B_Soldier_GL_F", "B_Soldier_TL_F"] or "B_Soldier_F"
	if (typeName _factionUnitVarData == "ARRAY") then {
		
		// schedule var randomization every N sec
		[_factionUnitVarData, _factionUnitVarName] spawn {
			params ["_factionUnitVarData", "_factionUnitVarName"];
			while{true} do {
				_randomSelection = selectRandom _factionUnitVarData;
				missionNamespace setVariable [_factionUnitVarName, ( if (isNil {_randomSelection}) then [{ "" }, { _randomSelection }] )];
				sleep 300; 
			};
		};		
	};
} forEach o_arraysToRandomize;
sleep 1;

opfor_autodetect_faction_init = true;
publicVariable "opfor_autodetect_faction_init";
