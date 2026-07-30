
///////////////
///////////////   "CUP_O_RU", "CUP Russian VDV(emr)+Spetsnaz", "CUP_O_RU_MVDV"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"CUP_O_RU_Soldier_VDV_M_EMR";				//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"CUP_O_RU_Soldier_LAT_VDV_M_EMR";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"CUP_O_RU_Soldier_GL_VDV_M_EMR";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"CUP_O_RU_Soldier_TL_VDV_M_EMR";			//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"CUP_O_RU_Soldier_SL_VDV_M_EMR";			//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"CUP_O_RU_Soldier_AR_VDV_M_EMR";			//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"CUP_O_RU_Soldier_Marksman_M_EMR";			//init_hq\fnc_HQguards
blufor_OFFICER_X =				"CUP_O_RU_Officer_VDV_M_EMR";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CUP_O_RU_Pilot";							//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"O_Boat_Armed_01_hmg_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"C_Man_UtilityWorker_01_F";		//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CUP_O_Mi8AMT_RU";				//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"CUP_O_Mi8_RU";  				//random patrol
blufor_HELI_ATTACK_X =			"CUP_O_Mi24_P_Dynamic_RU";		//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"CUP_O_Su25_Dyn_RU";			//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"CUP_O_GAZ_Vodnik_PK_RU";		//random patrol
blufor_APC_PATROL1_X =			"CUP_O_BTR80A_CAMO_RU";			//random patrol
blufor_APC_PATROL2_X =			"CUP_O_2S6M_RU";				//random patrol
blufor_TANK_PATROL1_X =			"CUP_O_T72_RU";					//random patrol


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

blufor_SPECOPS_X =				"CUP_O_RUS_SpecOps";					//operator
blufor_SPECOPS_GL_X =			"CUP_O_MVD_Soldier_TL";					//operator
blufor_SPECOPS_LAT_X =			"CUP_O_MVD_Soldier_AT";					//operator
blufor_SPECOPS_HAT_X =			"CUP_O_RU_Soldier_HAT_VDV";				//operator
blufor_SPECOPS_AA_X =			"CUP_O_RU_Soldier_AA_VDV";				//operator
blufor_SPECOPS_MG_X =			"CUP_O_MVD_Soldier_MG";					//operator
blufor_SPECOPS_MEDIC_X =		"CUP_O_RU_Medic_VDV";					//operator
blufor_SPECOPS_MARK_X =			"CUP_O_RUS_Soldier_Marksman";			//operator
blufor_SPECOPS_SNIPER_X =		"CUP_O_MVD_Sniper";						//operator
blufor_SPECOPS_EXP_X =			"CUP_O_RUS_Saboteur";					//operator
blufor_SPECOPS_ENG_X = 			"CUP_O_RU_Engineer_VDV";				//operator





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
	["CUP_O_RU_Soldier_VDV_M_EMR","Rifleman (EMR) (2CP)",2],
	["CUP_O_RU_Soldier_GL_VDV_M_EMR","Grenadier (EMR) (3CP)",3],
	["CUP_O_RU_Soldier_AR_VDV_M_EMR","Automatic Rifleman (EMR) (3CP)",3],
	["CUP_O_RU_Soldier_MG_VDV_M_EMR","Heavy Gunner (EMR) (4CP)",4],
	["CUP_O_RU_Medic_VDV_M_EMR","Medic (EMR) (4CP)",4],
	["CUP_O_RU_Soldier_LAT_VDV_M_EMR","AT Rifleman (EMR) (3CP)",3],
	["CUP_O_RU_Soldier_HAT_VDV_M_EMR","AT Specialist (EMR) (4CP)",4],
	["CUP_O_RU_Soldier_AA_VDV_M_EMR","AA Specialist (EMR) (4CP)",4],
	["CUP_O_RU_Engineer_VDV_M_EMR","Engineer (EMR) (4CP)",4],
	["CUP_O_RU_Explosive_Specialist_M_EMR","Explosive Specialist (EMR) (4CP)",4],
	["CUP_O_RU_Spotter_M_EMR","Spotter (EMR) (3CP)",3],
	["CUP_O_RU_Soldier_Marksman_M_EMR","Marksman (EMR) (3CP)",3],
	["CUP_O_RU_Sniper_M_EMR","Sniper (EMR) (4CP)",4]
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
	["CUP_O_UAZ_Open_RU","UAZ Unarmed (5CP)",5],
	["CUP_O_UAZ_MG_RU","UAZ DShKM (18CP)",18],
	["CUP_O_UAZ_SPG9_RU","UAZ SPG-9 (25CP)",25],
	["CUP_O_Kamaz_Open_RU","Kamaz Transport Uncovered (8CP)",8],
	["CUP_O_Kamaz_RU","Kamaz Transport Covered (8CP)",8],
	["CUP_O_Kamaz_Repair_RU","Kamaz Repair (50CP)",50],
	["CUP_O_Kamaz_Reammo_RU","Kamaz Ammo (50CP)",50],
	["CUP_O_Kamaz_Refuel_RU","Kamaz Fuel (50CP)",50],
	["CUP_O_BRDM2_RUS","BRDM-2 (25CP)",25],
	["CUP_O_BRDM2_ATGM_RUS","BRDM-2 ATGM (28CP)",28],
	["CUP_O_BMP2_RU","BMP-2 (30CP)",30],
	["CUP_O_BMP3_RU","BMP-3 (35CP)",35],
	["CUP_O_BTR80_CAMO_RU","BTR-80 (35CP)",35],
	["CUP_O_BTR80A_CAMO_RU","BTR-80A (35CP)",35],
	["CUP_O_BTR90_RU","BTR-90 (35CP)",35],
	["CUP_O_T55_CSAT","T-55 CSAT (40CP)",40],
	["CUP_O_T72_RU","T-72 (40CP)",40],
	["CUP_O_T90_RU","T-90 (50CP)",50],
	["CUP_O_2S6M_RU","Tunguska-M (50CP)",50],
	["CUP_O_BM21_RU","BM-21 Rocket (75CP)",75],
	["CUP_I_MH6M_ION","Heli - PMC Light (25CP)",25],
	["CUP_O_Mi24_V_Dynamic_RU","Mi-24 V (45CP)",45],
	["CUP_O_Ka50_DL_RU","Ka-50 Black (45CP)",45],
	["CUP_O_Ka52_RU","Ka-52 (45CP)",45],
	["CUP_O_Mi8AMT_RU","Mi-8AMT Transport (22CP)",22],
	["CUP_O_Mi8_RU","Mi-8 Armed (26CP)",26],
	["CUP_O_MI6T_RU","Mi-6T (26CP)",26],
	["CUP_O_Su25_Dyn_RU","Su-25 (45CP)",45],
	["CUP_O_SU34_RU","Su-34 (50CP)",50],
	["O_Plane_Fighter_02_Stealth_F","Shikra CSAT (Stealth) (60CP)",60],
	["O_UAV_06_F","UAV Jinaah AL-6 (5CP)",5],
	["O_UAV_02_dynamicLoadout_F","UAV K40 Ababil-3 (15CP)",15],
	["O_UGV_01_F","UGV Saif Recon (10CP)",10],
	["O_UGV_01_rcws_F","UGV Saif RCWS (20CP)",20]
];


