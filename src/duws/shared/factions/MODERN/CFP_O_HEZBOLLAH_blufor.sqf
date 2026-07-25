///////////////
///////////////    "CFP_O_HEZBOLLAH", "CFP Hezbollah + Stolen Vehicle Support", "CFP_O_HEZBOLLAH"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"CFP_O_HEZBOLLAH_Paramilitary_Rifleman_01";		//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"CFP_O_HEZBOLLAH_Paramilitary_Rifleman_AT_01";					//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"CFP_O_HEZBOLLAH_Militia_Explosive_Specialist_01";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"CFP_O_HEZBOLLAH_Squad_Leader_SF_01";				//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"CFP_O_HEZBOLLAH_Militia_Squad_Leader_01";			//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"CFP_O_HEZBOLLAH_Militia_Machine_Gunner_01";		//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"CFP_O_HEZBOLLAH_Sniper_SF_01";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"CFP_O_HEZBOLLAH_Militia_Squad_Leader_01";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CUP_O_TK_Pilot";					//missions\missions\pilot\mission.sqf

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CUP_I_UH1H_TK_GUE";				//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"CUP_I_UH1H_TK_GUE";   				//random patrol
blufor_HELI_ATTACK_X =			"CUP_I_UH1H_gunship_TK_GUE";		//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"CUP_I_UH1H_gunship_TK_GUE";		//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"CFP_O_HEZBOLLAH_Hilux_01";				//random patrol
blufor_APC_PATROL1_X =			"CFP_O_HEZBOLLAH_Hilux_Metis_01";					//random patrol
blufor_APC_PATROL2_X =			"CFP_O_HEZBOLLAH_BTR_60PB_01";				//random patrol
blufor_TANK_PATROL1_X =			"CFP_O_HEZBOLLAH_T72_01";				//random patrol


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

blufor_SPECOPS_X =				"CFP_O_HEZBOLLAH_Squad_Leader_SF_01";			//operator
blufor_SPECOPS_GL_X =			"CFP_O_HEZBOLLAH_Rifleman_AT_SF_01";					//operator
blufor_SPECOPS_LAT_X =			"CFP_O_HEZBOLLAH_Medic_SF_01";						//operator
blufor_SPECOPS_HAT_X =			"CFP_O_HEZBOLLAH_Explosive_Specialist_SF_01";			//operator
blufor_SPECOPS_AA_X =			"CFP_O_HEZBOLLAH_Militia_Rifleman_AT_01";				//operator
blufor_SPECOPS_MG_X =			"CFP_O_HEZBOLLAH_Militia_Machine_Gunner_01";			//operator
blufor_SPECOPS_MEDIC_X =		"CFP_O_HEZBOLLAH_Militia_Medic_01";			//operator
blufor_SPECOPS_MARK_X =			"CFP_O_HEZBOLLAH_Sniper_SF_01";					//operator
blufor_SPECOPS_SNIPER_X =		"CFP_O_HEZBOLLAH_Sniper_SF_01";				//operator
blufor_SPECOPS_EXP_X =			"CFP_O_HEZBOLLAH_Explosive_Specialist_SF_01";	//operator
blufor_SPECOPS_ENG_X = 			"CFP_O_HEZBOLLAH_Paramilitary_Rifleman_01";	//operator





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


