
///////////////
///////////////   "TIOW_CADIAN_776", "Cadian 776th", "TIOW_CADIAN_776"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"TIOW_Cad_GM776th";			//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"TIOW_Cad_GM_Plasma_776th";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"TIOW_Cad_GM_GrenadeLauncher_776th";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"TIOW_Cad_VET776th";	//init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"TIOW_Cad_SGT776th";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"TIOW_Cad_Kasr776th";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"TIOW_Cad_SNIPER776th";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"TIOW_IG_Captain_776";					//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"TIOW_Cad_Tnk776th";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"TIOW_Cad_Tnk776th";		//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"TIOW_Valkyrie_Fuel_B";		//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"TIOW_Valkyrie_Fuel_M_B";   //random patrol
blufor_HELI_ATTACK_X =			"TIOW_Valkyrie_Rocket_B";			//dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"TIOW_Valkyrie_Rocket_M_B";				//dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"TIOW_Centaur_01_Cadian_776_Blu";				//random patrol
blufor_APC_PATROL1_X =			"TIOW_CadianTrojan_776";	//random patrol
blufor_APC_PATROL2_X =			"TIOW_CadianChimAuto_776";		//random patrol
blufor_TANK_PATROL1_X =			"TIOW_Cad_LR_Battlecannon_776th_Blu";				//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"TIOW_IG_MissileLauncher_AA_776_Blu";
blufor_TURRET_AT =				"TIOW_IG_MissileLauncher_AT_776_Blu";
blufor_TURRET_HMG =				"TIOW_IG_Autocannon_776_Blu";
blufor_TURRET_GMG =				"TIOW_IG_HeavyBolter_776_Blu";



/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"TIOW_Cad_GM776th";					//operator
blufor_SPECOPS_GL_X =			"TIOW_Cad_GM_GrenadeLauncher_776th";				//operator
blufor_SPECOPS_LAT_X =			"TIOW_Cad_GM_Flamer_776th";				//operator
blufor_SPECOPS_HAT_X =			"TIOW_Cad_GM_Plasma_776th";		//operator
blufor_SPECOPS_AA_X =			"TIOW_Cad_GM_Melta_776th";				//operator
blufor_SPECOPS_MG_X =			"TIOW_Cad_Kasr776th";		//operator
blufor_SPECOPS_MEDIC_X =		"TIOW_Cad_Med776th";				//operator
blufor_SPECOPS_MARK_X =			"TIOW_Cad_SNIPER776th";					//operator
blufor_SPECOPS_SNIPER_X =		"TIOW_Cad_SNIPER776th";					//operator
blufor_SPECOPS_EXP_X =			"TIOW_Cad_GM_GrenadeLauncher_776th";				//operator
blufor_SPECOPS_ENG_X = 			"TIOW_Cad_GM_Vox_776th";			//operator





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
	["TIOW_Cad_GM776th","Shocktrooper (2CP)",2],
	["TIOW_Cad_VET776th","Veteran (3CP)",3],
	["TIOW_Cad_GM_Vox_776th","Vox Operator (3CP)",3],
	["TIOW_Cad_GM_Plasma_776th","Plasmagunner (4CP)",4],
	["TIOW_Cad_Med776th","Medic (4CP)",4],
	["TIOW_Cad_GM_Melta_776th","Meltagunner (4CP)",4],
	["TIOW_Cad_GM_GrenadeLauncher_776th","Grenade Launcher (4CP)",4],
	["TIOW_Cad_GM_Flamer_776th","Flamer (4CP)",4],
	["TIOW_Cad_Kasr776th","Kasrkin (4CP)",4],
	["TIOW_Cad_SNIPER776th","Sniper (3CP)",3],
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
	["TIOW_Centaur_01_Cadian_776_Blu","Centaur (1CP)",1],
	["C_Offroad_01_F","SF Offroader (2CP)",2],
	["I_G_Van_01_transport_F","Transport Truck (6CP)",6],
	["TIOW_CadianTrojan_776","Trojan(7CP)",7],
	["TIOW_CadianChimAuto_776","Chimera (18CP)",18],
	["TIOW_CadianWyvern_776","Wyvern (25CP)",25],
	["TIOW_CadianHydra_776","Hydra (25CP)",25],
	["B_Truck_01_transport_F","HEMTT Transport Uncovered (8CP)",8],
	["B_Truck_01_covered_F","HEMTT Transport Covered (8CP)",8],
	["B_Truck_01_Repair_F","HEMTT Repair (50CP)",50],
	["B_Truck_01_ammo_F","HEMTT Ammo (50CP)",50],
	["B_Truck_01_fuel_F","HEMTT Fuel (50CP)",50],
	["TIOW_Cad_LR_Battlecannon_776th_Blu","Leman Russ - Battlecannon (40CP)",40],
	["TIOW_Cad_LR_Conqueror_776th_Blu","Leman Russ - Conqueror (45CP)",45],
	["TIOW_Cad_LR_Demolisher_776th_Blu","Leman Russ - Demolisher (55CP)",55],
	["TIOW_Cad_LR_Executioner_776th_Blu","Leman Russ - Executioner (45CP)",45],
	["TIOW_Cad_LR_Exterminator_776th_Blu","Leman Russ - Exterminator (55CP)",55],
	["TIOW_Cad_LR_Punisher_776th_Blu","Leman Russ - Punisher (45CP)",45],
	["TIOW_Cad_LR_Vanquisher_776th_Blu","Leman Russ - Vanquisher (45CP)",40],
	["TIOW_Warhound_LP_PBG_BLU","Titan Warhound - Plasma (200CP)",200],
	["TIOW_Warhound_LP_TLD_BLU","Titan Warhound - Turbolaser (200CP)",200],
	["TIOW_Warhound_LP_VMB_BLU","Titan Warhound - Megabolter (200CP)",200],
	["TIOW_Valkyrie_Fuel_B","Valkyrie - Lascannon(40CP)",40],
	["TIOW_Valkyrie_Fuel_M_B","Valkyrie - Multilaser (45CP)",45],
	["TIOW_Valkyrie_Rocket_B","Valkyrie - Lascannon + Rockets (50CP)",50],
	["TIOW_Valkyrie_Rocket_M_B","Valkyrie - Multilaser + Rockets (50CP)",50],
	["TIOW_Thunderbolt_Base","Thunderbolt Heavy Figher (60CP",60]
];

