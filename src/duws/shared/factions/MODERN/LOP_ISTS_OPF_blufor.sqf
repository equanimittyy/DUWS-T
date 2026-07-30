
///////////////
///////////////   "LOP_ISTS_OPF", "PrOpfor Middle East Insurgents", "LOP_ISTS_OPF"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"LOP_AM_Infantry_Rifleman";			//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"LOP_ISTS_Infantry_B_AT";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"LOP_ISTS_Infantry_B_GL";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"LOP_AM_OPF_Infantry_SL";			//init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"LOP_AM_OPF_Infantry_SL";			//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"LOP_AM_Infantry_AR";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"LOP_ISTS_Infantry_B_Marksman";		//init_hq\fnc_HQguards
blufor_OFFICER_X =				"LOP_ISTS_OPF_Infantry_SL";			//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"LOP_TKA_Infantry_Pilot";			//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"rhs_uh1h_hidf";					//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"LOP_PMC_AW159";   					//random patrol
blufor_HELI_ATTACK_X =			"rhs_uh1h_hidf_gunship";			//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"rhsgref_cdf_su25";					//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"LOP_AM_OPF_Offroad_M2";			//random patrol
blufor_APC_PATROL1_X =			"LOP_ISTS_OPF_M113_W";				//random patrol
blufor_APC_PATROL2_X =			"LOP_ISTS_OPF_BMP2";				//random patrol
blufor_TANK_PATROL1_X =			"LOP_ISTS_OPF_T55";					//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"RHS_ZU23_MSV";						// also "rhs_Igla_AA_pod_msv"
blufor_TURRET_AT =				"rhs_SPG9M_MSV";					// also "rhs_Kornet_9M133_2_msv"
blufor_TURRET_HMG =				"LOP_IA_Static_DSHKM";
blufor_TURRET_GMG =				"B_G_HMG_02_high_F";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"LOP_ISTS_OPF_Infantry_Rifleman";		//operator
blufor_SPECOPS_GL_X =			"LOP_AM_OPF_Infantry_GL";				//operator
blufor_SPECOPS_LAT_X =			"LOP_ISTS_OPF_Infantry_Rifleman_3";		//operator
blufor_SPECOPS_HAT_X =			"LOP_ISTS_OPF_Infantry_AT";				//operator
blufor_SPECOPS_AA_X =			"LOP_PMC_Infantry_AA";					//operator
blufor_SPECOPS_MG_X =			"LOP_ISTS_OPF_Infantry_AR";				//operator
blufor_SPECOPS_MEDIC_X =		"LOP_ISTS_Infantry_B_Corpsman";			//operator
blufor_SPECOPS_MARK_X =			"LOP_ISTS_OPF_Infantry_Marksman";		//operator
blufor_SPECOPS_SNIPER_X =		"LOP_PMC_Infantry_Marksman_2";			//operator
blufor_SPECOPS_EXP_X =			"LOP_PMC_Infantry_EOD";					//operator
blufor_SPECOPS_ENG_X = 			"LOP_PMC_Infantry_Engineer";			//operator





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
	["LOP_AM_Infantry_Rifleman","Rifleman (2CP)",2],
	["LOP_ISTS_Infantry_B_GL","Grenadier (3CP)",3],
	["LOP_AM_Infantry_AR","Heavy Gunner ",4],
	["LOP_ISTS_Infantry_B_Corpsman","Medic (4CP)",4],
	["LOP_ISTS_Infantry_B_AT","AT Specialist (4CP)",4],
	["LOP_PMC_Infantry_AA","AA Specialist (4CP)",4],
	["LOP_PMC_Infantry_Engineer","Engineer (4CP)",4],
	["LOP_ISTS_Infantry_B_Marksman","Sniper (4CP)",4]
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
	["LOP_AM_OPF_Offroad_M2","Offroad HMG (10CP)",10],
	["LOP_AM_OPF_Offroad_AT","Offroad SPG-9 (15CP)",15],
	["LOP_ISTS_OPF_M998_D_4DR","HMMV Open (10CP)",10],
	["LOP_ISTS_OPF_M1025_W_M2","HMMV HMG (25CP)",25],
	["LOP_SYR_Ural","Ural Transport Covered (8CP)",8],
	["LOP_SYR_KAMAZ_Transport","KAMAZ Transport Open (8CP)",8],
	["LOP_SYR_KAMAZ_Repair","KAMAZ Repair (50CP)",50],
	["LOP_SYR_KAMAZ_Ammo","KAMAZ Ammo (50CP)",50],
	["LOP_SYR_KAMAZ_Fuel","KAMAZ Fuel (50CP)",50],
	["rhsgref_BRDM2_msv","BRDM-2 (25CP)",25],
	["LOP_ISTS_OPF_M113_W","M-113 APC (28CP)",28],
	["LOP_ISTS_OPF_BTR60","BTR-60 (28CP)",28],
	["LOP_ISTS_OPF_BMP1","BMP-1 (32CP)",32],
	["LOP_ISTS_OPF_BMP2","BMP-2 (35CP)",35],
	["LOP_ISTS_OPF_T34","T-34 Tank (35CP)",35],
	["LOP_ISTS_OPF_T55","T-55 Tank (40CP)",40],
	["LOP_ISTS_OPF_T72BA","T-72 Tank (50CP)",50],
	["LOP_ISTS_OPF_ZSU234","BMP-2 ZU-23 (35CP)",35],
	["LOP_AM_OPF_BM21","BM-21 Rockets (75CP)",75],
	["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15],
	["LOP_PMC_AW159","AW-159 Unarmed (22CP)",22],
	["rhs_uh1h_hidf","UH-1H Armed (25CP)",25],
	["rhs_uh1h_hidf_gunship","UH-1H Gunship (35CP)",35],
	["rhsgref_cdf_su25","SU-25 Frogfoot(stolen) (50CP)",50],
	["O_UAV_01_F","UAV AR-2 Tayran (5CP)",5],
	["rhs_pchela1t_vvs","UAV Pchela-1T (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20]
];


