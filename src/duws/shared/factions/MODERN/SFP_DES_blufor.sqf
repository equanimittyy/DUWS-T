
///////////////   "SFP", "SFP Swedish Forces + SOG (Desert)", "SFP_DES"


blufor_SOLDIER_X =				"sfp_m90d_rifleman_long_m08";			//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"sfp_m90d_at_specialist_pskott86";		//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"sfp_m90d_gr";							//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"sfp_m90d_teamleader";					//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"sfp_m90d_squadleader";					//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"sfp_m90d_machinegunner_ksp58";			//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"sfp_m90d_marksman";					//init_hq\fnc_HQguards
blufor_OFFICER_X =				"sfp_m90d_officer";						//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"sfp_m90w_helipilot";					//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";			//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";						//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"sfp_hkp4_2015";						//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"sfp_hkp16";   							//random patrol
blufor_ATTACK_HELI_X =			"B_Heli_Attack_01_dynamicLoadout_F";	//dialog\fnc_request_hcATTchop, random patrol
blufor_MISC_AIR_X =				"sfp_jas39_gbu39";						//dialog\fnc_request_hcCAS, random patrol
blufor_ARMED_CAR1_X =			"sfp_tgb16_ksp58";						//random patrol
blufor_APC1_X =					"sfp_patgb360";							//random patrol
blufor_APC2_X =					"sfp_strf90c_desert";					//random patrol
blufor_MBT_TANK1_X =			"sfp_strv122b";							//random patrol



blufor_TURRET_AA = 				"sfp_rbs70";
blufor_TURRET_AT =				"sfp_rbs55";
blufor_TURRET_HMG =				"B_G_HMG_02_high_F";
blufor_TURRET_GMG =				"sfp_grsp";



blufor_SPECOPS_X =				"sfp_m90d_sog_ak5";						//operator
blufor_SPECOPS_GL_X =			"sfp_m90d_sog_teamleader";				//operator
blufor_SPECOPS_LAT_X =			"sfp_m90d_sog_at_specialist_rb57";		//operator
blufor_SPECOPS_HAT_X =			"sfp_m90d_sog_at_specialist_grg";		//operator
blufor_SPECOPS_AA_X =			"B_soldier_AA_F";						//operator
blufor_SPECOPS_MG_X =			"sfp_m90d_sog_machinegunner_ksp58";		//operator
blufor_SPECOPS_MEDIC_X =		"sfp_m90d_sog_medic";					//operator
blufor_SPECOPS_MARK_X =			"sfp_m90d_marksman";					//operator
blufor_SPECOPS_SNIPER_X =		"sfp_m90d_sog_sniper_ag90";				//operator
blufor_SPECOPS_EXP_X =			"sfp_m90d_sog_explosive_specialist";	//operator
blufor_SPECOPS_ENG_X = 			"sfp_m90d_engineer";					//operator





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
	["sfp_m90d_rifleman_long_m08","Rifleman (Desert) (2CP)",2],
	["sfp_m90d_gr","Grenadier (Desert) (3CP)",3],
	["sfp_m90d_automaticrifleman_ksp90","Automatic Rifleman (Desert) (3CP)",3],
	["sfp_m90d_machinegunner_ksp58","Heavy Gunner (Desert) (4CP)",4],
	["sfp_m90d_medic","Medic (Desert) (4CP)",4],
	["sfp_m90d_at_specialist_pskott86","Rifleman AT (Desert) (4CP)",4],
	["sfp_m90d_at_specialist_grg86","AT Specialist (Desert) (4CP)",4],
	["sfp_m90d_engineer","Engineer (Desert) (4CP)",4],
	["sfp_m90d_marksman","Marksman (Desert) (3CP)",3],
	["sfp_m90d_sniper","Sniper (Desert) (4CP)",4]
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
	["sfp_tgb16","TGB-16 Unarmed (10CP)",10],
	["sfp_tgb16_ksp58","TGB-16 HMG (15CP)",15],
	["sfp_tgb16_rws","TGB-16 HMG Crows (18CP)",18],
	["sfp_tgb1111_sog_rbs56","TGB-1111 AT (20CP)",20],
	["B_LSV_01_AT_F","Prowler AT (20CP)",20],
	["C_Truck_02_transport_F","Zamak Transport Uncovered (8CP)",8],
	["sfp_tgb13_ksp58","TGB-13 Transport HMG (10CP)",10],
	["B_Truck_01_Repair_F","HEMTT Repair Truck(50CP)",50],
	["B_Truck_01_ammo_F","HEMTT Ammo Truck (50CP)",50],
	["B_Truck_01_fuel_F","HEMTT Fuel Truck (50CP)",50],
	["sfp_patgb360","PATGB-360 (35CP)",35],
	["sfp_strf90c_desert","STRF-90C (35CP)",35],
	["sfp_lvkv90c_desert","LVKV-90 AA (35CP)",35],
	["B_APC_Tracked_01_rcws_F","IFV-6c Panther (25CP)",25],
	["B_APC_Tracked_01_CRV_F","CRV-6e Bobcat (28CP)",28],
	["B_APC_Wheeled_01_cannon_F","AMV-7 Marshall (35CP)",35],
	["B_MBT_01_cannon_F","M2A1 Slammer (40CP)",40],
	["sfp_strv122b","STRV-122 MBT (50CP)",50],
	["sfp_grkpbv90120","GRKPBV Artillery (75CP)",75],
	["B_MBT_01_mlrs_F","M5 Sandstorm MLRS (75CP)",75],
	["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15],
	["sfp_hkp16","HPK-16 Unarmed (22CP)",22],
	["sfp_hkp4_2015","HPK-4 Trans (30CP)",30],
	["B_Heli_Transport_01_F","UH-80 Ghosthawk (22CP)",22],
	["B_Heli_Attack_01_dynamicLoadout_F","AH-99 Blackfoot (45CP)",45],
	["B_T_VTOL_01_armed_F","V-44 X Armed (40CP",40],
	["B_Plane_CAS_01_dynamicLoadout_F","A-164 Wipeout (45CP)",45],
	["B_Plane_Fighter_01_F","FA-181 Black Wasp (50CP)",50],
	["B_UAV_01_F","UAV Darter(5CP)",5],
	["B_UAV_02_dynamicLoadout_F","UAV MQ-4A Greyhawk (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20]
];


