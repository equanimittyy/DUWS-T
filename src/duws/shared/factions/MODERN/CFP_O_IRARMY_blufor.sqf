
///////////////
///////////////   "CFP_O_IRARMY", "CFP Iranian Army", "CFP_O_IRARMY"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"CFP_O_IRARMY_Rifleman_01";				//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"CFP_O_IRARMY_Rifleman_AT_01";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"CFP_O_IRARMY_Grenadier_01";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"CFP_O_IRARMY_Squad_Leader_01";			//init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"CFP_O_IRARMY_Squad_Leader_01";			//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"CFP_O_IRARMY_Machine_Gunner_01";		//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"CFP_O_IRARMY_Sniper_55th_AB_Div_01";	//init_hq\fnc_HQguards
blufor_OFFICER_X =				"CFP_O_IRARMY_Team_Leader_65th_AB_01";	//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CFP_O_IRARMY_Pilot_01";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"CUP_I_RHIB_RACS";					//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CFP_O_WAGNER_Mi24_D_DESERT_01";	//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"CFP_O_IRARMY_Mi_8MT_01";  			//random patrol
blufor_HELI_ATTACK_X =			"CFP_O_IRARMY_Toufan_II_01";		//dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"CFP_O_IRARMY_SU25_Frogfoot_01";	//dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"CFP_O_IRARMY_Safir_DShKM_01";		//random patrol
blufor_APC_PATROL1_X =			"CFP_O_IRARMY_BTR_80A_01";			//random patrol
blufor_APC_PATROL2_X =			"CFP_O_IRARMY_BMP2_01";				//random patrol
blufor_TANK_PATROL1_X =			"CFP_O_IRARMY_T72_01";				//random patrol


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

blufor_SPECOPS_X =				"CFP_O_IRARMY_Rifleman_55th_AB_Div_01";				//operator
blufor_SPECOPS_GL_X =			"CFP_O_IRARMY_Grenadier_55th_AB_Div_01";			//operator
blufor_SPECOPS_LAT_X =			"CFP_O_IRARMY_Rifleman_AT_55th_AB_Div_01";			//operator
blufor_SPECOPS_HAT_X =			"CFP_O_IRARMY_Rifleman_AT_55th_AB_Div_01";			//operator
blufor_SPECOPS_AA_X =			"CFP_O_IRARMY_AA_Specialist_01";					//operator
blufor_SPECOPS_MG_X =			"CFP_O_IRARMY_Machine_Gunner_55th_AB_Div_01";		//operator
blufor_SPECOPS_MEDIC_X =		"CFP_O_IRARMY_Medic_55th_AB_Div_01";				//operator
blufor_SPECOPS_MARK_X =			"CFP_O_IRARMY_Sniper_55th_AB_Div_01";				//operator
blufor_SPECOPS_SNIPER_X =		"CFP_O_IRARMY_Sniper_55th_AB_Div_01";				//operator
blufor_SPECOPS_EXP_X =			"CFP_O_IRARMY_Explosive_Specialist_55th_AB_Div_01";	//operator
blufor_SPECOPS_ENG_X = 			"CFP_O_IRARMY_Engineer_01";							//operator





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
	["CFP_O_IRARMY_Rifleman_01","Rifleman (2CP)",2],
	["CFP_O_IRARMY_Grenadier_01","Grenadier (3CP)",3],
	["CFP_O_IRARMY_Machine_Gunner_01","Heavy Gunner (4CP)",4],
	["CFP_O_IRARMY_Medic_01","Medic (3CP)",3],
	["CFP_O_IRARMY_Rifleman_AT_01","AT Specialist (4CP)",4],
	["CFP_O_IRARMY_AA_Specialist_01","AA Specialist (4CP)",4],
	["CFP_O_IRARMY_Engineer_01","Engineer (4CP)",4],
	["CFP_O_IRARMY_Sniper_55th_AB_Div_01","Sniper (4CP)",4]
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
	["CFP_O_IRARMY_Safir_01","Safir Unarmed (5CP)",5],
	["CFP_O_IRARMY_Safir_DShKM_01","Safir HMG (15CP)",15],
	["CFP_O_IRARMY_Safir_Metis_01","Safir METIS (20CP)",20],
	["CUP_O_GAZ_Vodnik_AGS_RU","GAZ Vodnik GMG (25CP)",25],
	["CFP_O_RUARMY_GAZ_Vodnik_BPPU_DES_01","GAZ Vodnik BPPU (25CP)",25],
	["B_Truck_01_transport_F","HEMTT Transport Uncovered (10CP)",10],
	["CFP_O_IRARMY_Ural_01","URAL Transport Covered (8CP)",8],
	["CFP_O_IRARMY_Ural_Repair_01","URAL Repair (50CP)",50],
	["CFP_O_IRARMY_Ural_Ammo_01","URAL Ammo (50CP)",50],
	["CFP_O_IRARMY_Ural_Fuel_01","URAL Fuel (50CP)",50],
	["CFP_O_IRARMY_M113_01","M113 HMG (25CP)",25],
	["CFP_O_IRARMY_BTR_60_01","BTR-60 (25CP)",25],
	["CFP_O_IRARMY_BTR_80_01","BTR-80 (30CP)",30],
	["CFP_O_IRARMY_BTR_80A_01","BTR-80A (32CP)",32],
	["CFP_O_IRARMY_BTR_90_01","BTR-90 (35CP)",35],
	["CFP_O_IRARMY_BMP1_01","BMP-1P (35CP)",35],
	["CFP_O_IRARMY_BMP2_01","BMP-2 (40CP)",40],
	["CFP_O_IRARMY_M60_Patton_01","M-60 Tank (40CP)",40],
	["CFP_O_IRARMY_T55_01","T-55 Tank (40CP)",45],
	["CFP_O_IRARMY_T72_01","T-72 Tank (50CP)",50],
	["CUP_O_ZSU23_SLA","ZSU-23 Tunguska (50CP)",50],
	["CUP_O_BM21_SLA","BM-21 Rockets (75CP)",75],
	["CUP_I_AH6J_RACS","AH-6 Littlebird (15CP)",15],
	["CFP_O_IRARMY_Mi_8MT_01","MI-8 Trans (20CP)",20],
	["CFP_O_WAGNER_Mi24_D_DESERT_01","MI-24P (25CP)",25],
	["CFP_O_WAGNER_Mi8_DESERT_01","MI-8 Armed (28CP)",28],
	["CUP_O_Ka52_RU","KA-52 Attack Heli (40CP",40],
	["CFP_O_IRARMY_Toufan_II_01","Toufan Attack Heli (40CP)",40],
	["CUP_O_MI6T_RU","MI-6T Hook Trans (30CP)",30],
	["CFP_O_IRARMY_SU25_Frogfoot_01","L-39 CAS (45CP)",45],
	["CUP_O_SU34_CSAT","SU-34 CSAT (50CP)",50],
	["O_Plane_Fighter_02_F","TO-201 Shikra CSAT (60CP)",60],
	["O_UAV_01_F","UAV AR-2 Tayran (5CP)",5],
	["rhs_pchela1t_vvs","UAV Pchela-1T (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20]
];


