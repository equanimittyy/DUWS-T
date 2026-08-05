
///////////////
///////////////   "CUP_O_TK_Army", "Takistani Army + USA SpecOps", "CUP_O_TK_Army"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"CUP_O_TK_Soldier";				//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"CUP_O_TK_Soldier_AT";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"CUP_O_TK_Soldier_GL";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"CUP_O_TK_SpecOps_TL";			//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"CUP_O_TK_Soldier_SL";			//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"CUP_O_TK_Soldier_AR";			//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"CUP_O_TK_Soldier_M";			//init_hq\fnc_HQguards
blufor_OFFICER_X =				"CUP_O_TK_Story_Aziz";			//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CUP_O_TK_Pilot";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CUP_O_Mi24_D_Dynamic_TK";		//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"CUP_O_Mi17_TK";   				//random patrol
blufor_ATTACK_HELI_X =			"CUP_O_Mi24_D_Dynamic_SLA";		//dialog\fnc_request_hcATTchop, random patrol
blufor_MISC_AIR_X =				"CUP_O_Su25_Dyn_SLA";			//dialog\fnc_request_hcCAS, random patrol
blufor_ARMED_CAR1_X =			"CUP_O_LR_MG_TKA";				//random patrol
blufor_APC1_X =					"CUP_O_BTR80A_TK";				//random patrol
blufor_APC2_X =					"CUP_O_BMP2_TKA";				//random patrol
blufor_MBT_TANK1_X =			"CUP_O_T72_TKA";				//random patrol


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

blufor_SPECOPS_X =				"CUP_O_TK_SpecOps_TL";				//operator
blufor_SPECOPS_GL_X =			"CUP_O_TK_SpecOps";					//operator
blufor_SPECOPS_LAT_X =			"CUP_O_TK_Soldier_AT";				//operator
blufor_SPECOPS_HAT_X =			"CUP_O_TK_Soldier_HAT";				//operator
blufor_SPECOPS_AA_X =			"CUP_O_TK_Soldier_AA";				//operator
blufor_SPECOPS_MG_X =			"CUP_O_TK_SpecOps_MG";				//operator
blufor_SPECOPS_MEDIC_X =		"CUP_O_TK_Medic";					//operator
blufor_SPECOPS_MARK_X =			"CUP_O_TK_Soldier_M";				//operator
blufor_SPECOPS_SNIPER_X =		"CUP_O_TK_Sniper";					//operator
blufor_SPECOPS_EXP_X =			"CUP_O_TK_Engineer";				//operator
blufor_SPECOPS_ENG_X = 			"CUP_O_TK_Engineer";				//operator





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
	["CUP_O_TK_Soldier","Rifleman (2CP)",2],
	["CUP_O_TK_Soldier_GL","Grenadier (3CP)",3],
	["CUP_O_TK_Soldier_AR","Automatic Rifleman (3CP)",3],
	["CUP_O_TK_Soldier_MG","Heavy Gunner ",4],
	["CUP_O_TK_Medic","Medic (4CP)",4],
	["CUP_O_TK_Soldier_AT","AT Rifleman (3CP)",3],
	["CUP_O_TK_Soldier_HAT","AT Specialist (4CP)",4],
	["CUP_O_TK_Soldier_AA","AA Specialist (4CP)",4],
	["CUP_O_TK_Engineer","Engineer (4CP)",4],
	["CUP_O_TK_Spotter","Spotter (3CP)",3],
	["CUP_O_TK_Soldier_M","Marksman (3CP)",3],
	["CUP_O_TK_Sniper","Sniper (4CP)",4]
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
	["CUP_B_HMMWV_M2_USA","HMMV HMG (18CP)",18],
	["CUP_B_RG31E_M2_USA","MRAP RG-31 HMG (25CP)",25],
	["CUP_O_UAZ_Unarmed_TKA","UAZ Unarmed (5CP)",5],
	["CUP_O_UAZ_MG_TKA","UAZ DshKm HMG (15CP)",15],
	["CUP_O_UAZ_METIS_TKA","UAZ Metis AT (20CP)",20],
	["CUP_O_Ural_Open_TKA","Ural Transport Uncovered (8CP)",8],
	["CUP_O_Ural_TKA","Ural Transport Covered (8CP)",8],
	["CUP_O_Ural_Repair_TKA","Ural Repair (50CP)",50],
	["CUP_O_Ural_Reammo_TKA","Ural Ammo (50CP)",50],
	["CUP_O_Ural_Refuel_TKA","Ural Fuel (50CP)",50],
	["CUP_O_M113_TKA","M-113 APC (28CP)",28],
	["CUP_O_BRDM2_ATGM_TKA","BRDM-2 ATGM (35CP)",35],
	["CUP_O_BTR60_TK","BTR-60 (28CP)",28],
	["CUP_O_BTR80_TK","BTR-80 (32CP)",32],
	["CUP_O_BTR80A_TK","BTR-80A (35CP)",35],
	["CUP_O_BMP2_TKA","BMP-2 (30CP)",30],
	["CUP_O_BMP_HQ_TKA","BMP-2k (35CP)",35],
	["CUP_O_T34_TKA","T-34 Tank (35CP)",35],
	["CUP_O_T55_TK","T-55 Tank (40CP)",40],
	["CUP_O_T72_TKA","T-72 Tank (50CP)",50],
	["CUP_O_ZSU23_TK","ZSU-23 Tunguska (50CP)",50],
	["CUP_O_BM21_TKA","BM-21 Rockets (75CP)",75],
	["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15],
	["CUP_O_UH1H_gunship_TKA","UH-1H Gunship (22CP)",22],
	["CUP_O_Mi17_TK","MI-8 Trans Heli (25CP)",25],
	["CUP_B_UH60M_US","UH-60 Blackhawk (35CP)",35],
	["CUP_O_Mi24_D_Dynamic_TK","MI-24D Armed (40CP",40],
	["CUP_O_L39_TK","SU-34 Sabre (50CP)",50],
	["CUP_O_Su25_Dyn_TKA","SU-25 Frogfoot CAS (45CP)",45],
	["O_UAV_06_F","UAV Jinaah AL-6 (5CP)",5],
	["CUP_B_USMC_DYN_MQ9","UAV USMC Reaper (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20]
];


