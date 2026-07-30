
///////////////
///////////////   "UK3CB_CW_US_B_LATE", "3CB US Army 80s (Wood)", "3CB_US80_WDL"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"UK3CB_CW_US_B_LATE_RIF_1";				//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"UK3CB_CW_US_B_LATE_LAT";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"UK3CB_CW_US_B_LATE_GL";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"UK3CB_CW_US_B_LATE_TL";				//init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"UK3CB_CW_US_B_LATE_RADIO";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"UK3CB_CW_US_B_LATE_AR";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"UK3CB_CW_US_B_LATE_MK";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"UK3CB_CW_US_B_LATE_OFF";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"UK3CB_CW_US_B_LATE_HELI_PILOT";		//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"UK3CB_TKA_B_RHIB_Gunboat";				//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"UK3CB_CW_US_B_LATE_RIF_1";				//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"UK3CB_CW_US_B_LATE_UH60M";				//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"UK3CB_CW_US_B_LATE_CH47";   			//random patrol
blufor_HELI_ATTACK_X =			"UK3CB_CW_US_B_LATE_AH64";				//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"UK3CB_CW_US_B_LATE_A10";				//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"UK3CB_CW_US_B_LATE_M1025_M2";			//random patrol
blufor_APC_PATROL1_X =			"UK3CB_CW_US_B_LATE_M2A2";				//random patrol
blufor_APC_PATROL2_X =			"UK3CB_CW_US_B_LATE_LAV25";				//random patrol
blufor_TANK_PATROL1_X =			"UK3CB_CW_US_B_LATE_M1A1";				//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"UK3CB_CW_US_B_LATE_Stinger_AA_pod";
blufor_TURRET_AT =				"UK3CB_CW_US_B_LATE_TOW_TriPod";
blufor_TURRET_HMG =				"UK3CB_CW_US_B_LATE_M2_TriPod";
blufor_TURRET_GMG =				"UK3CB_CW_US_B_LATE_MK19_TriPod";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"UK3CB_CW_US_B_LATE_SF_RIF_2";			//operator
blufor_SPECOPS_GL_X =			"UK3CB_CW_US_B_LATE_SF_GL";				//operator
blufor_SPECOPS_LAT_X =			"UK3CB_CW_US_B_LATE_SF_LAT";			//operator
blufor_SPECOPS_HAT_X =			"UK3CB_CW_US_B_LATE_SF_AT";				//operator
blufor_SPECOPS_AA_X =			"UK3CB_CW_US_B_LATE_SF_AA";				//operator
blufor_SPECOPS_MG_X =			"UK3CB_CW_US_B_LATE_SF_AR";				//operator
blufor_SPECOPS_MEDIC_X =		"UK3CB_CW_US_B_LATE_SF_MD";				//operator
blufor_SPECOPS_MARK_X =			"UK3CB_CW_US_B_LATE_SF_MK";				//operator
blufor_SPECOPS_SNIPER_X =		"UK3CB_CW_US_B_LATE_SF_SNI";			//operator
blufor_SPECOPS_EXP_X =			"UK3CB_CW_US_B_LATE_SF_DEM";			//operator
blufor_SPECOPS_ENG_X = 			"UK3CB_CW_US_B_LATE_SF_ENG";			//operator



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
	["UK3CB_CW_US_B_LATE_RIF_1","Rifleman (2CP)",2],
	["UK3CB_CW_US_B_LATE_GL","Grenadier (3CP)",3],
	["UK3CB_CW_US_B_LATE_AR","Automatic Rifleman (3CP)",3],
	["UK3CB_CW_US_B_LATE_MG","Machine Gunner (4CP)",4],
	["UK3CB_CW_US_B_LATE_MD","Medic (4CP)",4],
	["UK3CB_CW_US_B_LATE_AT","AT Specialist (4CP)",4],
	["UK3CB_CW_US_B_LATE_AA","AA Specialist (4CP)",4],
	["UK3CB_CW_US_B_LATE_ENG","Engineer (4CP)",4],
	["UK3CB_CW_US_B_LATE_MK","Marksman (3CP)",3],
	["UK3CB_CW_US_B_LATE_CREW","Crewman (2CP)",4],
	["UK3CB_CW_US_B_LATE_LAT","Rifleman (LAT) (3CP)",4],
	["UK3CB_CW_US_B_LATE_DEM","Explosive Specialist (4CP)",4]
];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////

blufor_RQST_VEHICLES = [
	["UK3CB_CW_US_B_LATE_M1025_Unarmed","M1025 (Unarmed) (5CP)",5],
	["UK3CB_CW_US_B_LATE_M1025_M2","M1025 (M2) (10CP)",10],
	["UK3CB_CW_US_B_LATE_M1025_MK19","M1025 (MK19) (12CP)",12],
	["UK3CB_CW_US_B_LATE_M1025_TOW","M1025 (TOW) (14CP)",14],
	["UK3CB_CW_US_B_LATE_M939","M939 (Transport) (10CP)",10],
	["UK3CB_CW_US_B_LATE_M939_Guntruck","M939 (Guntruck) (15CP)",15],
	["UK3CB_CW_US_B_LATE_M939_Repair","M939 (Repair) (50CP)",50],
	["UK3CB_CW_US_B_LATE_M939_Reammo","M939 (Ammo) (50CP)",50],
	["UK3CB_CW_US_B_LATE_M939_Fuel","M939 (Fuel) (50CP)",50],
	["UK3CB_CW_US_B_LATE_M113_AMB","M113 (Medic) (50CP)",50],
	["UK3CB_CW_US_B_LATE_M113_M2","M113 (M2) (18CP)",15],
	["UK3CB_CW_US_B_LATE_M113_MK19","M113 (MK19) (20CP)",18],
	["UK3CB_CW_US_B_LATE_LAV25","LAV25 (30CP)",30],
	["UK3CB_CW_US_B_LATE_AAV","AAVP-7A1 (28CP)",28],
	["UK3CB_CW_US_B_LATE_M2A2","M2A2 (35CP)",35],
	["UK3CB_CW_US_B_LATE_M60a3","M60A3 (40CP)",40],
	["UK3CB_CW_US_B_LATE_M1A1","M1A1 (50CP)",50],
	["UK3CB_CW_US_B_LATE_UH1H","UH1-H (Unarmed) (20CP)",20],
	["UK3CB_CW_US_B_LATE_UH1H_M240","UH1-H (Armed) (25CP)",25],
	["UK3CB_CW_US_B_LATE_UH1H_GUNSHIP","UH-1H (Gunship) (30CP)",30],
	["UK3CB_CW_US_B_LATE_CH47","CH-47 (20CP)",20],
	["UK3CB_CW_US_B_LATE_AH1Z","AH-1Z (40CP)",40],
	["UK3CB_CW_US_B_LATE_AH64","AH64 (45CP)",45],
	["UK3CB_CW_US_B_LATE_UH60M","UH60M Armed (28CP)",28],
	["UK3CB_CW_US_B_LATE_A10","A10 (45CP)", 45],
	["UK3CB_CW_US_B_LATE_M109","M109 (50CP)",50]
];


