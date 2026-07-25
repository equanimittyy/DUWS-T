
///////////////
///////////////   "CUP_O_TK_Army", "Takistani Army + USA SpecOps", "CUP_O_TK_Army"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"CUP_O_TK_Soldier";				//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"CUP_O_TK_Soldier_AT";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"CUP_O_TK_Soldier_GL";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"CUP_O_TK_SpecOps_TL";			//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"CUP_O_TK_Soldier_SL";			//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"CUP_O_TK_Soldier_AR";			//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"CUP_O_TK_Soldier_M";			//init_hq\fnc_HQguards
blufor_OFFICER_X =				"CUP_O_TK_Story_Aziz";			//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CUP_O_TK_Pilot";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CUP_O_Mi24_D_Dynamic_TK";		//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"CUP_O_Mi17_TK";   				//random patrol
blufor_HELI_ATTACK_X =			"CUP_O_Mi24_D_Dynamic_SLA";		//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"CUP_O_Su25_Dyn_SLA";			//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"CUP_O_LR_MG_TKA";				//random patrol
blufor_APC_PATROL1_X =			"CUP_O_BTR80A_TK";				//random patrol
blufor_APC_PATROL2_X =			"CUP_O_BMP2_TKA";				//random patrol
blufor_TANK_PATROL1_X =			"CUP_O_T72_TKA";				//random patrol


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

blufor_SPECOPS_X =				"CUP_O_TK_SpecOps_TL";				//operator
blufor_SPECOPS_GL_X =			"CUP_O_TK_SpecOps";					//operator
blufor_SPECOPS_LAT_X =			"CUP_O_TK_Soldier_AT";				//operator
blufor_SPECOPS_HAT_X =			"CUP_O_TK_Soldier_HAT";				//operator
blufor_SPECOPS_AA_X =			"CUP_O_TK_Soldier_AA";				//operator
blufor_SPECOPS_MG_X =			"CUP_O_TK_SpecOps_MG";				//operator
blufor_SPECOPS_MEDIC_X =		"CUP_O_TK_Medic";					//operator
blufor_SPECOPS_MARK_X =			"CUP_O_TK_Soldier_M";				//operator
blufor_SPECOPS_SNIPER_X =		"CUP_O_TK_Sniper";					//operator
blufor_SPECOPS_EXP_X =			"CUP_O_TK_Engineer";				//operator
blufor_SPECOPS_ENG_X = 			"CUP_O_TK_Engineer";				//operator





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


