
///////////////
///////////////   "CFP_B_YPG", "CFP YPG (Kurds) + USAF Support", "CFP_B_YPG"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"cfp_b_ypg_rifleman";				//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"cfp_b_ypg_at";						//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"cfp_b_ypg_grenadier";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"cfp_b_ypg_machinegunner";			//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"cfp_b_ypg_rifleman_dshkm";			//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"cfp_b_ypg_asst_gunner_dshkm";		//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"cfp_b_ypg_sniper";					//init_hq\fnc_HQguards
blufor_OFFICER_X =				"cfp_b_ypg_leader";					//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CUP_B_US_Pilot";					//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";	//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";				//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CFP_B_USARMY_2003_UH_60M_DES_01";		//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"CFP_B_USARMY_2003_UH_60M_MEV_WDL_01";  //random patrol
blufor_HELI_ATTACK_X =			"CFP_B_USARMY_2003_AH_64D_DES_01";		//dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"CUP_B_A10_DYN_USA";					//dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"CFP_B_YPG_Hilux_ZU_23_01";				//random patrol
blufor_APC_PATROL1_X =			"CFP_B_YPG_Hilux_DSHKM_01";				//random patrol
blufor_APC_PATROL2_X =			"CFP_B_YPG_Hilux_DSHKM_01";				//random patrol
blufor_TANK_PATROL1_X =			"CFP_B_YPG_Hilux_DSHKM_01";				//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"CFP_B_USARMY_2003_M2_Machine_Gun_DES_01";
blufor_TURRET_AT =				"CFP_B_USARMY_2003_TOW_Tripod_DES_01";
blufor_TURRET_HMG =				"CFP_B_USARMY_2003_M2_Machine_Gun_DES_01";
blufor_TURRET_GMG =				"CFP_B_USARMY_2003_M2_Machine_Gun_DES_01";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"cfp_b_ypg_rifleman";			//operator
blufor_SPECOPS_GL_X =			"cfp_b_ypg_grenadier";			//operator
blufor_SPECOPS_LAT_X =			"cfp_b_ypg_at";					//operator
blufor_SPECOPS_HAT_X =			"cfp_b_ypg_at";					//operator
blufor_SPECOPS_AA_X =			"CUP_B_US_Soldier_AA";			//operator
blufor_SPECOPS_MG_X =			"cfp_b_ypg_machinegunner";		//operator
blufor_SPECOPS_MEDIC_X =		"cfp_b_ypg_medic";				//operator
blufor_SPECOPS_MARK_X =			"cfp_b_ypg_sniper";				//operator
blufor_SPECOPS_SNIPER_X =		"cfp_b_ypg_sniper";				//operator
blufor_SPECOPS_EXP_X =			"cfp_b_ypg_grenadier";			//operator
blufor_SPECOPS_ENG_X = 			"cfp_b_ypg_crewman";			//operator





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
	["cfp_b_ypg_rifleman","Rifleman (2CP)",2],
	["cfp_b_ypg_grenadier","Grenadier (3CP)",3],
	["cfp_b_ypg_rifleman_dshkm","Rifleman (DSHKM) (3CP)",3],
	["cfp_b_ypg_asst_gunner_dshkm","Assistant Rifleman (DSHKM) (3CP)",4],
	["cfp_b_ypg_medic","Medic (4CP)",4],
	["cfp_b_ypg_at","AT Rifleman (3CP)",3],
	["cfp_b_ypg_machinegunner","Machinegunner (4CP)",4],
	["cfp_b_ypg_sniper","Sniper (4CP)",4]
];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////   

blufor_RQST_VEHICLES = [
	["CFP_B_YPG_Hilux_DSHKM_01","Hilux (DSHKM) (3CP)",3],
	["CFP_B_YPG_Hilux_ZU_23_01","Hilux (ZU23) (10CP)",10],
	["cfp_b_ypg_offroad_flag","Offroad (Unarmed) (1CP)",1],
	["cfp_b_ypg_offroad_M2_flag","Offroad (MG) (3CP)",3],
	["CUP_O_Ural_Open_SLA","URAL Transport (10CP)",10],
	["CUP_B_HMMWV_M2_GPK_USA","HMMWV HMG (18CP)",18],
	["CFP_B_USARMY_2003_UH_60M_MEV_WDL_01","USAF UH-60 Medical (Unarmed) (20CP)",20],
	["CFP_B_USARMY_2003_UH_60M_DES_01","USAF UH-60M (Armed) (25CP)",25],
	["CFP_B_USARMY_2003_AH_64D_DES_01","USAF AH-64D (35CP)",35],
	["CUP_B_A10_DYN_USA","USAF A10 (40CP)",40],
	["CUP_B_AV8B_DYN_USMC","AV-8B Harrier (50CP)",50]
];


