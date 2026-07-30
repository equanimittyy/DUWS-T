
///////////////
///////////////   "TIOW_REN_BL", "Chaos Renegades (Black)", "TIOW_REN_BL"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"TIOW_B_Ren_BL_Rifleman";			//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"TIOW_B_Ren_BL_AT";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"TIOW_B_Ren_BL_Plasma";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"TIOW_B_Ren_BL_Lead";	//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"TIOW_B_Ren_BL_Vox";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"TIOW_B_Ren_BL_LMG";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"TIOW_B_Ren_BL_Rifleman";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"TIOW_B_Ren_BL_Officer";					//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"TIOW_B_Ren_BL_Crew";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"TIOW_B_Ren_BL_Crew";		//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"Valkyrie_Possessed_BL_B";		//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"Valkyrie_Possessed_BL_B";   //random patrol
blufor_HELI_ATTACK_X =			"Valkyrie_Possessed_BL_B";			//dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"Valkyrie_Possessed_BL_B";				//dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"TIOW_Centaur_01_Renegade_BL_Blu";				//random patrol
blufor_APC_PATROL1_X =			"TIOW_RenegadeTrojan_Black";	//random patrol
blufor_APC_PATROL2_X =			"_RenegadeChimAuto_Black";		//random patrol
blufor_TANK_PATROL1_X =			"TIOW_Renegade_LR_Battlecannon_Black_Blu";				//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"TIOW_IG_MissileLauncher_AA_RenBlack_Blu";
blufor_TURRET_AT =				"TIOW_IG_MissileLauncher_AT_RenBlack_Blu";
blufor_TURRET_HMG =				"TIOW_IG_Autocannon_RenBlack_Blu";
blufor_TURRET_GMG =				"TIOW_IG_HeavyBolter_RenBlack_Blu";



/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

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
	["TIOW_B_Ren_BL_Rifleman","Rifleman (2CP)",2],
	["TIOW_B_Ren_BL_Lead","Enforcer (3CP)",3],
	["TIOW_B_Ren_BL_Vox","Vox Operator (3CP)",3],
	["TIOW_B_Ren_BL_Plasma","Plasmagunner (4CP)",4],
	["TIOW_B_Ren_BL_Medic","Medic (4CP)",4],
	["TIOW_B_Ren_BL_Melta","Meltagunner (4CP)",4],
	["TIOW_B_Ren_BL_Sapper","Sapper (4CP)",4],
	["TIOW_B_Ren_BL_Engineer","Engineer (4CP)",4],
	["TIOW_B_Ren_BL_LMG","Autorifleman (4CP)",4],
	["TIOW_B_Ren_BL_Officer","Officer (5CP)",5],
	["TIOW_B_Ren_BL_AT","AT Soldier (4CP)",4]
];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////

blufor_RQST_VEHICLES = [
	["TIOW_Centaur_01_Renegade_BL_Blu","Centaur (1CP)",1],
	["C_Offroad_01_F","SF Offroader (2CP)",2],
	["I_G_Van_01_transport_F","Transport Truck (6CP)",6],
	["TIOW_RenegadeTrojan_Black","Trojan(7CP)",7],
	["_RenegadeChimAuto_Black","Chimera (18CP)",18],
	["TIOW_RenegadeWyvern_Black_Blu","Wyvern (25CP)",25],
	["TIOW_RenegadeHydra_Black_Blu","Hydra (25CP)",25],
	["B_Truck_01_transport_F","HEMTT Transport Uncovered (8CP)",8],
	["B_Truck_01_covered_F","HEMTT Transport Covered (8CP)",8],
	["B_Truck_01_Repair_F","HEMTT Repair (50CP)",50],
	["B_Truck_01_ammo_F","HEMTT Ammo (50CP)",50],
	["B_Truck_01_fuel_F","HEMTT Fuel (50CP)",50],
	["B_Truck_01_ammo_F","HEMTT Ammo (50CP)",50],
	["B_Truck_01_fuel_F","HEMTT Fuel (50CP)",50],
	["TIOW_Renegade_LR_Annihilator_Black_Blu","Leman Russ - Annihilator (50CP)",50],
	["TIOW_Renegade_LR_Battlecannon_Black_Blu","Leman Russ - Battlecannon (40CP)",40],
	["TIOW_Renegade_LR_Conqueror_Black_Blu","Leman Russ - Conqueror (45CP)",45],
	["TIOW_Renegade_LR_Demolisher_Black_Blu","Leman Russ - Demolisher (55CP)",55],
	["TIOW_Renegade_LR_Executioner_Black_Blu","Leman Russ - Executioner (45CP)",45],
	["TIOW_Renegade_LR_Exterminator_Black_Blu","Leman Russ - Exterminator (55CP)",55],
	["TIOW_Renegade_LR_Punisher_Black_Blu","Leman Russ - Punisher (45CP)",45],
	["TIOW_Renegade_LR_Vanquisher_Black_Blu","Leman Russ - Vanquisher (45CP)",40],
	["Valkyrie_Possessed_BL_B","Chaos Valkyrie (50CP)",50],
	["TIOW_Warhound_MP_PBG_BLU_T","Titan Feral - Plasma Blastgun (200CP)",200],
	["TIOW_Warhound_MP_TLD_BLU_T","Titan Feral - Turbo Laser (200CP)",200],
	["TIOW_Warhound_MP_VMB_BLU_T","Titan Feral - Megabolter (200CP)",200]
];

