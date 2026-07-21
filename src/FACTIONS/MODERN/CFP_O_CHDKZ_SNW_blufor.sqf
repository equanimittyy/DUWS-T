
///////////////
///////////////   "CFP_O_CHDKZ", "CFP ChDKZ + Spetsnaz (Winter)", "CFP_O_CHDKZ_SNW"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"CFP_O_CHDKZ_Rifleman_AK_74_SNW_01";		//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"CFP_O_CHDKZ_AT_Specialist_SNW_01";			//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"CFP_O_CHDKZ_Grenadier_SNW_01";				//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"CFP_O_CHDKZ_Officer_SNW_01";				//initHQ\fnc_createpatrolFOB, initHQ\fnc_HQguards
blufor_SOLDIER_SL_X =			"CFP_O_CHDKZ_Officer_SNW_01";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"CFP_O_CHDKZ_Machinegunner_SNW_01";			//supports\fnc_paradrop, initHQ\fnc_HQguards
blufor_MARKSMAN_X = 			"CFP_O_CHDKZ_Sniper_SNW_01";				//initHQ\fnc_HQguards
blufor_OFFICER_X =				"CFP_O_CHDKZ_Commander_SNW_01";				//initHQ\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CFP_O_CHDKZ_Pilot_SNW_01";					//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CUP_O_Mi24_D_Dynamic_SLA";			//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"CFP_O_CHDKZ_Mi_8MT_SNW_01";   		//random patrol
blufor_HELI_ATTACK_X =			"CUP_O_Mi24_D_Dynamic_SLA";			//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"CUP_O_Su25_Dyn_SLA";				//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"CFP_O_CHDKZ_UAZ_DShKM_SNW_01";		//random patrol
blufor_APC_PATROL1_X =			"CFP_O_CHDKZ_BTR_80A_SNW_01";		//random patrol
blufor_APC_PATROL2_X =			"CFP_O_CHDKZ_BMP_2_SNW_01";			//random patrol
blufor_TANK_PATROL1_X =			"CFP_O_CHDKZ_T72_SNW_01";			//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"CUP_O_ZU23_TK";			// also "CUP_O_Igla_AA_pod_RU"
blufor_TURRET_AT =				"CUP_O_Kornet_RU";
blufor_TURRET_HMG =				"CUP_O_DSHKM_SLA";
blufor_TURRET_GMG =				"CUP_O_DSHKM_SLA";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"CUP_O_RU_Recon_TL_Ratnik_Winter";			//operator
blufor_SPECOPS_GL_X =			"CUP_O_RU_Soldier_GL_Ratnik_Winter";		//operator
blufor_SPECOPS_LAT_X =			"CUP_O_RU_Soldier_AT_Ratnik_Winter";		//operator
blufor_SPECOPS_HAT_X =			"CUP_O_RU_Soldier_HAT_Ratnik_Winter";		//operator
blufor_SPECOPS_AA_X =			"CUP_O_RU_Soldier_AA_Ratnik_Winter";		//operator
blufor_SPECOPS_MG_X =			"CUP_O_RU_Soldier_MG_Ratnik_Winter";		//operator
blufor_SPECOPS_MEDIC_X =		"CUP_O_RU_Soldier_Medic_Ratnik_Winter";		//operator
blufor_SPECOPS_MARK_X =			"CUP_O_RU_Recon_Marksman_Ratnik_Winter";	//operator
blufor_SPECOPS_SNIPER_X =		"CUP_O_RU_Soldier_Marksman_Ratnik_Winter";	//operator
blufor_SPECOPS_EXP_X =			"CUP_O_RU_Recon_Exp_Ratnik_Winter";			//operator
blufor_SPECOPS_ENG_X = 			"CUP_O_RU_Soldier_Engineer_Ratnik_Winter";	//operator





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


