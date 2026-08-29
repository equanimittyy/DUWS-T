
///////////////   "gm_fc_ge", "GM German Bundeswehr 80s (Winter) + USA (3CB)", "GM_BW80_WIN"


blufor_SOLDIER_X =				"gm_ge_army_rifleman_g3a3_parka_80_win";			//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"gm_ge_army_antitank_g3a3_pzf84_parka_80_win";		//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"gm_ge_army_grenadier_g3a3_parka_80_win";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"gm_ge_army_squadleader_g3a3_p2a1_parka_80_win";	//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"gm_ge_army_radioman_g3a3_parka_80_win";			//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"gm_ge_army_machinegunner_mg3_parka_80_win";		//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"gm_ge_army_marksman_g3a3_parka_80_win";			//init_hq\fnc_HQguards
blufor_OFFICER_X =				"gm_ge_army_officer_p1_parka_80_win";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"gm_ge_army_pilot_p1_80_oli";						//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"UK3CB_TKA_B_RHIB_Gunboat";							//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"gm_ge_army_rifleman_g3a3_parka_80_win";			//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"gm_ge_army_ch53g";									//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"UK3CB_CW_US_B_EARLY_UH1H_GUNSHIP";   				//random patrol
blufor_ATTACK_HELI_X =			"UK3CB_CW_US_B_EARLY_AH1Z";							//dialog\fnc_request_hcATTchop, random patrol
blufor_MISC_AIR_X =				"UK3CB_CW_US_B_EARLY_A10";							//dialog\fnc_request_hcCAS, random patrol
blufor_ARMED_CAR1_X =			"gm_ge_army_fuchsa0_engineer";						//random patrol
blufor_APC1_X =					"gm_ge_army_luchsa1";								//random patrol
blufor_APC2_X =					"gm_ge_army_marder1a1a";							//random patrol
blufor_MBT_TANK1_X =			"gm_ge_army_Leopard1a1";							//random patrol



blufor_TURRET_AA = 				"UK3CB_CW_US_B_LATE_Stinger_AA_pod";
blufor_TURRET_AT =				"UK3CB_CW_US_B_LATE_TOW_TriPod";
blufor_TURRET_HMG =				"UK3CB_CW_US_B_LATE_M2_TriPod";
blufor_TURRET_GMG =				"UK3CB_CW_US_B_LATE_MK19_TriPod";



blufor_SPECOPS_X =				"gm_ge_army_sf_rifleman_g3a4_parka_80_win";					//operator
blufor_SPECOPS_GL_X =			"gm_ge_army_sf_grenadier_hk69a1_parka_80_win";				//operator
blufor_SPECOPS_LAT_X =			"gm_ge_army_sf_antitank_mp5a2_pzf84_parka_80_win";			//operator
blufor_SPECOPS_HAT_X =			"gm_ge_army_sf_antitank_mp5a2_pzf84_parka_80_win";			//operator
blufor_SPECOPS_AA_X =			"gm_ge_army_sf_antiair_mp5a3_fim43_parka_80_win";			//operator
blufor_SPECOPS_MG_X =			"gm_ge_army_machinegunner_mg3_parka_80_win";				//operator
blufor_SPECOPS_MEDIC_X =		"gm_ge_army_medic_g3a3_parka_80_win";						//operator
blufor_SPECOPS_MARK_X =			"gm_ge_army_sf_marksman_g3a3_parka_80_win";					//operator
blufor_SPECOPS_SNIPER_X =		"gm_ge_army_sf_marksman_g3a3_parka_80_win";					//operator
blufor_SPECOPS_EXP_X =			"gm_ge_army_sf_demolition_mp5a2_parka_80_win";				//operator
blufor_SPECOPS_ENG_X = 			"gm_ge_army_engineer_g3a4_parka_80_win";					//operator





// REQUEST Units/Vehicles
// Ordered lists, no padding and no fixed length: the menus offer every entry in the order
// written here, so position in the list is the display order. A faction may list as many
// or as few as it has.

// REQUEST MENU defines labels/index for all request menu units/vehicles (not Operators)

// request_vehicle, request_vehicle_fob, request_unit, request_unit_fob 
// - these files contain the classnames referenced by the label/index


// dialog\fnc_request_unit
//   _index = lbCurSel 2100;
// dialog\fnc_request_unit_fob
//   _index = lbCurSel 2120;


blufor_RQST_UNITS = [
	["gm_ge_army_rifleman_g3a3_parka_80_win","Rifleman (2CP)",2],
	["gm_ge_army_grenadier_g3a3_parka_80_win","Grenadier (GraPi) (3CP)",3],
	["gm_ge_army_machinegunner_mg3_parka_80_win","Machinegunner (MG3) (3CP)",3],
	["gm_ge_army_demolition_g3a4_parka_80_win","Explosive Specialist (4CP)",4],
	["gm_ge_army_medic_g3a3_parka_80_win","Medic (4CP)",4],
	["gm_ge_army_antitank_g3a3_pzf84_parka_80_win","AT Specialist (4CP)",4],
	["gm_ge_army_antiair_g3a3_fim43_parka_80_win","AA Specialist (4CP)",4],
	["gm_ge_army_engineer_g3a4_parka_80_win","Engineer (4CP)",4],
	["gm_ge_army_marksman_g3a3_parka_80_win","Marksman (3CP)",3],
	["gm_ge_army_crew_mp2a1_80_oli","Crewman (2CP)",4],
	["gm_ge_army_antitank_g3a3_milan_parka_80_win","Rifleman (Milan) (4CP)",4]
];


// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;

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
	["gm_ge_army_marder1a1plus_win","Marder 1A1 (30CP)",30],
	["gm_ge_army_luchsa1_win","Luchs 2A1 (25CP)",25],
	["gm_ge_army_Leopard1a1_win","Leopard 1A1 (35CP)",35],
	["gm_ge_army_gepard1a1_win","Gepard 1A1 (30CP)",30],
	["gm_ge_army_ch53gs_un","CH53GS (20CP)",20],
	["gm_ge_army_bo105p_pah1a1","PAH 1A1 (20CP)",20],
	["gm_ge_army_bo105p1m_vbh_swooper","VBH Swooper (15CP)",15],
	["UK3CB_CW_US_B_EARLY_UH1H_GUNSHIP","UH-1H Gunship (USA) (30CP)",30],
	["UK3CB_CW_US_B_EARLY_AH1Z","AH1Z (USA) (45CP)",45],
	["UK3CB_CW_US_B_EARLY_UH1H_M240","UH-1H Armed (USA) (25CP)",25],
	["UK3CB_CW_US_B_EARLY_A10","A10 (USA) (45CP)", 45],
	["UK3CB_CW_US_B_EARLY_M109","M109 (USA) (50CP)",50]
];


