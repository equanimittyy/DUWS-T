///////////////
///////////////    "CFP_O_HEZBOLLAH", "CFP Hezbollah + Stolen Vehicle Support", "CFP_O_HEZBOLLAH"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"CFP_O_HEZBOLLAH_Paramilitary_Rifleman_01";		//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"CFP_O_HEZBOLLAH_Paramilitary_Rifleman_AT_01";					//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"CFP_O_HEZBOLLAH_Militia_Explosive_Specialist_01";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"CFP_O_HEZBOLLAH_Squad_Leader_SF_01";				//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"CFP_O_HEZBOLLAH_Militia_Squad_Leader_01";			//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"CFP_O_HEZBOLLAH_Militia_Machine_Gunner_01";		//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"CFP_O_HEZBOLLAH_Sniper_SF_01";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"CFP_O_HEZBOLLAH_Militia_Squad_Leader_01";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CUP_O_TK_Pilot";					//missions\missions\pilot\mission.sqf

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CUP_I_UH1H_TK_GUE";				//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"CUP_I_UH1H_TK_GUE";   				//random patrol
blufor_ATTACK_HELI_X =			"CUP_I_UH1H_gunship_TK_GUE";		//dialog\fnc_request_hcATTchop, random patrol
blufor_MISC_AIR_X =				"CUP_I_UH1H_gunship_TK_GUE";		//dialog\fnc_request_hcCAS, random patrol
blufor_ARMED_CAR1_X =			"CFP_O_HEZBOLLAH_Hilux_01";				//random patrol
blufor_APC1_X =					"CFP_O_HEZBOLLAH_Hilux_Metis_01";					//random patrol
blufor_APC2_X =					"CFP_O_HEZBOLLAH_BTR_60PB_01";				//random patrol
blufor_MBT_TANK1_X =			"CFP_O_HEZBOLLAH_T72_01";				//random patrol


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

blufor_SPECOPS_X =				"CFP_O_HEZBOLLAH_Squad_Leader_SF_01";			//operator
blufor_SPECOPS_GL_X =			"CFP_O_HEZBOLLAH_Rifleman_AT_SF_01";					//operator
blufor_SPECOPS_LAT_X =			"CFP_O_HEZBOLLAH_Medic_SF_01";						//operator
blufor_SPECOPS_HAT_X =			"CFP_O_HEZBOLLAH_Explosive_Specialist_SF_01";			//operator
blufor_SPECOPS_AA_X =			"CFP_O_HEZBOLLAH_Militia_Rifleman_AT_01";				//operator
blufor_SPECOPS_MG_X =			"CFP_O_HEZBOLLAH_Militia_Machine_Gunner_01";			//operator
blufor_SPECOPS_MEDIC_X =		"CFP_O_HEZBOLLAH_Militia_Medic_01";			//operator
blufor_SPECOPS_MARK_X =			"CFP_O_HEZBOLLAH_Sniper_SF_01";					//operator
blufor_SPECOPS_SNIPER_X =		"CFP_O_HEZBOLLAH_Sniper_SF_01";				//operator
blufor_SPECOPS_EXP_X =			"CFP_O_HEZBOLLAH_Explosive_Specialist_SF_01";	//operator
blufor_SPECOPS_ENG_X = 			"CFP_O_HEZBOLLAH_Paramilitary_Rifleman_01";	//operator





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
	["CFP_O_HEZBOLLAH_Paramilitary_Rifleman_01","Militant Rifleman (2CP)",2],
	["CFP_O_HEZBOLLAH_Militia_Explosive_Specialist_01","Explosive Specialist (3CP)",3],
	["CFP_O_HEZBOLLAH_Militia_Machine_Gunner_01","Heavy Gunner (4CP)",4],
	["CFP_O_HEZBOLLAH_Militia_Medic_01","Medic (4CP)",4],
	["CFP_O_HEZBOLLAH_Paramilitary_Rifleman_AT_01","AT Specialist (4CP)",4],
	["CFP_O_HEZBOLLAH_Militia_Rifleman_AT_01","AA Specialist (4CP)",4],
	["cfp_o_is_sapper","Engineer (4CP)",4],
	["CFP_O_HEZBOLLAH_Sniper_SF_01","Sniper (4CP)",4]
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
	["CFP_O_HEZBOLLAH_Truck_01","Transport Truck (6CP)",6],
	["CFP_O_HEZBOLLAH_Hilux_01","Hilux Vehicle (10CP)",10],
	["CFP_O_HEZBOLLAH_Offroad_Armed_01","Offroad HMG (15CP)",15],
	["CFP_O_HEZBOLLAH_Hilux_Metis_01","Hilux Metis AT (18CP)",18],
	["CFP_O_HEZBOLLAH_Hilux_Podnos_01","Hilux Podnos (25CP)",25],
	["CFP_O_HEZBOLLAH_Hilux_MLRS_01","Hilux MLRS (27CP)",27],
	["CFP_O_HEZBOLLAH_Hilux_ZU_23_01","Hilux ZU23 AA (22CP)",22],
	["CFP_O_ANSARALLAH_Ural_Repair_01","Ural Repair (50CP)",50],
	["CFP_O_ANSARALLAH_Ural_Ammo_01","Ural Ammo (50CP)",50],
	["CFP_O_ANSARALLAH_Ural_Fuel_01","Ural Fuel (50CP)",50],
	["CFP_O_HEZBOLLAH_BTR_60PB_01","BTR-60P APC (25CP)",25],
	["CFP_O_HEZBOLLAH_BMP_2_01","BMP2 APC (28CP)",28],
	["CFP_O_HEZBOLLAH_BTR_60PB_01","MTLB-LV APC (28CP)",28],
	["CUP_I_BRDM2_TK_Gue","BRDM-2 (32CP)",32],
	["CUP_I_BRDM2_ATGM_TK_Gue","BRDM-2 ATGM (35CP)",35],
	["cfp_i_alNusra_BMP1P","Stolen BMP1-P (32CP)",32],
	["CFP_O_HEZBOLLAH_BTR_60PB_01","BTR 60PB (35CP)",35],
	["CFP_O_HEZBOLLAH_T72_01","T-72 Tank (35CP)",35],
	["CFP_O_HEZBOLLAH_Quad_Bike_01","Quad Bike (2CP)",2],
	["CFP_O_HEZBOLLAH_Hilux_DShKM_01","Hilux DShKM (15CP)",15],
	["CUP_O_BM21_SLA","BM-21 Rockets (75CP)",75],
	["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15],
	["CUP_I_UH1H_TK_GUE","Stolen UH-1H (22CP)",22],
	["CUP_I_UH1H_gunship_TK_GUE","Stolen UH-1H Gunship (25CP)",25],
	["CUP_B_UH60M_US","Stolen UH-60 Blackhawk (35CP)",35],
	["CUP_O_Mi24_D_Dynamic_SLA","MI-24D Armed (40CP)",40],
	["CUP_O_Su25_Dyn_TKA","SU-25 Frogfoot(stolen) (50CP)",50],
	["B_UAV_01_F","UAV Darter(5CP)",5],
	["CUP_O_Pchela1T_RU","UAV Pchela 1T (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20]
];


