
///////////////
///////////////   "gm_fc_pl", "GM Poland 80s (Winter) + USSR (3CB)", "GM_Poland_WIN"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"gm_pl_army_rifleman_akm_80_win";			//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"gm_pl_army_antitank_akm_rpg7_80_win";		//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"gm_pl_army_grenadier_akm_pallad_80_win";	//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"gm_pl_army_squadleader_akm_80_win";		//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"gm_pl_army_radioman_akm_80_win";			//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"gm_pl_army_machinegunner_pk_80_win";		//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"gm_pl_army_marksman_svd_80_win";			//init_hq\fnc_HQguards
blufor_OFFICER_X =				"gm_pl_army_officer_pm_80_win";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"gm_pl_airforce_pilot_pm_80_gry";			//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"UK3CB_TKA_B_RHIB_Gunboat";					//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"gm_pl_army_rifleman_akm_80_win";			//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"UK3CB_CW_SOV_O_EARLY_Mi8";					//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"UK3CB_CW_SOV_O_EARLY_Mi8";   				//random patrol
blufor_HELI_ATTACK_X =			"UK3CB_CW_SOV_O_EARLY_Mi_24V";				//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"UK3CB_CW_SOV_O_EARLY_Su25SM";				//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"gm_pl_army_uaz469_dshkm";					//random patrol
blufor_APC_PATROL1_X =			"gm_pl_army_brdm2";							//random patrol
blufor_APC_PATROL2_X =			"gm_pl_army_ot64a";							//random patrol
blufor_TANK_PATROL1_X =			"gm_pl_army_t55ak";							//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"rhs_Igla_AA_pod_msv";
blufor_TURRET_AT =				"rhs_Kornet_9M133_2_msv";
blufor_TURRET_HMG =				"gm_pl_army_dshkm_aatripod";
blufor_TURRET_GMG =				"RHS_AGS30_TriPod_MSV";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"gm_pl_army_sf_rifleman_akmn_80_win";				//operator
blufor_SPECOPS_GL_X =			"gm_pl_army_sf_grenadier_akm_pallad_80_win";		//operator
blufor_SPECOPS_LAT_X =			"gm_pl_army_sf_antitank_akmn_rpg7_80_win";			//operator
blufor_SPECOPS_HAT_X =			"gm_pl_army_sf_antitank_akmn_rpg7_80_win";			//operator
blufor_SPECOPS_AA_X =			"gm_pl_army_sf_antiair_pm63_9k32m_80_win";			//operator
blufor_SPECOPS_MG_X =			"gm_pl_army_sf_machinegunner_rpk_80_win";			//operator
blufor_SPECOPS_MEDIC_X =		"gm_pl_army_medic_akm_80_win";						//operator
blufor_SPECOPS_MARK_X =			"gm_pl_army_sf_marksman_svd_80_win";				//operator
blufor_SPECOPS_SNIPER_X =		"gm_pl_army_sf_marksman_svd_80_win";				//operator
blufor_SPECOPS_EXP_X =			"gm_pl_army_sf_demolition_pm63_80_win";				//operator
blufor_SPECOPS_ENG_X = 			"gm_pl_army_sf_engineer_pm63_80_win";				//operator





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


