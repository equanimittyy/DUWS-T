
///////////////
///////////////   "IND_F", "AAF Altis Armed Forces", "IND_F"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"I_soldier_F";					//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"I_Soldier_LAT_F";				//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"I_Soldier_GL_F";				//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"I_Soldier_TL_F";				//initHQ\fnc_createpatrolFOB, initHQ\fnc_HQguards
blufor_SOLDIER_SL_X =			"I_Soldier_SL_F";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"I_Soldier_AR_F";				//supports\fnc_paradrop, initHQ\fnc_HQguards
blufor_MARKSMAN_X = 			"I_soldier_M_F";				//initHQ\fnc_HQguards
blufor_OFFICER_X =				"I_OFFICER_F";					//initHQ\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"I_helipilot_F";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";	//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";				//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"I_Heli_light_03_dynamicLoadout_F";		//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"I_Heli_Transport_02_F";   				//random patrol
blufor_HELI_ATTACK_X =			"I_Heli_light_03_dynamicLoadout_F";		//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"I_Plane_Fighter_03_dynamicLoadout_F";	//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"I_MRAP_03_hmg_F";						//random patrol
blufor_APC_PATROL1_X =			"I_APC_Wheeled_03_cannon_F";			//random patrol
blufor_APC_PATROL2_X =			"I_LT_01_cannon_F";						//random patrol
blufor_TANK_PATROL1_X =			"I_MBT_03_cannon_F";					//random patrol


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

blufor_SPECOPS_X =				"I_soldier_F";					//operator
blufor_SPECOPS_GL_X =			"I_Soldier_GL_F";				//operator
blufor_SPECOPS_LAT_X =			"I_Soldier_LAT_F";				//operator
blufor_SPECOPS_HAT_X =			"I_Soldier_AT_F";				//operator
blufor_SPECOPS_AA_X =			"I_Soldier_AAA_F";				//operator
blufor_SPECOPS_MG_X =			"I_C_Soldier_Para_4_F";			//operator
blufor_SPECOPS_MEDIC_X =		"I_medic_F";					//operator
blufor_SPECOPS_MARK_X =			"I_soldier_M_F";				//operator
blufor_SPECOPS_SNIPER_X =		"I_Sniper_F";					//operator
blufor_SPECOPS_EXP_X =			"I_Soldier_exp_F";				//operator
blufor_SPECOPS_ENG_X = 			"I_engineer_F";					//operator





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


