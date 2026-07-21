
///////////////
///////////////   "CFP_B_YPG", "CFP YPG (Kurds) + USAF Support", "CFP_B_YPG"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"cfp_b_ypg_rifleman";				//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"cfp_b_ypg_at";						//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"cfp_b_ypg_grenadier";				//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"cfp_b_ypg_machinegunner";			//initHQ\fnc_createpatrolFOB, initHQ\fnc_HQguards
blufor_SOLDIER_SL_X =			"cfp_b_ypg_rifleman_dshkm";			//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"cfp_b_ypg_asst_gunner_dshkm";		//supports\fnc_paradrop, initHQ\fnc_HQguards
blufor_MARKSMAN_X = 			"cfp_b_ypg_sniper";					//initHQ\fnc_HQguards
blufor_OFFICER_X =				"cfp_b_ypg_leader";					//initHQ\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CUP_B_US_Pilot";					//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";	//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";				//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CFP_B_USARMY_2003_UH_60M_DES_01";		//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"CFP_B_USARMY_2003_UH_60M_MEV_WDL_01";  //random patrol
blufor_HELI_ATTACK_X =			"CFP_B_USARMY_2003_AH_64D_DES_01";		//dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"CUP_B_A10_DYN_USA";					//dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"CFP_B_YPG_Hilux_ZU_23_01";				//random patrol
blufor_APC_PATROL1_X =			"CFP_B_YPG_Hilux_DSHKM_01";				//random patrol
blufor_APC_PATROL2_X =			"CFP_B_YPG_Hilux_DSHKM_01";				//random patrol
blufor_TANK_PATROL1_X =			"CFP_B_YPG_Hilux_DSHKM_01";				//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"CFP_B_USARMY_2003_M2_Machine_Gun_DES_01";
blufor_TURRET_AT =				"CFP_B_USARMY_2003_TOW_Tripod_DES_01";
blufor_TURRET_HMG =				"CFP_B_USARMY_2003_M2_Machine_Gun_DES_01";
blufor_TURRET_GMG =				"CFP_B_USARMY_2003_M2_Machine_Gun_DES_01";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"cfp_b_ypg_rifleman";			//operator
blufor_SPECOPS_GL_X =			"cfp_b_ypg_grenadier";			//operator
blufor_SPECOPS_LAT_X =			"cfp_b_ypg_at";					//operator
blufor_SPECOPS_HAT_X =			"cfp_b_ypg_at";					//operator
blufor_SPECOPS_AA_X =			"CUP_B_US_Soldier_AA";			//operator
blufor_SPECOPS_MG_X =			"cfp_b_ypg_machinegunner";		//operator
blufor_SPECOPS_MEDIC_X =		"cfp_b_ypg_medic";				//operator
blufor_SPECOPS_MARK_X =			"cfp_b_ypg_sniper";				//operator
blufor_SPECOPS_SNIPER_X =		"cfp_b_ypg_sniper";				//operator
blufor_SPECOPS_EXP_X =			"cfp_b_ypg_grenadier";			//operator
blufor_SPECOPS_ENG_X = 			"cfp_b_ypg_crewman";			//operator





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


blufor_RQST_UNIT_01_X = 			["cfp_b_ypg_rifleman","Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				["cfp_b_ypg_grenadier","Grenadier (3CP)",3];
blufor_RQST_UNIT_03_X =				["cfp_b_ypg_rifleman_dshkm","Rifleman (DSHKM) (3CP)",3];
blufor_RQST_UNIT_04_X =				["cfp_b_ypg_asst_gunner_dshkm","Assistant Rifleman (DSHKM) (3CP)",4];
blufor_RQST_UNIT_05_X =				["cfp_b_ypg_medic","Medic (4CP)",4];
blufor_RQST_UNIT_06_X =				["cfp_b_ypg_at","AT Rifleman (3CP)",3];
blufor_RQST_UNIT_07_X =				["cfp_b_ypg_machinegunner","Machinegunner (4CP)",4];
blufor_RQST_UNIT_08_X =				["cfp_b_ypg_sniper","Sniper (4CP)",4];
blufor_RQST_UNIT_09_X =				["empty",0,0];
blufor_RQST_UNIT_10_X =				["empty",0,0];
blufor_RQST_UNIT_11_X =				["empty",0,0];
blufor_RQST_UNIT_12_X =				["empty",0,0];
blufor_RQST_UNIT_13_X =				["empty",0,0];
blufor_RQST_UNIT_14_X =				["empty",0,0];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////   

blufor_RQST_VEHICLE_01_X =			["CFP_B_YPG_Hilux_DSHKM_01","Hilux (DSHKM) (3CP)",3];
blufor_RQST_VEHICLE_02_X =			["CFP_B_YPG_Hilux_ZU_23_01","Hilux (ZU23) (10CP)",10];
blufor_RQST_VEHICLE_03_X =			["cfp_b_ypg_offroad_flag","Offroad (Unarmed) (1CP)",1];
blufor_RQST_VEHICLE_04_X =			["cfp_b_ypg_offroad_M2_flag","Offroad (MG) (3CP)",3];
blufor_RQST_VEHICLE_05_X =			["CUP_O_Ural_Open_SLA","URAL Transport (10CP)",10];
blufor_RQST_VEHICLE_06_X =			["CUP_B_HMMWV_M2_GPK_USA","HMMWV HMG (18CP)",18];
blufor_RQST_VEHICLE_07_X =			["CFP_B_USARMY_2003_UH_60M_MEV_WDL_01","USAF UH-60 Medical (Unarmed) (20CP)",20];
blufor_RQST_VEHICLE_08_X =			["CFP_B_USARMY_2003_UH_60M_DES_01","USAF UH-60M (Armed) (25CP)",25];
blufor_RQST_VEHICLE_09_X =			["CFP_B_USARMY_2003_AH_64D_DES_01","USAF AH-64D (35CP)",35];
blufor_RQST_VEHICLE_10_X =			["CUP_B_A10_DYN_USA","USAF A10 (40CP)",40];
blufor_RQST_VEHICLE_11_X =			["CUP_B_AV8B_DYN_USMC","AV-8B Harrier (50CP)",50];
blufor_RQST_VEHICLE_12_X =			["empty",0,0];
blufor_RQST_VEHICLE_13_X =			["empty",0,0];
blufor_RQST_VEHICLE_14_X =			["empty",0,0];
blufor_RQST_VEHICLE_15_X =			["empty",0,0];
blufor_RQST_VEHICLE_16_X =			["empty",0,0];
blufor_RQST_VEHICLE_17_X =			["empty",0,0];
blufor_RQST_VEHICLE_18_X =			["empty",0,0];
blufor_RQST_VEHICLE_19_X =			["empty",0,0];
blufor_RQST_VEHICLE_20_X =			["empty",0,0];
blufor_RQST_VEHICLE_21_X =			["empty",0,0];
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


