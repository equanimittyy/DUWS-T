
///////////////
///////////////   "LOP_IA", "PrOpfor Iraqi Army + USA Specops", "LOP_IA"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"LOP_IA_Infantry_Rifleman";			//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"LOP_IA_Infantry_AT";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"LOP_IA_Infantry_GL";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"LOP_IA_Infantry_SL";				//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"LOP_IA_Infantry_SL";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"LOP_IA_Infantry_MG";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"LOP_IA_Infantry_Marksman";			//init_hq\fnc_HQguards
blufor_OFFICER_X =				"PO_IA_Infantry_SF_SL";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"LOP_IA_Infantry_Pilot";			//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"LOP_IA_Mi24V_UPK23";				//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"LOP_IA_Mi8MTV3_UPK23";   			//random patrol
blufor_HELI_ATTACK_X =			"LOP_IA_Mi24V_UPK23";				//dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"RHS_A10";							//dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"LOP_IA_M1025_W_M2";				//random patrol
blufor_APC_PATROL1_X =			"LOP_IA_M113_W";					//random patrol
blufor_APC_PATROL2_X =			"LOP_IA_BTR80";						//random patrol
blufor_TANK_PATROL1_X =			"LOP_IA_M1A1_AIM_D";				//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"RHS_Stinger_AA_pod_D";
blufor_TURRET_AT =				"RHS_TOW_TriPod_D";
blufor_TURRET_HMG =				"B_G_HMG_02_high_F";
blufor_TURRET_GMG =				"B_G_HMG_02_high_F";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"rhsusf_socom_marsoc_cso";				//operator
blufor_SPECOPS_GL_X =			"rhsusf_socom_marsoc_cso_grenadier";	//operator
blufor_SPECOPS_LAT_X =			"PO_IA_Infantry_SF_AT";				 	//operator 
blufor_SPECOPS_HAT_X =			"rhsusf_army_ocp_javelin";				//operator
blufor_SPECOPS_AA_X =			"rhsusf_army_ocp_aa";					//operator
blufor_SPECOPS_MG_X =			"PO_IA_Infantry_SF_MG";					//operator
blufor_SPECOPS_MEDIC_X =		"rhsusf_socom_marsoc_sarc";		 		//operator
blufor_SPECOPS_MARK_X =			"rhsusf_socom_marsoc_marksman";			//operator
blufor_SPECOPS_SNIPER_X =		"rhsusf_socom_marsoc_sniper_m107";		//operator
blufor_SPECOPS_EXP_X =			"rhsusf_socom_marsoc_cso_eod";			//operator
blufor_SPECOPS_ENG_X =			"PO_IA_Infantry_SF_Mechanic"; 			//operator





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
	["LOP_IA_Infantry_Rifleman","Rifleman (2CP)",2],
	["LOP_IA_Infantry_GL","Grenadier (3CP)",3],
	["LOP_IA_Infantry_MG","Heavy Gunner (4CP)",4],
	["LOP_IA_Infantry_Corpsman","Medic (3CP)",3],
	["LOP_IA_Infantry_AT","AT Specialist (4CP)",4],
	["LOP_IA_Infantry_Engineer","Engineer (4CP)",4],
	["LOP_IA_Infantry_Marksman","Sniper (4CP)",4]
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
	["LOP_IA_M1025_W_M2","HMMV HMG (15CP)",15],
	["LOP_IA_M1025_W_Mk19","HMMV GMG (18CP)",18],
	["rhsusf_m1240a1_m2_usarmy_d","MRAP M-1240 HMG (20CP)",20],
	["rhsgref_BRDM2_b","BRDM-2 (22CP)",22],
	["LOP_IA_HEMTT_Transport_D","HEMTT Transport Uncovered (10CP)",10],
	["LOP_IA_Ural","URAL Transport Covered (8CP)",8],
	["LOP_IA_HEMTT_Repair_D","HEMTT Repair (50CP)",50],
	["LOP_IA_HEMTT_Ammo_D","HEMTT Ammo (50CP)",50],
	["LOP_IA_HEMTT_Fuel_D","HEMTT Fuel (50CP)",50],
	["LOP_AA_M113_D","M113 HMG (25CP)",25],
	["LOP_IA_BTR80","BTR-80 (28CP)",28],
	["LOP_IA_BMP1","BMP-1 (30CP)",30],
	["LOP_IA_BMP2","BMP-2 (35CP)",35],
	["rhsusf_stryker_m1126_m2_d","Stryker HMG (30CP)",30],
	["RHS_M2A3_BUSKI","Bradley BUSK (40CP)",40],
	["LOP_IA_T55","T-55 Tank (40CP)",40],
	["LOP_IA_T72BB","T-72 Tank (45CP)",45],
	["LOP_IA_M1A1_AIM_D","M1A1 Abrahms (50CP)",50],
	["LOP_IA_ZSU234","ZSU-23 Tunguska (50CP)",50],
	["LOP_IA_BM21","BM-21 Rockets (75CP)",75],
	["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15],
	["LOP_IA_UH1Y_UN","UH-1Y Trans Heli (20CP)",20],
	["LOP_IA_Mi8MTV3_UPK23","MI-MI8 MTV (25CP)",25],
	["LOP_IA_Mi24V_UPK23","MI-24V Armed (28CP)",28],
	["RHS_UH60M_d","UH-60M Blackhawk (35CP",35],
	["RHS_CH_47F_10","CH-47 Transport (26CP)",26],
	["RHS_AH64D","AH-64D Attack Heli (30CP)",30],
	["RHS_A10","A-10 Warthog CAS (45CP)",45],
	["rhs_mig29s_vmf","MIG-29 (50CP)",50],
	["B_UAV_01_F","UAV Darter(5CP)",5],
	["B_UAV_02_dynamicLoadout_F","UAV MQ-4A Greyhawk (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20]
];


