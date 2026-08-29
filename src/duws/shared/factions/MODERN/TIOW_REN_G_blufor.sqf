
///////////////   "TIOW_REN_G", "Chaos Renegades (Green)", "TIOW_REN_G"


blufor_SOLDIER_X =				"TIOW_B_Ren_G_Rifleman";			//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"TIOW_B_Ren_G_AT";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"TIOW_B_Ren_G_Plasma";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"TIOW_B_Ren_G_Lead";	//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"TIOW_B_Ren_G_Vox";				//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"TIOW_B_Ren_G_LMG";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"TIOW_B_Ren_G_Rifleman";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"TIOW_B_Ren_G_Officer";					//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"TIOW_B_Ren_G_Crew";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"TIOW_B_Ren_G_Crew";		//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"Valkyrie_Possessed_B_B";		//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"Valkyrie_Possessed_B_B";   //random patrol
blufor_ATTACK_HELI_X =			"Valkyrie_Possessed_B_B";			//dialog\fnc_request_hcATTchop
blufor_MISC_AIR_X =				"Valkyrie_Possessed_B_B";				//dialog\fnc_request_hcCAS
blufor_ARMED_CAR1_X =			"TIOW_Centaur_01_Renegade_B_Blu";				//random patrol
blufor_APC1_X =					"TIOW_RenegadeTrojan_Green";	//random patrol
blufor_APC2_X =					"_RenegadeChimAuto_Green";		//random patrol
blufor_MBT_TANK1_X =			"TIOW_Renegade_LR_Battlecannon_Green_Blu";				//random patrol



blufor_TURRET_AA = 				"TIOW_IG_MissileLauncher_AA_RenGreen_Blu";
blufor_TURRET_AT =				"TIOW_IG_MissileLauncher_AT_RenGreen_Blu";
blufor_TURRET_HMG =				"TIOW_IG_Autocannon_RenGreen_Blu";
blufor_TURRET_GMG =				"TIOW_IG_HeavyBolter_RenGreen_Blu";




blufor_SPECOPS_X =				"TIOW_Cultist6";					//operator
blufor_SPECOPS_GL_X =			"TIOW_Cultist2";				//operator
blufor_SPECOPS_LAT_X =			"TIOW_Cultist5";				//operator
blufor_SPECOPS_HAT_X =			"TIOW_Cultist";		//operator
blufor_SPECOPS_AA_X =			"TIOW_Cultist3";				//operator
blufor_SPECOPS_MG_X =			"TIOW_Cultist3";		//operator
blufor_SPECOPS_MEDIC_X =		"TIOW_Cultist7";				//operator
blufor_SPECOPS_MARK_X =			"TIOW_Cultist6";					//operator
blufor_SPECOPS_SNIPER_X =		"TIOW_Cultist6";					//operator
blufor_SPECOPS_EXP_X =			"TIOW_Cultist2";				//operator
blufor_SPECOPS_ENG_X = 			"TIOW_Cultist4";			//operator





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
	["TIOW_B_Ren_G_Rifleman","Rifleman (2CP)",2],
	["TIOW_B_Ren_G_Lead","Enforcer (3CP)",3],
	["TIOW_B_Ren_G_Vox","Vox Operator (3CP)",3],
	["TIOW_B_Ren_G_Plasma","Plasmagunner (4CP)",4],
	["TIOW_B_Ren_G_Medic","Medic (4CP)",4],
	["TIOW_B_Ren_G_Melta","Meltagunner (4CP)",4],
	["TIOW_B_Ren_G_Sapper","Sapper (4CP)",4],
	["TIOW_B_Ren_G_Engineer","Engineer (4CP)",4],
	["TIOW_B_Ren_G_LMG","Autorifleman (4CP)",4],
	["TIOW_B_Ren_G_Officer","Officer (5CP)",5],
	["TIOW_B_Ren_G_AT","AT Soldier (4CP)",4]
];


// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;

blufor_RQST_VEHICLES = [
	["TIOW_Centaur_01_Renegade_B_Blu","Centaur (1CP)",1],
	["C_Offroad_01_F","SF Offroader (2CP)",2],
	["I_G_Van_01_transport_F","Transport Truck (6CP)",6],
	["TIOW_RenegadeTrojan_Green","Trojan(7CP)",7],
	["_RenegadeChimAuto_Green","Chimera (18CP)",18],
	["TIOW_RenegadeWyvern_Green_Blu","Wyvern (25CP)",25],
	["TIOW_RenegadeHydra_Green_Blu","Hydra (25CP)",25],
	["B_Truck_01_transport_F","HEMTT Transport Uncovered (8CP)",8],
	["B_Truck_01_covered_F","HEMTT Transport Covered (8CP)",8],
	["B_Truck_01_Repair_F","HEMTT Repair (50CP)",50],
	["B_Truck_01_ammo_F","HEMTT Ammo (50CP)",50],
	["B_Truck_01_fuel_F","HEMTT Fuel (50CP)",50],
	["B_Truck_01_ammo_F","HEMTT Ammo (50CP)",50],
	["B_Truck_01_fuel_F","HEMTT Fuel (50CP)",50],
	["TIOW_Renegade_LR_Annihilator_Green_Blu","Leman Russ - Annihilator (50CP)",50],
	["TIOW_Renegade_LR_Battlecannon_Green_Blu","Leman Russ - Battlecannon (40CP)",40],
	["TIOW_Renegade_LR_Conqueror_Green_Blu","Leman Russ - Conqueror (45CP)",45],
	["TIOW_Renegade_LR_Demolisher_Green_Blu","Leman Russ - Demolisher (55CP)",55],
	["TIOW_Renegade_LR_Executioner_Green_Blu","Leman Russ - Executioner (45CP)",45],
	["TIOW_Renegade_LR_Exterminator_Green_Blu","Leman Russ - Exterminator (55CP)",55],
	["TIOW_Renegade_LR_Punisher_Green_Blu","Leman Russ - Punisher (45CP)",45],
	["TIOW_Renegade_LR_Vanquisher_Green_Blu","Leman Russ - Vanquisher (45CP)",40],
	["Valkyrie_Possessed_B_B","Chaos Valkyrie (50CP)",50],
	["TIOW_Warhound_MP_PBG_BLU_T","Titan Feral - Plasma Blastgun (200CP)",200],
	["TIOW_Warhound_MP_TLD_BLU_T","Titan Feral - Turbo Laser (200CP)",200],
	["TIOW_Warhound_MP_VMB_BLU_T","Titan Feral - Megabolter (200CP)",200]
];

