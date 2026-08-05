
///////////////
///////////////   "TIOW_CADIAN_836", "Cadian 836th", "TIOW_CADIAN_836"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"TIOW_Cad_GM836th";			//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"TIOW_Cad_GM_Plasma_836th";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"TIOW_Cad_GM_GrenadeLauncher_836th";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"TIOW_Cad_VET836th";	//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"TIOW_Cad_SGT836th";				//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"TIOW_Cad_Kasr836th";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"TIOW_Cad_SNIPER836th";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"TIOW_IG_Captain_836";					//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"TIOW_Cad_Tnk836th";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"TIOW_Cad_Tnk836th";		//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"TIOW_Valkyrie_Fuel_B";		//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"TIOW_Valkyrie_Fuel_M_B";   //random patrol
blufor_ATTACK_HELI_X =			"TIOW_Valkyrie_Rocket_B";			//dialog\fnc_request_hcATTchop
blufor_MISC_AIR_X =				"TIOW_Valkyrie_Rocket_M_B";				//dialog\fnc_request_hcCAS
blufor_ARMED_CAR1_X =			"TIOW_Centaur_01_Cadian_836_Blu";				//random patrol
blufor_APC1_X =					"TIOW_CadianTrojan_836";	//random patrol
blufor_APC2_X =					"TIOW_CadianChimAuto_836";		//random patrol
blufor_MBT_TANK1_X =			"TIOW_Cad_LR_Battlecannon_836th_Blu";				//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"TIOW_IG_MissileLauncher_AA_836_Blu";
blufor_TURRET_AT =				"TIOW_IG_MissileLauncher_AT_836_Blu";
blufor_TURRET_HMG =				"TIOW_IG_Autocannon_836_Blu";
blufor_TURRET_GMG =				"TIOW_IG_HeavyBolter_836_Blu";



/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"TIOW_Cad_GM836th";					//operator
blufor_SPECOPS_GL_X =			"TIOW_Cad_GM_GrenadeLauncher_836th";				//operator
blufor_SPECOPS_LAT_X =			"TIOW_Cad_GM_Flamer_836th";				//operator
blufor_SPECOPS_HAT_X =			"TIOW_Cad_GM_Plasma_836th";		//operator
blufor_SPECOPS_AA_X =			"TIOW_Cad_GM_Melta_836th";				//operator
blufor_SPECOPS_MG_X =			"TIOW_Cad_Kasr836th";		//operator
blufor_SPECOPS_MEDIC_X =		"TIOW_Cad_Med836th";				//operator
blufor_SPECOPS_MARK_X =			"TIOW_Cad_SNIPER836th";					//operator
blufor_SPECOPS_SNIPER_X =		"TIOW_Cad_SNIPER836th";					//operator
blufor_SPECOPS_EXP_X =			"TIOW_Cad_GM_GrenadeLauncher_836th";				//operator
blufor_SPECOPS_ENG_X = 			"TIOW_Cad_GM_Vox_836th";			//operator





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
	["TIOW_Cad_GM836th","Shocktrooper (2CP)",2],
	["TIOW_Cad_VET836th","Veteran (3CP)",3],
	["TIOW_Cad_GM_Vox_836th","Vox Operator (3CP)",3],
	["TIOW_Cad_GM_Plasma_836th","Plasmagunner (4CP)",4],
	["TIOW_Cad_Med836th","Medic (4CP)",4],
	["TIOW_Cad_GM_Melta_836th","Meltagunner (4CP)",4],
	["TIOW_Cad_GM_GrenadeLauncher_836th","Grenade Launcher (4CP)",4],
	["TIOW_Cad_GM_Flamer_836th","Flamer (4CP)",4],
	["TIOW_Cad_Kasr836th","Kasrkin (4CP)",4],
	["TIOW_Cad_SNIPER836th","Sniper (3CP)",3],
	["TIOW_Comissar_Winter","Comissar (4CP)",4],
	["TIOW_Priest","Priest (4CP)",4]
];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////

blufor_RQST_VEHICLES = [
	["TIOW_Centaur_01_Cadian_836_Blu","Centaur (1CP)",1],
	["C_Offroad_01_F","SF Offroader (2CP)",2],
	["I_G_Van_01_transport_F","Transport Truck (6CP)",6],
	["TIOW_CadianTrojan_836","Trojan(7CP)",7],
	["TIOW_CadianChimAuto_836","Chimera (18CP)",18],
	["TIOW_CadianWyvern_836","Wyvern (25CP)",25],
	["TIOW_CadianHydra_836","Hydra (25CP)",25],
	["B_Truck_01_transport_F","HEMTT Transport Uncovered (8CP)",8],
	["B_Truck_01_covered_F","HEMTT Transport Covered (8CP)",8],
	["B_Truck_01_Repair_F","HEMTT Repair (50CP)",50],
	["B_Truck_01_ammo_F","HEMTT Ammo (50CP)",50],
	["B_Truck_01_fuel_F","HEMTT Fuel (50CP)",50],
	["B_Truck_01_ammo_F","HEMTT Ammo (50CP)",50],
	["B_Truck_01_fuel_F","HEMTT Fuel (50CP)",50],
	["TIOW_Cad_LR_Annihilator_836th_Blu","Leman Russ - Annihilator (50CP)",50],
	["TIOW_Cad_LR_Battlecannon_836th_Blu","Leman Russ - Battlecannon (40CP)",40],
	["TIOW_Cad_LR_Conqueror_836th_Blu","Leman Russ - Conqueror (45CP)",45],
	["TIOW_Cad_LR_Demolisher_836th_Blu","Leman Russ - Demolisher (55CP)",55],
	["TIOW_Cad_LR_Executioner_836th_Blu","Leman Russ - Executioner (45CP)",45],
	["TIOW_Cad_LR_Exterminator_836th_Blu","Leman Russ - Exterminator (55CP)",55],
	["TIOW_Cad_LR_Punisher_836th_Blu","Leman Russ - Punisher (45CP)",45],
	["TIOW_Cad_LR_Vanquisher_836th_Blu","Leman Russ - Vanquisher (45CP)",40],
	["TIOW_Warhound_LP_PBG_BLU","Titan Warhound - Plasma (200CP)",200],
	["TIOW_Warhound_LP_TLD_BLU","Titan Warhound - Turbolaser (200CP)",200],
	["TIOW_Warhound_LP_VMB_BLU","Titan Warhound - Megabolter (200CP)",200],
	["TIOW_Valkyrie_Fuel_B","Valkyrie - Lascannon(40CP)",40],
	["TIOW_Valkyrie_Fuel_M_B","Valkyrie - Multilaser (45CP)",45],
	["TIOW_Valkyrie_Rocket_B","Valkyrie - Lascannon + Rockets (50CP)",50],
	["TIOW_Valkyrie_Rocket_M_B","Valkyrie - Multilaser + Rockets (50CP)",50],
	["TIOW_Thunderbolt_Base","Thunderbolt Heavy Figher (60CP",60]
];

