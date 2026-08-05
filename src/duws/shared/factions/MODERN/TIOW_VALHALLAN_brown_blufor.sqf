
///////////////
///////////////   "TIOW_VALHALLAN_brown", "Valhallans (brown)", "TIOW_VALHALLAN_brown"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"TIOW_Valhallan_Trooper_1_brown_Blu";			//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"TIOW_Valhallan_Plasmagunner_1_brown_Blu";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"TIOW_Valhallan_Meltagunner_1_brown_Blu";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"TIOW_Valhallan_NCO_1_brown_Blu";	//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"TIOW_Valhallan_NCO_1_brown_Blu";				//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"TIOW_Valhallan_Stubber_2_brown_Blu";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"TIOW_Valhallan_Trooper_2_brown_Blu";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"TIOW_Comissar_Brown";					//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"TIOW_Valhallan_Tanker_1_brown_Blu";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"DKoK_Eng_82th";		//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"TIOW_Valkyrie_Fuel_B";		//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"TIOW_Valkyrie_Fuel_M_B";   //random patrol
blufor_ATTACK_HELI_X =			"TIOW_Valkyrie_Rocket_B";			//dialog\fnc_request_hcATTchop
blufor_MISC_AIR_X =				"TIOW_Valkyrie_Rocket_M_B";				//dialog\fnc_request_hcCAS
blufor_ARMED_CAR1_X =			"TIOW_Centaur_01_Valhallan_Brown_Blu";				//random patrol
blufor_APC1_X =					"TIOW_ValhallanTrojan_Brown";	//random patrol
blufor_APC2_X =					"TIOW_ValhallanChimAuto_Brown";		//random patrol
blufor_MBT_TANK1_X =			"TIOW_Valhallan_LR_Battlecannon_Brown_Blu";				//random patrol


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

blufor_SPECOPS_X =				"TIOW_Valhallan_Trooper_1_brown_Blu";					//operator
blufor_SPECOPS_GL_X =			"TIOW_Valhallan_Meltagunner_1_brown_Blu";				//operator
blufor_SPECOPS_LAT_X =			"TIOW_Valhallan_Plasmagunner_1_brown_Blu";				//operator
blufor_SPECOPS_HAT_X =			"TIOW_Valhallan_Launcher_1_brown_Blu";		//operator
blufor_SPECOPS_AA_X =			"TIOW_Valhallan_Plasmagunner_1_brown_Blu";				//operator
blufor_SPECOPS_MG_X =			"TIOW_Valhallan_Stubber_2_brown_Blu";		//operator
blufor_SPECOPS_MEDIC_X =		"TIOW_Priest";				//operator
blufor_SPECOPS_MARK_X =			"TIOW_Valhallan_Trooper_2_brown_Blu";					//operator
blufor_SPECOPS_SNIPER_X =		"TIOW_Valhallan_Trooper_2_brown_Blu";					//operator
blufor_SPECOPS_EXP_X =			"TIOW_Valhallan_Trooper_1_brown_Blu";				//operator
blufor_SPECOPS_ENG_X = 			"TIOW_Valhallan_Tanker_1_brown_Blu";			//operator





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
	["TIOW_Valhallan_Trooper_1_brown_Blu","Trooper (2CP)",2],
	["TIOW_Valhallan_Trooper_2_brown_Blu","Heavy Stubber (3CP)",3],
	["TIOW_Valhallan_NCO_1_brown_Blu","Trooper NCO (3CP)",3],
	["TIOW_Valhallan_Plasmagunner_1_brown_Blu","Plasmagunner (4CP)",4],
	["TIOW_Valhallan_Meltagunner_1_brown_Blu","Meltagunner (6CP)",6],
	["TIOW_Valhallan_Launcher_1_brown_Blu","Missile Launcher Trooper (6CP)",6],
	["TIOW_Comissar_Brown","Comissar (4CP)",4],
	["TIOW_Priest","Priest (4CP)",4]
];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////

blufor_RQST_VEHICLES = [
	["TIOW_Centaur_01_Valhallan_Brown_Blu","Centaur (1CP)",1],
	["C_Offroad_01_F","SF Offroader (2CP)",2],
	["I_G_Van_01_transport_F","Transport Truck (6CP)",6],
	["TIOW_ValhallanTrojan_Brown","Trojan(7CP)",7],
	["TIOW_ValhallanChimAuto_Brown","Chimera (18CP)",18],
	["TIOW_ValhallanWyvern_Brown","Wyvern (25CP)",25],
	["TIOW_ValhallanHydra_Brown","Hydra (25CP)",25],
	["O_Truck_03_transport_F","Tempest Transport Uncovered (8CP)",8],
	["O_Truck_03_covered_F","Tempest Transport Covered (8CP)",8],
	["O_Truck_02_box_F","Zamak Repair (50CP)",50],
	["O_Truck_02_Ammo_F","Zamak Ammo (50CP)",50],
	["O_Truck_02_fuel_F","Zamak Fuel (50CP)",50],
	["TIOW_Valhallan_LR_Annihilator_Brown_Blu","Leman Russ - Annihilator (50CP)",50],
	["TIOW_Valhallan_LR_Battlecannon_Brown_Blu","Leman Russ - Battlecannon (40CP)",40],
	["TIOW_Valhallan_LR_Conqueror_Brown_Blu","Leman Russ - Conqueror (45CP)",45],
	["TIOW_Valhallan_LR_Demolisher_Brown_Blu","Leman Russ - Demolisher (55CP)",55],
	["TIOW_Valhallan_LR_Executioner_Brown_Blu","Leman Russ - Executioner (45CP)",45],
	["TIOW_Valhallan_LR_Exterminator_Brown_Blu","Leman Russ - Exterminator (55CP)",55],
	["TIOW_Valhallan_LR_Punisher_Brown_Blu","Leman Russ - Punisher (45CP)",45],
	["TIOW_Valhallan_LR_Vanquisher_Brown_Blu","Leman Russ - Vanquisher (45CP)",40],
	["TIOW_Warhound_LP_PBG_BLU","Titan Warhound - Plasma (200CP)",200],
	["TIOW_Warhound_LP_TLD_BLU","Titan Warhound - Turbolaser (200CP)",200],
	["TIOW_Warhound_LP_VMB_BLU","Titan Warhound - Megabolter (200CP)",200],
	["TIOW_Valkyrie_Fuel_B","Valkyrie - Lascannon(40CP)",40],
	["TIOW_Valkyrie_Fuel_M_B","Valkyrie - Multilaser (45CP)",45],
	["TIOW_Valkyrie_Rocket_B","Valkyrie - Lascannon + Rockets (50CP)",50],
	["TIOW_Valkyrie_Rocket_M_B","Valkyrie - Multilaser + Rockets (50CP)",50],
	["TIOW_Thunderbolt_Base","Thunderbolt Heavy Figher (60CP",60]
];

