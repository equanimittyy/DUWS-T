
///////////////   "BLU_F_T", "NATO  (Pacific)", "BLU_F_PACIFIC"


blufor_SOLDIER_X =				"B_T_Soldier_F";				//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"B_T_Soldier_LAT_F";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"B_T_Soldier_GL_F";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"B_T_Soldier_TL_F";				//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"B_T_Soldier_SL_F";				//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"B_T_Soldier_AR_F";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"B_T_soldier_M_F";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"B_T_OFFICER_F";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"B_T_Helipilot_F";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";	//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";				//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"B_Heli_Transport_01_F";			//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"B_Heli_Transport_03_unarmed_F";   	//random patrol
blufor_ATTACK_HELI_X =			"B_Heli_Attack_01_F";				//dialog\fnc_request_hcATTchop
blufor_MISC_AIR_X =				"B_Plane_CAS_01_F";					//dialog\fnc_request_hcCAS
blufor_ARMED_CAR1_X =			"B_T_MRAP_01_hmg_F";				//random patrol
blufor_APC1_X =					"B_T_APC_Wheeled_01_cannon_F";		//random patrol
blufor_APC2_X =					"B_T_APC_Tracked_01_AA_F";			//random patrol
blufor_MBT_TANK1_X =			"B_T_MBT_01_TUSK_F";				//random patrol



blufor_TURRET_AA = 				"B_static_AA_F";
blufor_TURRET_AT =				"B_static_AT_F";
blufor_TURRET_HMG =				"B_G_HMG_02_high_F";
blufor_TURRET_GMG =				"B_GMG_01_high_F";



blufor_SPECOPS_X =				"B_T_Recon_F";					//operator
blufor_SPECOPS_GL_X =			"B_T_Recon_JTAC_F";				//operator
blufor_SPECOPS_LAT_X =			"B_T_Recon_LAT_F";				//operator
blufor_SPECOPS_HAT_X =			"B_T_Soldier_AT_F";				//operator
blufor_SPECOPS_AA_X =			"B_T_Soldier_AA_F";				//operator
blufor_SPECOPS_MG_X =			"B_Patrol_Soldier_MG_F";		//operator
blufor_SPECOPS_MEDIC_X =		"B_T_Recon_Medic_F";			//operator
blufor_SPECOPS_MARK_X =			"B_T_Recon_M_F";				//operator
blufor_SPECOPS_SNIPER_X =		"B_T_Sniper_F";					//operator
blufor_SPECOPS_EXP_X =			"B_T_Recon_Exp_F";				//operator
blufor_SPECOPS_ENG_X = 			"B_T_Recon_Exp_F";				//operator





// REQUEST Units/Vehicles
// Ordered lists, no padding and no fixed length: the menus offer every entry in the order
// written here, so position in the list is the display order. A faction may list as many
// or as few as it has.

// REQUEST MENU defines labels/index for all request menu units/vehicles (not Operators)

// request_vehicle, request_vehicle_fob, request_unit, request_unit_fob 
// - these files contain the classnames referenced by the label/index


// dialog\fnc_request_unit
//   _index = lbCurSel 2100;
// dialog\fnc_request_unit_fob
//   _index = lbCurSel 2120;


blufor_RQST_UNITS = [
	["B_T_Soldier_F","Rifleman (2CP)",2],
	["B_T_Soldier_GL_F","Grenadier (3CP)",3],
	["B_T_Soldier_AR_F","Automatic Rifleman (3CP)",3],
	["B_HeavyGunner_F","Heavy Gunner (4CP)",4],
	["B_T_Medic_F","Medic (4CP)",4],
	["B_T_Soldier_LAT_F","AT Rifleman (3CP)",3],
	["B_T_Soldier_AT_F","AT Specialist (4CP)",4],
	["B_T_soldier_AA_F","AA Specialist (4CP)",4],
	["B_T_Engineer_F","Engineer (4CP)",4],
	["B_T_soldier_M_F","Marksman (3CP)",3],
	["B_T_sniper_F","Sniper (4CP)",4]
];


// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;

blufor_RQST_VEHICLES = [
	["B_Quadbike_01_F","ATV (1CP)",1],
	["C_Offroad_01_F","SF Offroader (2CP)",2],
	["I_G_Van_01_transport_F","Transport Truck (6CP)",6],
	["B_T_MRAP_01_F","Hunter Unarmed (5CP)",5],
	["B_T_MRAP_01_hmg_F","Hunter HMG (18CP)",18],
	["B_T_MRAP_01_gmg_F","Hunter GMG (25CP)",25],
	["B_T_LSV_01_unarmed_F","Prowler Unarmed (5CP)",5],
	["B_T_LSV_01_armed_F","Prowler HMG (15CP)",15],
	["B_T_LSV_01_AT_F","Prowler AT (20CP)",20],
	["B_T_Truck_01_transport_F","HEMTT Transport Uncovered (8CP)",8],
	["B_T_Truck_01_covered_F","HEMTT Transport Covered (8CP)",8],
	["B_T_Truck_01_Repair_F","HEMTT Repair (50CP)",50],
	["B_T_Truck_01_ammo_F","HEMTT Ammo (50CP)",50],
	["B_T_Truck_01_fuel_F","HEMTT Fuel (50CP)",50],
	["B_T_APC_Wheeled_01_cannon_F","AMV-7 Marshall (35CP)",35],
	["I_APC_Wheeled_03_cannon_F","AFV-4 Gorgon (35CP)",35],
	["B_T_APC_Tracked_01_CRV_F","CRV-6e Bobcat (28CP)",28],
	["B_T_APC_Tracked_01_rcws_F","IFV-6c Panther (25CP)",25],
	["B_APC_Tracked_01_AA_F","IFV-6c Cheetah (30CP)",30],
	["B_T_MBT_01_cannon_F","M2A1 Slammer (40CP)",40],
	["B_T_MBT_01_TUSK_F","M2A4 Slammer UP (40CP)",40],
	["I_MBT_03_cannon_F","MBT-52 Kuma (50CP)",50],
	["B_T_MBT_01_arty_F","M4 Scorcher Artillery (75CP)",75],
	["B_T_MBT_01_mlrs_F","M5 Sandstorm MLRS (75CP)",75],
	["B_Heli_Light_01_dynamicLoadout_F","AH-9 Pawnee (25CP)",25],
	["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15],
	["B_Heli_Attack_01_dynamicLoadout_F","AH-99 Blackfoot (45CP)",45],
	["B_T_VTOL_01_armed_F","V-44 X Armed (40CP",40],
	["B_Heli_Transport_01_F","UH-80 Ghosthawk (22CP)",22],
	["B_Heli_Transport_03_unarmed_F","CH-67 Huron Unarmed (26CP)",26],
	["B_Heli_Transport_03_F","CH-67 Huron Armed (26CP)",26],
	["B_Plane_CAS_01_dynamicLoadout_F","A-164 Wipeout CAS (45CP)",45],
	["B_Plane_Fighter_01_F","FA-181 Black Wasp II (50CP)",50],
	["B_Plane_Fighter_01_Stealth_F","FA-181 Black Wasp II Stealth (60CP)",60],
	["B_UAV_01_F","UAV Darter(5CP)",5],
	["B_UAV_02_dynamicLoadout_F","UAV MQ-4A Greyhawk (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20],
	["B_T_UAV_03_dynamicLoadout_F","MQ-12 UAV (20CP)",20]
];


