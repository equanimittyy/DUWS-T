
///////////////   "PSZ_PL", "PSZ Polish Army (WDL20)", "PSZ_PL_WDL20"


blufor_SOLDIER_X =				"PSZ_PL_WDL20_Soldier_Rifleman";		//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"PSZ_PL_WDL20_Soldier_AT_RPG7";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"PSZ_PL_WDL20_Soldier_Grenadier";		//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"PSZ_PL_WDL20_Soldier_TL";				//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"PSZ_PL_WDL20_Soldier_SL";				//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"PSZ_PL_WDL20_Soldier_PKM";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"PSZ_PL_WDL20_Soldier_Marksman";		//init_hq\fnc_HQguards
blufor_OFFICER_X =				"PSZ_PL_WDL20_Soldier_Officer";			//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"PSZ_PL_WDL20_Soldier_Pilot";			//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";			//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";						//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"PSZ_PL_WDL20_Mi17_1W_UB32";			//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"PSZ_PL_WDL20_Mi17_1W_PKT";   			//random patrol
blufor_ATTACK_HELI_X =			"PSZ_PL_WDL20_Mi24D";					//dialog\fnc_request_hcATTchop
blufor_MISC_AIR_X =				"B_Plane_CAS_01_dynamicLoadout_F";		//dialog\fnc_request_hcCAS
blufor_ARMED_CAR1_X =			"PSZ_PL_WDL20_Tumak2_WKM";				//random patrol
blufor_APC1_X =					"PSZ_PL_WDL20_Zbik_M97";				//random patrol
blufor_APC2_X =					"PSZ_PL_WDL20_Rosomak_M1M";				//random patrol
blufor_MBT_TANK1_X =			"PSZ_PL_WDL20_Leopard_2PL";				//random patrol



blufor_TURRET_AA = 				"B_static_AA_F";
blufor_TURRET_AT =				"B_static_AT_F";
blufor_TURRET_HMG =				"B_G_HMG_02_high_F";
blufor_TURRET_GMG =				"B_GMG_01_high_F";



blufor_SPECOPS_X =				"PSZ_PL_WDL20_Soldier_Rifleman";		//operator
blufor_SPECOPS_GL_X =			"PSZ_PL_WDL20_Soldier_Grenadier";		//operator
blufor_SPECOPS_LAT_X =			"PSZ_PL_WDL20_Soldier_AT_RPG7";			//operator
blufor_SPECOPS_HAT_X =			"PSZ_PL_WDL20_Soldier_AT_M3";			//operator
blufor_SPECOPS_AA_X =			"PSZ_PL_WDL20_Soldier_AA";				//operator
blufor_SPECOPS_MG_X =			"PSZ_PL_WDL20_Soldier_PKM";				//operator
blufor_SPECOPS_MEDIC_X =		"PSZ_PL_WDL20_Soldier_Medic";			//operator
blufor_SPECOPS_MARK_X =			"PSZ_PL_WDL20_Soldier_Marksman";		//operator
blufor_SPECOPS_SNIPER_X =		"PSZ_PL_WDL20_Soldier_Sniper";			//operator
blufor_SPECOPS_EXP_X =			"PSZ_PL_WDL20_Soldier_Sapper";			//operator
blufor_SPECOPS_ENG_X = 			"PSZ_PL_WDL20_Soldier_Sapper";			//operator





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
	["PSZ_PL_WDL20_Soldier_Rifleman","Rifleman (2CP)",2],
	["PSZ_PL_WDL20_Soldier_Grenadier","Grenadier (3CP)",3],
	["PSZ_PL_WDL20_Soldier_AR","Automatic Rifleman (3CP)",3],
	["PSZ_PL_WDL20_Soldier_PKM","Heavy Gunner (4CP)",4],
	["PSZ_PL_WDL20_Soldier_Medic","Medic (4CP)",4],
	["PSZ_PL_WDL20_Soldier_AT_RPG7","AT Rifleman (3CP)",3],
	["PSZ_PL_WDL20_Soldier_AT_M3","AT Specialist (4CP)",4],
	["PSZ_PL_WDL20_Soldier_AA","AA Specialist (4CP)",4],
	["PSZ_PL_WDL20_Soldier_Sapper","Engineer (4CP)",4],
	["PSZ_PL_WDL20_Soldier_Marksman","Marksman (3CP)",3],
	["PSZ_PL_WDL20_Soldier_Sniper","Sniper (4CP)",4]
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
	["PSZ_PL_WDL20_Tumak2","Tumak 2 Unarmed (15CP)",15],
	["PSZ_PL_WDL20_Tumak2_WKM","Tumak 2 HMG (20CP)",20],
	["B_LSV_01_unarmed_F","Prowler Unarmed (5CP)",5],
	["B_LSV_01_armed_F","Prowler HMG (15CP)",15],
	["B_LSV_01_AT_F","Prowler AT (20CP)",20],
	["B_Truck_01_transport_F","HEMTT Transport Uncovered (8CP)",8],
	["PSZ_PL_WDL20_Star_1466","Star Transport Covered (8CP)",8],
	["B_Truck_01_Repair_F","HEMTT Repair (50CP)",50],
	["PSZ_PL_WDL20_Star_1466_Ammo","Star 1466 Ammo (50CP)",50],
	["PSZ_PL_WDL20_Star_1466_Fuel","MTVR Fuel (50CP)",50],
	["PSZ_PL_WDL20_Zbik_M96","BRDM Szakal (25CP)",25],
	["PSZ_PL_WDL20_Zbik_M97","BRDM Zbik (30CP)",30],
	["PSZ_PL_WDL20_Rosomak_1","Rosomak (32CP)",32],
	["PSZ_PL_WDL20_Rosomak_M1M","Rosomak M1M (35CP)",35],
	["B_MBT_01_cannon_F","M2A1 Slammer (40CP)",40],
	["PSZ_PL_WDL20_Leopard_2PL","Leopard 2 MBT (45CP)",40],
	["B_MBT_01_mlrs_F","Sandstorm MLRS (75CP)",75],
	["B_MBT_01_arty_F","M4 Scorcher (75CP)",75],
	["B_Heli_Light_01_dynamicLoadout_F","AH-9 Pawnee (25CP)",25],
	["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15],
	["PSZ_PL_WDL20_Mi17_1W_PKT","MI-17 Armed Heli (22CP)",22],
	["PSZ_PL_WDL20_Mi17_1W_UB32","MI-17 Gunship (26CP)",26],
	["B_T_VTOL_01_armed_F","V-44 X Armed (40CP",40],
	["PSZ_PL_WDL20_Mi24D","MI-24 Gunship (45CP)",45],
	["B_Plane_CAS_01_dynamicLoadout_F","A-164 Wipeout CAS (45CP)",45],
	["B_Plane_Fighter_01_F","Black Wasp 2 (50CP)",50],
	["B_Plane_Fighter_01_Stealth_F","Black Wasp 2 Stealth (60CP)",60],
	["B_UAV_01_F","UAV Darter(5CP)",5],
	["B_UAV_02_dynamicLoadout_F","UAV MQ-4A Greyhawk (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20]
];


