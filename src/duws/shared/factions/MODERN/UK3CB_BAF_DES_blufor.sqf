
///////////////   ""UK3CB_BAF", "3CB British AF (DDPM)", "UK3CB_BAF_DES""


blufor_SOLDIER_X =				"UK3CB_BAF_Pointman_DDPM";		//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"UK3CB_BAF_LAT_ILAW_DDPM";		//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"UK3CB_BAF_Grenadier_DDPM";		//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"UK3CB_BAF_FT_DDPM";			//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"UK3CB_BAF_SC_DDPM";			//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"UK3CB_BAF_LSW_DDPM";			//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"UK3CB_BAF_Marksman_DDPM";		//init_hq\fnc_HQguards
blufor_OFFICER_X =				"UK3CB_BAF_Officer_DDPM";		//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"UK3CB_BAF_HeliPilot_Army_DDPM";    //Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"UK3CB_BAF_RHIB_HMG_DDPM";	    //supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"UK3CB_BAF_GunnerStatic_DDPM";	//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"UK3CB_BAF_Merlin_HC3_18_GPMG_DDPM";    //supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"UK3CB_BAF_Merlin_HC3_18_DDPM";         //random patrol
blufor_ATTACK_HELI_X =			"UK3CB_BAF_Apache_AH1_DDPM";            //dialog\fnc_request_hcATTchop
blufor_MISC_AIR_X =				"B_Plane_CAS_01_F";                     //dialog\fnc_request_hcCAS
blufor_ARMED_CAR1_X =			"UK3CB_BAF_Jackal2_L2A1_D_DDPM";        //random patrol
blufor_APC1_X =					"UK3CB_BAF_FV432_Mk3_RWS_Sand_DDPM";    //random patrol
blufor_APC2_X =					"UK3CB_BAF_FV432_Mk3_GPMG_Sand_DDPM";   //random patrol
blufor_MBT_TANK1_X =			"B_MBT_01_TUSK_F";				        //random patrol



blufor_TURRET_AA = 				"B_static_AA_F";
blufor_TURRET_AT =				"B_static_AT_F";
blufor_TURRET_HMG =				"UK3CB_BAF_Static_L111A1_Deployed_High_DDPM";
blufor_TURRET_GMG =				"UK3CB_BAF_Static_L134A1_Deployed_High_DDPM";



blufor_SPECOPS_X =				"UK3CB_BAF_Pointman_DDPM_REC";	//operator
blufor_SPECOPS_GL_X =			"UK3CB_BAF_FAC_DDPM_REC";		//operator
blufor_SPECOPS_LAT_X =			"UK3CB_BAF_LAT_DDPM";           //operator
blufor_SPECOPS_HAT_X =			"UK3CB_BAF_MAT_DDPM";           //operator
blufor_SPECOPS_AA_X =			"B_soldier_AA_F";				//operator
blufor_SPECOPS_MG_X =			"UK3CB_BAF_MGLMG_DDPM_REC";		//operator
blufor_SPECOPS_MEDIC_X =		"UK3CB_BAF_Medic_DDPM_REC";		//operator
blufor_SPECOPS_MARK_X =			"UK3CB_BAF_Marksman_DDPM_REC";	//operator
blufor_SPECOPS_SNIPER_X =		"UK3CB_BAF_Sniper_DDPM_Ghillie_L115";   //operator
blufor_SPECOPS_EXP_X =			"UK3CB_BAF_Explosive_DDPM_REC";	//operator
blufor_SPECOPS_ENG_X = 			"UK3CB_BAF_Engineer_DDPM";		//operator





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
	["UK3CB_BAF_Pointman_DDPM","Point Man (DDPM) (2CP)",2],
	["UK3CB_BAF_Grenadier_DDPM","Grenadier (DDPM) (3CP)",3],
	["UK3CB_BAF_LSW_DDPM","Automatic Rifleman (DDPM) (3CP)",3],
	["UK3CB_BAF_MGGPMG_DDPM","Heavy Gunner (DDPM) (4CP)",4],
	["UK3CB_BAF_Medic_DDPM","Medic (DDPM) (4CP)",4],
	["UK3CB_BAF_LAT_ILAW_DDPM","AT Rifleman (DDPM) (3CP)",3],
	["UK3CB_BAF_MAT_DDPM","AT Specialist (DDPM) (4CP)",4],
	["UK3CB_BAF_Engineer_DDPM","Engineer (DDPM) (4CP)",4],
	["UK3CB_BAF_Repair_DDPM","Repair Specialist (DDPM) (4CP)",4],
	["UK3CB_BAF_Explosive_DDPM","Explosive Specialist (DDPM) (4CP)",4],
	["UK3CB_BAF_Spotter_DDPM_Ghillie_L129","Spotter (DDPM) (3CP)",3],
	["UK3CB_BAF_Marksman_DDPM","Marksman (DDPM) (3CP)",3],
	["UK3CB_BAF_Sniper_DDPM_Ghillie_L115","Sniper (DDPM) (4CP)",4]
];


// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;

blufor_RQST_VEHICLES = [
	["B_Quadbike_01_F","ATV (1CP)",1],
	["C_Offroad_01_F","SF Offroader (2CP)",2],
	["I_G_Van_01_transport_F","Transport Truck (6CP)",6],
	["B_MRAP_01_F","Hunter Unarmed (5CP)",5],
	["UK3CB_BAF_Husky_Passenger_HMG_Sand_DDPM","Husky HMG (18CP)",18],
	["UK3CB_BAF_Husky_Passenger_GMG_Sand_DDPM","Husky GMG (25CP)",25],
	["UK3CB_BAF_LandRover_Hard_FFR_Sand_A_DDPM","Land Rover Unarmed (5CP)",5],
	["UK3CB_BAF_LandRover_WMIK_HMG_FFR_Sand_A_DDPM","Land Rover HMG (15CP)",15],
	["UK3CB_BAF_LandRover_WMIK_Milan_FFR_Sand_A_DDPM","Land Rover AT (20CP)",20],
	["B_Truck_01_transport_F","HEMTT Transport Uncovered (8CP)",8],
	["UK3CB_BAF_MAN_HX58_Transport_Sand_DDPM","MAN Transport Covered (8CP)",8],
	["UK3CB_BAF_MAN_HX58_Repair_Sand_DDPM","MAN Repair (50CP)",50],
	["UK3CB_BAF_MAN_HX58_Cargo_Sand_B_DDPM","MAN Cargo (50CP)",50],
	["UK3CB_BAF_MAN_HX58_Fuel_Sand_DDPM","MAN Fuel (50CP)",50],
	["B_APC_Wheeled_01_cannon_F","AMV-7 Marshall (35CP)",35],
	["B_APC_Tracked_01_AA_F","IFV-6c Cheetah (30CP)",30],
	["B_AFV_Wheeled_01_cannon_F","Rhino MGS (35CP)",35],
	["B_AFV_Wheeled_01_up_cannon_F","Rhino MGS UP (35CP)",35],
	["UK3CB_BAF_LandRover_Panama_Sand_A_DDPM","Land Rover ROV (10CP)",10],
	["UK3CB_BAF_FV432_Mk3_RWS_Sand_DDPM","FV432/3 Bulldog HMG (25CP)",25],
	["UK3CB_BAF_FV432_Mk3_GPMG_Sand_DDPM","FV432/3 Bulldog GPMG (35CP)",35],
	["B_MBT_01_cannon_F","M2A1 Slammer (40CP)",40],
	["B_MBT_01_TUSK_F","M2A4 Slammer UP (40CP)",40],
	["I_MBT_03_cannon_F","MBT-52 Kuma (50CP)",50],
	["B_MBT_01_arty_F","M4 Scorcher Artillery (75CP)",75],
	["B_MBT_01_mlrs_F","M5 Sandstorm MLRS (75CP)",75],
	["B_Heli_Light_01_dynamicLoadout_F","AH-9 Pawnee (25CP)",25],
	["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15],
	["UK3CB_BAF_Apache_AH1_DDPM","Apache AH1 (45CP)",45],
	["B_T_VTOL_01_armed_F","V-44 X Armed (40CP",40],
	["UK3CB_BAF_Wildcat_AH1_TRN_8A_DDPM","Wildcat AH1 Transport (22CP)",22],
	["UK3CB_BAF_Merlin_HC3_18_DDPM","Merlin HC3 Unarmed (26CP)",26],
	["UK3CB_BAF_Merlin_HC3_18_GPMG_DDPM","Merlin HC3 Armed (26CP)",26],
	["B_Plane_CAS_01_dynamicLoadout_F","A-164 Wipeout CAS (45CP)",45],
	["B_Plane_Fighter_01_F","FA-181 Black Wasp II (50CP)",50],
	["B_Plane_Fighter_01_Stealth_F","FA-181 Black Wasp II Stealth (60CP)",60],
	["B_UAV_01_F","UAV Darter(5CP)",5],
	["UK3CB_BAF_MQ9_Reaper_DDPM","MQ-9 Reaper (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20],
	["B_T_UAV_03_dynamicLoadout_F","MQ-12 UAV (20CP)",20]
];


