
///////////////
///////////////   "CFP_B_CDF", "CUP-CFP Chernarus Defense Force (Winter)", "CFP_B_CDF_SNW"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"CUP_B_CDF_Soldier_SNW";			//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"CUP_B_CDF_Soldier_LAT_SNW";		//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"CUP_B_CDF_Soldier_GL_SNW";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"CUP_B_CDF_Soldier_TL_SNW";			//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"CUP_B_CDF_Soldier_TL_SNW";			//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"CUP_B_CDF_Soldier_MG_SNW";			//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"CUP_B_CDF_Soldier_Marksman_SNW";	//init_hq\fnc_HQguards
blufor_OFFICER_X =				"CUP_B_CDF_Officer_SNW";			//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CUP_B_CDF_Pilot_SNW";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CFP_B_CDF_Mi_24D_SNW_01";			//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"CFP_B_CDF_Mi_8MT_VIV_SNW_01";   	//random patrol
blufor_HELI_ATTACK_X =			"CFP_B_CDF_Mi_24D_SNW_01";			//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"CFP_B_CDF_Su_25_Frogfoot_SNW_01";	//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"CFP_B_CDF_UAZ_DShKM_SNW_01";		//random patrol
blufor_APC_PATROL1_X =			"CFP_B_CDF_BTR_80A_SNW_01";			//random patrol
blufor_APC_PATROL2_X =			"CFP_B_CDF_BMP_2K_SNW_01";			//random patrol
blufor_TANK_PATROL1_X =			"CFP_B_CDF_T72_SNW_01";				//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"CUP_O_Igla_AA_pod_RU";			// also "CUP_O_ZU23_TK"
blufor_TURRET_AT =				"CUP_O_Kornet_RU";
blufor_TURRET_HMG =				"CUP_O_DSHKM_SLA";
blufor_TURRET_GMG =				"CUP_O_DSHKM_SLA";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"CFP_B_CDF_SF_Operator_SNW_01";					//operator
blufor_SPECOPS_GL_X =			"CFP_B_CDF_SF_Team_Leader_SNW_01";				//operator
blufor_SPECOPS_LAT_X =			"CUP_B_CDF_Soldier_RPG18_SNW";					//operator
blufor_SPECOPS_HAT_X =			"CUP_B_CDF_Soldier_LAT_SNW";					//operator
blufor_SPECOPS_AA_X =			"CUP_B_CDF_Soldier_AA_SNW";						//operator
blufor_SPECOPS_MG_X =			"CUP_B_CDF_Soldier_MG_SNW";						//operator
blufor_SPECOPS_MEDIC_X =		"CUP_B_CDF_Medic_SNW";							//operator
blufor_SPECOPS_MARK_X =			"CUP_B_CDF_Soldier_Marksman_SNW";				//operator
blufor_SPECOPS_SNIPER_X =		"CUP_B_CDF_Sniper_SNW";							//operator
blufor_SPECOPS_EXP_X =			"CFP_B_CDF_SF_Explosives_Specialist_SNW_01";	//operator
blufor_SPECOPS_ENG_X = 			"CUP_B_CDF_Engineer_SNW";						//operator





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


