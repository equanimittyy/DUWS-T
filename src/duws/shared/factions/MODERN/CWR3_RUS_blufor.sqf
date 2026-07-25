
///////////////
///////////////   "CWR3_O", "CWR3 Soviet Armed Forces (1985)", "CWR3_RUS"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"cwr3_o_soldier";					//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"cwr3_o_soldier_at_rpg7";			//init_hq\guards.sqf, support\paradrop.sqf
blufor_SOLDIER_GL_X =			"cwr3_o_soldier_gl";				//init_hq\guards.sqf, support\paradrop.sqf
blufor_SOLDIER_TL_X =			"cwr3_o_soldier_tl";				//init_hq\createpatrol.sqf, init_hq\guards.sqf
blufor_SOLDIER_SL_X =			"cwr3_o_soldier_sl";				//support\cluster\cluster.sqf (comms voice), Multiplayer slot
blufor_SOLDIER_AR_X =			"cwr3_o_soldier_ar";				//support\paradrop.sqf, init_hq\guards.sqf
blufor_MARKSMAN_X = 			"cwr3_o_soldier_marksman";			//init_hq\guards.sqf
blufor_OFFICER_X =				"cwr3_o_officer";					//init_hq\BluHQinit.sqf
blufor_HELI_PILOT_X	=			"cwr3_o_soldier_pilot";				//missions\missions\pilot\mission.sqf

blufor_BOAT_ARMED_X	=			"cwr3_o_boat";					//support\taxi\boatTaxi.sqf
blufor_BOAT_CREW_X =			"cwr3_o_zodiac";				//support\taxi\boatTaxi.sqf

blufor_HELI_TRANS_ARM_X =		"cwr3_o_mi8_mtv3";		//support\taxi\helotaxi.sqf, random patrol
blufor_HELI_TRANS_UNARM_X =		"cwr3_o_mi8_amt";   	//random patrol
blufor_HELI_ATTACK_X =			"cwr3_o_mi24d";			//dialog\request_hcATTchop.sqf
blufor_PLANE_CAS_X =			"cwr3_o_su25";			//dialog\request_hcCAS.sqf
blufor_CAR_PATROL1_X =			"cwr3_o_uaz_dshkm";		//random patrol
blufor_APC_PATROL1_X =			"cwr3_o_brdm2";			//random patrol
blufor_APC_PATROL2_X =			"cwr3_o_bmp2";			//random patrol
blufor_TANK_PATROL1_X =			"cwr3_o_t72a";			//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"cwr3_o_zu23";
blufor_TURRET_AT =				"cwr3_o_konkurs_tripod";
blufor_TURRET_HMG =				"cwr3_o_nsv_high";
blufor_TURRET_GMG =				"cwr3_o_nsv_high";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"cwr3_o_spetsnaz_akms";				//operator
blufor_SPECOPS_GL_X =			"cwr3_o_soldier_gl";				//operator
blufor_SPECOPS_LAT_X =			"cwr3_o_soldier_aat_rpg7";			//operator
blufor_SPECOPS_HAT_X =			"cwr3_o_soldier_at_rpg7";			//operator
blufor_SPECOPS_AA_X =			"cwr3_o_soldier_aa_igla";			//operator
blufor_SPECOPS_MG_X =			"cwr3_o_soldier_mg";				//operator
blufor_SPECOPS_MEDIC_X =		"cwr3_o_soldier_medic";				//operator
blufor_SPECOPS_MARK_X =			"cwr3_o_soldier_marksman";			//operator
blufor_SPECOPS_SNIPER_X =		"cwr3_o_soldier_sniper";			//operator
blufor_SPECOPS_EXP_X =			"cwr3_o_soldier_sapper";			//operator
blufor_SPECOPS_ENG_X = 			"cwr3_o_soldier_engineer";			//operator


/////////////////////////////////////////////////////////////////
// REQUEST Units/Vehicles
//
// THESE HAVE FIXED AMOUNTS -fill the ends with ["empty",0,0];
//
// - Units = 				14
// - Vehicles/Statics = 	50
//
/////////////////////////////////////////////////////////////////

// request.sqf,request_fob.sqf defines labels/index for all request menu units/vehicles (not Operators)

// request_vehicle, request_vehicle_fob, request_unit, request_unit_fob 
// - these files contain the classnames referenced by the label/index


///////////////////////////////
// dialog\request_unit.sqf
//   _index = lbCurSel 2100;
// dialog\request_unit_fob.sqf
//   _index = lbCurSel 2120;
///////////////////////////////


