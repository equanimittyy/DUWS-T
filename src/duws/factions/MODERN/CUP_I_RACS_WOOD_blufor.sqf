
///////////////
///////////////   "CUP_I_RACS", "CUP Sahrani RACS (Wood)", "CUP_I_RACS_WOOD"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"CUP_I_RACS_Soldier_wdl";			//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"CUP_I_RACS_Soldier_MAT_wdl";		//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"CUP_I_RACS_GL_wdl";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"CUP_I_RACS_SL_wdl";				//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"CUP_I_RACS_SL_wdl";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"CUP_I_RACS_AR_wdl";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"CUP_I_RACS_Sniper_wdl";			//init_hq\fnc_HQguards
blufor_OFFICER_X =				"CUP_I_RACS_Officer_wdl";			//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CUP_I_RACS_Pilot_wdl";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"CUP_I_RHIB_RACS";					//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CUP_I_UH60L_FFV_RACS";			//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"CUP_I_CH47F_VIV_RACS";   		//random patrol
blufor_HELI_ATTACK_X =			"CUP_I_UH1H_gunship_RACS";		//dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"CUP_B_A10_DYN_USA";			//dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"CUP_I_LR_MG_RACS";				//random patrol
blufor_APC_PATROL1_X =			"CUP_I_LAV25M240_RACS";			//random patrol
blufor_APC_PATROL2_X =			"CUP_I_AAV_RACS";				//random patrol
blufor_TANK_PATROL1_X =			"CUP_I_T72_RACS";				//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"CUP_B_CUP_Stinger_AA_pod_US";
blufor_TURRET_AT =				"CUP_B_TOW_TriPod_US";
blufor_TURRET_HMG =				"B_G_HMG_02_high_F";
blufor_TURRET_GMG =				"B_G_HMG_02_high_F";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"CUP_I_RACS_Soldier_wdl";			//operator
blufor_SPECOPS_GL_X =			"CUP_I_RACS_GL_wdl";				//operator
blufor_SPECOPS_LAT_X =			"CUP_I_RACS_Soldier_MAT_wdl";		//operator
blufor_SPECOPS_HAT_X =			"CUP_I_RACS_Soldier_HAT_wdl";		//operator
blufor_SPECOPS_AA_X =			"CUP_I_RACS_Soldier_AA_wdl";		//operator
blufor_SPECOPS_MG_X =			"CUP_I_RACS_MMG_wdl";				//operator
blufor_SPECOPS_MEDIC_X =		"CUP_I_RACS_Medic_wdl";				//operator
blufor_SPECOPS_MARK_X =			"CUP_I_RACS_M_wdl";					//operator
blufor_SPECOPS_SNIPER_X =		"CUP_I_RACS_Sniper_wdl";			//operator
blufor_SPECOPS_EXP_X =			"CUP_I_RACS_Engineer_wdl";			//operator
blufor_SPECOPS_ENG_X = 			"CUP_I_RACS_Engineer_wdl";			//operator





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


