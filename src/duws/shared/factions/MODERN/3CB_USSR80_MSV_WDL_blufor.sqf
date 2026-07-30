
///////////////
///////////////   "UK3CB_CW_SOV_O_LATE", "3CB USSR MSV 80s (Wood)", "3CB_USSR80_MSV_WDL"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"UK3CB_CW_SOV_O_LATE_RIF_1";			//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"UK3CB_CW_SOV_O_LATE_LAT";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"UK3CB_CW_SOV_O_LATE_GL";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"UK3CB_CW_SOV_O_LATE_TL";				//init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"UK3CB_CW_SOV_O_LATE_RADIO";			//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"UK3CB_CW_SOV_O_LATE_MG";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"UK3CB_CW_SOV_O_LATE_MK";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"UK3CB_CW_SOV_O_LATE_OFF";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"UK3CB_CW_SOV_O_LATE_HELI_PILOT";		//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"UK3CB_TKA_B_RHIB_Gunboat";				//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"UK3CB_CW_SOV_O_LATE_RIF_1";			//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"UK3CB_CW_SOV_O_LATE_Mi8";				//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"UK3CB_CW_SOV_O_LATE_Mi8";   			//random patrol
blufor_HELI_ATTACK_X =			"UK3CB_CW_SOV_O_LATE_Mi_24V";			//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"UK3CB_CW_SOV_O_LATE_Su25SM";			//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"UK3CB_CW_SOV_O_LATE_UAZ_MG";			//random patrol
blufor_APC_PATROL1_X =			"UK3CB_CW_SOV_O_LATE_BRDM2";			//random patrol
blufor_APC_PATROL2_X =			"UK3CB_CW_SOV_O_LATE_BTR80";			//random patrol
blufor_TANK_PATROL1_X =			"UK3CB_CW_SOV_O_LATE_T72BB";			//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"rhs_Igla_AA_pod_msv";
blufor_TURRET_AT =				"rhs_Kornet_9M133_2_msv";
blufor_TURRET_HMG =				"rhs_KORD_high_MSV";
blufor_TURRET_GMG =				"RHS_AGS30_TriPod_MSV";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"UK3CB_CW_SOV_O_LATE_SF_RIF_1";			//operator
blufor_SPECOPS_GL_X =			"UK3CB_CW_SOV_O_LATE_SF_GL";			//operator
blufor_SPECOPS_LAT_X =			"UK3CB_CW_SOV_O_LATE_SF_LAT";			//operator
blufor_SPECOPS_HAT_X =			"UK3CB_CW_SOV_O_LATE_SF_AT";			//operator
blufor_SPECOPS_AA_X =			"UK3CB_CW_SOV_O_LATE_SF_AA";			//operator
blufor_SPECOPS_MG_X =			"UK3CB_CW_SOV_O_LATE_SF_MG";			//operator
blufor_SPECOPS_MEDIC_X =		"UK3CB_CW_SOV_O_LATE_SF_MD";			//operator
blufor_SPECOPS_MARK_X =			"UK3CB_CW_SOV_O_LATE_SF_MK";			//operator
blufor_SPECOPS_SNIPER_X =		"UK3CB_CW_SOV_O_LATE_SF_SNI";			//operator
blufor_SPECOPS_EXP_X =			"UK3CB_CW_SOV_O_LATE_SF_DEM";			//operator
blufor_SPECOPS_ENG_X = 			"UK3CB_CW_SOV_O_LATE_SF_ENG";			//operator





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


blufor_RQST_UNITS = [
	["UK3CB_CW_SOV_O_LATE_RIF_1","Rifleman (2CP)",2],
	["UK3CB_CW_SOV_O_LATE_LAT","Rifleman (AT) (3CP)",3],
	["UK3CB_CW_SOV_O_LATE_GL","Grenadier (3CP)",3],
	["UK3CB_CW_SOV_O_LATE_MG","Machinegunner (3CP)",3],
	["UK3CB_CW_SOV_O_LATE_DEM","Explosive Specialist (4CP)",4],
	["UK3CB_CW_SOV_O_LATE_MD","Medic (4CP)",4],
	["UK3CB_CW_SOV_O_LATE_AT","AT Specialist (4CP)",4],
	["UK3CB_CW_SOV_O_LATE_AA","AA Specialist (4CP)",4],
	["UK3CB_CW_SOV_O_LATE_ENG","Engineer (4CP)",4],
	["UK3CB_CW_SOV_O_LATE_MK","Marksman (3CP)",3],
	["UK3CB_CW_SOV_O_LATE_CREW","Crewman (2CP)",4]
];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////

blufor_RQST_VEHICLES = [
	["UK3CB_CW_SOV_O_LATE_UAZ_Closed","UAZ (Unarmed) (2CP)",2],
	["UK3CB_CW_SOV_O_LATE_UAZ_MG","UAZ (DShKM) (6CP)",6],
	["UK3CB_CW_SOV_O_LATE_UAZ_AGS30","UAZ (AGS-30) (8CP)",8],
	["UK3CB_CW_SOV_O_LATE_UAZ_SPG9","UAZ (SPG-9) (8CP)",8],
	["UK3CB_CW_SOV_O_LATE_Ural","Ural (Cargo) (10CP)",10],
	["UK3CB_CW_SOV_O_LATE_Ural_Repair","Ural (Repair) (50CP)",50],
	["UK3CB_CW_SOV_O_LATE_Ural_Ammo","Ural (Ammo) (50CP)",50],
	["UK3CB_CW_SOV_O_LATE_Ural_Fuel","Ural (Fuel) (50CP)",50],
	["UK3CB_CW_SOV_O_LATE_BRDM2_HQ","BRDM2UM (Hatch) (12CP)",12],
	["UK3CB_CW_SOV_O_LATE_BRDM2","BRDM2 (Armed) (20CP)",20],
	["UK3CB_CW_SOV_O_LATE_BTR80","BTR80 (25CP)",25],
	["UK3CB_CW_SOV_O_LATE_BMD1P","BMD1 (28CP)",30],
	["UK3CB_CW_SOV_O_LATE_BMP1","BMP1 (30CP)",30],
	["UK3CB_CW_SOV_O_LATE_T72BB","T72 (35CP)",35],
	["UK3CB_CW_SOV_O_LATE_ZsuTank","ZSU-23-4 (30CP)",30],
	["UK3CB_CW_SOV_O_EARLY_Mi8AMT","Mi-8 (Unarmed) (20CP)",20],
	["UK3CB_CW_SOV_O_LATE_Mi8","Mi-8 (Armed) (25CP)",25],
	["UK3CB_CW_SOV_O_EARLY_Mi_24V","Mi-24V (45CP)",45],
	["UK3CB_CW_SOV_O_EARLY_Su25SM","SU25SM (45CP)",45],
	["UK3CB_CW_SOV_O_EARLY_2S3","2S3 SPG (50CP)",50],
	["UK3CB_CW_SOV_O_EARLY_BM21","BM21 (65CP)",65]
];


