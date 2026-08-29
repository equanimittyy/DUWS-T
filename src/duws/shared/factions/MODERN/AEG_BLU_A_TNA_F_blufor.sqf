
///////////////   "BLU_A_tna_F", "Aegis British - 2035 (Pacific)", "AEG_BLU_A_TNA_F"


blufor_SOLDIER_X =				"B_A_Soldier_TNA_F";					//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"B_A_Soldier_LAT_tna_F";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"B_A_Soldier_GL_tna_F";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"B_A_Soldier_TL_tna_F";				//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"B_A_Soldier_SL_tna_F";				//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"B_A_Soldier_AR_tna_F";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"B_A_soldier_M_tna_F";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"B_A_OFFICER_tna_F";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"B_A_Helipilot_tna_F";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_A_Boat_Armed_01_hmg_F";			//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"B_A_Heli_Light_03_dynamicloadout_F";		//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"B_A_Heli_Light_03_unarmed_F";   			//random patrol
blufor_ATTACK_HELI_X =			"B_A_Heli_Attack_01_dynamicloadout_F";		//dialog\fnc_request_hcATTchop
blufor_MISC_AIR_X =				"B_Plane_CAS_01_F";							//dialog\fnc_request_hcCAS
blufor_ARMED_CAR1_X =			"B_A_LSV_01_armed_tna_F";					//random patrol
blufor_APC1_X =					"B_A_MRAP_03_HMG_tna_F";					//random patrol
blufor_APC2_X =					"B_A_APC_tracked_03_cannon_v2_tna_F";		//random patrol
blufor_MBT_TANK1_X =			"B_T_MBT_01_cannon_F";						//random patrol



blufor_TURRET_AA = 				"B_A_static_AA_tna_F";
blufor_TURRET_AT =				"B_A_static_AT_tna_F";
blufor_TURRET_HMG =				"B_A_HMG_02_high_tna_F";
blufor_TURRET_GMG =				"B_A_GMG_01_high_tna_F";



blufor_SPECOPS_X =				"B_A_recon_tna_F";					//operator
blufor_SPECOPS_GL_X =			"B_A_recon_JTAC_tna_F";				//operator
blufor_SPECOPS_LAT_X =			"B_A_recon_LAT_tna_F";				//operator
blufor_SPECOPS_HAT_X =			"B_A_Soldier_AT_tna_F";		//operator
blufor_SPECOPS_AA_X =			"B_A_soldier_AA_tna_F";				//operator
blufor_SPECOPS_MG_X =			"B_A_Recon_MG_tna_F";		//operator
blufor_SPECOPS_MEDIC_X =		"B_A_recon_medic_tna_F";				//operator
blufor_SPECOPS_MARK_X =			"B_A_recon_M_tna_F";					//operator
blufor_SPECOPS_SNIPER_X =		"B_A_Recon_Sharpshooter_tna_F";					//operator
blufor_SPECOPS_EXP_X =			"B_A_recon_exp_tna_F";				//operator
blufor_SPECOPS_ENG_X = 			"B_A_Engineer_tna_F";			//operator





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
	["B_A_Soldier_tna_F","Rifleman (2CP)",2],
	["B_A_Soldier_GL_tna_F","Grenadier (3CP)",3],
	["B_A_Soldier_AR_tna_F","Automatic Rifleman (3CP)",3],
	["B_A_HeavyGunner_tna_F","Heavy Gunner (4CP)",4],
	["B_A_Medic_tna_F","Medic (4CP)",4],
	["B_A_Soldier_LAT_tna_F","AT Rifleman (3CP)",3],
	["B_A_Soldier_AT_tna_F","AT Specialist (4CP)",4],
	["B_A_soldier_AA_tna_F","AA Specialist (4CP)",4],
	["B_A_Engineer_tna_F","Engineer (4CP)",4],
	["B_A_soldier_M_tna_F","Marksman (3CP)",3],
	["B_A_sniper_tna_F","Sniper (4CP)",4]
];


// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;

blufor_RQST_VEHICLES = [
	["B_Quadbike_01_F","ATV (1CP)",1],
	["C_Offroad_01_F","SF Offroader (2CP)",2],
	["B_A_APC_TRACKED_03_CANNON_v2_tna_F","Lancer APC (30CP)",30],
	["B_A_MRAP_03_tna_F","Strider Unarmed (5CP)",5],
	["B_A_MRAP_03_hmg_tna_F","Strider HMG (18CP)",18],
	["B_A_MRAP_03_gmg_tna_F","Strider GMG (25CP)",25],
	["B_LSV_01_unarmed_tna_F","Prowler Unarmed (5CP)",5],
	["B_LSV_01_armed_tna_F","Prowler HMG (15CP)",15],
	["B_LSV_01_tna_AT_F","Prowler AT (20CP)",20],
	["B_T_Truck_01_transport_F","HEMTT Transport Uncovered (8CP)",8],
	["B_T_Truck_01_covered_F","HEMTT Transport Covered (8CP)",8],
	["B_T_Truck_01_Repair_F","HEMTT Repair (50CP)",50],
	["B_T_Truck_01_ammo_F","HEMTT Ammo (50CP)",50],
	["B_T_Truck_01_fuel_F","HEMTT Fuel (50CP)",50],
	["B_T_APC_Wheeled_01_cannon_F","AMV-7 Marshall (35CP)",35],
	["B_T_APC_Tracked_01_AA_F","IFV-6c Cheetah (30CP)",30],
	["B_T_AFV_Wheeled_01_cannon_F","Rhino MGS (35CP)",35],
	["B_T_AFV_Wheeled_01_up_cannon_F","Rhino MGS UP (35CP)",35],
	["B_T_APC_Tracked_01_CRV_F","CRV-6e Bobcat (28CP)",28],
	["B_T_APC_Tracked_01_rcws_F","IFV-6c Panther (25CP)",25],
	["I_APC_Wheeled_03_cannon_F","AFV-4 Gorgon (35CP)",35],
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


