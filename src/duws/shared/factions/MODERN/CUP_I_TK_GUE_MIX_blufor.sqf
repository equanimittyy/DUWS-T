
///////////////   "CUP_I_TK_GUE", "TAKI Insurgents + Militia", "CUP_I_TK_GUE_MIX"


blufor_SOLDIER_X =				"CUP_O_TK_INS_Soldier";				//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"CUP_O_TK_INS_Soldier_AT";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"CUP_I_TK_GUE_Soldier_GL";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"CUP_I_TK_GUE_Soldier_TL";			//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"CUP_O_TK_INS_Soldier_TL";			//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"CUP_O_TK_INS_Soldier_AR";			//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"CUP_I_TK_GUE_Sniper";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"CUP_O_TK_SpecOps_TL";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CUP_O_TK_Pilot";					//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CUP_I_UH1H_TK_GUE";				//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"CUP_I_UH1H_TK_GUE";   				//random patrol
blufor_ATTACK_HELI_X =			"CUP_I_UH1H_gunship_TK_GUE";		//dialog\fnc_request_hcATTchop, random patrol
blufor_MISC_AIR_X =				"CUP_I_UH1H_gunship_TK_GUE";		//dialog\fnc_request_hcCAS, random patrol
blufor_ARMED_CAR1_X =			"CUP_I_Hilux_DSHKM_TK";				//random patrol
blufor_APC1_X =					"CUP_I_BRDM2_TK_Gue";				//random patrol
blufor_APC2_X =					"CUP_I_BMP1_TK_GUE";				//random patrol
blufor_MBT_TANK1_X =			"CUP_I_T55_TK_GUE";					//random patrol



blufor_TURRET_AA = 				"CUP_O_ZU23_TK";			// also "CUP_O_Igla_AA_pod_RU"
blufor_TURRET_AT =				"CUP_O_Kornet_RU";
blufor_TURRET_HMG =				"CUP_O_DSHKM_SLA";
blufor_TURRET_GMG =				"CUP_O_DSHKM_SLA";



blufor_SPECOPS_X =				"CUP_O_TK_INS_Soldier";				//operator
blufor_SPECOPS_GL_X =			"CUP_I_TK_GUE_Soldier_GL";			//operator
blufor_SPECOPS_LAT_X =			"CUP_O_TK_INS_Soldier_AT";			//operator
blufor_SPECOPS_HAT_X =			"CUP_I_TK_GUE_Soldier_HAT";			//operator
blufor_SPECOPS_AA_X =			"CUP_O_TK_INS_Soldier_AA";			//operator
blufor_SPECOPS_MG_X =			"CUP_O_TK_INS_Soldier_MG";			//operator
blufor_SPECOPS_MEDIC_X =		"CUP_O_TK_INS_Guerilla_Medic";		//operator
blufor_SPECOPS_MARK_X =			"CUP_O_TK_INS_Sniper";				//operator
blufor_SPECOPS_SNIPER_X =		"CUP_I_TK_GUE_Sniper";				//operator
blufor_SPECOPS_EXP_X =			"CUP_O_TK_INS_Bomber";				//operator
blufor_SPECOPS_ENG_X = 			"CUP_O_TK_INS_Mechanic";			//operator





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
	["CUP_O_TK_INS_Soldier","Rifleman (2CP)",2],
	["CUP_I_TK_GUE_Soldier_GL","Grenadier (3CP)",3],
	["CUP_O_TK_INS_Soldier_AR","Automatic Rifleman (3CP)",3],
	["CUP_O_TK_INS_Soldier_MG","Heavy Gunner ",4],
	["CUP_O_TK_INS_Guerilla_Medic","Medic (4CP)",4],
	["CUP_O_TK_INS_Soldier_AT","AT Rifleman (3CP)",3],
	["CUP_I_TK_GUE_Soldier_HAT","AT Specialist (4CP)",4],
	["CUP_O_TK_INS_Soldier_AA","AA Specialist (4CP)",4],
	["CUP_O_TK_INS_Mechanic","Engineer (4CP)",4],
	["CUP_O_TK_INS_Sniper","Marksman (3CP)",3],
	["CUP_I_TK_GUE_Sniper","Sniper (4CP)",4]
];


// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;

blufor_RQST_VEHICLES = [
	["B_Quadbike_01_F","ATV (1CP)",1],
	["C_Offroad_01_F","SF Offroader (2CP)",2],
	["I_G_Van_01_transport_F","Transport Truck (6CP)",6],
	["CUP_O_LR_Transport_TKM","LandRover Transport (10CP)",10],
	["CUP_O_Hilux_DSHKM_TK_INS","Hilux HMG (15CP)",15],
	["CUP_O_Hilux_AGS30_TK_INS","Hilux GMG (18CP)",18],
	["CUP_O_LR_MG_TKM","LandRover HMG (18CP)",18],
	["CUP_O_LR_SPG9_TKM","LandRover SPG-9 (20CP)",20],
	["CUP_B_HMMWV_M2_USA","HMMV HMG (25CP)",25],
	["CUP_I_V3S_Open_TKG","Praga Transport Uncovered (8CP)",8],
	["CUP_I_V3S_Covered_TKG","Praga Transport Covered (8CP)",8],
	["CUP_I_V3S_Repair_TKG","Praga Repair (50CP)",50],
	["CUP_I_V3S_Rearm_TKG","Praga Ammo (50CP)",50],
	["CUP_I_V3S_Refuel_TKG","Praga Fuel (50CP)",50],
	["CUP_I_BTR40_MG_TKG","BTR-40 HMG (25CP)",25],
	["CUP_I_M113_RACS_URB","M-113 APC (28CP)",28],
	["CUP_O_MTLB_pk_TK_MILITIA","MTLB-LV APC (28CP)",28],
	["CUP_I_BRDM2_TK_Gue","BRDM-2 (32CP)",32],
	["CUP_I_BRDM2_ATGM_TK_Gue","BRDM-2 ATGM (35CP)",35],
	["CUP_I_BMP1_TK_GUE","BMP-1 (32CP)",32],
	["CUP_O_BMP_HQ_sla","BMP-2K (35CP)",35],
	["CUP_I_T34_TK_GUE","T-34 Tank (35CP)",35],
	["CUP_I_T55_TK_GUE","T-55 Tank (40CP)",40],
	["CUP_O_T72_TKA","T-72 Tank (50CP)",50],
	["CUP_I_Ural_ZU23_TK_Gue","Ural ZU-23 (30CP)",30],
	["CUP_O_BM21_SLA","BM-21 Rockets (75CP)",75],
	["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15],
	["CUP_I_UH1H_TK_GUE","UH-1H (22CP)",22],
	["CUP_I_UH1H_gunship_TK_GUE","UH-1H Gunship (25CP)",25],
	["CUP_B_UH60M_US","UH-60 Blackhawk (35CP)",35],
	["CUP_O_Mi24_D_Dynamic_SLA","MI-24D Armed (40CP)",40],
	["CUP_O_Su25_Dyn_TKA","SU-25 Frogfoot (stolen)(50CP)",50],
	["B_UAV_01_F","UAV Darter(5CP)",5],
	["CUP_O_Pchela1T_RU","UAV Pchela 1T (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20]
];


