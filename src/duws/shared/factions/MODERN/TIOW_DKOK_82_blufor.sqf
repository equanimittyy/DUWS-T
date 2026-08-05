
///////////////
///////////////   "TIOW_DKOK_82", "Death Korps of Krieg 82nd", "TIOW_DKOK_82"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"DKoK_GM_82nd";			//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"DKoK_GM_82nd_Plasma";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"DKoK_Gren_82nd";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"DKoK_GM_WM_82nd";	//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"DKoK_QM_82nd";				//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"DKoK_GM_82nd_HStubber";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"DKoK_GM_82nd";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"DKoK_Off_82nd";					//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"DKoK_GM_82nd";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"DKoK_Eng_82nd";		//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"TIOW_Valkyrie_Fuel_B";		//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"TIOW_Valkyrie_Fuel_M_B";   //random patrol
blufor_ATTACK_HELI_X =			"TIOW_Valkyrie_Rocket_B";			//dialog\fnc_request_hcATTchop
blufor_MISC_AIR_X =				"TIOW_Valkyrie_Rocket_M_B";				//dialog\fnc_request_hcCAS
blufor_ARMED_CAR1_X =			"TIOW_Centaur_01_Krieg_82_Blu";				//random patrol
blufor_APC1_X =					"TIOW_DKOKTrojan_82";	//random patrol
blufor_APC2_X =					"_82ndChimAuto";		//random patrol
blufor_MBT_TANK1_X =			"TIOW_Krieg_LR_Battlecannon_82nd_Blu";				//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"TIOW_IG_MissileLauncher_AA_82_Blu";
blufor_TURRET_AT =				"TIOW_IG_MissileLauncher_AT_82_Blu";
blufor_TURRET_HMG =				"TIOW_IG_Autocannon_82_Blu";
blufor_TURRET_GMG =				"TIOW_IG_HeavyBolter_82_Blu";



/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"DKoK_GM_82nd";					//operator
blufor_SPECOPS_GL_X =			"DKoK_Gren_82nd";				//operator
blufor_SPECOPS_LAT_X =			"DKoK_GM_82nd_AT";				//operator
blufor_SPECOPS_HAT_X =			"DKoK_GM_82nd_Plasma";		//operator
blufor_SPECOPS_AA_X =			"DKoK_Gren_82nd_AT";				//operator
blufor_SPECOPS_MG_X =			"DKoK_GM_82nd_HStubber";		//operator
blufor_SPECOPS_MEDIC_X =		"TIOW_Priest";				//operator
blufor_SPECOPS_MARK_X =			"DKoK_GM_82nd";					//operator
blufor_SPECOPS_SNIPER_X =		"DKoK_GM_82nd";					//operator
blufor_SPECOPS_EXP_X =			"DKoK_Eng_82nd";				//operator
blufor_SPECOPS_ENG_X = 			"DKoK_Eng_82nd";			//operator





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
	["DKoK_GM_82nd","Guardsman (2CP)",2],
	["DKoK_GM_82nd_HStubber","Heavy Stubber (3CP)",3],
	["DKoK_GM_WM_82nd","Watchmaster (3CP)",3],
	["DKoK_GM_82nd_Plasma","Plasmagunner (4CP)",4],
	["DKoK_Gren_82nd_Plasma","Grenadier Plasmagunner (6CP)",6],
	["DKoK_Gren_82nd","Grenadier (4CP)",4],
	["DKoK_Eng_82nd","Engineer (4CP)",4],
	["DKoK_Gren_82nd_AT","AT Grenadier (4CP)",4],
	["DKoK_GM_82nd_AT","AT Guardsman (4CP)",4],
	["DKoK_QM_82nd","Quartermaster (3CP)",3],
	["TIOW_Comissar_Krieg","Comissar (4CP)",4],
	["TIOW_Priest","Priest (4CP)",4]
];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////

blufor_RQST_VEHICLES = [
	["TIOW_Centaur_01_Krieg_82_Blu","Centaur (1CP)",1],
	["C_Offroad_01_F","SF Offroader (2CP)",2],
	["I_G_Van_01_transport_F","Transport Truck (6CP)",6],
	["TIOW_DKOKTrojan_82","Trojan(7CP)",7],
	["_82ndChimAuto","Chimera (18CP)",18],
	["TIOW_KriegWyvern_82nd","Wyvern (25CP)",25],
	["TIOW_KriegHydra_82nd","Hydra (25CP)",25],
	["B_Truck_01_transport_F","HEMTT Transport Uncovered (8CP)",8],
	["B_Truck_01_covered_F","HEMTT Transport Covered (8CP)",8],
	["B_Truck_01_Repair_F","HEMTT Repair (50CP)",50],
	["B_Truck_01_ammo_F","HEMTT Ammo (50CP)",50],
	["B_Truck_01_fuel_F","HEMTT Fuel (50CP)",50],
	["B_Truck_01_ammo_F","HEMTT Ammo (50CP)",50],
	["B_Truck_01_fuel_F","HEMTT Fuel (50CP)",50],
	["TIOW_Krieg_LR_Annihilator_82nd_Blu","Leman Russ - Annihilator (50CP)",50],
	["TIOW_Krieg_LR_Battlecannon_82nd_Blu","Leman Russ - Battlecannon (40CP)",40],
	["TIOW_Krieg_LR_Conqueror_82nd_Blu","Leman Russ - Conqueror (45CP)",45],
	["TIOW_Krieg_LR_Demolisher_82nd_Blu","Leman Russ - Demolisher (55CP)",55],
	["TIOW_Krieg_LR_Executioner_82nd_Blu","Leman Russ - Executioner (45CP)",45],
	["TIOW_Krieg_LR_Exterminator_82nd_Blu","Leman Russ - Exterminator (55CP)",55],
	["TIOW_Krieg_LR_Punisher_82nd_Blu","Leman Russ - Punisher (45CP)",45],
	["TIOW_Krieg_LR_Vanquisher_82nd_Blu","Leman Russ - Vanquisher (45CP)",40],
	["TIOW_Warhound_LP_PBG_BLU","Titan Warhound - Plasma (200CP)",200],
	["TIOW_Warhound_LP_TLD_BLU","Titan Warhound - Turbolaser (200CP)",200],
	["TIOW_Warhound_LP_VMB_BLU","Titan Warhound - Megabolter (200CP)",200],
	["TIOW_Valkyrie_Fuel_B","Valkyrie - Lascannon(40CP)",40],
	["TIOW_Valkyrie_Fuel_M_B","Valkyrie - Multilaser (45CP)",45],
	["TIOW_Valkyrie_Rocket_B","Valkyrie - Lascannon + Rockets (50CP)",50],
	["TIOW_Valkyrie_Rocket_M_B","Valkyrie - Multilaser + Rockets (50CP)",50],
	["TIOW_Thunderbolt_Base","Thunderbolt Heavy Figher (60CP",60]
];