blufor_RQST_UNIT_01_X = 			["CFP_O_CHDKZ_Rifleman_AK_74_SNW_01","Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				["CFP_O_CHDKZ_Grenadier_SNW_01","Grenadier (3CP)",3];
blufor_RQST_UNIT_03_X =				["CFP_O_CHDKZ_Automatic_Rifleman_SNW_01","Automatic Rifleman (3CP)",3];
blufor_RQST_UNIT_04_X =				["CFP_O_CHDKZ_Machinegunner_SNW_01","Heavy Gunner (4CP)",4];
blufor_RQST_UNIT_05_X =				["CFP_O_CHDKZ_Medic_SNW_01","Medic (4CP)",4];
blufor_RQST_UNIT_06_X =				["CUP_O_INS_Soldier_LAT","AT Rifleman (3CP)",3];
blufor_RQST_UNIT_07_X =				["CFP_O_CHDKZ_AT_Specialist_SNW_01","AT Specialist (4CP)",4];
blufor_RQST_UNIT_08_X =				["CFP_O_CHDKZ_AA_Specialist_SNW_01","AA Specialist (4CP)",4];
blufor_RQST_UNIT_09_X =				["CFP_O_CHDKZ_Engineer_SNW_01","Engineer (4CP)",4];
blufor_RQST_UNIT_10_X =				["CFP_O_CHDKZ_Sniper_SNW_01","Sniper (4CP)",4];
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

blufor_RQST_VEHICLE_01_X =			["B_Quadbike_01_F","ATV (1CP)",1];
blufor_RQST_VEHICLE_02_X =			["C_Offroad_01_F","SF Offroader (2CP)",2];
blufor_RQST_VEHICLE_03_X =			["I_G_Van_01_transport_F","Transport Truck (6CP)",6];
blufor_RQST_VEHICLE_04_X =			["CUP_O_GAZ_Vodnik_PK_RU","GAZ Vodnik MG (10CP)",10];
blufor_RQST_VEHICLE_05_X =			["CUP_O_GAZ_Vodnik_AGS_RU","GAZ Vodnik GMG (18CP)",18];
blufor_RQST_VEHICLE_06_X =			["CUP_O_GAZ_Vodnik_BPPU_RU","GAZ Vodnik BPPU (25CP)",25];
blufor_RQST_VEHICLE_07_X =			["CFP_O_CHDKZ_UAZ_SNW_01","UAZ Unarmed (5CP)",5];
blufor_RQST_VEHICLE_08_X =			["CFP_O_CHDKZ_UAZ_DShKM_SNW_01","UAZ DshKm HMG (15CP)",15];
blufor_RQST_VEHICLE_09_X =			["CFP_O_CHDKZ_UAZ_Metis_SNW_01","UAZ Metis AT (20CP)",20];
blufor_RQST_VEHICLE_10_X =			["CFP_O_CHDKZ_Ural_Open_SNW_01","Ural Transport Uncovered (8CP)",8];
blufor_RQST_VEHICLE_11_X =			["CFP_O_CHDKZ_Ural_SNW_01","Ural Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_12_X =			["CFP_O_CHDKZ_Ural_Repair_SNW_01","Ural Repair (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["CFP_O_CHDKZ_Ural_Ammo_SNW_01","Ural Ammo (50CP)",50];
blufor_RQST_VEHICLE_14_X =			["CFP_O_CHDKZ_Ural_Refuel_SNW_01","Ural Fuel (50CP)",50];
blufor_RQST_VEHICLE_15_X =			["CFP_O_CHDKZ_BRDM_2_SNW_01","BRDM-2 (28CP)",28];
blufor_RQST_VEHICLE_16_X =			["CFP_O_CHDKZ_BRDM_2ATGM_SNW_01","BRDM-2 ATGM (35CP)",35];
blufor_RQST_VEHICLE_17_X =			["CFP_O_CHDKZ_BTR_60PB_SNW_01","BTR-60 (28CP)",28];
blufor_RQST_VEHICLE_18_X =			["CFP_O_CHDKZ_BTR_80_SNW_01","BTR-80 (32CP)",32];
blufor_RQST_VEHICLE_19_X =			["CFP_O_CHDKZ_BTR_80A_SNW_01","BTR-80A (35CP)",35];
blufor_RQST_VEHICLE_20_X =			["CFP_O_CHDKZ_BMP_2_SNW_01","BMP-2 (30CP)",30];
blufor_RQST_VEHICLE_21_X =			["CFP_O_CHDKZ_BMP_2K_SNW_01","BMP-2k (35CP)",35];
blufor_RQST_VEHICLE_22_X =			["CFP_O_CHDKZ_T55_SNW_01","T-55 Tank (35CP)",35];
blufor_RQST_VEHICLE_23_X =			["CFP_O_CHDKZ_T72_SNW_01","T-72 (40CP)",40];
blufor_RQST_VEHICLE_24_X =			["CUP_O_T90_RU","Russian T-90A (50CP)",50];
blufor_RQST_VEHICLE_25_X =			["CFP_O_CHDKZ_ZSU_23_4_SNW_01","ZSU-23 Tunguska (50CP)",50];
blufor_RQST_VEHICLE_26_X =			["CFP_O_CHDKZ_BM_21_SNW_01","BM-21 Rockets (75CP)",75];
blufor_RQST_VEHICLE_27_X =			["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15];
blufor_RQST_VEHICLE_28_X =			["CUP_O_UH1H_gunship_SLA","UH-1H Gunship (22CP)",22];
blufor_RQST_VEHICLE_29_X =			["CFP_O_CHDKZ_Mi_8MT_SNW_01","MI-8 Trans Heli (25CP)",25];
blufor_RQST_VEHICLE_30_X =			["CUP_O_MI6A_CHDKZ","MI-6A Transport (40CP)",40];
blufor_RQST_VEHICLE_31_X =			["CUP_O_Mi24_D_Dynamic_SLA","MI-24D Armed (40CP",40];
blufor_RQST_VEHICLE_32_X =			["CUP_O_Su25_Dyn_SLA","SU-25 Frogfoot CAS (45CP)",45];
blufor_RQST_VEHICLE_33_X =			["CUP_O_SU34_SLA","SU-34 Sabre (50CP)",50];
blufor_RQST_VEHICLE_34_X =			["B_UAV_01_F","UAV Darter(5CP)",5];
blufor_RQST_VEHICLE_35_X =			["CUP_O_Pchela1T_RU","UAV Pchela 1T (15CP)",15];
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