blufor_RQST_UNIT_01_X = 			["CUP_B_CDF_Soldier_SNW","Rifleman (CDF) (2CP)",2];
blufor_RQST_UNIT_02_X =				["CUP_B_CDF_Soldier_GL_SNW","Grenadier (CDF) (3CP)",3];
blufor_RQST_UNIT_03_X =				["CUP_B_CDF_Soldier_AR_SNW","Automatic Rifleman (CDF) (3CP)",3];
blufor_RQST_UNIT_04_X =				["CUP_B_CDF_Soldier_MG_SNW","Heavy Gunner (MTP) (CDF)",4];
blufor_RQST_UNIT_05_X =				["CUP_B_CDF_Medic_SNW","Medic (CDF) (4CP)",4];
blufor_RQST_UNIT_06_X =				["CUP_B_CDF_Soldier_RPG18_SNW","AT Rifleman (CDF) (3CP)",3];
blufor_RQST_UNIT_07_X =				["CUP_B_CDF_Soldier_LAT_SNW","AT Specialist (CDF) (4CP)",4];
blufor_RQST_UNIT_08_X =				["CUP_B_CDF_Soldier_AA_SNW","AA Specialist (CDF) (4CP)",4];
blufor_RQST_UNIT_09_X =				["CUP_B_CDF_Engineer_SNW","Engineer (CDF) (4CP)",4];
blufor_RQST_UNIT_10_X =				["CUP_B_CDF_Spotter_SNW","Spotter (CDF) (3CP)",3];
blufor_RQST_UNIT_11_X =				["CUP_B_CDF_Soldier_Marksman_SNW","Marksman (CDF) (3CP)",3];
blufor_RQST_UNIT_12_X =				["CUP_B_CDF_Sniper_SNW","Sniper (CDF) (4CP)",4];
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
blufor_RQST_VEHICLE_07_X =			["CUP_B_CDF_Soldier_SNW","UAZ Unarmed (5CP)",5];
blufor_RQST_VEHICLE_08_X =			["CUP_B_CDF_Soldier_SNW","UAZ DshKm HMG (15CP)",15];
blufor_RQST_VEHICLE_09_X =			["CUP_B_CDF_Soldier_SNW","UAZ Metis AT (20CP)",20];
blufor_RQST_VEHICLE_10_X =			["CFP_B_CDF_Ural_Open_SNW_01","Ural Transport Uncovered (8CP)",8];
blufor_RQST_VEHICLE_11_X =			["CFP_B_CDF_Ural_SNW_01","Ural Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_12_X =			["CFP_B_CDF_Ural_Repair_SNW_01","Ural Repair (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["CFP_B_CDF_Ural_Ammo_SNW_01","Ural Ammo (50CP)",50];
blufor_RQST_VEHICLE_14_X =			["CFP_B_CDF_Ural_Refuel_SNW_01","Ural Fuel (50CP)",50];
blufor_RQST_VEHICLE_15_X =			["CFP_B_CDF_BRDM_2_SNW_01","BRDM-2 (28CP)",28];
blufor_RQST_VEHICLE_16_X =			["CFP_B_CDF_BRDM_2ATGM_SNW_01","BRDM-2 ATGM (35CP)",35];
blufor_RQST_VEHICLE_17_X =			["CFP_B_CDF_BTR_60PB_SNW_01","BTR-60 (28CP)",28];
blufor_RQST_VEHICLE_18_X =			["CFP_B_CDF_BTR_80_SNW_01","BTR-80 (32CP)",32];
blufor_RQST_VEHICLE_19_X =			["CFP_B_CDF_BTR_80A_SNW_01","BTR-80A (35CP)",35];
blufor_RQST_VEHICLE_20_X =			["CFP_B_CDF_BMP_2_SNW_01","BMP-2 (30CP)",30];
blufor_RQST_VEHICLE_21_X =			["CFP_B_CDF_BMP_2K_SNW_01","BMP-2k (35CP)",35];
blufor_RQST_VEHICLE_22_X =			["CUP_O_T55_SLA","T-55 Tank (35CP)",35];
blufor_RQST_VEHICLE_23_X =			["CFP_B_CDF_T72_SNW_01","T-72 (40CP)",40];
blufor_RQST_VEHICLE_24_X =			["CFP_O_RUARMY_T90A_DES_01","T-90 (50CP)",50];
blufor_RQST_VEHICLE_25_X =			["CFP_B_CDF_ZSU_23_4_SNW_01","ZSU-23 Tunguska (50CP)",50];
blufor_RQST_VEHICLE_26_X =			["CFP_B_CDF_BM_21_SNW_01","BM-21 Rockets (75CP)",75];
blufor_RQST_VEHICLE_27_X =			["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15];
blufor_RQST_VEHICLE_28_X =			["CUP_O_UH1H_gunship_SLA","UH-1H Gunship (25CP)",25];
blufor_RQST_VEHICLE_29_X =			["CUP_O_Ka50_DL_SLA","KA-50 Attack Heli (45CP)",45];
blufor_RQST_VEHICLE_30_X =			["CFP_B_CDF_Mi_24D_SNW_01","MI-24D Armed (40CP",40];
blufor_RQST_VEHICLE_31_X =			["CFP_B_CDF_Mi_8MT_VIV_SNW_01","MI-8 Trans Heli (22CP)",22];
blufor_RQST_VEHICLE_32_X =			["CUP_O_Mi8_SLA_2","MI-8 Armed (26CP)",26];
blufor_RQST_VEHICLE_33_X =			["CFP_B_CDF_Mi_6A_Hook_VIV_SNW_01","MI-6A Transport (26CP)",26];
blufor_RQST_VEHICLE_34_X =			["CFP_B_CDF_Su_25_Frogfoot_SNW_01","SU-25 Frogfoot CAS (45CP)",45];
blufor_RQST_VEHICLE_35_X =			["CFP_B_CDF_Su_34_SNW_01","SU-34 Sabre (50CP)",50];
blufor_RQST_VEHICLE_36_X =			["O_Plane_Fighter_02_Stealth_F","Shikra CSAT (Stealth) (60CP)",60];
blufor_RQST_VEHICLE_37_X =			["B_UAV_01_F","UAV Darter(5CP)",5];
blufor_RQST_VEHICLE_38_X =			["CUP_B_Pchela1T_CDF","UAV Pchela 1T (15CP)",15];
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


