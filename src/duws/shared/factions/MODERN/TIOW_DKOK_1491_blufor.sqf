
///////////////
///////////////   "TIOW_DKOK_1491", "Death Korps of Krieg 1491st", "TIOW_DKOK_1491"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"DKoK_GM_1491st";			//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"DKoK_GM_1491st_Plasma";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"DKoK_Gren_1491st";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"DKoK_GM_WM_1491st";	//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"DKoK_QM_1491st";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"DKoK_GM_1491st_HStubber";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"DKoK_GM_1491st";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"DKoK_Off_1491st";					//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"DKoK_GM_1491st";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"DKoK_Eng_1491st";		//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"TIOW_Valkyrie_Fuel_B";		//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"TIOW_Valkyrie_Fuel_M_B";   //random patrol
blufor_HELI_ATTACK_X =			"TIOW_Valkyrie_Rocket_B";			//dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"TIOW_Valkyrie_Rocket_M_B";				//dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"TIOW_Centaur_01_Krieg_1491_Blu";				//random patrol
blufor_APC_PATROL1_X =			"TIOW_DKOKTrojan_1491";	//random patrol
blufor_APC_PATROL2_X =			"_1491stChimAuto";		//random patrol
blufor_TANK_PATROL1_X =			"TIOW_Krieg_LR_Battlecannon_1491st_Blu";				//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"TIOW_IG_MissileLauncher_AA_1491_Blu";
blufor_TURRET_AT =				"TIOW_IG_MissileLauncher_AT_1491_Blu";
blufor_TURRET_HMG =				"TIOW_IG_Autocannon_1491_Blu";
blufor_TURRET_GMG =				"TIOW_IG_HeavyBolter_1491_Blu";



/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"DKoK_GM_1491st";					//operator
blufor_SPECOPS_GL_X =			"DKoK_Gren_1491st";				//operator
blufor_SPECOPS_LAT_X =			"DKoK_GM_1491st_AT";				//operator
blufor_SPECOPS_HAT_X =			"DKoK_GM_1491st_Plasma";		//operator
blufor_SPECOPS_AA_X =			"DKoK_Gren_1491st_AT";				//operator
blufor_SPECOPS_MG_X =			"DKoK_GM_1491st_HStubber";		//operator
blufor_SPECOPS_MEDIC_X =		"TIOW_Priest";				//operator
blufor_SPECOPS_MARK_X =			"DKoK_GM_1491st";					//operator
blufor_SPECOPS_SNIPER_X =		"DKoK_GM_1491st";					//operator
blufor_SPECOPS_EXP_X =			"DKoK_Eng_1491st";				//operator
blufor_SPECOPS_ENG_X = 			"DKoK_Eng_1491st";			//operator





/////////////////////////////////////////////////////////////////
// REQUEST Units/Vehicles
//
// THESE HAVE FIXED AMOUNTS -fill the ends with ["empty",0,0];
//
// - Units = 				14
// - Vehicles/Statics = 	50
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


blufor_RQST_UNIT_01_X = 			["DKoK_GM_1491st","Guardsman (2CP)",2];
blufor_RQST_UNIT_02_X =				["DKoK_GM_1491st_HStubber","Heavy Stubber (3CP)",3];
blufor_RQST_UNIT_03_X =				["DKoK_GM_WM_1491st","Watchmaster (3CP)",3];
blufor_RQST_UNIT_04_X =				["DKoK_GM_1491st_Plasma","Plasmagunner (4CP)",4];
blufor_RQST_UNIT_05_X =				["DKoK_Gren_1491st_Plasma","Grenadier Plasmagunner (6CP)",6];
blufor_RQST_UNIT_06_X =				["DKoK_Gren_1491st","Grenadier (4CP)",4];
blufor_RQST_UNIT_07_X =				["DKoK_Eng_1491st","Engineer (4CP)",4];
blufor_RQST_UNIT_08_X =				["DKoK_Gren_1491st_AT","AT Grenadier (4CP)",4];
blufor_RQST_UNIT_09_X =				["DKoK_GM_1491st_AT","AT Guardsman (4CP)",4];
blufor_RQST_UNIT_10_X =				["DKoK_QM_1491st","Quartermaster (3CP)",3];
blufor_RQST_UNIT_11_X =				["TIOW_Comissar_Krieg","Comissar (4CP)",4];
blufor_RQST_UNIT_12_X =				["TIOW_Priest","Priest (4CP)",4];
blufor_RQST_UNIT_13_X =				["empty",0,0];
blufor_RQST_UNIT_14_X =				["empty",0,0];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////

