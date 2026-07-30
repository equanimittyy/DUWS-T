
///////////////
///////////////   "CUP_B_BAF", "CUP British AF (DDPM)", "CUP_B_BAF_DDPM"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"CUP_B_BAF_Soldier_Rifleman_DDPM";		//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"CUP_B_BAF_Soldier_RiflemanLAT_DDPM";	//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"CUP_B_BAF_Soldier_Grenadier_DDPM";		//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"CUP_B_BAF_Soldier_TeamLeader_DDPM";	//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"CUP_B_BAF_Soldier_SquadLeader_DDPM";	//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"CUP_B_BAF_Soldier_AutoRifleman_DDPM";	//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"CUP_B_BAF_Soldier_Marksman_DDPM";		//init_hq\fnc_HQguards
blufor_OFFICER_X =				"CUP_B_BAF_Soldier_Officer_DDPM";		//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CUP_B_BAF_Soldier_Pilot_DDPM";			//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";			//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";						//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CUP_B_Merlin_HC3A_Armed_GB";	//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"CUP_B_MH47E_GB";   			//random patrol
blufor_HELI_ATTACK_X =			"CUP_B_AH1_DL_BAF";				//dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"CUP_B_A10_DYN_USA";			//dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"CUP_B_Jackal2_L2A1_GB_D";		//random patrol
blufor_APC_PATROL1_X =			"CUP_B_FV432_Bulldog_GB_D";		//random patrol
blufor_APC_PATROL2_X =			"CUP_B_FV510_GB_D";				//random patrol
blufor_TANK_PATROL1_X =			"CUP_B_Challenger2_2CD_BAF";	//random patrol


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

blufor_SPECOPS_X =				"CUP_B_BAF_Soldier_Rifleman_DDPM";		//operator
blufor_SPECOPS_GL_X =			"CUP_B_BAF_Soldier_Grenadier_DDPM";		//operator
blufor_SPECOPS_LAT_X =			"CUP_B_BAF_Soldier_RiflemanAT_DDPM";	//operator
blufor_SPECOPS_HAT_X =			"CUP_B_BAF_Soldier_AT_DDPM";			//operator
blufor_SPECOPS_AA_X =			"CUP_B_BAF_Soldier_AA_DDPM";			//operator
blufor_SPECOPS_MG_X =			"CUP_B_BAF_Soldier_HeavyGunner_DDPM";	//operator
blufor_SPECOPS_MEDIC_X =		"CUP_B_BAF_Soldier_Medic_DDPM";			//operator
blufor_SPECOPS_MARK_X =			"CUP_B_BAF_Soldier_Marksman_DDPM";		//operator
blufor_SPECOPS_SNIPER_X =		"CUP_B_BAF_Sniper_DDPM";				//operator
blufor_SPECOPS_EXP_X =			"CUP_B_BAF_Soldier_Explosive_DDPM";		//operator
blufor_SPECOPS_ENG_X = 			"CUP_B_BAF_Soldier_Engineer_DDPM";		//operator





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
	["CUP_B_BAF_Soldier_Rifleman_DDPM","Rifleman (DDPM) (2CP)",2],
	["CUP_B_BAF_Soldier_Grenadier_DDPM","Grenadier (DDPM) (3CP)",3],
	["CUP_B_BAF_Soldier_AutoRifleman_DDPM","Automatic Rifleman (DDPM) (3CP)",3],
	["CUP_B_BAF_Soldier_HeavyGunner_DDPM","Heavy Gunner (MTP) (DDPM)",4],
	["CUP_B_BAF_Soldier_Medic_DDPM","Medic (DDPM) (4CP)",4],
	["CUP_B_BAF_Soldier_RiflemanLAT_DDPM","AT Rifleman (DDPM) (3CP)",3],
	["CUP_B_BAF_Soldier_AT_DDPM","AT Specialist (DDPM) (4CP)",4],
	["CUP_B_BAF_Soldier_AA_DDPM","AA Specialist (DDPM) (4CP)",4],
	["CUP_B_BAF_Soldier_Engineer_DDPM","Engineer (DDPM) (4CP)",4],
	["CUP_B_BAF_Soldier_Repair_DDPM","Repair Specialist (DDPM) (4CP)",4],
	["CUP_B_BAF_Soldier_Explosive_DDPM","Explosive Specialist (DDPM) (4CP)",4],
	["CUP_B_BAF_Spotter_DDPM","Spotter (DDPM) (3CP)",3],
	["CUP_B_BAF_Soldier_Marksman_DDPM","Marksman (DDPM) (3CP)",3],
	["CUP_B_BAF_Sniper_DDPM","Sniper (DDPM) (4CP)",4]
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
	["CUP_B_Ridgback_LMG_GB_D","Ridgeback HMG (18CP)",18],
	["CUP_B_Ridgback_GMG_GB_D","Ridgeback GMG (25CP)",25],
	["CUP_B_LR_Transport_GB_D","Land Rover Unarmed (5CP)",5],
	["CUP_B_LR_Special_M2_GB_D","Land Rover HMG (15CP)",15],
	["CUP_B_LR_Special_GMG_GB_D","Land Rover GMG (20CP)",20],
	["B_Truck_01_transport_F","HEMTT Transport Uncovered (8CP)",8],
	["CUP_B_MTVR_BAF_DES","MTVR Transport Covered (8CP)",8],
	["CUP_B_MTVR_Repair_BAF_DES","MTVR Repair (50CP)",50],
	["CUP_B_MTVR_Ammo_BAF_DES","MTVR Ammo (50CP)",50],
	["CUP_B_MTVR_Refuel_BAF_DES","MTVR Fuel (50CP)",50],
	["CUP_B_Mastiff_GMG_GB_D","Mastiff GMG (35CP)",35],
	["CUP_B_FV432_GB_GPMG","FV-432 GPMG (Wood) (35CP)",35],
	["CUP_B_FV432_Bulldog_GB_D_RWS","FV-432 Bulldog L111 (35CP)",35],
	["CUP_B_FV432_Bulldog_GB_D","FV-432 Bulldog L7A2 (35CP)",35],
	["B_APC_Tracked_01_CRV_F","CRV-6e Bobcat (28CP)",28],
	["CUP_B_FV510_GB_D","FV-510 Warrior (30CP)",30],
	["CUP_B_MCV80_GB_D","MCV-80 Warrior (30CP)",30],
	["B_MBT_01_cannon_F","M2A1 Slammer (40CP)",40],
	["CUP_B_M1A2_TUSK_MG_DES_US_Army","M1A2 TUSK (45CP)",40],
	["CUP_B_Challenger2_2CD_BAF","Challenger 2 (50CP)",50],
	["CUP_B_M270_DPICM_BAF_DES","M270 MLRS DPICM Arty (75CP)",75],
	["CUP_B_M270_HE_BAF_DES","M270 MLRS HE (75CP)",75],
	["B_Heli_Light_01_dynamicLoadout_F","AH-9 Pawnee (25CP)",25],
	["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15],
	["CUP_B_AH1_DL_BAF","AH-1 Attack Heli (45CP)",45],
	["B_T_VTOL_01_armed_F","V-44 X Armed (40CP",40],
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


