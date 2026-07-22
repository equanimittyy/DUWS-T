
///////////////
///////////////   "TIOW_REN_B", "Chaos Renegades (brown)", "TIOW_REN_B"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"TIOW_B_Ren_B_Rifleman";			//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"TIOW_B_Ren_B_AT";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"TIOW_B_Ren_B_Plasma";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"TIOW_B_Ren_B_Lead";	//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"TIOW_B_Ren_B_Vox";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"TIOW_B_Ren_B_LMG";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"TIOW_B_Ren_B_Rifleman";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"TIOW_B_Ren_B_Officer";					//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"TIOW_B_Ren_B_Crew";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"TIOW_B_Ren_B_Crew";		//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"Valkyrie_Possessed_B_B";		//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"Valkyrie_Possessed_B_B";   //random patrol
blufor_HELI_ATTACK_X =			"Valkyrie_Possessed_B_B";			//dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"Valkyrie_Possessed_B_B";				//dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"TIOW_Centaur_01_Renegade_B_Blu";				//random patrol
blufor_APC_PATROL1_X =			"TIOW_RenegadeTrojan_brown";	//random patrol
blufor_APC_PATROL2_X =			"_RenegadeChimAuto_brown";		//random patrol
blufor_TANK_PATROL1_X =			"TIOW_Renegade_LR_Battlecannon_brown_Blu";				//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"TIOW_IG_MissileLauncher_AA_Renbrown_Blu";
blufor_TURRET_AT =				"TIOW_IG_MissileLauncher_AT_Renbrown_Blu";
blufor_TURRET_HMG =				"TIOW_IG_Autocannon_Renbrown_Blu";
blufor_TURRET_GMG =				"TIOW_IG_HeavyBolter_Renbrown_Blu";



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


blufor_RQST_UNIT_01_X = 			["TIOW_B_Ren_B_Rifleman","Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				["TIOW_B_Ren_B_Lead","Enforcer (3CP)",3];
blufor_RQST_UNIT_03_X =				["TIOW_B_Ren_B_Vox","Vox Operator (3CP)",3];
blufor_RQST_UNIT_04_X =				["TIOW_B_Ren_B_Plasma","Plasmagunner (4CP)",4];
blufor_RQST_UNIT_05_X =				["TIOW_B_Ren_B_Medic","Medic (4CP)",4];
blufor_RQST_UNIT_06_X =				["TIOW_B_Ren_B_Melta","Meltagunner (4CP)",4];
blufor_RQST_UNIT_07_X =				["TIOW_B_Ren_B_Sapper","Sapper (4CP)",4];
blufor_RQST_UNIT_08_X =				["TIOW_B_Ren_B_Engineer","Engineer (4CP)",4];
blufor_RQST_UNIT_09_X =				["TIOW_B_Ren_B_LMG","Autorifleman (4CP)",4];
blufor_RQST_UNIT_10_X =				["TIOW_B_Ren_B_Officer","Officer (5CP)",5];
blufor_RQST_UNIT_11_X =				["TIOW_B_Ren_B_AT","AT Soldier (4CP)",4];
blufor_RQST_UNIT_12_X =				["empty",0,0];
blufor_RQST_UNIT_13_X =				["empty",0,0];
blufor_RQST_UNIT_14_X =				["empty",0,0];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////

blufor_RQST_VEHICLE_01_X =			["TIOW_Centaur_01_Renegade_B_Blu","Centaur (1CP)",1];
blufor_RQST_VEHICLE_02_X =			["C_Offroad_01_F","SF Offroader (2CP)",2];
blufor_RQST_VEHICLE_03_X =			["I_G_Van_01_transport_F","Transport Truck (6CP)",6];
blufor_RQST_VEHICLE_04_X =			["TIOW_RenegadeTrojan_brown","Trojan(7CP)",7];
blufor_RQST_VEHICLE_05_X =			["_RenegadeChimAuto_brown","Chimera (18CP)",18];
blufor_RQST_VEHICLE_06_X =			["TIOW_RenegadeWyvern_brown_Blu","Wyvern (25CP)",25];
blufor_RQST_VEHICLE_07_X =			["TIOW_RenegadeHydra_brown_Blu","Hydra (25CP)",25];
blufor_RQST_VEHICLE_08_X =			["B_Truck_01_transport_F","HEMTT Transport Uncovered (8CP)",8];
blufor_RQST_VEHICLE_09_X =			["B_Truck_01_covered_F","HEMTT Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_10_X =			["B_Truck_01_Repair_F","HEMTT Repair (50CP)",50];
blufor_RQST_VEHICLE_11_X =			["B_Truck_01_ammo_F","HEMTT Ammo (50CP)",50];
blufor_RQST_VEHICLE_12_X =			["B_Truck_01_fuel_F","HEMTT Fuel (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["B_Truck_01_ammo_F","HEMTT Ammo (50CP)",50];
blufor_RQST_VEHICLE_14_X =			["B_Truck_01_fuel_F","HEMTT Fuel (50CP)",50];
blufor_RQST_VEHICLE_15_X =			["TIOW_Renegade_LR_Annihilator_brown_Blu","Leman Russ - Annihilator (50CP)",50];
blufor_RQST_VEHICLE_16_X =			["TIOW_Renegade_LR_Battlecannon_brown_Blu","Leman Russ - Battlecannon (40CP)",40];
blufor_RQST_VEHICLE_17_X =			["TIOW_Renegade_LR_Conqueror_brown_Blu","Leman Russ - Conqueror (45CP)",45];
blufor_RQST_VEHICLE_18_X =			["TIOW_Renegade_LR_Demolisher_brown_Blu","Leman Russ - Demolisher (55CP)",55];
blufor_RQST_VEHICLE_19_X =			["TIOW_Renegade_LR_Executioner_brown_Blu","Leman Russ - Executioner (45CP)",45];
blufor_RQST_VEHICLE_20_X =			["TIOW_Renegade_LR_Exterminator_brown_Blu","Leman Russ - Exterminator (55CP)",55];
blufor_RQST_VEHICLE_21_X =			["TIOW_Renegade_LR_Punisher_brown_Blu","Leman Russ - Punisher (45CP)",45];
blufor_RQST_VEHICLE_22_X =			["TIOW_Renegade_LR_Vanquisher_brown_Blu","Leman Russ - Vanquisher (45CP)",40];
blufor_RQST_VEHICLE_23_X =			["Valkyrie_Possessed_B_B","Chaos Valkyrie (50CP)",50];
blufor_RQST_VEHICLE_24_X =			["TIOW_Warhound_MP_PBG_BLU_T","Titan Feral - Plasma Blastgun (200CP)",200];
blufor_RQST_VEHICLE_25_X =			["TIOW_Warhound_MP_TLD_BLU_T","Titan Feral - Turbo Laser (200CP)",200];
blufor_RQST_VEHICLE_26_X =			["TIOW_Warhound_MP_VMB_BLU_T","Titan Feral - Megabolter (200CP)",200];
blufor_RQST_VEHICLE_27_X =			["empty",0,0];
blufor_RQST_VEHICLE_28_X =			["empty",0,0];
blufor_RQST_VEHICLE_29_X =			["empty",0,0];
blufor_RQST_VEHICLE_30_X =			["empty",0,0];
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

