
///////////////
///////////////   "RHS_msv", "RHS Russia MSV+Spetsnaz (Flora)","RHS_MSV_flora"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"rhs_msv_arifleman";			//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"rhs_msv_LAT";					//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"rhs_msv_grenadier";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"rhs_msv_junior_sergeant";		//init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"rhs_msv_sergeant";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"rhs_msv_arifleman";			//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"rhs_msv_marksman";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"rhs_msv_officer";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"rhs_pilot";					//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"O_Boat_Armed_01_hmg_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"C_Man_UtilityWorker_01_F";		//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"RHS_Mi8MTV3_vvsc";				//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"rhs_ka60_c";   				//random patrol
blufor_HELI_ATTACK_X =			"rhs_mi28n_vvsc";				//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"RHS_Su25SM_vvsc";				//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"rhs_tigr_sts_msv";				//random patrol
blufor_APC_PATROL1_X =			"rhs_btr70_msv";				//random patrol
blufor_APC_PATROL2_X =			"rhs_zsu234_aa";				//random patrol
blufor_TANK_PATROL1_X =			"rhs_t72be_tv";					//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"rhs_Igla_AA_pod_msv";			// also "RHS_ZU23_MSV"
blufor_TURRET_AT =				"rhs_Kornet_9M133_2_msv";
blufor_TURRET_HMG =				"rhs_KORD_high_MSV";
blufor_TURRET_GMG =				"rhs_KORD_high_MSV";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"rhs_vmf_recon_rifleman_scout";		//operator
blufor_SPECOPS_GL_X =			"rhs_vmf_recon_grenadier";			//operator
blufor_SPECOPS_LAT_X =			"rhs_vmf_recon_rifleman_lat";		//operator
blufor_SPECOPS_HAT_X =			"rhs_mvd_izlom_grenadier_rpg";		//operator
blufor_SPECOPS_AA_X =			"rhs_msv_aa";						//operator
blufor_SPECOPS_MG_X =			"rhs_vmf_recon_arifleman";			//operator
blufor_SPECOPS_MEDIC_X =		"rhs_vmf_recon_medic";				//operator
blufor_SPECOPS_MARK_X =			"rhs_vmf_recon_marksman";			//operator
blufor_SPECOPS_SNIPER_X =		"O_sniper_F";						//operator
blufor_SPECOPS_EXP_X =			"I_Soldier_exp_F";					//operator
blufor_SPECOPS_ENG_X = 			"rhs_msv_engineer";					//operator





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
	["rhs_msv_rifleman","Rifleman (Flora) (2CP)",2],
	["rhs_msv_grenadier","Grenadier (Flora) (3CP)",3],
	["rhs_msv_arifleman","Automatic Rifleman (Flora) (3CP)",3],
	["rhs_msv_machinegunner","Heavy Gunner (Flora) (4CP)",4],
	["rhs_msv_medic","Medic (Flora) (4CP)",4],
	["rhs_msv_LAT","AT Rifleman (Flora) (3CP)",3],
	["rhs_msv_grenadier_rpg","AT Specialist (Flora) (4CP)",4],
	["rhs_msv_aa","AA Specialist (Flora) (4CP)",4],
	["rhs_msv_engineer","Engineer (Flora) (4CP)",4],
	["rhs_msv_marksman","Marksman (Flora) (3CP)",3]
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
	["rhs_uaz_open_MSV_01","UAZ open (3CP)",3],
	["rhs_tigr_m_msv","GAZ 233114 (15CP)",15],
	["rhs_tigr_sts_msv","GAZ HMG/GMG (25CP)",25],
	["rhs_gaz66o_msv","GAZ-67 Transport Uncovered (8CP)",8],
	["rhs_kamaz5350_msv","KamAZ 5350 Transport Covered (8CP)",8],
	["RHS_Ural_Repair_MSV_01","Ural Repair Trk (50CP)",50],
	["rhs_gaz66_ammo_msv","GAZ-66 Ammo Trk (50CP)",50],
	["RHS_Ural_Fuel_MSV_01","Ural Fuel Trk (50CP)",50],
	["rhs_btr70_msv","BTR-70 (25CP)",25],
	["rhs_btr80_msv","BTR-80 (30CP)",30],
	["rhs_btr80a_msv","BTR-80A (35CP)",35],
	["rhs_bmp1_msv","BMP-1 (28CP)",25],
	["rhs_bmp2k_msv","BMP-2K (30CP)",30],
	["rhs_bmp3_late_msv","BMP-3 (30CP)",30],
	["rhs_zsu234_aa","ZSU-234 Shilka AA (40CP)",40],
	["rhs_t72be_tv","T-72 B3 (40CP)",40],
	["rhs_t80um","T-80 UM (40CP)",40],
	["rhs_t90sm_tv","T-90 SM (50CP)",50],
	["RHS_BM21_MSV_01","BM-21 MSV Rocket (75CP)",75],
	["rhs_2s3_tv","2S3-M1 Arty (75CP)",75],
	["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15],
	["rhs_ka60_c","KA-60 Unarmed (22CP)",22],
	["RHS_Mi8mt_vvsc","MI-8 MT Armed (26CP)",26],
	["RHS_Mi8AMTSh_vvsc","MI-8 AMT Armed (30CP)",30],
	["rhs_mi28n_vvsc","MI-28N Armed (35CP)",35],
	["RHS_Mi24V_vvsc","MI-24V Attack Heli (45CP)",45],
	["RHS_Ka52_vvsc","KA-52 Attack Heli (50CP",50],
	["RHS_Su25SM_vvsc","SU-25 Frogfoot CAS (45CP)",45],
	["rhs_mig29sm_vvsc","MIG-29 SM (50CP)",50],
	["RHS_T50_vvs_blueonblue","TO-50 obr 055 (60CP)",60],
	["O_UAV_01_F","UAV AR-2 Tayran (5CP)",5],
	["rhs_pchela1t_vvs","UAV Pchela-1T (15CP)",15],
	["B_UGV_01_F","UGV Stomper Recon (10CP)",10],
	["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20]
];

