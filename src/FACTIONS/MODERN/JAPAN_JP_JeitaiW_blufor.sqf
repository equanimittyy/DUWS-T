
///////////////
///////////////   "JAPAN_JP", "JP Japan JGSDF (Jeitai-W)", "JAPAN_JP_JeitaiW"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"Japan_JP_Jeitai_Soldier_Base";		//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"Japan_JP_Jeitai_Soldier_LAT";		//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"Japan_JP_Jeitai_Soldier_GL";		//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"Japan_JP_Jeitai_Soldier_TL";		//initHQ\fnc_createpatrolFOB, initHQ\fnc_HQguards
blufor_SOLDIER_SL_X =			"Japan_JP_Jeitai_Soldier_SL";		//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"Japan_JP_Jeitai_soldier_AR";		//supports\fnc_paradrop, initHQ\fnc_HQguards
blufor_MARKSMAN_X = 			"Japan_JP_Jeitai_soldier_M";		//initHQ\fnc_HQguards
blufor_OFFICER_X =				"Japan_JP_Jeitai_officer";			//initHQ\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"Japan_JP_Jeitai_Soldier_F";		//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"JPA_MH60M";						//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"Jp_Bell_412";   					//random patrol
blufor_HELI_ATTACK_X =			"Jp_Cobra_Camo_H";					//dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"Japan_Plane_Fighter_03_CAS";		//dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"Jp_MRZR_Armed_2";					//random patrol
blufor_APC_PATROL1_X =			"Jp_IFV_Warrior";					//random patrol
blufor_APC_PATROL2_X =			"Jp_IFV_Warrior";					//random patrol
blufor_TANK_PATROL1_X =			"Jp_MBT_Kuma";						//random patrol


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

blufor_SPECOPS_X =				"Japan_JP_Jeitai_recon";				//operator
blufor_SPECOPS_GL_X =			"Japan_JP_Pattern_Soldier_GL";			//operator
blufor_SPECOPS_LAT_X =			"Japan_JP_Jeitai_recon_LAT";			//operator
blufor_SPECOPS_HAT_X =			"Japan_JP_Pattern_Soldier_AT";			//operator
blufor_SPECOPS_AA_X =			"Japan_JP_Pattern_Soldier_AA";			//operator
blufor_SPECOPS_MG_X =			"Japan_JP_Pattern_soldier_AR";			//operator
blufor_SPECOPS_MEDIC_X =		"Japan_JP_Pattern_Soldier_Tshirt";		//operator
blufor_SPECOPS_MARK_X =			"Japan_JP_Jeitai_soldier_M";			//operator
blufor_SPECOPS_SNIPER_X =		"Japan_JP_Pattern_Soldier_M";			//operator
blufor_SPECOPS_EXP_X =			"Japan_JP_Pattern_Soldier_repair";		//operator
blufor_SPECOPS_ENG_X = 			"Japan_JP_Pattern_Soldier_repair";		//operator





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


