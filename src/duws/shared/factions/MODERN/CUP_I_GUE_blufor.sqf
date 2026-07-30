
///////////////
///////////////   "CUP_I_GUE", "CUP Chernarus NAPA + USMC Recon", "CUP_I_GUE"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"CUP_I_GUE_Soldier_AKS74";			//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"CUP_I_GUE_Soldier_AT";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"CUP_I_GUE_Soldier_GL";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"CUP_I_GUE_Officer";				//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"CUP_I_GUE_Officer";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"CUP_I_GUE_Soldier_MG";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"CUP_I_GUE_Sniper";					//init_hq\fnc_HQguards
blufor_OFFICER_X =				"CUP_I_GUE_Commander";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CUP_I_GUE_Pilot";					//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"CUP_I_RHIB_RACS";					//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CUP_B_UH60S_USN";					//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"CUP_C_SA330_Puma_HC1_ChernAvia";   //random patrol
blufor_HELI_ATTACK_X =			"CUP_B_AH1Z_Dynamic_USMC";			//dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"CUP_B_AV8B_DYN_USMC";				//dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"CUP_I_Datsun_PK";					//random patrol
blufor_APC_PATROL1_X =			"CUP_I_BRDM2_NAPA";					//random patrol
blufor_APC_PATROL2_X =			"CUP_I_BMP_HQ_NAPA";				//random patrol
blufor_TANK_PATROL1_X =			"CUP_I_T72_NAPA";					//random patrol


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

blufor_SPECOPS_X =				"CUP_B_FR_Soldier_Assault";					//operator
blufor_SPECOPS_GL_X =			"CUP_B_FR_Story_Miles";						//operator
blufor_SPECOPS_LAT_X =			"CUP_B_USMC_Soldier_AT_FROG_WDL";			//operator
blufor_SPECOPS_HAT_X =			"CUP_B_USMC_Soldier_HAT_FROG_WDL";			//operator
blufor_SPECOPS_AA_X =			"CUP_B_USMC_Soldier_AA_FROG_WDL";			//operator
blufor_SPECOPS_MG_X =			"CUP_B_FR_Story_Rodriguez";					//operator
blufor_SPECOPS_MEDIC_X =		"CUP_B_FR_Medic";							//operator
blufor_SPECOPS_MARK_X =			"CUP_B_FR_Soldier_Marksman";				//operator
blufor_SPECOPS_SNIPER_X =		"CUP_B_USMC_Sniper_M107";					//operator
blufor_SPECOPS_EXP_X =			"CUP_B_FR_Soldier_Exp";						//operator
blufor_SPECOPS_ENG_X = 			"CUP_B_FR_Saboteur";						//operator





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
	["CUP_I_GUE_Soldier_AKS74","Rifleman (2CP)",2],
	["CUP_I_GUE_Soldier_GL","Grenadier (3CP)",3],
	["CUP_I_GUE_Soldier_MG","Heavy Gunner (4CP)",4],
	["CUP_I_GUE_Medic","Medic (3CP)",3],
	["CUP_I_GUE_Soldier_AT","AT Specialist (4CP)",4],
	["CUP_I_GUE_Saboteur","Engineer (4CP)",4],
	["CUP_I_GUE_Sniper","Sniper (4CP)",4]
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
	["CUP_O_UAZ_Unarmed_SLA","UAZ Unarmed (5CP)",5],
	["CUP_I_Datsun_PK","Datsun HMG (10CP)",10],
	["CUP_B_HMMWV_M2_USMC","HMMV HMG (15CP)",15],
	["CUP_B_HMMWV_MK19_USMC","HMMV GMG (18CP)",18],
	["cfp_b_iqarmy_mrap_ridgback_hmg","Ridgeback HMG(25CP)",25],
	["B_Truck_01_transport_F","HEMTT Transport Uncovered (10CP)",10],
	["CUP_O_Ural_SLA","URAL Transport Covered (8CP)",8],
	["CUP_O_Ural_Repair_SLA","URAL Repair (50CP)",50],
	["CUP_O_Ural_Reammo_SLA","URAL Ammo (50CP)",50],
	["CUP_O_Ural_Refuel_SLA","URAL Fuel (50CP)",50],
	["CUP_I_M113_RACS_URB","M113 HMG (25CP)",25],
	["CUP_I_MTLB_pk_NAPA","MTLB HMG (28CP)",28],
	["CUP_I_BRDM2_NAPA","BRDM-2 (28CP)",28],
	["CUP_I_BRDM2_ATGM_NAPA","BRDM-ATGM (30CP)",30],
	["CUP_I_BMP2_NAPA","BMP-2 (32CP)",32],
	["CUP_I_BMP_HQ_NAPA","BMP-2K (35CP)",35],
	["CUP_B_LAV25M240_USMC","LAV-25 (35CP)",35],
	["CUP_B_M2A3Bradley_USA_D","Bradley ERA (45CP)",45],
	["CUP_I_T55_NAPA","T-55 Tank (40CP)",40],
	["CUP_I_T72_NAPA","T-72 Tank (45CP)",45],
	["CUP_B_M1A1_Woodland_USMC","M1A1 Abrahms (50CP)",50],
	["CUP_O_ZSU23_SLA","ZSU-23 Tunguska (50CP)",50],
	["CUP_O_BM21_SLA","BM-21 Rockets (75CP)",75],
	["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15],
	["CUP_O_UH1H_armed_SLA","UH-1H Armed (20CP)",20],
	["CUP_B_UH60S_USN","UH-60 Armed (28CP)",28],
	["CUP_O_Mi24_D_Dynamic_SLA","MI-24D (30CP)",30],
	["CUP_B_AH1Z_Dynamic_USMC","AH-1Z Attack Heli (45CP)",45],
	["CUP_C_SA330_Puma_HC1_ChernAvia","Civilian PUMA (26CP)",26],
	["CUP_B_CH53E_USMC","CH-53 Sea Knight(35CP)",35],
	["CUP_O_Su25_Dyn_SLA","SU-25 Frogfoot CAS (45CP)",45],
	["CUP_B_AV8B_DYN_USMC","AV-8 Harrier (50CP)",50],
	["CUP_B_MV22_USMC_RAMPGUN","MV-22 Osprey (60CP)",60],
	["B_UAV_01_F","UAV Darter(5CP)",5],
	["CUP_B_USMC_DYN_MQ9","UAV MQ-9 Reaper (USMC)(15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20]
];


