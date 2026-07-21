
///////////////
///////////////   "CFP_O_IS", "CFP Middle East Insurgents", "CFP_O_IS"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"CFP_O_ALQAEDA_Rifleman_01";		//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"cfp_i_alNusra_at";					//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"cfp_o_is_grenadier";				//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"cfp_o_is_team_leader";				//initHQ\fnc_createpatrolFOB, initHQ\fnc_HQguards
blufor_SOLDIER_SL_X =			"cfp_o_is_squad_leader";			//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"cfp_i_alNusra_machinegunner";		//supports\fnc_paradrop, initHQ\fnc_HQguards
blufor_MARKSMAN_X = 			"cfp_i_alNusra_sniper";				//initHQ\fnc_HQguards
blufor_OFFICER_X =				"CUP_O_TK_SpecOps_TL";				//initHQ\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CUP_O_TK_Pilot";					//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CUP_I_UH1H_TK_GUE";				//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"CUP_I_UH1H_TK_GUE";   				//random patrol
blufor_HELI_ATTACK_X =			"CUP_I_UH1H_gunship_TK_GUE";		//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"CUP_I_UH1H_gunship_TK_GUE";		//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"cfp_o_is_offroad_M2";				//random patrol
blufor_APC_PATROL1_X =			"cfp_o_is_M113";					//random patrol
blufor_APC_PATROL2_X =			"cfp_o_is_BMP2_PKM";				//random patrol
blufor_TANK_PATROL1_X =			"cfp_i_alNusra_T55";				//random patrol


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

blufor_SPECOPS_X =				"CFP_O_ALQAEDA_Rifleman_01";			//operator
blufor_SPECOPS_GL_X =			"cfp_o_is_grenadier";					//operator
blufor_SPECOPS_LAT_X =			"cfp_i_alNusra_at";						//operator
blufor_SPECOPS_HAT_X =			"CFP_O_ALQAEDA_Rifleman_AT_01";			//operator
blufor_SPECOPS_AA_X =			"CUP_O_TK_INS_Soldier_AA";				//operator
blufor_SPECOPS_MG_X =			"cfp_i_alNusra_machinegunner";			//operator
blufor_SPECOPS_MEDIC_X =		"CFP_O_ANSARALLAH_Medic_01";			//operator
blufor_SPECOPS_MARK_X =			"cfp_i_alNusra_sniper";					//operator
blufor_SPECOPS_SNIPER_X =		"CFP_O_ALQAEDA_Sniper_01";				//operator
blufor_SPECOPS_EXP_X =			"CFP_O_ALQAEDA_Explosive_Specialist_01";	//operator
blufor_SPECOPS_ENG_X = 			"cfp_o_is_sapper";						//operator





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