blufor_RQST_UNIT_01_X = 			["Japan_JP_Jeitai_Soldier_Base","Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				["Japan_JP_Jeitai_Soldier_GL","Grenadier (3CP)",3];
blufor_RQST_UNIT_03_X =				["Japan_JP_Jeitai_soldier_AR","Automatic Rifleman (3CP)",3];
blufor_RQST_UNIT_04_X =				["Japan_JP_Jeitai_Soldier_Tshirt","Medic (4CP)",4];
blufor_RQST_UNIT_05_X =				["Japan_JP_Jeitai_Soldier_LAT","AT Rifleman (3CP)",3];
blufor_RQST_UNIT_06_X =				["Japan_JP_Jeitai_soldier_AT","AT Specialist (4CP)",4];
blufor_RQST_UNIT_07_X =				["Japan_JP_Jeitai_soldier_AA","AA Specialist (4CP)",4];
blufor_RQST_UNIT_08_X =				["Japan_JP_Jeitai_soldier_repair","Engineer (4CP)",4];
blufor_RQST_UNIT_09_X =				["Japan_JP_Jeitai_soldier_M","Sniper (4CP)",4];
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
blufor_RQST_VEHICLE_04_X =			["B_MRAP_01_F","Hunter Unarmed (5CP)",5];
blufor_RQST_VEHICLE_05_X =			["B_MRAP_01_hmg_F","Hunter HMG (18CP)",18];
blufor_RQST_VEHICLE_06_X =			["B_MRAP_01_gmg_F","Hunter GMG (25CP)",25];
blufor_RQST_VEHICLE_07_X =			["B_LSV_01_unarmed_F","Prowler Unarmed (5CP)",5];
blufor_RQST_VEHICLE_08_X =			["B_LSV_01_armed_F","Prowler HMG (15CP)",15];
blufor_RQST_VEHICLE_09_X =			["B_LSV_01_AT_F","Prowler AT (20CP)",20];
blufor_RQST_VEHICLE_10_X =			["Japan_Fuso_transport_Truck_OD","Fuso Truck Uncovered (8CP)",8];
blufor_RQST_VEHICLE_11_X =			["O_Truck_03_covered_F","Fuso Truck Covered (8CP)",8];
blufor_RQST_VEHICLE_12_X =			["Japan_Fuso_device_Truck_OD","Fuso Truck Repair (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["Japan_Fuso_ammo_Truck_OD","Fuso Truck Ammo (50CP)",50];
blufor_RQST_VEHICLE_14_X =			["O_Truck_03_fuel_F","Fuso Truck Fuel (50CP)",50];
blufor_RQST_VEHICLE_15_X =			["B_APC_Tracked_01_rcws_F","IFV-6c Panther (25CP)",25];
blufor_RQST_VEHICLE_16_X =			["B_APC_Wheeled_01_cannon_F","AMV-7 Marshall (35CP)",35];
blufor_RQST_VEHICLE_17_X =			["Jp_IFV_Warrior","IFV Warrior (32CP)",32];
blufor_RQST_VEHICLE_18_X =			["B_APC_Tracked_01_AA_F","IFV-6c Cheetah (35CP)",35];
blufor_RQST_VEHICLE_19_X =			["B_MBT_01_cannon_F","M2A1 Slammer (40CP)",40];
blufor_RQST_VEHICLE_20_X =			["Jp_MBT_Kuma","Kuma MBT (45CP)",40];
blufor_RQST_VEHICLE_21_X =			["B_MBT_01_mlrs_F","Sandstorm MLRS (75CP)",75];
blufor_RQST_VEHICLE_22_X =			["B_MBT_01_arty_F","M4 Scorcher (75CP)",75];
blufor_RQST_VEHICLE_23_X =			["B_Heli_Light_01_dynamicLoadout_F","AH-9 Pawnee (25CP)",25];
blufor_RQST_VEHICLE_24_X =			["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15];
blufor_RQST_VEHICLE_25_X =			["Jp_Bell_412","Bell Huey Trans (22CP)",22];
blufor_RQST_VEHICLE_26_X =			["JPA_MH60M","Blackhawk Armed (26CP)",26];
blufor_RQST_VEHICLE_27_X =			["B_T_VTOL_01_armed_F","V-44 X Armed (40CP",40];
blufor_RQST_VEHICLE_28_X =			["Jp_Cobra_Camo_H","Super Cobra Gunship (45CP)",45];
blufor_RQST_VEHICLE_29_X =			["B_Plane_CAS_01_dynamicLoadout_F","A-164 Wipeout CAS (45CP)",45];
blufor_RQST_VEHICLE_30_X =			["Japan_Plane_Fighter_02_CAS","Czech L-39 (50CP)",50];
blufor_RQST_VEHICLE_31_X =			["B_Plane_Fighter_01_Stealth_F","Black Wasp 2 Stealth (60CP)",60];
blufor_RQST_VEHICLE_32_X =			["B_UAV_01_F","UAV Darter(5CP)",5];
blufor_RQST_VEHICLE_33_X =			["B_UAV_02_dynamicLoadout_F","UAV MQ-4A Greyhawk (15CP)",15];
blufor_RQST_VEHICLE_34_X =			["B_UGV_01_F","UGV Stomper Recon (10CP)",10];
blufor_RQST_VEHICLE_35_X =			["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20];
blufor_RQST_VEHICLE_36_X =			["B_T_UAV_03_dynamicLoadout_F","MQ-12 UAV (20CP)",20];
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


