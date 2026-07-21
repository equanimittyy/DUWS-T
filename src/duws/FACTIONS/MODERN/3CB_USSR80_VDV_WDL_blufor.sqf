
///////////////
///////////////   "UK3CB_CW_SOV_O_LATE", "3CB USSR VDV 80s (Wood)", "3CB_USSR80_VDV_WDL"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"UK3CB_CW_SOV_O_LATE_VDV_RIF_1";			//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"UK3CB_CW_SOV_O_LATE_VDV_LAT";				//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"UK3CB_CW_SOV_O_LATE_VDV_GL";				//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"UK3CB_CW_SOV_O_LATE_VDV_TL";				//initHQ\fnc_createpatrolFOB, initHQ\fnc_HQguards
blufor_SOLDIER_SL_X =			"UK3CB_CW_SOV_O_LATE_VDV_RADIO";			//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"UK3CB_CW_SOV_O_LATE_VDV_MG";				//supports\fnc_paradrop, initHQ\fnc_HQguards
blufor_MARKSMAN_X = 			"UK3CB_CW_SOV_O_LATE_VDV_MK";				//initHQ\fnc_HQguards
blufor_OFFICER_X =				"UK3CB_CW_SOV_O_LATE_OFF";					//initHQ\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"UK3CB_CW_SOV_O_LATE_HELI_PILOT";			//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"UK3CB_TKA_B_RHIB_Gunboat";					//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"UK3CB_CW_SOV_O_LATE_VDV_RIF_1";			//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"UK3CB_CW_SOV_O_LATE_Mi8";					//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"UK3CB_CW_SOV_O_LATE_Mi8";   				//random patrol
blufor_HELI_ATTACK_X =			"UK3CB_CW_SOV_O_LATE_Mi_24V";				//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"UK3CB_CW_SOV_O_LATE_Su25SM";				//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"UK3CB_CW_SOV_O_LATE_UAZ_MG";				//random patrol
blufor_APC_PATROL1_X =			"UK3CB_CW_SOV_O_LATE_BRDM2";				//random patrol
blufor_APC_PATROL2_X =			"UK3CB_CW_SOV_O_LATE_BTR80";				//random patrol
blufor_TANK_PATROL1_X =			"UK3CB_CW_SOV_O_LATE_T72BB";				//random patrol


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