blufor_RQST_UNIT_01_X = 			["I_soldier_F","Rifleman (AAF) (2CP)",2];
blufor_RQST_UNIT_02_X =				["I_Soldier_GL_F","Grenadier (AAF) (3CP)",3];
blufor_RQST_UNIT_03_X =				["I_Soldier_AR_F","Automatic Rifleman (AAF) (3CP)",3];
blufor_RQST_UNIT_04_X =				["I_C_Soldier_Para_4_F","Heavy Gunner (AAF) (4CP)",4];
blufor_RQST_UNIT_05_X =				["I_medic_F","Medic (AAF) (4CP)",4];
blufor_RQST_UNIT_06_X =				["I_Soldier_LAT_F","AT Rifleman (AAF) (3CP)",3];
blufor_RQST_UNIT_07_X =				["I_Soldier_AT_F","AT Specialist (AAF) (4CP)",4];
blufor_RQST_UNIT_08_X =				["I_Soldier_AAA_F","AA Specialist (AAF) (4CP)",4];
blufor_RQST_UNIT_09_X =				["I_engineer_F","Engineer (AAF) (4CP)",4];
blufor_RQST_UNIT_10_X =				["I_soldier_M_F","Marksman (AAF) (3CP)",3];
blufor_RQST_UNIT_11_X =				["I_Sniper_F","Sniper (AAF) (4CP)",4];
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
blufor_RQST_VEHICLE_04_X =			["I_MRAP_03_F","Strider Unarmed (5CP)",5];
blufor_RQST_VEHICLE_05_X =			["I_MRAP_03_hmg_F","Strider HMG (18CP)",18];
blufor_RQST_VEHICLE_06_X =			["I_MRAP_03_gmg_F","Hunter GMG (25CP)",25];
blufor_RQST_VEHICLE_07_X =			["I_C_Offroad_02_unarmed_F","4WD Jeep Unarmed (5CP)",5];
blufor_RQST_VEHICLE_08_X =			["I_G_Offroad_01_armed_F","Offroad HMG (15CP)",15];
blufor_RQST_VEHICLE_09_X =			["I_G_Offroad_01_AT_F","Offroad AT (20CP)",20];
blufor_RQST_VEHICLE_10_X =			["I_Truck_02_transport_F","Zamak Transport Uncovered (8CP)",8];
blufor_RQST_VEHICLE_11_X =			["I_Truck_02_covered_F","Zamak Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_12_X =			["I_Truck_02_box_F","Zamak Repair (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["I_Truck_02_ammo_F","Zamak Ammo (50CP)",50];
blufor_RQST_VEHICLE_14_X =			["I_Truck_02_fuel_F","Zamak Fuel (50CP)",50];
blufor_RQST_VEHICLE_15_X =			["B_APC_Wheeled_01_cannon_F","AMV-7 Marshall (35CP)",35];
blufor_RQST_VEHICLE_16_X =			["I_APC_Wheeled_03_cannon_F","AFV-4 Gorgon (35CP)",35];
blufor_RQST_VEHICLE_17_X =			["B_AFV_Wheeled_01_cannon_F","Rhino MGS (35CP)",35];
blufor_RQST_VEHICLE_18_X =			["B_APC_Tracked_01_CRV_F","CRV-6e Bobcat (28CP)",28];
blufor_RQST_VEHICLE_19_X =			["I_APC_tracked_03_cannon_F","FV-720 Mora (30CP)",30];
blufor_RQST_VEHICLE_20_X =			["I_LT_01_cannon_F","AWC-304 Nyx (30CP)",30];
blufor_RQST_VEHICLE_21_X =			["I_LT_01_AA_F","AWC-304 Nyx AA (35CP)",35];
blufor_RQST_VEHICLE_22_X =			["B_MBT_01_cannon_F","M2A1 Slammer (40CP)",40];
blufor_RQST_VEHICLE_23_X =			["B_MBT_01_TUSK_F","M2A4 Slammer UP (40CP)",40];
blufor_RQST_VEHICLE_24_X =			["I_MBT_03_cannon_F","MBT-52 Kuma (50CP)",50];
blufor_RQST_VEHICLE_25_X =			["B_MBT_01_arty_F","M4 Scorcher Artillery (75CP)",75];
blufor_RQST_VEHICLE_26_X =			["I_Truck_02_MRL_F","Zamak MRL (75CP)",75];
blufor_RQST_VEHICLE_27_X =			["B_Heli_Light_01_dynamicLoadout_F","AH-9 Pawnee (25CP)",25];
blufor_RQST_VEHICLE_28_X =			["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15];
blufor_RQST_VEHICLE_29_X =			["I_Heli_light_03_dynamicLoadout_F","MY-55 Hellcat Armed (45CP)",45];
blufor_RQST_VEHICLE_30_X =			["B_T_VTOL_01_armed_F","V-44 X Armed (40CP",40];
blufor_RQST_VEHICLE_31_X =			["B_Heli_Transport_01_F","UH-80 Ghosthawk (22CP)",22];
blufor_RQST_VEHICLE_32_X =			["I_Heli_Transport_02_F","CH-49 Mowawk (26CP)",26];
blufor_RQST_VEHICLE_33_X =			["B_Heli_Transport_03_F","CH-67 Huron Armed (26CP)",26];
blufor_RQST_VEHICLE_34_X =			["I_Plane_Fighter_03_dynamicLoadout_F","A-143 Buzzard CAS (45CP)",45];
blufor_RQST_VEHICLE_35_X =			["I_Plane_Fighter_04_F","A-149 Gryphon (50CP)",50];
blufor_RQST_VEHICLE_36_X =			["B_Plane_Fighter_01_Stealth_F","FA-181 Black Wasp II Stealth (60CP)",60];
blufor_RQST_VEHICLE_37_X =			["I_UAV_01_F","UAV Darter (5CP)",5];
blufor_RQST_VEHICLE_38_X =			["I_UAV_02_dynamicLoadout_F","UAV K-40 Ababil (15CP)",15];
blufor_RQST_VEHICLE_39_X =			["I_UGV_01_F","UGV Stomper Recon (10CP)",10];
blufor_RQST_VEHICLE_40_X =			["I_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20];
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