blufor_RQST_VEHICLE_01_X =			["TIOW_Centaur_01_Krieg_1491_Blu","Centaur (1CP)",1];
blufor_RQST_VEHICLE_02_X =			["C_Offroad_01_F","SF Offroader (2CP)",2];
blufor_RQST_VEHICLE_03_X =			["I_G_Van_01_transport_F","Transport Truck (6CP)",6];
blufor_RQST_VEHICLE_04_X =			["TIOW_DKOKTrojan_1491","Trojan(7CP)",7];
blufor_RQST_VEHICLE_05_X =			["_1491stChimAuto","Chimera (18CP)",18];
blufor_RQST_VEHICLE_06_X =			["TIOW_KriegWyvern_1491st","Wyvern (25CP)",25];
blufor_RQST_VEHICLE_07_X =			["TIOW_KriegHydra_1491st","Hydra (25CP)",25];
blufor_RQST_VEHICLE_08_X =			["B_Truck_01_transport_F","HEMTT Transport Uncovered (8CP)",8];
blufor_RQST_VEHICLE_09_X =			["B_Truck_01_covered_F","HEMTT Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_10_X =			["B_Truck_01_Repair_F","HEMTT Repair (50CP)",50];
blufor_RQST_VEHICLE_11_X =			["B_Truck_01_ammo_F","HEMTT Ammo (50CP)",50];
blufor_RQST_VEHICLE_12_X =			["B_Truck_01_fuel_F","HEMTT Fuel (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["B_Truck_01_ammo_F","HEMTT Ammo (50CP)",50];
blufor_RQST_VEHICLE_14_X =			["B_Truck_01_fuel_F","HEMTT Fuel (50CP)",50];
blufor_RQST_VEHICLE_15_X =			["TIOW_Krieg_LR_Annihilator_1491st_Blu","Leman Russ - Annihilator (50CP)",50];
blufor_RQST_VEHICLE_16_X =			["TIOW_Krieg_LR_Battlecannon_1491st_Blu","Leman Russ - Battlecannon (40CP)",40];
blufor_RQST_VEHICLE_17_X =			["TIOW_Krieg_LR_Conqueror_1491st_Blu","Leman Russ - Conqueror (45CP)",45];
blufor_RQST_VEHICLE_18_X =			["TIOW_Krieg_LR_Demolisher_1491st_Blu","Leman Russ - Demolisher (55CP)",55];
blufor_RQST_VEHICLE_19_X =			["TIOW_Krieg_LR_Executioner_1491st_Blu","Leman Russ - Executioner (45CP)",45];
blufor_RQST_VEHICLE_20_X =			["TIOW_Krieg_LR_Exterminator_1491st_Blu","Leman Russ - Exterminator (55CP)",55];
blufor_RQST_VEHICLE_21_X =			["TIOW_Krieg_LR_Punisher_1491st_Blu","Leman Russ - Punisher (45CP)",45];
blufor_RQST_VEHICLE_22_X =			["TIOW_Krieg_LR_Vanquisher_1491st_Blu","Leman Russ - Vanquisher (45CP)",40];
blufor_RQST_VEHICLE_23_X =			["TIOW_Warhound_LP_PBG_BLU","Titan Warhound - Plasma (200CP)",200];
blufor_RQST_VEHICLE_24_X =			["TIOW_Warhound_LP_TLD_BLU","Titan Warhound - Turbolaser (200CP)",200];
blufor_RQST_VEHICLE_25_X =			["TIOW_Warhound_LP_VMB_BLU","Titan Warhound - Megabolter (200CP)",200];
blufor_RQST_VEHICLE_26_X =			["TIOW_Valkyrie_Fuel_B","Valkyrie - Lascannon(40CP)",40];
blufor_RQST_VEHICLE_27_X =			["TIOW_Valkyrie_Fuel_M_B","Valkyrie - Multilaser (45CP)",45];
blufor_RQST_VEHICLE_28_X =			["TIOW_Valkyrie_Rocket_B","Valkyrie - Lascannon + Rockets (50CP)",50];
blufor_RQST_VEHICLE_29_X =			["TIOW_Valkyrie_Rocket_M_B","Valkyrie - Multilaser + Rockets (50CP)",50];
blufor_RQST_VEHICLE_30_X =			["TIOW_Thunderbolt_Base","Thunderbolt Heavy Figher (60CP",60];
blufor_RQST_VEHICLE_31_X =			["empty",0,0];
blufor_RQST_VEHICLE_32_X =			["empty",0,0];
blufor_RQST_VEHICLE_33_X =			["empty",0,0];
blufor_RQST_VEHICLE_34_X =			["empty",0,0];
blufor_RQST_VEHICLE_35_X =			["empty",0,0];
blufor_RQST_VEHICLE_36_X =			["empty",0,0];
blufor_RQST_VEHICLE_37_X =			["empty",0,0];
blufor_RQST_VEHICLE_38_X =			["empty",0,0];
blufor_RQST_VEHICLE_39_X =			["empty",0,0];
blufor_RQST_VEHICLE_40_X =			["empty",0,0];
blufor_RQST_VEHICLE_41_X =			["empty",0,0];
blufor_RQST_VEHICLE_42_X =			["empty",0,0];
blufor_RQST_VEHICLE_43_X =			["empty",0,0];
blufor_RQST_VEHICLE_44_X =			["empty",0,0];
blufor_RQST_VEHICLE_45_X =			["empty",0,0];
blufor_RQST_VEHICLE_46_X =			["empty",0,0];
blufor_RQST_VEHICLE_47_X =			["empty",0,0];
blufor_RQST_VEHICLE_48_X =			["empty",0,0];
blufor_RQST_VEHICLE_49_X =			["empty",0,0];
blufor_RQST_VEHICLE_50_X =			["empty",0,0];

