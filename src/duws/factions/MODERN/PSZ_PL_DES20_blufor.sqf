
///////////////
///////////////   "PSZ_PL", "PSZ Polish Army (DES20)", "PSZ_PL_DES20"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"PSZ_PL_DES20_Soldier_Rifleman";		//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"PSZ_PL_DES20_Soldier_AT_RPG7";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"PSZ_PL_DES20_Soldier_Grenadier";		//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"PSZ_PL_DES20_Soldier_TL";				//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"PSZ_PL_DES20_Soldier_SL";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"PSZ_PL_DES20_Soldier_PKM";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"PSZ_PL_DES20_Soldier_Marksman";		//init_hq\fnc_HQguards
blufor_OFFICER_X =				"PSZ_PL_DES20_Soldier_Officer";			//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"PSZ_PL_DES20_Soldier_Pilot";			//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";			//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";						//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"PSZ_PL_DES20_Mi17_1W_UB32";			//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"PSZ_PL_DES20_Mi17_1W_PKT";   			//random patrol
blufor_HELI_ATTACK_X =			"PSZ_PL_DES20_Mi24D";					//dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"B_Plane_CAS_01_dynamicLoadout_F";		//dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"PSZ_PL_DES20_Tumak2_WKM";				//random patrol
blufor_APC_PATROL1_X =			"PSZ_PL_DES20_Zbik_M97";				//random patrol
blufor_APC_PATROL2_X =			"PSZ_PL_DES20_Rosomak_M1M";				//random patrol
blufor_TANK_PATROL1_X =			"PSZ_PL_DES20_Leopard_2PL";				//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"B_static_AA_F";
blufor_TURRET_AT =				"B_static_AT_F";
blufor_TURRET_HMG =				"B_G_HMG_02_high_F";
blufor_TURRET_GMG =				"B_GMG_01_high_F";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"PSZ_PL_DES20_Soldier_Rifleman";		//operator
blufor_SPECOPS_GL_X =			"PSZ_PL_DES20_Soldier_Grenadier";		//operator
blufor_SPECOPS_LAT_X =			"PSZ_PL_DES20_Soldier_AT_RPG7";			//operator
blufor_SPECOPS_HAT_X =			"PSZ_PL_DES20_Soldier_AT_M3";			//operator
blufor_SPECOPS_AA_X =			"PSZ_PL_DES20_Soldier_AA";				//operator
blufor_SPECOPS_MG_X =			"PSZ_PL_DES20_Soldier_PKM";				//operator
blufor_SPECOPS_MEDIC_X =		"PSZ_PL_DES20_Soldier_Medic";			//operator
blufor_SPECOPS_MARK_X =			"PSZ_PL_DES20_Soldier_Marksman";		//operator
blufor_SPECOPS_SNIPER_X =		"PSZ_PL_DES20_Soldier_Sniper";			//operator
blufor_SPECOPS_EXP_X =			"PSZ_PL_DES20_Soldier_Sapper";			//operator
blufor_SPECOPS_ENG_X = 			"PSZ_PL_DES20_Soldier_Sapper";			//operator





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


