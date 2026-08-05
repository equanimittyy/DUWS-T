
///////////////
///////////////   "LOP_UA", "PrOpfor Eastern Bloc Insurgents", "LOP_EASTBLOC"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"LOP_UA_Infantry_Rifleman_2";		//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"rhsgref_nat_grenadier_rpg";		//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"LOP_UA_Infantry_GL";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"LOP_US_Infantry_TL";				//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"rhsgref_nat_commander";			//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"rhsgref_nat_machinegunner";		//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"LOP_US_Infantry_Marksman";			//init_hq\fnc_HQguards
blufor_OFFICER_X =				"LOP_US_Infantry_Officer";			//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"LOP_SLA_Infantry_Pilot";			//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"LOP_SLA_Mi8MTV3_UPK23";			//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"LOP_SLA_Mi8MT_Cargo";   			//random patrol
blufor_ATTACK_HELI_X =			"LOP_UKR_Mi24V_UPK23";				//dialog\fnc_request_hcATTchop, random patrol
blufor_MISC_AIR_X =				"rhsgref_cdf_su25";					//dialog\fnc_request_hcCAS, random patrol
blufor_ARMED_CAR1_X =			"LOP_US_UAZ_DshKM";					//random patrol
blufor_APC1_X =					"rhsgref_nat_btr70";				//random patrol
blufor_APC2_X =					"LOP_UA_BMP2";						//random patrol
blufor_MBT_TANK1_X =			"LOP_UA_T72BB";						//random patrol


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

blufor_SPECOPS_X =				"rhsgref_nat_pmil_rifleman_akm";		//operator
blufor_SPECOPS_GL_X =			"rhsgref_nat_pmil_grenadier";			//operator
blufor_SPECOPS_LAT_X =			"rhsgref_cdf_reg_rifleman_rpg75";		//operator
blufor_SPECOPS_HAT_X =			"rhsgref_nat_pmil_grenadier_rpg";		//operator
blufor_SPECOPS_AA_X =			"rhsgref_nat_pmil_specialist_aa";		//operator
blufor_SPECOPS_MG_X =			"rhsgref_nat_pmil_machinegunner";		//operator
blufor_SPECOPS_MEDIC_X =		"rhsgref_nat_pmil_medic";				//operator
blufor_SPECOPS_MARK_X =			"rhsgref_nat_pmil_hunter";				//operator
blufor_SPECOPS_SNIPER_X =		"rhsgref_nat_pmil_hunter";				//operator
blufor_SPECOPS_EXP_X =			"rhsgref_nat_pmil_saboteur";			//operator
blufor_SPECOPS_ENG_X = 			"LOP_SLA_Infantry_Engineer";			//operator





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
	["LOP_UA_Infantry_Rifleman_2","Rifleman (2CP)",2],
	["LOP_UA_Infantry_GL","Grenadier (3CP)",3],
	["rhsgref_nat_machinegunner","Heavy Gunner ",4],
	["LOP_US_Infantry_Corpsman","Medic (4CP)",4],
	["rhsgref_nat_grenadier_rpg","AT Specialist (4CP)",4],
	["LOP_US_Infantry_AA","AA Specialist (4CP)",4],
	["LOP_SLA_Infantry_Engineer","Engineer (4CP)",4],
	["LOP_US_Infantry_Marksman","Sniper (4CP)",4]
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
	["LOP_UA_UAZ","UAZ Unarmed (5CP)",5],
	["LOP_UA_UAZ_DshKM","UAZ Unarmed (10CP)",10],
	["LOP_AM_OPF_Offroad_M2","Offroad HMG (12CP)",12],
	["LOP_AM_OPF_Offroad_AT","Offroad SPG-9 (15CP)",15],
	["LOP_UKR_Ural","Ural Transport Covered (8CP)",8],
	["LOP_UKR_KAMAZ_Transport","KAMAZ Transport Open (8CP)",8],
	["LOP_UKR_KAMAZ_Repair","KAMAZ Repair (50CP)",50],
	["LOP_UKR_KAMAZ_Ammo","KAMAZ Ammo (50CP)",50],
	["LOP_UKR_KAMAZ_Fuel","KAMAZ Fuel (50CP)",50],
	["rhsgref_BRDM2_msv","BRDM-2 (25CP)",25],
	["rhsgref_BRDM2_ATGM_msv","BRDM-2 ATGM (28CP)",28],
	["LOP_UKR_BTR80","BTR-80 (30CP)",30],
	["LOP_UKR_BMP1D","BMP-1 (32CP)",32],
	["LOP_UKR_BMP2D","BMP-2 (35CP)",35],
	["LOP_AFR_T55","T-55 Tank (40CP)",40],
	["LOP_UKR_T72BC","T-72 Tank (50CP)",50],
	["LOP_UKR_ZSU234","BMP-2 ZU-23 (35CP)",35],
	["LOP_IRAN_BM21","BM-21 Rockets (75CP)",75],
	["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15],
	["LOP_SLA_Mi8MT_Cargo","MI-8 Cargo (25CP)",25],
	["LOP_UKR_Mi24V_UPK23","MI-24V (30CP)",30],
	["LOP_SLA_Mi8MTV3_UPK23","MI-8MTV (35CP)",35],
	["rhsgref_cdf_su25","SU-25 Frogfoot(stolen) (50CP)",50],
	["O_UAV_01_F","UAV AR-2 Tayran (5CP)",5],
	["CUP_O_Pchela1T_RU","UAV Pchela 1T (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20]
];