blufor_RQST_UNIT_01_X = 			["CFP_O_ALQAEDA_Rifleman_01","Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				["cfp_o_is_grenadier","Grenadier (3CP)",3];
blufor_RQST_UNIT_03_X =				["cfp_i_alNusra_machinegunner","Heavy Gunner ",4];
blufor_RQST_UNIT_04_X =				["CUP_O_TK_INS_Guerilla_Medic","Medic (4CP)",4];
blufor_RQST_UNIT_05_X =				["CFP_O_ALQAEDA_Rifleman_AT_01","AT Specialist (4CP)",4];
blufor_RQST_UNIT_06_X =				["CUP_O_TK_INS_Soldier_AA","AA Specialist (4CP)",4];
blufor_RQST_UNIT_07_X =				["cfp_o_is_sapper","Engineer (4CP)",4];
blufor_RQST_UNIT_08_X =				["CFP_O_ALQAEDA_Sniper_01","Sniper (4CP)",4];
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

blufor_RQST_VEHICLE_01_X =			["B_Quadbike_01_F","ATV (1CP)",1];
blufor_RQST_VEHICLE_02_X =			["C_Offroad_01_F","SF Offroader (2CP)",2];
blufor_RQST_VEHICLE_03_X =			["I_G_Van_01_transport_F","Transport Truck (6CP)",6];
blufor_RQST_VEHICLE_04_X =			["CUP_B_HMMWV_Transport_USA","HMMV Transport (10CP)",10];
blufor_RQST_VEHICLE_05_X =			["CFP_O_HEZBOLLAH_Offroad_Armed_01","Offroad HMG (15CP)",15];
blufor_RQST_VEHICLE_06_X =			["CFP_O_ANSARALLAH_Offroad_AT_01","Offroad AT (18CP)",18];
blufor_RQST_VEHICLE_07_X =			["CUP_B_HMMWV_M2_USA","HMMV HMG (25CP)",25];
blufor_RQST_VEHICLE_08_X =			["CFP_O_ANSARALLAH_Zamak_01","Zamak Transport Uncovered (8CP)",8];
blufor_RQST_VEHICLE_09_X =			["cfp_o_is_Ural","Ural Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_10_X =			["CFP_O_ANSARALLAH_Ural_Repair_01","Ural Repair (50CP)",50];
blufor_RQST_VEHICLE_11_X =			["CFP_O_ANSARALLAH_Ural_Ammo_01","Ural Ammo (50CP)",50];
blufor_RQST_VEHICLE_12_X =			["CFP_O_ANSARALLAH_Ural_Fuel_01","Ural Fuel (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["cfp_o_is_BTR40_MG","BTR-40 HMG (25CP)",25];
blufor_RQST_VEHICLE_14_X =			["cfp_o_is_M113","M-113 APC (28CP)",28];
blufor_RQST_VEHICLE_15_X =			["CFP_O_HEZBOLLAH_BTR_60PB_01","MTLB-LV APC (28CP)",28];
blufor_RQST_VEHICLE_16_X =			["CUP_I_BRDM2_TK_Gue","BRDM-2 (32CP)",32];
blufor_RQST_VEHICLE_17_X =			["CUP_I_BRDM2_ATGM_TK_Gue","BRDM-2 ATGM (35CP)",35];
blufor_RQST_VEHICLE_18_X =			["cfp_i_alNusra_BMP1P","BMP-1 (32CP)",32];
blufor_RQST_VEHICLE_19_X =			["cfp_o_is_BMP2_PKM","BMP-2K (35CP)",35];
blufor_RQST_VEHICLE_20_X =			["cfp_o_is_T34","T-34 Tank (35CP)",35];
blufor_RQST_VEHICLE_21_X =			["cfp_o_is_T55","T-55 Tank (40CP)",40];
blufor_RQST_VEHICLE_22_X =			["cfp_o_is_T72","T-72 Tank (50CP)",50];
blufor_RQST_VEHICLE_23_X =			["cfp_o_is_BMP2_ZU","BMP-2 ZU-23 (35CP)",35];
blufor_RQST_VEHICLE_24_X =			["CUP_O_BM21_SLA","BM-21 Rockets (75CP)",75];
blufor_RQST_VEHICLE_25_X =			["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15];
blufor_RQST_VEHICLE_26_X =			["CUP_I_UH1H_TK_GUE","UH-1H (22CP)",22];
blufor_RQST_VEHICLE_27_X =			["CUP_I_UH1H_gunship_TK_GUE","UH-1H Gunship (25CP)",25];
blufor_RQST_VEHICLE_28_X =			["CUP_B_UH60M_US","UH-60 Blackhawk (35CP)",35];
blufor_RQST_VEHICLE_29_X =			["CUP_O_Mi24_D_Dynamic_SLA","MI-24D Armed (40CP)",40];
blufor_RQST_VEHICLE_30_X =			["CUP_O_Su25_Dyn_TKA","SU-25 Frogfoot(stolen) (50CP)",50];
blufor_RQST_VEHICLE_31_X =			["B_UAV_01_F","UAV Darter(5CP)",5];
blufor_RQST_VEHICLE_32_X =			["CUP_O_Pchela1T_RU","UAV Pchela 1T (15CP)",15];
blufor_RQST_VEHICLE_33_X =			["B_UGV_01_F","UGV Stomper Recon (10CP)",10];
blufor_RQST_VEHICLE_34_X =			["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20];
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


