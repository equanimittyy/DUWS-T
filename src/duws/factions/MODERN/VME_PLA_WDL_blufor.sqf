
///////////////
///////////////   "PLA", "VME PLA Chinese Army + SpecOps (Wood)", "VME_PLA_WDL"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"PLA_Soldier_F";				//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"PLA_Soldier_AT89B_F";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"PLA_Soldier_GL_F";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"PLA_Soldier_TL_F";				//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"PLA_Soldier_SL_F";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"PLA_Soldier_HMG_F";			//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"PLA_Soldier_mk_F";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"PLA_Soldier_OF_F";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"PLAAF_pilot_heli";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"PLAN_Soldier_CREW";				//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"VME_PLA_Mi17";					//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"VME_PLA_z9_CAS";   			//random patrol
blufor_HELI_ATTACK_X =			"VME_WZ10";						//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"VME_PLA_jh7";					//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"VME_PLA_EQ2050_MG";			//random patrol
blufor_APC_PATROL1_X =			"VME_PLA_ZBL09";				//random patrol
blufor_APC_PATROL2_X =			"VME_PLA_ZBD08";				//random patrol
blufor_TANK_PATROL1_X =			"VME_PLA_ZTZ99";				//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"B_static_AA_F";
blufor_TURRET_AT =				"VME_PLA_HJ8";
blufor_TURRET_HMG =				"VME_PLA_QJZ89A";
blufor_TURRET_GMG =				"VME_PLA_QJZ89A";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"PLA_spec_base";					//operator
blufor_SPECOPS_GL_X =			"PLA_spec_GL";						//operator
blufor_SPECOPS_LAT_X =			"PLA_Soldier_AT89B_F";				//operator
blufor_SPECOPS_HAT_X =			"PLA_Soldier_AT_F";					//operator
blufor_SPECOPS_AA_X =			"PLA_Soldier_AA_F";					//operator
blufor_SPECOPS_MG_X =			"PLA_Soldier_HMG_F";				//operator
blufor_SPECOPS_MEDIC_X =		"PLA_spec_MEDIC";					//operator
blufor_SPECOPS_MARK_X =			"PLA_Soldier_LR_F";					//operator
blufor_SPECOPS_SNIPER_X =		"PLA_spec_SNIPER";					//operator
blufor_SPECOPS_EXP_X =			"PLA_Soldier_special_4";			//operator
blufor_SPECOPS_ENG_X = 			"PLA_spec_ENG";						//operator





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


