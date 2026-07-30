
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
blufor_SOLDIER_TL_X =			"gm_pl_army_squadleader_akm_80_win";		//init_hq\fnc_HQguards
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
	["gm_pl_army_rifleman_akm_80_win","Rifleman (2CP)",2],
	["gm_pl_army_grenadier_akm_pallad_80_win","Grenadier (3CP)",3],
	["gm_pl_army_machinegunner_pk_80_win","Machinegunner (3CP)",3],
	["gm_pl_army_demolition_akm_80_win","Explosive Specialist (4CP)",4],
	["gm_pl_army_medic_akm_80_win","Medic (4CP)",4],
	["gm_pl_army_antitank_akm_rpg7_80_win","AT Specialist (4CP)",4],
	["gm_pl_army_antiair_akm_9k32m_80_win","AA Specialist (4CP)",4],
	["gm_pl_army_engineer_akm_80_win","Engineer (4CP)",4],
	["gm_pl_army_marksman_svd_80_win","Marksman (3CP)",3],
	["gm_pl_army_crew_pm63_80_moro","Crewman (2CP)",4],
	["gm_pl_army_antitank_akm_fagot_80_win","Rifleman (Fagot) (4CP)",4]
];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////

blufor_RQST_VEHICLES = [
	["gm_pl_army_uaz469_cargo_win","UAZ469 (Unarmed) (4CP)",4],
	["gm_pl_army_uaz469_dshkm_win","UAZ469 (DShKM) (6CP)",6],
	["gm_pl_army_ural4320_cargo_win","URAL 4320 (Cargo) (10CP)",10],
	["gm_pl_army_ural4320_repair_win","URAL 4320 (Repair) (50CP)",50],
	["gm_pl_army_ural375d_medic_win","URAL 375D (Medic) (50CP)",50],
	["gm_pl_army_ural4320_reammo_win","URAL 4320 (Ammo) (50CP)",50],
	["gm_pl_army_ural375d_refuel_win","URAL 375D (Fuel) (50CP)",50],
	["gm_pl_army_brdm2_win","BRDM2 (Armed) (20CP)",20],
	["gm_pl_army_ot64a_win","OT64A (25CP)",25],
	["gm_pl_army_bmp1sp2_win","BMP1 (30CP)",30],
	["gm_pl_army_pt76b_win","PT76B (32CP)",32],
	["gm_pl_army_t55ak_win","T55 (35CP)",35],
	["gm_pl_army_zsu234v1_win","ZSU-23-4V1 (30CP)",30],
	["gm_pl_airforce_mi2p","Mi-2P (Unarmed) (15CP)",15],
	["UK3CB_CW_SOV_O_EARLY_Mi8AMT","Mi-8 (Unarmed) (USSR) (20CP)",20],
	["gm_pl_airforce_mi2urn","Mi-2URN (Armed) (25CP)",25],
	["gm_pl_airforce_mi2urpg","Mi-2URP-G (Armed) (30CP)",30],
	["UK3CB_CW_SOV_O_EARLY_Mi_24V","Mi-24V (USSR) (45CP)",45],
	["UK3CB_CW_SOV_O_EARLY_Su25SM","SU25SM (USSR) (45CP)",45],
	["UK3CB_CW_SOV_O_EARLY_2S3","2S3 SPG (USSR) (50CP)",50],
	["UK3CB_CW_SOV_O_EARLY_BM21","BM21 (USSR) (65CP)",65]
];