blufor_RQST_UNIT_01_X = 			["CUP_O_TK_Soldier","Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				["CUP_O_TK_Soldier_GL","Grenadier (3CP)",3];
blufor_RQST_UNIT_03_X =				["CUP_O_TK_Soldier_AR","Automatic Rifleman (3CP)",3];
blufor_RQST_UNIT_04_X =				["CUP_O_TK_Soldier_MG","Heavy Gunner ",4];
blufor_RQST_UNIT_05_X =				["CUP_O_TK_Medic","Medic (4CP)",4];
blufor_RQST_UNIT_06_X =				["CUP_O_TK_Soldier_AT","AT Rifleman (3CP)",3];
blufor_RQST_UNIT_07_X =				["CUP_O_TK_Soldier_HAT","AT Specialist (4CP)",4];
blufor_RQST_UNIT_08_X =				["CUP_O_TK_Soldier_AA","AA Specialist (4CP)",4];
blufor_RQST_UNIT_09_X =				["CUP_O_TK_Engineer","Engineer (4CP)",4];
blufor_RQST_UNIT_10_X =				["CUP_O_TK_Spotter","Spotter (3CP)",3];
blufor_RQST_UNIT_11_X =				["CUP_O_TK_Soldier_M","Marksman (3CP)",3];
blufor_RQST_UNIT_12_X =				["CUP_O_TK_Sniper","Sniper (4CP)",4];
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
blufor_RQST_VEHICLE_04_X =			["CUP_B_HMMWV_Transport_USA","HMMV Transport (10CP)",10];
blufor_RQST_VEHICLE_05_X =			["CUP_B_HMMWV_M2_USA","HMMV HMG (18CP)",18];
blufor_RQST_VEHICLE_06_X =			["CUP_B_RG31E_M2_USA","MRAP RG-31 HMG (25CP)",25];
blufor_RQST_VEHICLE_07_X =			["CUP_O_UAZ_Unarmed_TKA","UAZ Unarmed (5CP)",5];
blufor_RQST_VEHICLE_08_X =			["CUP_O_UAZ_MG_TKA","UAZ DshKm HMG (15CP)",15];
blufor_RQST_VEHICLE_09_X =			["CUP_O_UAZ_METIS_TKA","UAZ Metis AT (20CP)",20];
blufor_RQST_VEHICLE_10_X =			["CUP_O_Ural_Open_TKA","Ural Transport Uncovered (8CP)",8];
blufor_RQST_VEHICLE_11_X =			["CUP_O_Ural_TKA","Ural Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_12_X =			["CUP_O_Ural_Repair_TKA","Ural Repair (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["CUP_O_Ural_Reammo_TKA","Ural Ammo (50CP)",50];
blufor_RQST_VEHICLE_14_X =			["CUP_O_Ural_Refuel_TKA","Ural Fuel (50CP)",50];
blufor_RQST_VEHICLE_15_X =			["CUP_O_M113_TKA","M-113 APC (28CP)",28];
blufor_RQST_VEHICLE_16_X =			["CUP_O_BRDM2_ATGM_TKA","BRDM-2 ATGM (35CP)",35];
blufor_RQST_VEHICLE_17_X =			["CUP_O_BTR60_TK","BTR-60 (28CP)",28];
blufor_RQST_VEHICLE_18_X =			["CUP_O_BTR80_TK","BTR-80 (32CP)",32];
blufor_RQST_VEHICLE_19_X =			["CUP_O_BTR80A_TK","BTR-80A (35CP)",35];
blufor_RQST_VEHICLE_20_X =			["CUP_O_BMP2_TKA","BMP-2 (30CP)",30];
blufor_RQST_VEHICLE_21_X =			["CUP_O_BMP_HQ_TKA","BMP-2k (35CP)",35];
blufor_RQST_VEHICLE_22_X =			["CUP_O_T34_TKA","T-34 Tank (35CP)",35];
blufor_RQST_VEHICLE_23_X =			["CUP_O_T55_TK","T-55 Tank (40CP)",40];
blufor_RQST_VEHICLE_24_X =			["CUP_O_T72_TKA","T-72 Tank (50CP)",50];
blufor_RQST_VEHICLE_25_X =			["CUP_O_ZSU23_TK","ZSU-23 Tunguska (50CP)",50];
blufor_RQST_VEHICLE_26_X =			["CUP_O_BM21_TKA","BM-21 Rockets (75CP)",75];
blufor_RQST_VEHICLE_27_X =			["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15];
blufor_RQST_VEHICLE_28_X =			["CUP_O_UH1H_gunship_TKA","UH-1H Gunship (22CP)",22];
blufor_RQST_VEHICLE_29_X =			["CUP_O_Mi17_TK","MI-8 Trans Heli (25CP)",25];
blufor_RQST_VEHICLE_30_X =			["CUP_B_UH60M_US","UH-60 Blackhawk (35CP)",35];
blufor_RQST_VEHICLE_31_X =			["CUP_O_Mi24_D_Dynamic_TK","MI-24D Armed (40CP",40];
blufor_RQST_VEHICLE_32_X =			["CUP_O_L39_TK","SU-34 Sabre (50CP)",50];
blufor_RQST_VEHICLE_33_X =			["CUP_O_Su25_Dyn_TKA","SU-25 Frogfoot CAS (45CP)",45];
blufor_RQST_VEHICLE_34_X =			["O_UAV_06_F","UAV Jinaah AL-6 (5CP)",5];
blufor_RQST_VEHICLE_35_X =			["CUP_B_USMC_DYN_MQ9","UAV USMC Reaper (15CP)",15];
blufor_RQST_VEHICLE_36_X =			["B_UGV_01_F","UGV Stomper Recon (10CP)",10];
blufor_RQST_VEHICLE_37_X =			["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20];
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


