
///////////////   "IND_F", "AAF Altis Armed Forces", "IND_F"


blufor_SOLDIER_X =				"I_soldier_F";					//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"I_Soldier_LAT_F";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"I_Soldier_GL_F";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"I_Soldier_TL_F";				//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"I_Soldier_SL_F";				//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"I_Soldier_AR_F";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"I_soldier_M_F";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"I_OFFICER_F";					//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"I_helipilot_F";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";	//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";				//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"I_Heli_light_03_dynamicLoadout_F";		//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"I_Heli_Transport_02_F";   				//random patrol
blufor_ATTACK_HELI_X =			"I_Heli_light_03_dynamicLoadout_F";		//dialog\fnc_request_hcATTchop, random patrol
blufor_MISC_AIR_X =				"I_Plane_Fighter_03_dynamicLoadout_F";	//dialog\fnc_request_hcCAS, random patrol
blufor_ARMED_CAR1_X =			"I_MRAP_03_hmg_F";						//random patrol
blufor_APC1_X =					"I_APC_Wheeled_03_cannon_F";			//random patrol
blufor_APC2_X =					"I_LT_01_cannon_F";						//random patrol
blufor_MBT_TANK1_X =			"I_MBT_03_cannon_F";					//random patrol



blufor_TURRET_AA = 				"B_static_AA_F";
blufor_TURRET_AT =				"B_static_AT_F";
blufor_TURRET_HMG =				"B_G_HMG_02_high_F";
blufor_TURRET_GMG =				"B_GMG_01_high_F";



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
	["I_soldier_F","Rifleman (AAF) (2CP)",2],
	["I_Soldier_GL_F","Grenadier (AAF) (3CP)",3],
	["I_Soldier_AR_F","Automatic Rifleman (AAF) (3CP)",3],
	["I_C_Soldier_Para_4_F","Heavy Gunner (AAF) (4CP)",4],
	["I_medic_F","Medic (AAF) (4CP)",4],
	["I_Soldier_LAT_F","AT Rifleman (AAF) (3CP)",3],
	["I_Soldier_AT_F","AT Specialist (AAF) (4CP)",4],
	["I_Soldier_AAA_F","AA Specialist (AAF) (4CP)",4],
	["I_engineer_F","Engineer (AAF) (4CP)",4],
	["I_soldier_M_F","Marksman (AAF) (3CP)",3],
	["I_Sniper_F","Sniper (AAF) (4CP)",4]
];


// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;

blufor_RQST_VEHICLES = [
	["B_Quadbike_01_F","ATV (1CP)",1],
	["C_Offroad_01_F","SF Offroader (2CP)",2],
	["I_G_Van_01_transport_F","Transport Truck (6CP)",6],
	["I_MRAP_03_F","Strider Unarmed (5CP)",5],
	["I_MRAP_03_hmg_F","Strider HMG (18CP)",18],
	["I_MRAP_03_gmg_F","Hunter GMG (25CP)",25],
	["I_C_Offroad_02_unarmed_F","4WD Jeep Unarmed (5CP)",5],
	["I_G_Offroad_01_armed_F","Offroad HMG (15CP)",15],
	["I_G_Offroad_01_AT_F","Offroad AT (20CP)",20],
	["I_Truck_02_transport_F","Zamak Transport Uncovered (8CP)",8],
	["I_Truck_02_covered_F","Zamak Transport Covered (8CP)",8],
	["I_Truck_02_box_F","Zamak Repair (50CP)",50],
	["I_Truck_02_ammo_F","Zamak Ammo (50CP)",50],
	["I_Truck_02_fuel_F","Zamak Fuel (50CP)",50],
	["B_APC_Wheeled_01_cannon_F","AMV-7 Marshall (35CP)",35],
	["I_APC_Wheeled_03_cannon_F","AFV-4 Gorgon (35CP)",35],
	["B_AFV_Wheeled_01_cannon_F","Rhino MGS (35CP)",35],
	["B_APC_Tracked_01_CRV_F","CRV-6e Bobcat (28CP)",28],
	["I_APC_tracked_03_cannon_F","FV-720 Mora (30CP)",30],
	["I_LT_01_cannon_F","AWC-304 Nyx (30CP)",30],
	["I_LT_01_AA_F","AWC-304 Nyx AA (35CP)",35],
	["B_MBT_01_cannon_F","M2A1 Slammer (40CP)",40],
	["B_MBT_01_TUSK_F","M2A4 Slammer UP (40CP)",40],
	["I_MBT_03_cannon_F","MBT-52 Kuma (50CP)",50],
	["B_MBT_01_arty_F","M4 Scorcher Artillery (75CP)",75],
	["I_Truck_02_MRL_F","Zamak MRL (75CP)",75],
	["B_Heli_Light_01_dynamicLoadout_F","AH-9 Pawnee (25CP)",25],
	["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15],
	["I_Heli_light_03_dynamicLoadout_F","MY-55 Hellcat Armed (45CP)",45],
	["B_T_VTOL_01_armed_F","V-44 X Armed (40CP",40],
	["B_Heli_Transport_01_F","UH-80 Ghosthawk (22CP)",22],
	["I_Heli_Transport_02_F","CH-49 Mowawk (26CP)",26],
	["B_Heli_Transport_03_F","CH-67 Huron Armed (26CP)",26],
	["I_Plane_Fighter_03_dynamicLoadout_F","A-143 Buzzard CAS (45CP)",45],
	["I_Plane_Fighter_04_F","A-149 Gryphon (50CP)",50],
	["B_Plane_Fighter_01_Stealth_F","FA-181 Black Wasp II Stealth (60CP)",60],
	["I_UAV_01_F","UAV Darter (5CP)",5],
	["I_UAV_02_dynamicLoadout_F","UAV K-40 Ababil (15CP)",15],
	["I_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["I_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20]
];