blufor_RQST_UNIT_01_X = 			["PSZ_PL_DES20_Soldier_Rifleman","Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				["PSZ_PL_DES20_Soldier_Grenadier","Grenadier (3CP)",3];
blufor_RQST_UNIT_03_X =				["PSZ_PL_DES20_Soldier_AR","Automatic Rifleman (3CP)",3];
blufor_RQST_UNIT_04_X =				["PSZ_PL_DES20_Soldier_PKM","Heavy Gunner (4CP)",4];
blufor_RQST_UNIT_05_X =				["PSZ_PL_DES20_Soldier_Medic","Medic (4CP)",4];
blufor_RQST_UNIT_06_X =				["PSZ_PL_DES20_Soldier_AT_RPG7","AT Rifleman (3CP)",3];
blufor_RQST_UNIT_07_X =				["PSZ_PL_DES20_Soldier_AT_M3","AT Specialist (4CP)",4];
blufor_RQST_UNIT_08_X =				["PSZ_PL_DES20_Soldier_AA","AA Specialist (4CP)",4];
blufor_RQST_UNIT_09_X =				["PSZ_PL_DES20_Soldier_Sapper","Engineer (4CP)",4];
blufor_RQST_UNIT_10_X =				["PSZ_PL_DES20_Soldier_Marksman","Marksman (3CP)",3];
blufor_RQST_UNIT_11_X =				["PSZ_PL_DES20_Soldier_Sniper","Sniper (4CP)",4];
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
blufor_RQST_VEHICLE_05_X =			["PSZ_PL_DES20_Tumak2","Tumak 2 Unarmed (15CP)",15];
blufor_RQST_VEHICLE_06_X =			["PSZ_PL_DES20_Tumak2_WKM","Tumak 2 HMG (20CP)",20];
blufor_RQST_VEHICLE_07_X =			["B_LSV_01_unarmed_F","Prowler Unarmed (5CP)",5];
blufor_RQST_VEHICLE_08_X =			["B_LSV_01_armed_F","Prowler HMG (15CP)",15];
blufor_RQST_VEHICLE_09_X =			["B_LSV_01_AT_F","Prowler AT (20CP)",20];
blufor_RQST_VEHICLE_10_X =			["B_Truck_01_transport_F","HEMTT Transport Uncovered (8CP)",8];
blufor_RQST_VEHICLE_11_X =			["PSZ_PL_DES20_Star_1466","Star Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_12_X =			["B_Truck_01_Repair_F","HEMTT Repair (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["PSZ_PL_DES20_Star_1466_Ammo","Star 1466 Ammo (50CP)",50];
blufor_RQST_VEHICLE_14_X =			["PSZ_PL_DES20_Star_1466_Fuel","MTVR Fuel (50CP)",50];
blufor_RQST_VEHICLE_15_X =			["PSZ_PL_DES20_Zbik_M96","BRDM Szakal (25CP)",25];
blufor_RQST_VEHICLE_16_X =			["PSZ_PL_DES20_Zbik_M97","BRDM Zbik (30CP)",30];
blufor_RQST_VEHICLE_17_X =			["PSZ_PL_DES20_Rosomak_1","Rosomak (32CP)",32];
blufor_RQST_VEHICLE_18_X =			["PSZ_PL_DES20_Rosomak_M1M","Rosomak M1M (35CP)",35];
blufor_RQST_VEHICLE_19_X =			["B_MBT_01_cannon_F","M2A1 Slammer (40CP)",40];
blufor_RQST_VEHICLE_20_X =			["PSZ_PL_DES20_Leopard_2PL","Leopard 2 MBT (45CP)",40];
blufor_RQST_VEHICLE_21_X =			["B_MBT_01_mlrs_F","Sandstorm MLRS (75CP)",75];
blufor_RQST_VEHICLE_22_X =			["B_MBT_01_arty_F","M4 Scorcher (75CP)",75];
blufor_RQST_VEHICLE_23_X =			["B_Heli_Light_01_dynamicLoadout_F","AH-9 Pawnee (25CP)",25];
blufor_RQST_VEHICLE_24_X =			["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15];
blufor_RQST_VEHICLE_25_X =			["PSZ_PL_DES20_Mi17_1W_PKT","MI-17 Armed Heli (22CP)",22];
blufor_RQST_VEHICLE_26_X =			["PSZ_PL_DES20_Mi17_1W_UB32","MI-17 Gunship (26CP)",26];
blufor_RQST_VEHICLE_27_X =			["B_T_VTOL_01_armed_F","V-44 X Armed (40CP",40];
blufor_RQST_VEHICLE_28_X =			["PSZ_PL_DES20_Mi24D","MI-24 Gunship (45CP)",45];
blufor_RQST_VEHICLE_29_X =			["B_Plane_CAS_01_dynamicLoadout_F","A-164 Wipeout CAS (45CP)",45];
blufor_RQST_VEHICLE_30_X =			["B_Plane_Fighter_01_F","Black Wasp 2 (50CP)",50];
blufor_RQST_VEHICLE_31_X =			["B_Plane_Fighter_01_Stealth_F","Black Wasp 2 Stealth (60CP)",60];
blufor_RQST_VEHICLE_32_X =			["B_UAV_01_F","UAV Darter(5CP)",5];
blufor_RQST_VEHICLE_33_X =			["B_UAV_02_dynamicLoadout_F","UAV MQ-4A Greyhawk (15CP)",15];
blufor_RQST_VEHICLE_34_X =			["B_UGV_01_F","UGV Stomper Recon (10CP)",10];
blufor_RQST_VEHICLE_35_X =			["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20];
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


