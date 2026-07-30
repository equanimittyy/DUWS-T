
///////////////
///////////////   "CUP_B_CDF", "CUP Chernarus Defense Force (Mntn)", "CUP_B_CDF_MNT"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"CUP_B_CDF_Soldier_MNT";			//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"CUP_B_CDF_Soldier_LAT_MNT";		//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"CUP_B_CDF_Soldier_GL_MNT";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"CUP_B_CDF_Soldier_TL_MNT";			//init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"CUP_B_CDF_Soldier_TL_MNT";			//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"CUP_B_CDF_Soldier_AR_MNT";			//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"CUP_B_CDF_Soldier_Marksman_MNT";	//init_hq\fnc_HQguards
blufor_OFFICER_X =				"CUP_B_CDF_Officer_MNT";			//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CUP_B_CDF_Pilot_MNT";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CUP_B_Mi24_D_Dynamic_CDF";			//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"CUP_B_Mi17_VIV_CDF";   			//random patrol
blufor_HELI_ATTACK_X =			"CUP_B_Mi24_D_Dynamic_CDF";			//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"CUP_B_Su25_Dyn_CDF";				//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"CUP_B_UAZ_MG_CDF";					//random patrol
blufor_APC_PATROL1_X =			"CUP_B_BTR80A_CDF";					//random patrol
blufor_APC_PATROL2_X =			"CUP_B_BMP_HQ_CDF";					//random patrol
blufor_TANK_PATROL1_X =			"CUP_B_T72_CDF";					//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"CUP_O_Igla_AA_pod_RU";			// also "CUP_O_ZU23_TK"
blufor_TURRET_AT =				"CUP_O_Kornet_RU";
blufor_TURRET_HMG =				"CUP_O_DSHKM_SLA";
blufor_TURRET_GMG =				"CUP_O_DSHKM_SLA";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"CUP_B_CDF_Soldier_MNT";				//operator
blufor_SPECOPS_GL_X =			"CUP_B_CDF_Soldier_GL_MNT";				//operator
blufor_SPECOPS_LAT_X =			"CUP_B_CDF_Soldier_RPG18_MNT";			//operator
blufor_SPECOPS_HAT_X =			"CUP_B_CDF_Soldier_LAT_MNT";			//operator
blufor_SPECOPS_AA_X =			"CUP_B_CDF_Soldier_AA_MNT";				//operator
blufor_SPECOPS_MG_X =			"CUP_B_CDF_Soldier_MG_MNT";				//operator
blufor_SPECOPS_MEDIC_X =		"CUP_B_CDF_Medic_MNT";					//operator
blufor_SPECOPS_MARK_X =			"CUP_B_CDF_Soldier_Marksman_MNT";		//operator
blufor_SPECOPS_SNIPER_X =		"CUP_B_CDF_Sniper_MNT";					//operator
blufor_SPECOPS_EXP_X =			"CUP_B_CDF_Engineer_MNT";				//operator
blufor_SPECOPS_ENG_X = 			"CUP_B_CDF_Engineer_MNT";				//operator





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
	["CUP_B_CDF_Soldier_MNT","Rifleman (CDF) (2CP)",2],
	["CUP_B_CDF_Soldier_GL_MNT","Grenadier (CDF) (3CP)",3],
	["CUP_B_CDF_Soldier_AR_MNT","Automatic Rifleman (CDF) (3CP)",3],
	["CUP_B_CDF_Soldier_MG_MNT","Heavy Gunner (MTP) (CDF)",4],
	["CUP_B_CDF_Medic_MNT","Medic (CDF) (4CP)",4],
	["CUP_B_CDF_Soldier_RPG18_MNT","AT Rifleman (CDF) (3CP)",3],
	["CUP_B_CDF_Soldier_LAT_MNT","AT Specialist (CDF) (4CP)",4],
	["CUP_B_CDF_Soldier_AA_MNT","AA Specialist (CDF) (4CP)",4],
	["CUP_B_CDF_Engineer_MNT","Engineer (CDF) (4CP)",4],
	["CUP_B_CDF_Spotter_MNT","Spotter (CDF) (3CP)",3],
	["CUP_B_CDF_Soldier_Marksman_MNT","Marksman (CDF) (3CP)",3],
	["CUP_B_CDF_Sniper_MNT","Sniper (CDF) (4CP)",4]
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
	["CUP_O_GAZ_Vodnik_PK_RU","GAZ Vodnik MG (10CP)",10],
	["CUP_O_GAZ_Vodnik_AGS_RU","GAZ Vodnik GMG (18CP)",18],
	["CUP_O_GAZ_Vodnik_BPPU_RU","GAZ Vodnik BPPU (25CP)",25],
	["CUP_B_UAZ_Unarmed_CDF","UAZ Unarmed (5CP)",5],
	["CUP_B_UAZ_MG_CDF","UAZ DshKm HMG (15CP)",15],
	["CUP_B_UAZ_METIS_CDF","UAZ Metis AT (20CP)",20],
	["CUP_B_Ural_Open_CDF","Ural Transport Uncovered (8CP)",8],
	["CUP_B_Ural_CDF","Ural Transport Covered (8CP)",8],
	["CUP_B_Ural_Repair_CDF","Ural Repair (50CP)",50],
	["CUP_B_Ural_Reammo_CDF","Ural Ammo (50CP)",50],
	["CUP_B_Ural_Refuel_CDF","Ural Fuel (50CP)",50],
	["CUP_B_BRDM2_CDF","BRDM-2 (28CP)",28],
	["CUP_B_BRDM2_ATGM_CDF","BRDM-2 ATGM (35CP)",35],
	["CUP_B_BTR60_CDF","BTR-60 (28CP)",28],
	["CUP_B_BTR80_CDF","BTR-80 (32CP)",32],
	["CUP_B_BTR80A_CDF","BTR-80A (35CP)",35],
	["CUP_B_BMP2_CDF","BMP-2 (30CP)",30],
	["CUP_B_BMP_HQ_CDF","BMP-2k (35CP)",35],
	["CUP_O_T55_SLA","T-55 Tank (35CP)",35],
	["CUP_B_T72_CDF","T-72 (40CP)",40],
	["CUP_O_T90_RU","T-90A (50CP)",50],
	["CUP_B_ZSU23_CDF","ZSU-23 Tunguska (50CP)",50],
	["CUP_B_BM21_CDF","BM-21 Rockets (75CP)",75],
	["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15],
	["CUP_O_UH1H_gunship_SLA","UH-1H Gunship (25CP)",25],
	["CUP_O_Ka50_DL_SLA","KA-50 Attack Heli (45CP)",45],
	["CUP_B_Mi24_D_Dynamic_CDF","MI-24D Armed (40CP",40],
	["CUP_B_Mi17_VIV_CDF","MI-8 Trans Heli (22CP)",22],
	["CUP_O_Mi8_SLA_2","MI-8 Armed (26CP)",26],
	["CUP_B_MI6A_CDF","MI-6A Transport (26CP)",26],
	["CUP_B_Su25_Dyn_CDF","SU-25 Frogfoot CAS (45CP)",45],
	["CUP_B_SU34_CDF","SU-34 Sabre (50CP)",50],
	["O_Plane_Fighter_02_Stealth_F","Shikra CSAT (Stealth) (60CP)",60],
	["B_UAV_01_F","UAV Darter(5CP)",5],
	["CUP_B_Pchela1T_CDF","UAV Pchela 1T (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20]
];