blufor_RQST_UNIT_01_X = 			["UK3CB_CW_SOV_O_LATE_VDV_RIF_1","Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				["UK3CB_CW_SOV_O_LATE_VDV_LAT","Rifleman (AT) (3CP)",3];
blufor_RQST_UNIT_03_X =				["UK3CB_CW_SOV_O_LATE_VDV_GL","Grenadier (3CP)",3];
blufor_RQST_UNIT_04_X =				["UK3CB_CW_SOV_O_LATE_VDV_MG","Machinegunner (3CP)",3];
blufor_RQST_UNIT_05_X =				["UK3CB_CW_SOV_O_LATE_VDV_DEM","Explosive Specialist (4CP)",4];
blufor_RQST_UNIT_06_X =				["UK3CB_CW_SOV_O_LATE_VDV_MD","Medic (4CP)",4];
blufor_RQST_UNIT_07_X =				["UK3CB_CW_SOV_O_LATE_VDV_AT","AT Specialist (4CP)",4];
blufor_RQST_UNIT_08_X =				["UK3CB_CW_SOV_O_LATE_VDV_AA","AA Specialist (4CP)",4];
blufor_RQST_UNIT_09_X =				["UK3CB_CW_SOV_O_LATE_VDV_ENG","Engineer (4CP)",4];
blufor_RQST_UNIT_10_X =				["UK3CB_CW_SOV_O_LATE_VDV_MK","Marksman (3CP)",3];
blufor_RQST_UNIT_11_X =				["UK3CB_CW_SOV_O_LATE_VDV_CREW","Crewman (2CP)",4];
blufor_RQST_UNIT_12_X =				["empty",0,0];
blufor_RQST_UNIT_13_X =				["empty",0,0];
blufor_RQST_UNIT_14_X =				["empty",0,0];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////

blufor_RQST_VEHICLE_01_X =			["UK3CB_CW_SOV_O_LATE_UAZ_Closed","UAZ (Unarmed) (2CP)",2];
blufor_RQST_VEHICLE_02_X =			["UK3CB_CW_SOV_O_LATE_UAZ_MG","UAZ (DShKM) (6CP)",6];
blufor_RQST_VEHICLE_03_X =			["UK3CB_CW_SOV_O_LATE_UAZ_AGS30","UAZ (AGS-30) (8CP)",8];
blufor_RQST_VEHICLE_04_X =			["UK3CB_CW_SOV_O_LATE_UAZ_SPG9","UAZ (SPG-9) (8CP)",8];
blufor_RQST_VEHICLE_05_X =			["UK3CB_CW_SOV_O_LATE_Ural","Ural (Cargo) (10CP)",10];
blufor_RQST_VEHICLE_06_X =			["UK3CB_CW_SOV_O_LATE_Ural_Repair","Ural (Repair) (50CP)",50];
blufor_RQST_VEHICLE_07_X =			["UK3CB_CW_SOV_O_LATE_Ural_Ammo","Ural (Ammo) (50CP)",50];
blufor_RQST_VEHICLE_08_X =			["UK3CB_CW_SOV_O_LATE_Ural_Fuel","Ural (Fuel) (50CP)",50];
blufor_RQST_VEHICLE_09_X =			["UK3CB_CW_SOV_O_LATE_BRDM2_HQ","BRDM2UM (Hatch) (12CP)",12];
blufor_RQST_VEHICLE_10_X =			["UK3CB_CW_SOV_O_LATE_BRDM2","BRDM2 (Armed) (20CP)",20];
blufor_RQST_VEHICLE_11_X =			["UK3CB_CW_SOV_O_LATE_BTR80","BTR80 (25CP)",25];
blufor_RQST_VEHICLE_12_X =			["UK3CB_CW_SOV_O_LATE_BMD1P","BMD1 (28CP)",30];
blufor_RQST_VEHICLE_13_X =			["UK3CB_CW_SOV_O_LATE_BMP1","BMP1 (30CP)",30];
blufor_RQST_VEHICLE_14_X =			["UK3CB_CW_SOV_O_LATE_T72BB","T72 (35CP)",35];
blufor_RQST_VEHICLE_15_X =			["UK3CB_CW_SOV_O_LATE_ZsuTank","ZSU-23-4 (30CP)",30];
blufor_RQST_VEHICLE_16_X =			["UK3CB_CW_SOV_O_EARLY_Mi8AMT","Mi-8 (Unarmed) (20CP)",20];
blufor_RQST_VEHICLE_17_X =			["UK3CB_CW_SOV_O_LATE_Mi8","Mi-8 (Armed) (25CP)",25];
blufor_RQST_VEHICLE_18_X =			["UK3CB_CW_SOV_O_EARLY_Mi_24V","Mi-24V (45CP)",45];
blufor_RQST_VEHICLE_19_X =			["UK3CB_CW_SOV_O_EARLY_Su25SM","SU25SM (45CP)",45];
blufor_RQST_VEHICLE_20_X =			["UK3CB_CW_SOV_O_EARLY_2S3","2S3 SPG (50CP)",50];
blufor_RQST_VEHICLE_21_X =			["UK3CB_CW_SOV_O_EARLY_BM21","BM21 (65CP)",65];
blufor_RQST_VEHICLE_22_X =			["empty",0,0];
blufor_RQST_VEHICLE_23_X =			["empty",0,0];
blufor_RQST_VEHICLE_24_X =			["empty",0,0];
blufor_RQST_VEHICLE_25_X =			["empty",0,0];
blufor_RQST_VEHICLE_26_X =			["empty",0,0];
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


