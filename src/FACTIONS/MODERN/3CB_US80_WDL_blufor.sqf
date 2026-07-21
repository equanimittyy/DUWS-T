
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
blufor_SOLDIER_LAT_X =			"UK3CB_CW_US_B_LATE_LAT";				//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"UK3CB_CW_US_B_LATE_GL";				//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"UK3CB_CW_US_B_LATE_TL";				//initHQ\fnc_createpatrolFOB, initHQ\fnc_HQguards
blufor_SOLDIER_SL_X =			"UK3CB_CW_US_B_LATE_RADIO";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"UK3CB_CW_US_B_LATE_AR";				//supports\fnc_paradrop, initHQ\fnc_HQguards
blufor_MARKSMAN_X = 			"UK3CB_CW_US_B_LATE_MK";				//initHQ\fnc_HQguards
blufor_OFFICER_X =				"UK3CB_CW_US_B_LATE_OFF";				//initHQ\fnc_BluHQinit
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
// THESE HAVE FIXED AMOUNTS -fill the ends with ["empty",0,0];
//
// - Units = 				14
// - Vehicles/Statics = 	50
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


blufor_RQST_UNIT_01_X = 			["UK3CB_CW_US_B_LATE_RIF_1","Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				["UK3CB_CW_US_B_LATE_GL","Grenadier (3CP)",3];
blufor_RQST_UNIT_03_X =				["UK3CB_CW_US_B_LATE_AR","Automatic Rifleman (3CP)",3];
blufor_RQST_UNIT_04_X =				["UK3CB_CW_US_B_LATE_MG","Machine Gunner (4CP)",4];
blufor_RQST_UNIT_05_X =				["UK3CB_CW_US_B_LATE_MD","Medic (4CP)",4];
blufor_RQST_UNIT_06_X =				["UK3CB_CW_US_B_LATE_AT","AT Specialist (4CP)",4];
blufor_RQST_UNIT_07_X =				["UK3CB_CW_US_B_LATE_AA","AA Specialist (4CP)",4];
blufor_RQST_UNIT_08_X =				["UK3CB_CW_US_B_LATE_ENG","Engineer (4CP)",4];
blufor_RQST_UNIT_09_X =				["UK3CB_CW_US_B_LATE_MK","Marksman (3CP)",3];
blufor_RQST_UNIT_10_X =				["UK3CB_CW_US_B_LATE_CREW","Crewman (2CP)",4];
blufor_RQST_UNIT_11_X =				["UK3CB_CW_US_B_LATE_LAT","Rifleman (LAT) (3CP)",4];
blufor_RQST_UNIT_12_X =				["UK3CB_CW_US_B_LATE_DEM","Explosive Specialist (4CP)",4];
blufor_RQST_UNIT_13_X =				["empty",0,0];
blufor_RQST_UNIT_14_X =				["empty",0,0];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////

blufor_RQST_VEHICLE_01_X =			["UK3CB_CW_US_B_LATE_M1025_Unarmed","M1025 (Unarmed) (5CP)",5];
blufor_RQST_VEHICLE_02_X =			["UK3CB_CW_US_B_LATE_M1025_M2","M1025 (M2) (10CP)",10];
blufor_RQST_VEHICLE_03_X =			["UK3CB_CW_US_B_LATE_M1025_MK19","M1025 (MK19) (12CP)",12];
blufor_RQST_VEHICLE_04_X =			["UK3CB_CW_US_B_LATE_M1025_TOW","M1025 (TOW) (14CP)",14];
blufor_RQST_VEHICLE_05_X =			["UK3CB_CW_US_B_LATE_M939","M939 (Transport) (10CP)",10];
blufor_RQST_VEHICLE_06_X =			["UK3CB_CW_US_B_LATE_M939_Guntruck","M939 (Guntruck) (15CP)",15];
blufor_RQST_VEHICLE_07_X =			["UK3CB_CW_US_B_LATE_M939_Repair","M939 (Repair) (50CP)",50];
blufor_RQST_VEHICLE_08_X =			["UK3CB_CW_US_B_LATE_M939_Reammo","M939 (Ammo) (50CP)",50];
blufor_RQST_VEHICLE_09_X =			["UK3CB_CW_US_B_LATE_M939_Fuel","M939 (Fuel) (50CP)",50];
blufor_RQST_VEHICLE_10_X =			["UK3CB_CW_US_B_LATE_M113_AMB","M113 (Medic) (50CP)",50];
blufor_RQST_VEHICLE_11_X =			["UK3CB_CW_US_B_LATE_M113_M2","M113 (M2) (18CP)",15];
blufor_RQST_VEHICLE_12_X =			["UK3CB_CW_US_B_LATE_M113_MK19","M113 (MK19) (20CP)",18];
blufor_RQST_VEHICLE_13_X =			["UK3CB_CW_US_B_LATE_LAV25","LAV25 (30CP)",30];
blufor_RQST_VEHICLE_14_X =			["UK3CB_CW_US_B_LATE_AAV","AAVP-7A1 (28CP)",28];
blufor_RQST_VEHICLE_15_X =			["UK3CB_CW_US_B_LATE_M2A2","M2A2 (35CP)",35];
blufor_RQST_VEHICLE_16_X =			["UK3CB_CW_US_B_LATE_M60a3","M60A3 (40CP)",40];
blufor_RQST_VEHICLE_17_X =			["UK3CB_CW_US_B_LATE_M1A1","M1A1 (50CP)",50];
blufor_RQST_VEHICLE_18_X =			["UK3CB_CW_US_B_LATE_UH1H","UH1-H (Unarmed) (20CP)",20];
blufor_RQST_VEHICLE_19_X =			["UK3CB_CW_US_B_LATE_UH1H_M240","UH1-H (Armed) (25CP)",25];
blufor_RQST_VEHICLE_20_X =			["UK3CB_CW_US_B_LATE_UH1H_GUNSHIP","UH-1H (Gunship) (30CP)",30];
blufor_RQST_VEHICLE_21_X =			["UK3CB_CW_US_B_LATE_CH47","CH-47 (20CP)",20];
blufor_RQST_VEHICLE_22_X =			["UK3CB_CW_US_B_LATE_AH1Z","AH-1Z (40CP)",40];
blufor_RQST_VEHICLE_23_X =			["UK3CB_CW_US_B_LATE_AH64","AH64 (45CP)",45];
blufor_RQST_VEHICLE_24_X =			["UK3CB_CW_US_B_LATE_UH60M","UH60M Armed (28CP)",28];
blufor_RQST_VEHICLE_25_X =			["UK3CB_CW_US_B_LATE_A10","A10 (45CP)", 45];
blufor_RQST_VEHICLE_26_X =			["UK3CB_CW_US_B_LATE_M109","M109 (50CP)",50];
blufor_RQST_VEHICLE_27_X =			["empty",0,0];
blufor_RQST_VEHICLE_28_X =			["empty",0,0];
blufor_RQST_VEHICLE_29_X =			["empty",0,0];
blufor_RQST_VEHICLE_30_X =			["empty",0,0];
blufor_RQST_VEHICLE_31_X =			["empty",0,0];
blufor_RQST_VEHICLE_32_X =			["empty",0,0];
blufor_RQST_VEHICLE_33_X =			["empty",0,0];
blufor_RQST_VEHICLE_34_X =			["empty",0,0];
blufor_RQST_VEHICLE_35_X =			["empty",0,0];
blufor_RQST_VEHICLE_36_X =			["empty",0,0];
blufor_RQST_VEHICLE_37_X =			["empty",0,0];
blufor_RQST_VEHICLE_38_X =			["empty",0,0];
blufor_RQST_VEHICLE_39_X =			["empty",0,0];
blufor_RQST_VEHICLE_40_X =			["empty",0,0];
blufor_RQST_VEHICLE_41_X =			["empty",0,0];
blufor_RQST_VEHICLE_42_X =			["empty",0,0];
blufor_RQST_VEHICLE_43_X =			["empty",0,0];
blufor_RQST_VEHICLE_44_X =			["empty",0,0];
blufor_RQST_VEHICLE_45_X =			["empty",0,0];
blufor_RQST_VEHICLE_46_X =			["empty",0,0];
blufor_RQST_VEHICLE_47_X =			["empty",0,0];
blufor_RQST_VEHICLE_48_X =			["empty",0,0];
blufor_RQST_VEHICLE_49_X =			["empty",0,0];
blufor_RQST_VEHICLE_50_X =			["empty",0,0];


