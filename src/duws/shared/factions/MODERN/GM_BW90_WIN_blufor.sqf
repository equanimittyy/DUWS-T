
///////////////
///////////////   "gm_fc_ge", "GM German Bundeswehr 90s (Winter) + USA (3CB)", "GM_BW90_WIN"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"gm_ge_army_rifleman_g36a1_90_win";				//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"gm_ge_army_antitank_g36a1_pzf3_90_win";		//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"gm_ge_army_grenadier_hk69a1_90_win";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"gm_ge_army_squadleader_g36a1_p2a1_90_win";		//init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"gm_ge_army_radioman_g36a1_90_win";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"gm_ge_army_machinegunner_mg3_90_win";			//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"gm_ge_army_marksman_g3a3_90_win";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"gm_ge_army_officer_p1_90_win";					//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"gm_ge_army_pilot_p1_80_oli";					//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"UK3CB_TKA_B_RHIB_Gunboat";						//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"gm_ge_army_rifleman_g36a1_90_win";				//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"UK3CB_CW_US_B_LATE_UH60M";						//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"gm_ge_army_ch53g_un";   						//random patrol
blufor_HELI_ATTACK_X =			"UK3CB_CW_US_B_LATE_AH64";						//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"UK3CB_CW_US_B_LATE_A10";						//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"gm_ge_army_fuchsa0_engineer_win";						//random patrol
blufor_APC_PATROL1_X =			"gm_ge_army_luchsa2_win";						//random patrol
blufor_APC_PATROL2_X =			"gm_ge_army_marder1a2_win";						//random patrol
blufor_TANK_PATROL1_X =			"gm_ge_army_Leopard1a5_win";					//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"UK3CB_CW_US_B_LATE_Stinger_AA_pod";
blufor_TURRET_AT =				"UK3CB_CW_US_B_LATE_TOW_TriPod";
blufor_TURRET_HMG =				"UK3CB_CW_US_B_LATE_M2_TriPod";
blufor_TURRET_GMG =				"UK3CB_CW_US_B_LATE_MK19_TriPod";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"gm_ge_army_rifleman_g36a1_90_win";					//operator
blufor_SPECOPS_GL_X =			"gm_ge_army_grenadier_hk69a1_90_win";				//operator
blufor_SPECOPS_LAT_X =			"gm_ge_army_antitank_g36a1_pzf3_90_win";			//operator
blufor_SPECOPS_HAT_X =			"gm_ge_army_antitank_g36a1_pzf3_90_win";			//operator
blufor_SPECOPS_AA_X =			"gm_ge_army_antiair_g36a1_fim43_90_win";			//operator
blufor_SPECOPS_MG_X =			"gm_ge_army_machinegunner_mg3_90_win";				//operator
blufor_SPECOPS_MEDIC_X =		"gm_ge_army_medic_g36a1_90_win";					//operator
blufor_SPECOPS_MARK_X =			"gm_ge_army_marksman_g3a3_90_win";					//operator
blufor_SPECOPS_SNIPER_X =		"gm_ge_army_marksman_g3a3_90_win";					//operator
blufor_SPECOPS_EXP_X =			"gm_ge_army_demolition_g36a1_90_win";				//operator
blufor_SPECOPS_ENG_X = 			"gm_ge_army_engineer_g36a1_90_win";					//operator





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
	["gm_ge_army_rifleman_g36a1_90_win","Rifleman (2CP)",2],
	["gm_ge_army_grenadier_hk69a1_90_win","Grenadier (GraPi) (3CP)",3],
	["gm_ge_army_machinegunner_mg3_90_win","Machinegunner (MG3) (3CP)",3],
	["gm_ge_army_demolition_g36a1_90_win","Explosive Specialist (4CP)",4],
	["gm_ge_army_medic_g36a1_90_win","Medic (4CP)",4],
	["gm_ge_army_antitank_g36a1_pzf3_90_win","AT Specialist (4CP)",4],
	["gm_ge_army_antiair_g36a1_fim43_90_win","AA Specialist (4CP)",4],
	["gm_ge_army_engineer_g36a1_90_win","Engineer (4CP)",4],
	["gm_ge_army_marksman_g3a3_90_win","Marksman (3CP)",3],
	["gm_ge_army_crew_90_flk","Crewman (2CP)",4],
	["gm_ge_army_antitank_g36a1_milan_90_win","Rifleman (Milan) (4CP)",4]
];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////

blufor_RQST_VEHICLES = [
	["gm_ge_army_k125","Krad K125 (1CP)",1],
	["gm_ge_army_iltis_cargo_win","Iltis (Unarmed) (2CP)",4],
	["gm_ge_army_iltis_mg3_win","Iltis (MG3) (6CP)",6],
	["gm_ge_army_iltis_milan_win","Iltis (AT) (8CP)",8],
	["gm_ge_army_u1300l_cargo_win","U1300 (Cargo) (8CP)",8],
	["gm_ge_army_u1300l_repair_win","U1300 (Repair) (50CP)",50],
	["gm_ge_army_u1300l_medic_win","U1300 Medic (50CP)",50],
	["gm_ge_army_kat1_451_cargo_win","KAT1 451 (Cargo) (10CP)",10],
	["gm_ge_army_kat1_451_reammo_win","KAT1 451 (Ammo) (50CP)",50],
	["gm_ge_army_kat1_451_refuel_win","KAT1 451 (Fuel) (50CP)",50],
	["gm_ge_army_fuchsa0_engineer_win","Fuchs (MG) (15CP)",15],
	["gm_ge_army_fuchsa0_reconnaissance_win","Fuchs (AT) (18CP)",18],
	["gm_ge_army_m113a1g_apc_win","M113 (MG) (15CP)",15],
	["gm_ge_army_m113a1g_apc_milan_win","M113 (AT) (18CP)",18],
	["gm_ge_army_marder1a2_win","Marder 1A2 (30CP)",30],
	["gm_ge_army_luchsa2_win","Luchs 2A1 (25CP)",25],
	["gm_ge_army_Leopard1a5_win","Leopard 1A5 (35CP)",35],
	["gm_ge_army_gepard1a1_win","Gepard 1A1 (30CP)",30],
	["gm_ge_army_ch53gs_un","CH53GS (20CP)",20],
	["gm_ge_army_bo105p_pah1a1","PAH 1A1 (20CP)",20],
	["gm_ge_army_bo105p1m_vbh_swooper","VBH Swooper (15CP)",15],
	["UK3CB_CW_US_B_LATE_UH1H_GUNSHIP","UH-1H Gunship (USA) (30CP)",30],
	["UK3CB_CW_US_B_LATE_AH64","AH64 (USA) (45CP)",45],
	["UK3CB_CW_US_B_LATE_UH60M","UH60M Armed (USA) (25CP)",25],
	["UK3CB_CW_US_B_LATE_A10","A10 (USA) (45CP)", 45],
	["UK3CB_CW_US_B_LATE_M109","M109 (USA) (50CP)",50]
];