blufor_RQST_UNIT_01_X = 			["gm_pl_army_rifleman_akm_80_win","Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				["gm_pl_army_grenadier_akm_pallad_80_win","Grenadier (3CP)",3];
blufor_RQST_UNIT_03_X =				["gm_pl_army_machinegunner_pk_80_win","Machinegunner (3CP)",3];
blufor_RQST_UNIT_04_X =				["gm_pl_army_demolition_akm_80_win","Explosive Specialist (4CP)",4];
blufor_RQST_UNIT_05_X =				["gm_pl_army_medic_akm_80_win","Medic (4CP)",4];
blufor_RQST_UNIT_06_X =				["gm_pl_army_antitank_akm_rpg7_80_win","AT Specialist (4CP)",4];
blufor_RQST_UNIT_07_X =				["gm_pl_army_antiair_akm_9k32m_80_win","AA Specialist (4CP)",4];
blufor_RQST_UNIT_08_X =				["gm_pl_army_engineer_akm_80_win","Engineer (4CP)",4];
blufor_RQST_UNIT_09_X =				["gm_pl_army_marksman_svd_80_win","Marksman (3CP)",3];
blufor_RQST_UNIT_10_X =				["gm_pl_army_crew_pm63_80_moro","Crewman (2CP)",4];
blufor_RQST_UNIT_11_X =				["gm_pl_army_antitank_akm_fagot_80_win","Rifleman (Fagot) (4CP)",4];
blufor_RQST_UNIT_12_X =				["empty",0,0];
blufor_RQST_UNIT_13_X =				["empty",0,0];
blufor_RQST_UNIT_14_X =				["empty",0,0];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////

blufor_RQST_VEHICLE_01_X =			["gm_pl_army_uaz469_cargo_win","UAZ469 (Unarmed) (4CP)",4];
blufor_RQST_VEHICLE_02_X =			["gm_pl_army_uaz469_dshkm_win","UAZ469 (DShKM) (6CP)",6];
blufor_RQST_VEHICLE_03_X =			["gm_pl_army_ural4320_cargo_win","URAL 4320 (Cargo) (10CP)",10];
blufor_RQST_VEHICLE_04_X =			["gm_pl_army_ural4320_repair_win","URAL 4320 (Repair) (50CP)",50];
blufor_RQST_VEHICLE_05_X =			["gm_pl_army_ural375d_medic_win","URAL 375D (Medic) (50CP)",50];
blufor_RQST_VEHICLE_06_X =			["gm_pl_army_ural4320_reammo_win","URAL 4320 (Ammo) (50CP)",50];
blufor_RQST_VEHICLE_07_X =			["gm_pl_army_ural375d_refuel_win","URAL 375D (Fuel) (50CP)",50];
blufor_RQST_VEHICLE_08_X =			["gm_pl_army_brdm2_win","BRDM2 (Armed) (20CP)",20];
blufor_RQST_VEHICLE_09_X =			["gm_pl_army_ot64a_win","OT64A (25CP)",25];
blufor_RQST_VEHICLE_10_X =			["gm_pl_army_bmp1sp2_win","BMP1 (30CP)",30];
blufor_RQST_VEHICLE_11_X =			["gm_pl_army_pt76b_win","PT76B (32CP)",32];
blufor_RQST_VEHICLE_12_X =			["gm_pl_army_t55ak_win","T55 (35CP)",35];
blufor_RQST_VEHICLE_13_X =			["gm_pl_army_zsu234v1_win","ZSU-23-4V1 (30CP)",30];
blufor_RQST_VEHICLE_14_X =			["gm_pl_airforce_mi2p","Mi-2P (Unarmed) (15CP)",15];
blufor_RQST_VEHICLE_15_X =			["UK3CB_CW_SOV_O_EARLY_Mi8AMT","Mi-8 (Unarmed) (USSR) (20CP)",20];
blufor_RQST_VEHICLE_16_X =			["gm_pl_airforce_mi2urn","Mi-2URN (Armed) (25CP)",25];
blufor_RQST_VEHICLE_17_X =			["gm_pl_airforce_mi2urpg","Mi-2URP-G (Armed) (30CP)",30];
blufor_RQST_VEHICLE_18_X =			["UK3CB_CW_SOV_O_EARLY_Mi_24V","Mi-24V (USSR) (45CP)",45];
blufor_RQST_VEHICLE_19_X =			["UK3CB_CW_SOV_O_EARLY_Su25SM","SU25SM (USSR) (45CP)",45];
blufor_RQST_VEHICLE_20_X =			["UK3CB_CW_SOV_O_EARLY_2S3","2S3 SPG (USSR) (50CP)",50];
blufor_RQST_VEHICLE_21_X =			["UK3CB_CW_SOV_O_EARLY_BM21","BM21 (USSR) (65CP)",65];
blufor_RQST_VEHICLE_22_X =			["empty",0,0];
blufor_RQST_VEHICLE_23_X =			["empty",0,0];
blufor_RQST_VEHICLE_24_X =			["empty",0,0];
blufor_RQST_VEHICLE_25_X =			["empty",0,0];
blufor_RQST_VEHICLE_26_X =			["empty",0,0];
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


