
///////////////
///////////////   "LOP_UKR", "PrOpfor UKRAINE Army", "LOP_UKR"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"LOP_UKR_Infantry_Rifleman";			//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"LOP_UKR_Infantry_RPG";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"LOP_UKR_Infantry_Grenadier";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"LOP_UKR_Infantry_junior_sergeant";		//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"LOP_UKR_Infantry_sergeant";			//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"LOP_UKR_Infantry_AR";					//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"LOP_UKR_Infantry_Marksman";			//init_hq\fnc_HQguards
blufor_OFFICER_X =				"LOP_UKR_Infantry_officer";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"LOP_UKR_Infantry_pilot";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"O_Boat_Armed_01_hmg_F";			//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"LOP_UKR_Mi8MTV3_UPK23";			//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"LOP_UKR_Mi8MT_Cargo";  			//random patrol
blufor_HELI_ATTACK_X =			"LOP_UKR_Mi24V_UPK23";				//dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"rhsgref_cdf_su25";					//dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"LOP_UKR_UAZ_DshKM";				//random patrol
blufor_APC_PATROL1_X =			"LOP_UKR_BTR80";					//random patrol
blufor_APC_PATROL2_X =			"LOP_UKR_BMP2D";					//random patrol
blufor_TANK_PATROL1_X =			"LOP_UKR_T72BC";					//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"RHS_ZU23_MSV";						// also "rhs_Igla_AA_pod_msv"
blufor_TURRET_AT =				"rhs_Kornet_9M133_2_msv";			// also "rhs_SPG9M_MSV"
blufor_TURRET_HMG =				"LOP_IA_Static_DSHKM";
blufor_TURRET_GMG =				"LOP_IA_Static_DSHKM";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"LOP_UKR_Infantry_Rifleman";					//operator
blufor_SPECOPS_GL_X =			"LOP_UKR_Infantry_Grenadier";					//operator
blufor_SPECOPS_LAT_X =			"LOP_UKR_Infantry_LAT";							//operator
blufor_SPECOPS_HAT_X =			"LOP_UKR_Infantry_RPG";							//operator
blufor_SPECOPS_AA_X =			"LOP_UKR_Infantry_AA";							//operator
blufor_SPECOPS_MG_X =			"LOP_UKR_Infantry_AR";							//operator
blufor_SPECOPS_MEDIC_X =		"LOP_UKR_Infantry_medic";						//operator
blufor_SPECOPS_MARK_X =			"LOP_UKR_Infantry_Marksman";					//operator
blufor_SPECOPS_SNIPER_X =		"LOP_UKR_Infantry_Marksman";					//operator
blufor_SPECOPS_EXP_X =			"I_C_Soldier_Para_8_F";							//operator
blufor_SPECOPS_ENG_X = 			"LOP_UKR_Infantry_engineer";					//operator





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
	["LOP_UKR_Infantry_Rifleman","Rifleman (2CP)",2],
	["LOP_UKR_Infantry_Grenadier","Grenadier (3CP)",3],
	["LOP_UKR_Infantry_AR","Heavy Gunner (4CP)",4],
	["LOP_UKR_Infantry_medic","Medic (3CP)",3],
	["LOP_UKR_Infantry_RPG","AT Specialist (4CP)",4],
	["LOP_UKR_Infantry_AA","AA Specialist (4CP)",4],
	["LOP_UKR_Infantry_engineer","Engineer (4CP)",4],
	["LOP_UKR_Infantry_Marksman","Sniper (4CP)",4]
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
	["LOP_UKR_UAZ","UAZ Unarmed (5CP)",5],
	["LOP_UKR_UAZ_DshKM","UAZ HMG (15CP)",15],
	["LOP_UKR_UAZ_SPG","UAZ SPG-9 (20CP)",20],
	["rhs_tigr_sts_vdv","GAZ Tigr HMG/GMG (22CP)",22],
	["LOP_UKR_Ural","URAL Transport Covered (8CP)",8],
	["LOP_UKR_KAMAZ_Transport","KAMAZ Transport Open (8CP)",8],
	["LOP_UKR_KAMAZ_Repair","KAMAZ Repair (50CP)",50],
	["LOP_UKR_KAMAZ_Ammo","KAMAZ Ammo (50CP)",50],
	["LOP_UKR_KAMAZ_Fuel","KAMAZ Fuel (50CP)",50],
	["rhsgref_BRDM2_vdv","BRDM-2 (22CP)",22],
	["LOP_UKR_BTR60","BTR-60 (25CP)",25],
	["LOP_UKR_BTR80","BTR-80 (30CP)",30],
	["rhs_btr80a_vdv","BTR-80A (32CP)",32],
	["LOP_UKR_BMP1D","BMP-1D (35CP)",35],
	["LOP_UKR_BMP2D","BMP-2D (40CP)",40],
	["LOP_UKR_T72BC","T-72BC Tank (45CP)",45],
	["rhsgref_cdf_t80bv_tv","T-80BV Tank (50CP)",50],
	["LOP_UKR_ZSU234","ZSU-23 Tunguska (50CP)",50],
	["LOP_UKR_BM21","BM-21 Rockets (75CP)",75],
	["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15],
	["LOP_UKR_Mi8MT_Cargo","MI-8 Trans (20CP)",20],
	["LOP_UKR_Mi24V_UPK23","MI-24V (25CP)",25],
	["LOP_UKR_Mi8MTV3_UPK23","MI-8 Armed (30CP)",30],
	["rhsgref_cdf_su25","SU-25 Frogfoot (45CP)",45],
	["rhsgref_cdf_mig29s","MIG-29 (60CP)",60],
	["O_UAV_01_F","UAV AR-2 Tayran (5CP)",5],
	["rhs_pchela1t_vvs","UAV Pchela-1T (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20]
];


