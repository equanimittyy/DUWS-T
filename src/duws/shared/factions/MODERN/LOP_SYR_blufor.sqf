
///////////////   "LOP_SYR", "PrOpfor SYRIAN Army + Russ VMF", "LOP_SYR"


blufor_SOLDIER_X =				"LOP_SYR_Infantry_Rifleman";		//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"LOP_SYR_Infantry_AT";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"LOP_SYR_Infantry_Grenadier";		//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"LOP_SYR_Infantry_TL";				//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"LOP_SYR_Infantry_SL";				//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"LOP_SYR_Infantry_MG";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"LOP_SYR_Infantry_Marksman";		//init_hq\fnc_HQguards
blufor_OFFICER_X =				"LOP_SYR_Infantry_SL";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"LOP_SYR_Infantry_Pilot";			//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"RHS_Mi24V_vvsc";					//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"RHS_Mi8mt_vvsc";   				//random patrol
blufor_ATTACK_HELI_X =			"RHS_Mi24V_vvsc";					//dialog\fnc_request_hcATTchop
blufor_MISC_AIR_X =				"RHS_Su25SM_vvsc";					//dialog\fnc_request_hcCAS
blufor_ARMED_CAR1_X =			"LOP_SYR_UAZ_DshKM";				//random patrol
blufor_APC1_X =					"LOP_SYR_BTR80";					//random patrol
blufor_APC2_X =					"LOP_SYR_BMP2";						//random patrol
blufor_MBT_TANK1_X =			"LOP_SYR_T72BB";					//random patrol



blufor_TURRET_AA = 				"RHS_ZU23_MSV";						// also "rhs_Igla_AA_pod_msv"
blufor_TURRET_AT =				"rhs_Kornet_9M133_2_msv";			// also "rhs_SPG9M_MSV"
blufor_TURRET_HMG =				"LOP_IA_Static_DSHKM";
blufor_TURRET_GMG =				"LOP_IA_Static_DSHKM";



blufor_SPECOPS_X =				"rhs_vmf_recon_rifleman_scout";		//operator
blufor_SPECOPS_GL_X =			"rhs_vmf_recon_grenadier";			//operator
blufor_SPECOPS_LAT_X =			"rhs_vmf_recon_rifleman_lat";		//operator
blufor_SPECOPS_HAT_X =			"rhs_vdv_des_at";					//operator
blufor_SPECOPS_AA_X =			"rhs_vdv_des_aa";					//operator
blufor_SPECOPS_MG_X =			"rhs_vmf_recon_arifleman";			//operator
blufor_SPECOPS_MEDIC_X =		"rhs_vmf_recon_medic";				//operator
blufor_SPECOPS_MARK_X =			"rhs_vmf_recon_marksman";			//operator
blufor_SPECOPS_SNIPER_X =		"O_sniper_F";						//operator
blufor_SPECOPS_EXP_X =			"I_C_Soldier_Para_8_F";				//operator
blufor_SPECOPS_ENG_X = 			"rhs_vdv_des_engineer";				//operator





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
	["LOP_SYR_Infantry_Rifleman","Rifleman (2CP)",2],
	["LOP_SYR_Infantry_Grenadier","Grenadier (3CP)",3],
	["LOP_SYR_Infantry_MG","Heavy Gunner (4CP)",4],
	["LOP_SYR_Infantry_Corpsman","Medic (3CP)",3],
	["LOP_SYR_Infantry_AT","AT Specialist (4CP)",4],
	["LOP_SYR_Infantry_Engineer","Engineer (4CP)",4],
	["LOP_SYR_Infantry_Marksman","Sniper (4CP)",4]
];


// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;

blufor_RQST_VEHICLES = [
	["B_Quadbike_01_F","ATV (1CP)",1],
	["C_Offroad_01_F","SF Offroader (2CP)",2],
	["I_G_Van_01_transport_F","Transport Truck (6CP)",6],
	["B_MRAP_01_F","Hunter Unarmed (5CP)",5],
	["LOP_SYR_UAZ_DshKM","UAZ HMG (15CP)",15],
	["LOP_SYR_UAZ_SPG","UAZ SPG-9 (18CP)",18],
	["rhsgref_BRDM2_b","BRDM-2 (25CP)",25],
	["rhs_tigr_sts_3camo_vdv","GAZ Tigr HMG/GMG (25CP)",25],
	["LOP_SYR_Ural","URAL Transport Covered (8CP)",8],
	["LOP_SYR_KAMAZ_Transport","KAMAZ Transport Open (8CP)",8],
	["LOP_SYR_KAMAZ_Repair","KAMAZ Repair (50CP)",50],
	["LOP_SYR_KAMAZ_Ammo","KAMAZ Ammo (50CP)",50],
	["LOP_SYR_KAMAZ_Fuel","KAMAZ Fuel (50CP)",50],
	["LOP_SYR_BTR60","BTR-60 (25CP)",25],
	["LOP_SYR_BTR80","BTR-80 (28CP)",28],
	["rhs_btr80a_vmf","BTR-80A (32CP)",32],
	["LOP_SYR_BMP1","BMP-1 (30CP)",30],
	["LOP_SYR_BMP2","BMP-2 (35CP)",35],
	["LOP_SYR_T55","T-55 Tank (40CP)",40],
	["LOP_SYR_T72BB","T-72 Tank (45CP)",45],
	["LOP_SYR_ZSU234","ZSU-23 Tunguska (50CP)",50],
	["LOP_SYR_BM21","BM-21 Rockets (75CP)",75],
	["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15],
	["RHS_Mi8mt_vvsc","MI-MI8 MTV (25CP)",25],
	["RHS_Mi24V_vvsc","MI-24V Armed (35CP)",35],
	["RHS_Ka52_vvsc","KA-52 Attack Heli (40CP)",40],
	["RHS_Su25SM_vvsc","SU-25 Frogfoot (45CP)",45],
	["rhs_mig29s_vmf","MIG-29 (50CP)",50],
	["O_UAV_01_F","UAV AR-2 Tayran (5CP)",5],
	["rhs_pchela1t_vvs","UAV Pchela-1T (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20]
];