blufor_RQST_UNIT_01_X = 			["PLA_Soldier_F","Rifleman (Wood) (2CP)",2];
blufor_RQST_UNIT_02_X =				["PLA_Soldier_GL_F","Grenadier (Wood) (3CP)",3];
blufor_RQST_UNIT_03_X =				["PLA_Soldier_MG_F","Automatic Rifleman (Wood) (3CP)",3];
blufor_RQST_UNIT_04_X =				["PLA_Soldier_HMG_F","Heavy Gunner (Wood) (4CP)",4];
blufor_RQST_UNIT_05_X =				["PLA_Soldier_medic_F","Medic (Wood) (4CP)",4];
blufor_RQST_UNIT_06_X =				["PLA_Soldier_AT89B_F","AT Specialist (Wood) (4CP)",4];
blufor_RQST_UNIT_07_X =				["PLA_Soldier_AA_F","AA Specialist (Wood) (4CP)",4];
blufor_RQST_UNIT_08_X =				["PLA_Soldier_Engineer_F","Engineer (Wood) (4CP)",4];
blufor_RQST_UNIT_09_X =				["PLA_Soldier_mk_F","Marksman (Wood) (3CP)",3];
blufor_RQST_UNIT_10_X =				["PLA_spec_SNIPER","Sniper (Wood) (4CP)",4];
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
blufor_RQST_VEHICLE_05_X =			["VME_PLA_BJ2022patrol","BJ 2022 HMG (15CP)",15];
blufor_RQST_VEHICLE_06_X =			["VME_PLA_EQ2050","EQ 2050 Unarmed (8CP)",8];
blufor_RQST_VEHICLE_07_X =			["VME_PLA_EQ2050_MG","EQ 2050 HMG (18CP)",18];
blufor_RQST_VEHICLE_08_X =			["VME_PLA_EQ2050_GL","EQ 2050 GMG (20CP)",20];
blufor_RQST_VEHICLE_09_X =			["VME_PLA_EQ2050_AT","EQ 2050 ATGM (20CP)",20];
blufor_RQST_VEHICLE_10_X =			["C_Truck_02_transport_F","Zamak Transport Uncovered (8CP)",8];
blufor_RQST_VEHICLE_11_X =			["VME_PLA_SX2190","SX 2190 Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_12_X =			["VME_PLA_SX2190Repair","SX 2190 Repair Truck(50CP)",50];
blufor_RQST_VEHICLE_13_X =			["VME_PLA_SX2190Reammo","SX 2190 Ammo Truck (50CP)",50];
blufor_RQST_VEHICLE_14_X =			["VME_PLA_SX2190Refuel","SX 2190 Fuel Truck (50CP)",50];
blufor_RQST_VEHICLE_15_X =			["VME_PLA_ZBD03","APC ZBD-03 (25CP)",25];
blufor_RQST_VEHICLE_16_X =			["VME_PLA_ZBD04","APC ZBD-04 (30CP)",30];
blufor_RQST_VEHICLE_17_X =			["VME_PLA_ZBL09","APC ZBL-08 (35CP)",35];
blufor_RQST_VEHICLE_18_X =			["O_T_APC_Wheeled_02_rcws_v2_ghex_F","MSE-3 Marid (25CP)",25];
blufor_RQST_VEHICLE_19_X =			["B_APC_Tracked_01_CRV_F","CRV-6e Bobcat (28CP)",28];
blufor_RQST_VEHICLE_20_X =			["VME_PLA_PGZ07","PGZ-07 AA (35CP)",35];
blufor_RQST_VEHICLE_21_X =			["VME_PLA_AFT10","AFT-10 AT (35CP)",35];
blufor_RQST_VEHICLE_22_X =			["VME_PLA_ZTZ96A","ZTZ-96 MBT (40CP)",40];
blufor_RQST_VEHICLE_23_X =			["VME_PLA_ZTZ99","ZTZ-99 MBT (50CP)",50];
blufor_RQST_VEHICLE_24_X =			["VME_PLA_PLZ05","PLZ-05 Artillery (75CP)",75];
blufor_RQST_VEHICLE_25_X =			["VME_PLA_HQ64","HQ 64 ADS (75CP)",75];
blufor_RQST_VEHICLE_26_X =			["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15];
blufor_RQST_VEHICLE_27_X =			["VME_PLA_z9_base","Z9-A Heli (20CP)",20];
blufor_RQST_VEHICLE_28_X =			["VME_PLA_z9_CAS","Z9-A CAS Heli (25CP)",25];
blufor_RQST_VEHICLE_29_X =			["VME_PLA_Mi17","Mi-17 Trans (25CP)",25];
blufor_RQST_VEHICLE_30_X =			["VME_PLA_Mi171","Mi-171 Gunship (30CP)",30];
blufor_RQST_VEHICLE_31_X =			["VME_WZ10","WZ-10 Attack Heli (45CP)",45];
blufor_RQST_VEHICLE_32_X =			["O_T_VTOL_02_infantry_dynamicLoadout_F","Y-32 Zian VTOL (45CP",45];
blufor_RQST_VEHICLE_33_X =			["VME_PLA_jh7","JH-7 Jet (45CP)",45];
blufor_RQST_VEHICLE_34_X =			["VME_PLA_J20","J-20 Jet (50CP)",50];
blufor_RQST_VEHICLE_35_X =			["PLA_UAV_01","AR-2 Darter (5CP)",5];
blufor_RQST_VEHICLE_36_X =			["vme_CH4B","Wing Loong II UAV (15CP)",15];
blufor_RQST_VEHICLE_37_X =			["B_UGV_01_F","UGV Stomper Recon (10CP)",10];
blufor_RQST_VEHICLE_38_X =			["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20];
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


