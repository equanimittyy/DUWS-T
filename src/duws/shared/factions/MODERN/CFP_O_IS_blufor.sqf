
///////////////
///////////////   "CFP_O_IS", "CFP Middle East Insurgents", "CFP_O_IS"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"CFP_O_ALQAEDA_Rifleman_01";		//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"cfp_i_alNusra_at";					//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"cfp_o_is_grenadier";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"cfp_o_is_team_leader";				//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"cfp_o_is_squad_leader";			//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"cfp_i_alNusra_machinegunner";		//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"cfp_i_alNusra_sniper";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"CUP_O_TK_SpecOps_TL";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CUP_O_TK_Pilot";					//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CUP_I_UH1H_TK_GUE";				//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"CUP_I_UH1H_TK_GUE";   				//random patrol
blufor_ATTACK_HELI_X =			"CUP_I_UH1H_gunship_TK_GUE";		//dialog\fnc_request_hcATTchop, random patrol
blufor_MISC_AIR_X =				"CUP_I_UH1H_gunship_TK_GUE";		//dialog\fnc_request_hcCAS, random patrol
blufor_ARMED_CAR1_X =			"cfp_o_is_offroad_M2";				//random patrol
blufor_APC1_X =					"cfp_o_is_M113";					//random patrol
blufor_APC2_X =					"cfp_o_is_BMP2_PKM";				//random patrol
blufor_MBT_TANK1_X =			"cfp_i_alNusra_T55";				//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"CUP_O_ZU23_TK";			// also "CUP_O_Igla_AA_pod_RU"
blufor_TURRET_AT =				"CUP_O_Kornet_RU";
blufor_TURRET_HMG =				"CUP_O_DSHKM_SLA";
blufor_TURRET_GMG =				"CUP_O_DSHKM_SLA";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"CFP_O_ALQAEDA_Rifleman_01";			//operator
blufor_SPECOPS_GL_X =			"cfp_o_is_grenadier";					//operator
blufor_SPECOPS_LAT_X =			"cfp_i_alNusra_at";						//operator
blufor_SPECOPS_HAT_X =			"CFP_O_ALQAEDA_Rifleman_AT_01";			//operator
blufor_SPECOPS_AA_X =			"CUP_O_TK_INS_Soldier_AA";				//operator
blufor_SPECOPS_MG_X =			"cfp_i_alNusra_machinegunner";			//operator
blufor_SPECOPS_MEDIC_X =		"CFP_O_ANSARALLAH_Medic_01";			//operator
blufor_SPECOPS_MARK_X =			"cfp_i_alNusra_sniper";					//operator
blufor_SPECOPS_SNIPER_X =		"CFP_O_ALQAEDA_Sniper_01";				//operator
blufor_SPECOPS_EXP_X =			"CFP_O_ALQAEDA_Explosive_Specialist_01";	//operator
blufor_SPECOPS_ENG_X = 			"cfp_o_is_sapper";						//operator





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
	["CFP_O_ALQAEDA_Rifleman_01","Rifleman (2CP)",2],
	["cfp_o_is_grenadier","Grenadier (3CP)",3],
	["cfp_i_alNusra_machinegunner","Heavy Gunner ",4],
	["CUP_O_TK_INS_Guerilla_Medic","Medic (4CP)",4],
	["CFP_O_ALQAEDA_Rifleman_AT_01","AT Specialist (4CP)",4],
	["CUP_O_TK_INS_Soldier_AA","AA Specialist (4CP)",4],
	["cfp_o_is_sapper","Engineer (4CP)",4],
	["CFP_O_ALQAEDA_Sniper_01","Sniper (4CP)",4]
];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////

blufor_RQST_VEHICLES = [
	["B_Quadbike_01_F","ATV (1CP)",1],
	["C_Offroad_01_F","SF Offroader (2CP)",2],
	["I_G_Van_01_transport_F","Transport Truck (6CP)",6],
	["CUP_B_HMMWV_Transport_USA","HMMV Transport (10CP)",10],
	["CFP_O_HEZBOLLAH_Offroad_Armed_01","Offroad HMG (15CP)",15],
	["CFP_O_ANSARALLAH_Offroad_AT_01","Offroad AT (18CP)",18],
	["CUP_B_HMMWV_M2_USA","HMMV HMG (25CP)",25],
	["CFP_O_ANSARALLAH_Zamak_01","Zamak Transport Uncovered (8CP)",8],
	["cfp_o_is_Ural","Ural Transport Covered (8CP)",8],
	["CFP_O_ANSARALLAH_Ural_Repair_01","Ural Repair (50CP)",50],
	["CFP_O_ANSARALLAH_Ural_Ammo_01","Ural Ammo (50CP)",50],
	["CFP_O_ANSARALLAH_Ural_Fuel_01","Ural Fuel (50CP)",50],
	["cfp_o_is_BTR40_MG","BTR-40 HMG (25CP)",25],
	["cfp_o_is_M113","M-113 APC (28CP)",28],
	["CFP_O_HEZBOLLAH_BTR_60PB_01","MTLB-LV APC (28CP)",28],
	["CUP_I_BRDM2_TK_Gue","BRDM-2 (32CP)",32],
	["CUP_I_BRDM2_ATGM_TK_Gue","BRDM-2 ATGM (35CP)",35],
	["cfp_i_alNusra_BMP1P","BMP-1 (32CP)",32],
	["cfp_o_is_BMP2_PKM","BMP-2K (35CP)",35],
	["cfp_o_is_T34","T-34 Tank (35CP)",35],
	["cfp_o_is_T55","T-55 Tank (40CP)",40],
	["cfp_o_is_T72","T-72 Tank (50CP)",50],
	["cfp_o_is_BMP2_ZU","BMP-2 ZU-23 (35CP)",35],
	["CUP_O_BM21_SLA","BM-21 Rockets (75CP)",75],
	["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15],
	["CUP_I_UH1H_TK_GUE","UH-1H (22CP)",22],
	["CUP_I_UH1H_gunship_TK_GUE","UH-1H Gunship (25CP)",25],
	["CUP_B_UH60M_US","UH-60 Blackhawk (35CP)",35],
	["CUP_O_Mi24_D_Dynamic_SLA","MI-24D Armed (40CP)",40],
	["CUP_O_Su25_Dyn_TKA","SU-25 Frogfoot(stolen) (50CP)",50],
	["B_UAV_01_F","UAV Darter(5CP)",5],
	["CUP_O_Pchela1T_RU","UAV Pchela 1T (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20]
];