blufor_RQST_UNIT_01_X = 			["CUP_I_RACS_Soldier_wdl","Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				["CUP_I_RACS_GL_wdl","Grenadier (3CP)",3];
blufor_RQST_UNIT_03_X =				["CUP_I_RACS_AR_wdl","Automatic Rifleman (3CP)",3];
blufor_RQST_UNIT_04_X =				["CUP_I_RACS_MMG_wdl","Heavy Gunner ",4];
blufor_RQST_UNIT_05_X =				["CUP_I_RACS_Medic_wdl","Medic (4CP)",4];
blufor_RQST_UNIT_06_X =				["CUP_I_RACS_Soldier_MAT_wdl","AT Rifleman (3CP)",3];
blufor_RQST_UNIT_07_X =				["CUP_I_RACS_Soldier_HAT_wdl","AT Specialist (4CP)",4];
blufor_RQST_UNIT_08_X =				["CUP_I_RACS_Soldier_AA_wdl","AA Specialist (4CP)",4];
blufor_RQST_UNIT_09_X =				["CUP_I_RACS_Engineer_wdl","Engineer (4CP)",4];
blufor_RQST_UNIT_10_X =				["CUP_I_RACS_M_wdl","Marksman (3CP)",3];
blufor_RQST_UNIT_11_X =				["CUP_I_RACS_Sniper_wdl","Sniper (4CP)",4];
blufor_RQST_UNIT_12_X =				["empty",0,0];
blufor_RQST_UNIT_13_X =				["empty",0,0];
blufor_RQST_UNIT_14_X =				["empty",0,0];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////

blufor_RQST_VEHICLE_01_X =			["B_Quadbike_01_F","ATV (1CP)",1];
blufor_RQST_VEHICLE_02_X =			["C_Offroad_01_F","SF Offroader (2CP)",2];
blufor_RQST_VEHICLE_03_X =			["I_G_Van_01_transport_F","Transport Truck (6CP)",6];
blufor_RQST_VEHICLE_04_X =			["B_MRAP_01_F","Hunter Unarmed (5CP)",5];
blufor_RQST_VEHICLE_05_X =			["B_MRAP_01_hmg_F","Hunter HMG (18CP)",18];
blufor_RQST_VEHICLE_06_X =			["B_MRAP_01_gmg_F","Hunter GMG (25CP)",25];
blufor_RQST_VEHICLE_07_X =			["CUP_I_LR_Transport_RACS","Land Rover Unarmed (5CP)",5];
blufor_RQST_VEHICLE_08_X =			["CUP_I_LR_MG_RACS","Land Rover HMG (15CP)",15];
blufor_RQST_VEHICLE_09_X =			["CUP_I_LR_SF_GMG_AAF","Land Rover GMG (20CP)",20];
blufor_RQST_VEHICLE_10_X =			["B_Truck_01_transport_F","HEMTT Transport Uncovered (8CP)",8];
blufor_RQST_VEHICLE_11_X =			["CUP_I_MTVR_RACS","MTVR Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_12_X =			["CUP_I_MTVR_Repair_RACS","MTVR Repair (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["CUP_I_MTVR_Ammo_RACS","MTVR Ammo (50CP)",50];
blufor_RQST_VEHICLE_14_X =			["CUP_I_MTVR_Refuel_RACS","MTVR Fuel (50CP)",50];
blufor_RQST_VEHICLE_15_X =			["CUP_I_M113_RACS","M113A3 (25CP)",25];
blufor_RQST_VEHICLE_16_X =			["CUP_I_M163_RACS","M163 Vulcan AA (35CP)",35];
blufor_RQST_VEHICLE_17_X =			["CUP_I_LAV25_RACS","LAV 25 (28CP)",28];
blufor_RQST_VEHICLE_18_X =			["CUP_I_LAV25M240_RACS","LAV 25 MG (32CP)",32];
blufor_RQST_VEHICLE_19_X =			["CUP_I_AAV_RACS","AAVP7/A1 (35CP)",35];
blufor_RQST_VEHICLE_20_X =			["B_APC_Tracked_01_rcws_F","IFV-6C Panther (30CP)",30];
blufor_RQST_VEHICLE_21_X =			["B_APC_Tracked_01_AA_F","IFV-6A Cheetah (35CP)",35];
blufor_RQST_VEHICLE_22_X =			["CUP_I_M60A3_TTS_RACS","M60A3 Tank (40CP)",40];
blufor_RQST_VEHICLE_23_X =			["CUP_I_T72_RACS","T-72 Tank (40CP)",40];
blufor_RQST_VEHICLE_24_X =			["CUP_O_T90_RU","T-90A (50CP)",50];
blufor_RQST_VEHICLE_25_X =			["CUP_O_ZSU23_SLA","ZSU-23 Tunguska (50CP)",50];
blufor_RQST_VEHICLE_26_X =			["CUP_I_M270_DPICM_RACS","M270 MLRS Artillery (75CP)",75];
blufor_RQST_VEHICLE_27_X =			["CUP_I_AH6J_RACS","AH-6 Littlebird (15CP)",15];
blufor_RQST_VEHICLE_28_X =			["CUP_I_UH1H_RACS","UH-1H MG (25CP)",25];
blufor_RQST_VEHICLE_29_X =			["CUP_I_UH1H_gunship_RACS","UH-1H Gunship (25CP)",25];
blufor_RQST_VEHICLE_30_X =			["CUP_I_UH60L_RACS","UH-60 Armed (28CP)",28];
blufor_RQST_VEHICLE_31_X =			["CUP_B_AH1Z_Dynamic_USMC","AH1Z Attack Heli (40CP)",40];
blufor_RQST_VEHICLE_32_X =			["CUP_I_SA330_Puma_HC2_RACS","SA-330 Puma Trans Heli (22CP)",22];
blufor_RQST_VEHICLE_33_X =			["CUP_I_CH47F_RACS","CH-47 Transport (26CP)",26];
blufor_RQST_VEHICLE_34_X =			["CUP_B_A10_DYN_USA","A-10 CAS (45CP)",45];
blufor_RQST_VEHICLE_35_X =			["CUP_B_AV8B_DYN_USMC","AV-8 Harrier (50CP)",50];
blufor_RQST_VEHICLE_36_X =			["CUP_B_MV22_USMC_RAMPGUN","MV-22 Osprey (60CP)",60];
blufor_RQST_VEHICLE_37_X =			["B_UAV_01_F","UAV Darter(5CP)",5];
blufor_RQST_VEHICLE_38_X =			["CUP_O_Pchela1T_RU","UAV Pchela 1T (15CP)",15];
blufor_RQST_VEHICLE_39_X =			["B_UGV_01_F","UGV Stomper Recon (10CP)",10];
blufor_RQST_VEHICLE_40_X =			["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20];
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



