
///////////////
///////////////   "CFP_O_SYARMY", "CFP SYRIAN ARAB ARMY (SAA)", "CFP_O_SYARMY"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"cfp_o_syarmy_rifleman";			//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"cfp_o_syarmy_at";					//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"cfp_o_syarmy_grenadier";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"cfp_o_syarmy_officer";				//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"cfp_o_syarmy_officer";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"cfp_o_syarmy_machinegunner";		//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"cfp_o_syarmy_sniper";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"cfp_o_syarmy_officer";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"cfp_o_syarmy_pilot_01";			//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"CUP_I_RHIB_RACS";					//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CFP_O_RUARMY_Mi_24V_DES_01";		//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"CFP_O_RUARMY_Mi_8AMT_VIV_DES_01";  //random patrol
blufor_HELI_ATTACK_X =			"CFP_O_RUARMY_Mi_24V_DES_01";		//dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"cfp_o_syarmy_L39_CAS";				//dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"CFP_O_SYARMY_Hilux_DSHKM_01";		//random patrol
blufor_APC_PATROL1_X =			"cfp_o_syarmy_BTR60";				//random patrol
blufor_APC_PATROL2_X =			"cfp_o_syarmy_BMP2";				//random patrol
blufor_TANK_PATROL1_X =			"cfp_o_syarmy_T72";					//random patrol


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

blufor_SPECOPS_X =				"CUP_O_RUS_SpecOps";							//operator
blufor_SPECOPS_GL_X =			"CUP_O_MVD_Soldier_GL";							//operator
blufor_SPECOPS_LAT_X =			"CUP_O_MVD_Soldier_AT";							//operator
blufor_SPECOPS_HAT_X =			"CUP_O_RU_Soldier_HAT";								//operator
blufor_SPECOPS_AA_X =			"CUP_O_RU_Soldier_AA";								//operator
blufor_SPECOPS_MG_X =			"CUP_O_RU_Soldier_MG";								//operator
blufor_SPECOPS_MEDIC_X =		"CUP_O_RU_Medic";									//operator
blufor_SPECOPS_MARK_X =			"CFP_O_RUARMY_Spetsnaz_Marksman_DES_02";			//operator
blufor_SPECOPS_SNIPER_X =		"CUP_O_RU_Sniper";									//operator
blufor_SPECOPS_EXP_X =			"cfp_b_iqarmy_sapper";								//operator
blufor_SPECOPS_ENG_X = 			"cfp_b_iqarmy_sapper";								//operator





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
	["cfp_o_syarmy_rifleman","Rifleman (2CP)",2],
	["cfp_o_syarmy_grenadier","Grenadier (3CP)",3],
	["cfp_o_syarmy_machinegunner","Heavy Gunner (4CP)",4],
	["cfp_o_syarmy_medic","Medic (3CP)",3],
	["cfp_o_syarmy_at","AT Specialist (4CP)",4],
	["cfp_o_syarmy_sapper","Engineer (4CP)",4],
	["cfp_o_syarmy_sniper","Sniper (4CP)",4]
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
	["B_MRAP_01_F","Hunter Unarmed (5CP)",5],
	["CUP_O_UAZ_Unarmed_RU","UAZ Unarmed (5CP)",5],
	["CFP_O_SYARMY_Hilux_DSHKM_01","Hilux HMG (15CP)",15],
	["CUP_O_UAZ_METIS_SLA","UAZ METIS (20CP)",20],
	["CUP_O_GAZ_Vodnik_PK_RU","GAZ Vodnik HMG (20CP)",20],
	["CUP_O_GAZ_Vodnik_AGS_RU","GAZ Vodnik GMG (25CP)",25],
	["B_Truck_01_transport_F","HEMTT Transport Uncovered (10CP)",10],
	["cfp_o_syarmy_Ural","URAL Transport Covered (8CP)",8],
	["cfp_o_syarmy_Ural_Repair_01","URAL Repair (50CP)",50],
	["cfp_o_syarmy_Ural_Ammo_01","URAL Ammo (50CP)",50],
	["cfp_o_syarmy_Ural_Refuel_01","URAL Fuel (50CP)",50],
	["cfp_o_syarmy_BTR40_MG","BTR-40 HMG (20CP)",20],
	["CFP_O_SYARMY_BRDM2","BRDM-2 (30CP)",30],
	["cfp_o_syarmy_BTR60","BTR-60 (28CP)",28],
	["cfp_o_syarmy_BMP1","BMP-1 (30CP)",30],
	["cfp_o_syarmy_BMP1P","BMP-1P (32CP)",32],
	["cfp_o_syarmy_BMP2","BMP-2 (35CP)",35],
	["CUP_O_BTR80A_DESERT_RU","BTR-80A (40CP)",40],
	["cfp_o_syarmy_T55","T-55 Tank (40CP)",40],
	["cfp_o_syarmy_T72","T-72 Tank (45CP)",45],
	["CUP_O_T90_RU","T-90 Tank (50CP)",50],
	["cfp_o_syarmy_ZSU","ZSU-23 Tunguska (50CP)",50],
	["CFP_O_SYRARMY_BM21","BM-21 Rockets (75CP)",75],
	["CUP_I_AH6J_RACS","AH-6 Littlebird (15CP)",15],
	["CFP_O_RUARMY_Mi_8AMT_VIV_DES_01","MI-8 Trans (20CP)",20],
	["CFP_O_RUARMY_Mi_24V_DES_01","MI-24P (25CP)",25],
	["CUP_O_Mi8_RU","MI-8 Armed (28CP)",28],
	["CUP_O_Ka52_RU","KA-52 Attack Heli (40CP",40],
	["CUP_O_Ka60_Grey_RU","KA-60 Armed (26CP)",26],
	["CUP_O_MI6T_RU","MI-6T Hook Trans (30CP)",30],
	["cfp_o_syarmy_L39_CAS","L-39 CAS (45CP)",45],
	["cfp_o_syarmy_SU25","SU-25 Frogfoot (50CP)",50],
	["cfp_o_syarmy_yak130","Yak-130 (60CP)",60],
	["O_UAV_01_F","UAV AR-2 Tayran (5CP)",5],
	["rhs_pchela1t_vvs","UAV Pchela-1T (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20]
];


