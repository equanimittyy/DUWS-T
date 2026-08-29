
///////////////   "CWR3_O", "CWR3 Soviet Armed Forces (1985)", "CWR3_RUS"


blufor_SOLDIER_X =				"cwr3_o_soldier";					//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"cwr3_o_soldier_at_rpg7";			//init_hq\guards.sqf, support\paradrop.sqf
blufor_GL_SOLDIER_X =			"cwr3_o_soldier_gl";				//init_hq\guards.sqf, support\paradrop.sqf
blufor_TL_SOLDIER_X =			"cwr3_o_soldier_tl";				//init_hq\createpatrol.sqf, init_hq\guards.sqf
blufor_SL_SOLDIER_X =			"cwr3_o_soldier_sl";				//support\cluster\cluster.sqf (comms voice), Multiplayer slot
blufor_AR_SOLDIER_X =			"cwr3_o_soldier_ar";				//support\paradrop.sqf, init_hq\guards.sqf
blufor_MARK_SOLDIER_X =			"cwr3_o_soldier_marksman";			//init_hq\guards.sqf
blufor_OFFICER_X =				"cwr3_o_officer";					//init_hq\BluHQinit.sqf
blufor_HELI_PILOT_X	=			"cwr3_o_soldier_pilot";				//missions\missions\pilot\mission.sqf

blufor_BOAT_ARMED_X	=			"cwr3_o_boat";					//support\taxi\boatTaxi.sqf
blufor_BOAT_CREW_X =			"cwr3_o_zodiac";				//support\taxi\boatTaxi.sqf

blufor_HELI_TRANS_ARM_X =		"cwr3_o_mi8_mtv3";		//support\taxi\helotaxi.sqf, random patrol
blufor_TRANS_HELI_X =			"cwr3_o_mi8_amt";   	//random patrol
blufor_ATTACK_HELI_X =			"cwr3_o_mi24d";			//dialog\request_hcATTchop.sqf
blufor_MISC_AIR_X =				"cwr3_o_su25";			//dialog\request_hcCAS.sqf
blufor_ARMED_CAR1_X =			"cwr3_o_uaz_dshkm";		//random patrol
blufor_APC1_X =					"cwr3_o_brdm2";			//random patrol
blufor_APC2_X =					"cwr3_o_bmp2";			//random patrol
blufor_MBT_TANK1_X =			"cwr3_o_t72a";			//random patrol



blufor_TURRET_AA = 				"cwr3_o_zu23";
blufor_TURRET_AT =				"cwr3_o_konkurs_tripod";
blufor_TURRET_HMG =				"cwr3_o_nsv_high";
blufor_TURRET_GMG =				"cwr3_o_nsv_high";



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


// REQUEST Units/Vehicles
// Ordered lists, no padding and no fixed length: the menus offer every entry in the order
// written here, so position in the list is the display order. A faction may list as many
// or as few as it has.

// request.sqf,request_fob.sqf defines labels/index for all request menu units/vehicles (not Operators)

// request_vehicle, request_vehicle_fob, request_unit, request_unit_fob 
// - these files contain the classnames referenced by the label/index


// dialog\request_unit.sqf
//   _index = lbCurSel 2100;
// dialog\request_unit_fob.sqf
//   _index = lbCurSel 2120;


blufor_RQST_UNITS = [
	["cwr3_o_soldier","Rifleman (2CP)",2],
	["cwr3_o_soldier_gl","Grenadier (3CP)",3],
	["cwr3_o_soldier_ar","Automatic Rifleman (3CP)",3],
	["cwr3_o_soldier_mg","Heavy Gunner (4CP)",4],
	["cwr3_o_soldier_medic","Medic (4CP)",4],
	["cwr3_o_soldier_at_rpg7","AT Rifleman (3CP)",3],
	["cwr3_o_soldier_aat_rpg7","AT Assistant (2CP)",4],
	["cwr3_o_soldier_aa_igla","AA Specialist (4CP)",4],
	["cwr3_o_soldier_engineer","Engineer (4CP)",4],
	["cwr3_o_soldier_marksman","Marksman (3CP)",3],
	["cwr3_o_soldier_sniper","Sniper (4CP)",4],
	["cwr3_o_soldier_hg","Heavy Grenadier (4CP)",4]
];


// dialog\request_vehicle.sqf
//   _index = lbCurSel 2102;
// dialog\request_vehicle_fob.sqf
//   _index = lbCurSel 2122;

blufor_RQST_VEHICLES = [
	["cwr3_o_bmp1","BMP-1 (20CP)",20],
	["cwr3_o_bmp2","BMP-2 (22CP)",22],
	["cwr3_o_brdm2","BRDM-2 (24CP)",24],
	["cwr3_o_btr80","BTR-80 (25CP)",25],
	["cwr3_o_zsu","ZSU AA Vehicle (20CP)",20],
	["cwr3_o_bmp2_zu23","BMP-2 (ZU23 AA Cannon) (22CP)",22],
	["cwr3_o_uaz452","UAZ452 (Van) (5CP)",5],
	["cwr3_o_uaz","UAZ (Truck, roof) (3CP)",3],
	["cwr3_o_uaz_open","UAZ (Truck, no roof) (3CP)",3],
	["cwr3_o_ural","Ural (6CP)",6],
	["cwr3_o_uaz_dshkm","UAZ (DshKM) (8CP)",8],
	["cwr3_o_t55","T55 (30CP)",30],
	["cwr3_o_t64b","T64 (32CP)",32],
	["cwr3_o_t72a","T72 (35CP)",35],
	["cwr3_o_mi24d","MI24D (Hind) (35CP)",35],
	["cwr3_o_mi8_amt","MI8 Transp. (30CP)",30],
	["cwr3_o_v80","V80 (35CP)",35],
	["cwr3_o_su25","SU-25 Frogfoot (40CP)",40],
	["cwr3_o_ural_reammo","Ural Rearm (50CP)",50],
	["cwr3_o_ural_refuel","Ural Refuel (50CP)",50],
	["cwr3_o_ural_repair","Ural Repair (50CP)",50],
	["cwr3_o_mtlb_repair","MTLB Repair (50CP)",50],
	["cwr3_o_bm21","BM-21 GRAD MLRS (50CP)",50],
	["cwr3_o_scud","Scud-B TEL SRBM (75CP)",75]
];


