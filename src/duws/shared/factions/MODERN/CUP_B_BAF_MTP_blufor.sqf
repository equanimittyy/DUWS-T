
///////////////
///////////////   "CUP_B_BAF", "CUP British AF (MTP)", "CUP_B_BAF_MTP"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"CUP_B_BAF_Soldier_Rifleman_MTP";		//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"CUP_B_BAF_Soldier_RiflemanLAT_MTP";	//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"CUP_B_BAF_Soldier_Grenadier_MTP";		//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"CUP_B_BAF_Soldier_TeamLeader_MTP";		//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"CUP_B_BAF_Soldier_SquadLeader_MTP";	//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"CUP_B_BAF_Soldier_AutoRifleman_MTP";	//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"CUP_B_BAF_Soldier_Marksman_MTP";		//init_hq\fnc_HQguards
blufor_OFFICER_X =				"CUP_B_BAF_Soldier_Officer_MTP";		//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CUP_B_BAF_Soldier_Pilot_MTP";			//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";			//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";						//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CUP_B_Merlin_HC3A_Armed_GB";		//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"CUP_B_MH47E_GB";   				//random patrol
blufor_HELI_ATTACK_X =			"CUP_B_AH1_DL_BAF";					//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"CUP_B_A10_DYN_USA";				//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"CUP_B_Jackal2_L2A1_GB_W";			//random patrol
blufor_APC_PATROL1_X =			"CUP_B_FV432_Bulldog_GB_W";			//random patrol
blufor_APC_PATROL2_X =			"CUP_B_FV510_GB_W";					//random patrol
blufor_TANK_PATROL1_X =			"CUP_B_Challenger2_2CW_BAF";		//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"CUP_B_CUP_Stinger_AA_pod_US";
blufor_TURRET_AT =				"CUP_B_TOW_TriPod_US";
blufor_TURRET_HMG =				"B_G_HMG_02_high_F";
blufor_TURRET_GMG =				"B_G_HMG_02_high_F";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"CUP_B_BAF_Soldier_Rifleman_MTP";		//operator
blufor_SPECOPS_GL_X =			"CUP_B_BAF_Soldier_Grenadier_MTP";		//operator
blufor_SPECOPS_LAT_X =			"CUP_B_BAF_Soldier_RiflemanAT_MTP";		//operator
blufor_SPECOPS_HAT_X =			"CUP_B_BAF_Soldier_AT_MTP";				//operator
blufor_SPECOPS_AA_X =			"CUP_B_BAF_Soldier_AA_MTP";				//operator
blufor_SPECOPS_MG_X =			"CUP_B_BAF_Soldier_HeavyGunner_MTP";	//operator
blufor_SPECOPS_MEDIC_X =		"CUP_B_BAF_Soldier_Medic_MTP";			//operator
blufor_SPECOPS_MARK_X =			"CUP_B_BAF_Soldier_Marksman_MTP";		//operator
blufor_SPECOPS_SNIPER_X =		"CUP_B_BAF_Sniper_MTP";					//operator
blufor_SPECOPS_EXP_X =			"CUP_B_BAF_Soldier_Explosive_MTP";		//operator
blufor_SPECOPS_ENG_X = 			"CUP_B_BAF_Soldier_Engineer_MTP";		//operator





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
	["CUP_B_BAF_Soldier_Rifleman_MTP","Rifleman (MTP) (2CP)",2],
	["CUP_B_BAF_Soldier_Grenadier_MTP","Grenadier (MTP) (3CP)",3],
	["CUP_B_BAF_Soldier_AutoRifleman_MTP","Automatic Rifleman (MTP) (3CP)",3],
	["CUP_B_BAF_Soldier_HeavyGunner_MTP","Heavy Gunner (MTP) (4CP)",4],
	["CUP_B_BAF_Soldier_Medic_MTP","Medic (MTP) (4CP)",4],
	["CUP_B_BAF_Soldier_RiflemanLAT_MTP","AT Rifleman (MTP) (3CP)",3],
	["CUP_B_BAF_Soldier_AT_MTP","AT Specialist (MTP) (4CP)",4],
	["CUP_B_BAF_Soldier_AA_MTP","AA Specialist (MTP) (4CP)",4],
	["CUP_B_BAF_Soldier_Engineer_MTP","Engineer (MTP) (4CP)",4],
	["CUP_B_BAF_Soldier_Repair_MTP","Repair Specialist (MTP) (4CP)",4],
	["CUP_B_BAF_Soldier_Explosive_MTP","Explosive Specialist (MTP) (4CP)",4],
	["CUP_B_BAF_Spotter_MTP","Spotter (MTP) (3CP)",3],
	["CUP_B_BAF_Soldier_Marksman_MTP","Marksman (MTP) (3CP)",3],
	["CUP_B_BAF_Sniper_MTP","Sniper (MTP) (4CP)",4]
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
	["CUP_B_Ridgback_LMG_GB_W","Ridgeback HMG (18CP)",18],
	["CUP_B_Ridgback_GMG_GB_W","Ridgeback GMG (25CP)",25],
	["CUP_B_LR_Transport_GB_W","Land Rover Unarmed (5CP)",5],
	["CUP_B_LR_Special_M2_GB_W","Land Rover HMG (15CP)",15],
	["CUP_B_LR_Special_GMG_GB_W","Land Rover GMG (20CP)",20],
	["B_Truck_01_transport_F","HEMTT Transport Uncovered (8CP)",8],
	["CUP_B_MTVR_BAF_WOOD","MTVR Transport Covered (8CP)",8],
	["CUP_B_MTVR_Repair_BAF_WOOD","MTVR Repair (50CP)",50],
	["CUP_B_MTVR_Ammo_BAF_WOOD","MTVR Ammo (50CP)",50],
	["CUP_B_MTVR_Refuel_BAF_WOOD","MTVR Fuel (50CP)",50],
	["CUP_B_Mastiff_GMG_GB_W","Mastiff GMG (35CP)",35],
	["CUP_B_FV432_GB_GPMG","FV-432 GPMG (35CP)",35],
	["CUP_B_FV432_Bulldog_GB_W_RWS","FV-432 Bulldog L111 (35CP)",35],
	["CUP_B_FV432_Bulldog_GB_W","FV-432 Bulldog L7A2 (35CP)",35],
	["B_APC_Tracked_01_CRV_F","CRV-6e Bobcat (28CP)",28],
	["CUP_B_FV510_GB_W","FV-510 Warrior (30CP)",30],
	["CUP_B_MCV80_GB_W","MCV-80 Warrior (30CP)",30],
	["B_MBT_01_cannon_F","M2A1 Slammer (40CP)",40],
	["CUP_B_M1A2_TUSK_MG_US_Army","M1A2 TUSK (45CP)",45],
	["CUP_B_Challenger2_2CW_BAF","Challenger 2 (50CP)",50],
	["CUP_B_M270_DPICM_BAF_WOOD","M270 MLRS DPICM Arty (75CP)",75],
	["CUP_B_M270_HE_BAF_WOOD","M270 MLRS HE (75CP)",75],
	["B_Heli_Light_01_dynamicLoadout_F","AH-9 Pawnee (25CP)",25],
	["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15],
	["CUP_B_AH1_DL_BAF","AH-1 Attack Heli (45CP)",45],
	["B_T_VTOL_01_armed_F","V-44 X Armed (40CP)",40],
	["CUP_B_Merlin_HC3A_GB","Merlin HC3A Trans Heli (22CP)",22],
	["CUP_B_Merlin_HC3A_Armed_GB","Merlin HC3A Armed (26CP)",26],
	["CUP_B_MH47E_GB","MH-47  (26CP)",26],
	["CUP_B_A10_DYN_USA","A-10 Warthog CAS (45CP)",45],
	["CUP_B_GR9_DYN_GB","Harrier GR-9 (50CP)",50],
	["CUP_B_F35B_BAF","F-35B Stealth (60CP)",60],
	["B_UAV_01_F","UAV Darter(5CP)",5],
	["B_UAV_02_dynamicLoadout_F","UAV MQ-4A Greyhawk (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20],
	["B_T_UAV_03_dynamicLoadout_F","MQ-12 UAV (20CP)",20]
];


