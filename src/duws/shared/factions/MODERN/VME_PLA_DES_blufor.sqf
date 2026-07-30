
///////////////
///////////////   "PLA", "VME PLA Chinese Army + SpecOps (Desert)", "VME_PLA_DES"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"PLA_Soldier_HM_F";					//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"PLA_Soldier_AT89B_HM_F";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"PLA_Soldier_HM_GL_F";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"PLA_Soldier_TL_HM_F";				//init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"PLA_Soldier_TL_HM_F";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"PLA_Soldier_HMG_HM_F";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"PLA_Soldier_mk_HM_F";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"PLA_Soldier_OF_HM_F";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"PLAAF_pilot_heli";					//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"PLAN_Soldier_CREW";				//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"VME_PLA_Mi17_DES";					//supports\taxi\fnc_helotaxi, random patrol  
blufor_HELI_TRANS_UNARM_X =		"VME_PLA_z9_CAS";   				//random patrol
blufor_HELI_ATTACK_X =			"VME_WZ10_DES";						//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"VME_PLA_jh7";						//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"VME_PLA_EQ2050_MG";				//random patrol
blufor_APC_PATROL1_X =			"VME_PLA_ZBL09";					//random patrol
blufor_APC_PATROL2_X =			"VME_PLA_ZBD08";					//random patrol
blufor_TANK_PATROL1_X =			"VME_PLA_ZTZ99";					//random patrol


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

blufor_SPECOPS_X =				"PLA_spec_DES_base";					//operator
blufor_SPECOPS_GL_X =			"PLA_spec_DES_GL";						//operator
blufor_SPECOPS_LAT_X =			"PLA_Soldier_AT89B_HM_F";				//operator
blufor_SPECOPS_HAT_X =			"PLA_Soldier_AT_HM_F";					//operator
blufor_SPECOPS_AA_X =			"PLA_Soldier_AA_HM_F";					//operator
blufor_SPECOPS_MG_X =			"PLA_Soldier_HMG_HM_F";					//operator
blufor_SPECOPS_MEDIC_X =		"PLA_spec_DES_MEDIC";					//operator
blufor_SPECOPS_MARK_X =			"PLA_Soldier_LR_HM_F";					//operator
blufor_SPECOPS_SNIPER_X =		"PLA_spec_DES_SNIPER";					//operator
blufor_SPECOPS_EXP_X =			"PLA_Soldier_special_4";				//operator
blufor_SPECOPS_ENG_X = 			"PLA_spec_DES_ENG";						//operator





/////////////////////////////////////////////////////////////////
// REQUEST Units/Vehicles
//
// Ordered lists, no padding and no fixed length: the menus offer every entry in the order
// written here, so position in the list is the display order. A faction may list as many
// or as few as it has.
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


blufor_RQST_UNITS = [
	["PLA_Soldier_HM_F","Rifleman (Desert) (2CP)",2],
	["PLA_Soldier_HM_GL_F","Grenadier (Desert) (3CP)",3],
	["PLA_Soldier_MG_HM_F","Automatic Rifleman (Desert) (3CP)",3],
	["PLA_Soldier_HMG_HM_F","Heavy Gunner (Desert) (4CP)",4],
	["PLA_Soldier_medic_HM_F","Medic (Desert) (4CP)",4],
	["PLA_Soldier_AT89B_HM_F","AT Specialist (Desert) (4CP)",4],
	["PLA_Soldier_AA_HM_F","AA Specialist (Desert) (4CP)",4],
	["PLA_Soldier_Engineer_HM_F","Engineer (Desert) (4CP)",4],
	["PLA_Soldier_mk_HM_F","Marksman (Desert) (3CP)",3],
	["PLA_spec_DES_SNIPER","Sniper (Desert) (4CP)",4]
];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////

blufor_RQST_VEHICLES = [
	["B_Quadbike_01_F","ATV (1CP)",1],
	["C_Offroad_01_F","SF Offroader (2CP)",2],
	["I_G_Van_01_transport_F","Transport Truck (6CP)",6],
	["B_MRAP_01_F","Hunter Unarmed (5CP)",5],
	["VME_PLA_BJ2022patrol","BJ 2022 HMG (15CP)",15],
	["VME_PLA_EQ2050","EQ 2050 Unarmed (8CP)",8],
	["VME_PLA_EQ2050_MG","EQ 2050 HMG (18CP)",18],
	["VME_PLA_EQ2050_GL","EQ 2050 GMG (20CP)",20],
	["VME_PLA_EQ2050_AT","EQ 2050 ATGM (20CP)",20],
	["C_Truck_02_transport_F","Zamak Transport Uncovered (8CP)",8],
	["VME_PLA_SX2190_DES","SX 2190 Transport Covered (8CP)",8],
	["VME_PLA_SX2190Repair_DES","SX 2190 Repair Truck(50CP)",50],
	["VME_PLA_SX2190Reammo_DES","SX 2190 Ammo Truck (50CP)",50],
	["VME_PLA_SX2190Refuel_DES","SX 2190 Fuel Truck (50CP)",50],
	["VME_PLA_ZBD03","APC ZBD-03 (25CP)",25],
	["VME_PLA_ZBD04","APC ZBD-04 (30CP)",30],
	["VME_PLA_ZBL09","APC ZBL-08 (35CP)",35],
	["O_APC_Wheeled_02_rcws_v2_F","MSE-3 Marid (25CP)",25],
	["B_APC_Tracked_01_CRV_F","CRV-6e Bobcat (28CP)",28],
	["VME_PLA_PGZ07","PGZ-07 AA (35CP)",35],
	["VME_PLA_AFT10","AFT-10 AT (35CP)",35],
	["VME_PLA_ZTZ96A","ZTZ-96 MBT (40CP)",40],
	["VME_PLA_ZTZ99","ZTZ-99 MBT (50CP)",50],
	["VME_PLA_PLZ05","PLZ-05 Artillery (75CP)",75],
	["VME_PLA_HQ64_DES","HQ 64 ADS (75CP)",75],
	["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15],
	["VME_PLA_z9_base","Z9-A Heli (20CP)",20],
	["VME_PLA_z9_CAS","Z9-A CAS Heli (25CP)",25],
	["VME_PLA_Mi17_DES","Mi-17 Trans (25CP)",25],
	["VME_PLA_Mi171_DES","Mi-171 Gunship (30CP)",30],
	["VME_WZ10_DES","WZ-10 Attack Heli (45CP)",45],
	["O_T_VTOL_02_infantry_dynamicLoadout_F","Y-32 Zian VTOL (45CP",45],
	["VME_PLA_jh7","JH-7 Jet (45CP)",45],
	["VME_PLA_J20","J-20 Jet (50CP)",50],
	["PLA_UAV_01","AR-2 Darter (5CP)",5],
	["vme_CH4B","Wing Loong II UAV (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20]
];