blufor_RQST_UNIT_01_X = 			["cwr3_o_soldier","Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				["cwr3_o_soldier_gl","Grenadier (3CP)",3];
blufor_RQST_UNIT_03_X =				["cwr3_o_soldier_ar","Automatic Rifleman (3CP)",3];
blufor_RQST_UNIT_04_X =				["cwr3_o_soldier_mg","Heavy Gunner (4CP)",4];
blufor_RQST_UNIT_05_X =				["cwr3_o_soldier_medic","Medic (4CP)",4];
blufor_RQST_UNIT_06_X =				["cwr3_o_soldier_at_rpg7","AT Rifleman (3CP)",3];
blufor_RQST_UNIT_07_X =				["cwr3_o_soldier_aat_rpg7","AT Assistant (2CP)",4];
blufor_RQST_UNIT_08_X =				["cwr3_o_soldier_aa_igla","AA Specialist (4CP)",4];
blufor_RQST_UNIT_09_X =				["cwr3_o_soldier_engineer","Engineer (4CP)",4];
blufor_RQST_UNIT_10_X =				["cwr3_o_soldier_marksman","Marksman (3CP)",3];
blufor_RQST_UNIT_11_X =				["cwr3_o_soldier_sniper","Sniper (4CP)",4];
blufor_RQST_UNIT_12_X =				["cwr3_o_soldier_hg","Heavy Grenadier (4CP)",4];
blufor_RQST_UNIT_13_X =				["empty",0,0];
blufor_RQST_UNIT_14_X =				["empty",0,0];


///////////////////////////////
// dialog\request_vehicle.sqf
//   _index = lbCurSel 2102;
// dialog\request_vehicle_fob.sqf
//   _index = lbCurSel 2122;
////////////////////////////////   

blufor_RQST_VEHICLE_01_X =			["cwr3_o_bmp1","BMP-1 (20CP)",20];
blufor_RQST_VEHICLE_02_X =			["cwr3_o_bmp2","BMP-2 (22CP)",22];
blufor_RQST_VEHICLE_03_X =			["cwr3_o_brdm2","BRDM-2 (24CP)",24];
blufor_RQST_VEHICLE_04_X =			["cwr3_o_btr80","BTR-80 (25CP)",25];
blufor_RQST_VEHICLE_05_X =			["cwr3_o_zsu","ZSU AA Vehicle (20CP)",20];
blufor_RQST_VEHICLE_06_X =			["cwr3_o_bmp2_zu23","BMP-2 (ZU23 AA Cannon) (22CP)",22];
blufor_RQST_VEHICLE_07_X =			["cwr3_o_uaz452","UAZ452 (Van) (5CP)",5];
blufor_RQST_VEHICLE_08_X =			["cwr3_o_uaz","UAZ (Truck, roof) (3CP)",3];
blufor_RQST_VEHICLE_09_X =			["cwr3_o_uaz_open","UAZ (Truck, no roof) (3CP)",3];
blufor_RQST_VEHICLE_10_X =			["cwr3_o_ural","Ural (6CP)",6];
blufor_RQST_VEHICLE_11_X =			["cwr3_o_uaz_dshkm","UAZ (DshKM) (8CP)",8];
blufor_RQST_VEHICLE_12_X =			["cwr3_o_t55","T55 (30CP)",30];
blufor_RQST_VEHICLE_13_X =			["cwr3_o_t64b","T64 (32CP)",32];
blufor_RQST_VEHICLE_14_X =			["cwr3_o_t72a","T72 (35CP)",35];
blufor_RQST_VEHICLE_15_X =			["cwr3_o_mi24d","MI24D (Hind) (35CP)",35];
blufor_RQST_VEHICLE_16_X =			["cwr3_o_mi8_amt","MI8 Transp. (30CP)",30];
blufor_RQST_VEHICLE_17_X =			["cwr3_o_v80","V80 (35CP)",35];
blufor_RQST_VEHICLE_18_X =			["cwr3_o_su25","SU-25 Frogfoot (40CP)",40];
blufor_RQST_VEHICLE_19_X =			["cwr3_o_ural_reammo","Ural Rearm (50CP)",50];
blufor_RQST_VEHICLE_20_X =			["cwr3_o_ural_refuel","Ural Refuel (50CP)",50];
blufor_RQST_VEHICLE_21_X =			["cwr3_o_ural_repair","Ural Repair (50CP)",50];
blufor_RQST_VEHICLE_22_X =			["cwr3_o_mtlb_repair","MTLB Repair (50CP)",50];
blufor_RQST_VEHICLE_23_X =			["cwr3_o_bm21","BM-21 GRAD MLRS (50CP)",50];
blufor_RQST_VEHICLE_24_X =			["cwr3_o_scud","Scud-B TEL SRBM (75CP)",75];
blufor_RQST_VEHICLE_25_X =			["empty",0,0];
blufor_RQST_VEHICLE_26_X =			["empty",0,0];
blufor_RQST_VEHICLE_27_X =			["empty",0,0];
blufor_RQST_VEHICLE_28_X =			["empty",0,0];
blufor_RQST_VEHICLE_29_X =			["empty",0,0];
blufor_RQST_VEHICLE_30_X =			["empty",0,0];
blufor_RQST_VEHICLE_31_X =			["empty",0,0];
blufor_RQST_VEHICLE_32_X =			["empty",0,0];
blufor_RQST_VEHICLE_33_X =			["empty",0,0];
blufor_RQST_VEHICLE_34_X =			["empty",0,0];
blufor_RQST_VEHICLE_35_X =			["empty",0,0];
blufor_RQST_VEHICLE_36_X =			["empty",0,0];
blufor_RQST_VEHICLE_37_X =			["empty",0,0];
blufor_RQST_VEHICLE_38_X =			["empty",0,0];
blufor_RQST_VEHICLE_39_X =			["empty",0,0];
blufor_RQST_VEHICLE_40_X =			["empty",0,0];
blufor_RQST_VEHICLE_41_X =			["empty",0,0];
blufor_RQST_VEHICLE_42_X =			["empty",0,0];
blufor_RQST_VEHICLE_43_X =			["empty",0,0];
blufor_RQST_VEHICLE_44_X =			["empty",0,0];
blufor_RQST_VEHICLE_45_X =			["empty",0,0];
blufor_RQST_VEHICLE_46_X =			["empty",0,0];
blufor_RQST_VEHICLE_47_X =			["empty",0,0];
blufor_RQST_VEHICLE_48_X =			["empty",0,0];
blufor_RQST_VEHICLE_49_X =			["empty",0,0];
blufor_RQST_VEHICLE_50_X =			["empty",0,0];