blufor_RQST_UNIT_01_X = 			["CFP_O_HEZBOLLAH_Paramilitary_Rifleman_01","Militant Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				["CFP_O_HEZBOLLAH_Militia_Explosive_Specialist_01","Explosive Specialist (3CP)",3];
blufor_RQST_UNIT_03_X =				["CFP_O_HEZBOLLAH_Militia_Machine_Gunner_01","Heavy Gunner (4CP)",4];
blufor_RQST_UNIT_04_X =				["CFP_O_HEZBOLLAH_Militia_Medic_01","Medic (4CP)",4];
blufor_RQST_UNIT_05_X =				["CFP_O_HEZBOLLAH_Paramilitary_Rifleman_AT_01","AT Specialist (4CP)",4];
blufor_RQST_UNIT_06_X =				["CFP_O_HEZBOLLAH_Militia_Rifleman_AT_01","AA Specialist (4CP)",4];
blufor_RQST_UNIT_07_X =				["cfp_o_is_sapper","Engineer (4CP)",4];
blufor_RQST_UNIT_08_X =				["CFP_O_HEZBOLLAH_Sniper_SF_01","Sniper (4CP)",4];
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
blufor_RQST_VEHICLE_03_X =			["CFP_O_HEZBOLLAH_Truck_01","Transport Truck (6CP)",6];
blufor_RQST_VEHICLE_04_X =			["CFP_O_HEZBOLLAH_Hilux_01","Hilux Vehicle (10CP)",10];
blufor_RQST_VEHICLE_05_X =			["CFP_O_HEZBOLLAH_Offroad_Armed_01","Offroad HMG (15CP)",15];
blufor_RQST_VEHICLE_06_X =			["CFP_O_HEZBOLLAH_Hilux_Metis_01","Hilux Metis AT (18CP)",18];
blufor_RQST_VEHICLE_07_X =			["CFP_O_HEZBOLLAH_Hilux_Podnos_01","Hilux Podnos (25CP)",25];
blufor_RQST_VEHICLE_08_X =			["CFP_O_HEZBOLLAH_Hilux_MLRS_01","Hilux MLRS (27CP)",27];
blufor_RQST_VEHICLE_09_X =			["CFP_O_HEZBOLLAH_Hilux_ZU_23_01","Hilux ZU23 AA (22CP)",22];
blufor_RQST_VEHICLE_10_X =			["CFP_O_ANSARALLAH_Ural_Repair_01","Ural Repair (50CP)",50];
blufor_RQST_VEHICLE_11_X =			["CFP_O_ANSARALLAH_Ural_Ammo_01","Ural Ammo (50CP)",50];
blufor_RQST_VEHICLE_12_X =			["CFP_O_ANSARALLAH_Ural_Fuel_01","Ural Fuel (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["CFP_O_HEZBOLLAH_BTR_60PB_01","BTR-60P APC (25CP)",25];
blufor_RQST_VEHICLE_14_X =			["CFP_O_HEZBOLLAH_BMP_2_01","BMP2 APC (28CP)",28];
blufor_RQST_VEHICLE_15_X =			["CFP_O_HEZBOLLAH_BTR_60PB_01","MTLB-LV APC (28CP)",28];
blufor_RQST_VEHICLE_16_X =			["CUP_I_BRDM2_TK_Gue","BRDM-2 (32CP)",32];
blufor_RQST_VEHICLE_17_X =			["CUP_I_BRDM2_ATGM_TK_Gue","BRDM-2 ATGM (35CP)",35];
blufor_RQST_VEHICLE_18_X =			["cfp_i_alNusra_BMP1P","Stolen BMP1-P (32CP)",32];
blufor_RQST_VEHICLE_19_X =			["CFP_O_HEZBOLLAH_BTR_60PB_01","BTR 60PB (35CP)",35];
blufor_RQST_VEHICLE_20_X =			["CFP_O_HEZBOLLAH_T72_01","T-72 Tank (35CP)",35];
blufor_RQST_VEHICLE_21_X =			["CFP_O_HEZBOLLAH_Quad_Bike_01","Quad Bike (2CP)",2];
blufor_RQST_VEHICLE_22_X =			["CFP_O_HEZBOLLAH_Hilux_DShKM_01","Hilux DShKM (15CP)",15];
blufor_RQST_VEHICLE_23_X =			["empty",0,0];
blufor_RQST_VEHICLE_24_X =			["CUP_O_BM21_SLA","BM-21 Rockets (75CP)",75];
blufor_RQST_VEHICLE_25_X =			["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15];
blufor_RQST_VEHICLE_26_X =			["CUP_I_UH1H_TK_GUE","Stolen UH-1H (22CP)",22];
blufor_RQST_VEHICLE_27_X =			["CUP_I_UH1H_gunship_TK_GUE","Stolen UH-1H Gunship (25CP)",25];
blufor_RQST_VEHICLE_28_X =			["CUP_B_UH60M_US","Stolen UH-60 Blackhawk (35CP)",35];
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


