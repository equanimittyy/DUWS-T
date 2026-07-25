
///////////////
///////////////   "CWR3_B", "CWR3 US Armed Forces (1985)", "CWR3_USA"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"cwr3_b_soldier";					//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"cwr3_b_soldier_at_m47";			//init_hq\guards.sqf, support\paradrop.sqf
blufor_SOLDIER_GL_X =			"cwr3_b_soldier_gl";				//init_hq\guards.sqf, support\paradrop.sqf
blufor_SOLDIER_TL_X =			"cwr3_b_soldier_tl";				//init_hq\createpatrol.sqf, init_hq\guards.sqf
blufor_SOLDIER_SL_X =			"cwr3_b_soldier_sl";				//support\cluster\cluster.sqf (comms voice), Multiplayer slot
blufor_SOLDIER_AR_X =			"cwr3_b_soldier_ar";				//support\paradrop.sqf, init_hq\guards.sqf
blufor_MARKSMAN_X = 			"cwr3_b_soldier_marksman";			//init_hq\guards.sqf
blufor_OFFICER_X =				"cwr3_b_officer";					//init_hq\BluHQinit.sqf
blufor_HELI_PILOT_X	=			"cwr3_b_soldier_pilot";				//missions\missions\pilot\mission.sqf

blufor_BOAT_ARMED_X	=			"cwr3_b_boat";						//support\taxi\boatTaxi.sqf
blufor_BOAT_CREW_X =			"cwr3_b_zodiac";					//support\taxi\boatTaxi.sqf

blufor_HELI_TRANS_ARM_X =		"cwr3_b_uh60";						//support\taxi\helotaxi.sqf, random patrol
blufor_HELI_TRANS_UNARM_X =		"cwr3_b_uh60_unarmed";   			//random patrol
blufor_HELI_ATTACK_X =			"cwr3_b_ah64_hellfire";				//dialog\request_hcATTchop.sqf
blufor_PLANE_CAS_X =			"cwr3_b_a10";						//dialog\request_hcCAS.sqf
blufor_CAR_PATROL1_X =			"cwr3_b_hmmwv_m2";					//random patrol
blufor_APC_PATROL1_X =			"cwr3_b_m2a2";						//random patrol
blufor_APC_PATROL2_X =			"cwr3_b_m113a1";					//random patrol
blufor_TANK_PATROL1_X =			"cwr3_b_m1a1";						//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"cwr3_b_tow";
blufor_TURRET_AT =				"cwr3_b_tow";
blufor_TURRET_HMG =				"cwr3_b_m2hb_high";
blufor_TURRET_GMG =				"B_G_HMG_02_high_F";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"cwr3_b_soldier";					//operator
blufor_SPECOPS_GL_X =			"cwr3_b_soldier_gl";				//operator
blufor_SPECOPS_LAT_X =			"cwr3_b_soldier_at_m47";				//operator
blufor_SPECOPS_HAT_X =			"cwr3_b_soldier_at_m47";				//operator
blufor_SPECOPS_AA_X =			"cwr3_b_soldier_aa_stinger";				//operator
blufor_SPECOPS_MG_X =			"cwr3_b_soldier_mg";		//operator
blufor_SPECOPS_MEDIC_X =		"cwr3_b_soldier_medic";			//operator
blufor_SPECOPS_MARK_X =			"cwr3_b_soldier_marksman";				//operator
blufor_SPECOPS_SNIPER_X =		"cwr3_b_soldier_sniper";					//operator
blufor_SPECOPS_EXP_X =			"cwr3_b_soldier_sapper";				//operator
blufor_SPECOPS_ENG_X = 			"cwr3_b_soldier_engineer";				//operator


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


blufor_RQST_UNIT_01_X = 			["cwr3_b_soldier","Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				["cwr3_b_soldier_gl","Grenadier (3CP)",3];
blufor_RQST_UNIT_03_X =				["cwr3_b_soldier_ar","Automatic Rifleman (3CP)",3];
blufor_RQST_UNIT_04_X =				["cwr3_b_soldier_mg","Heavy Gunner (4CP)",4];
blufor_RQST_UNIT_05_X =				["cwr3_b_soldier_medic","Medic (4CP)",4];
blufor_RQST_UNIT_06_X =				["cwr3_b_soldier_aat_m47","Asst. AT Specialist (3CP)",3];
blufor_RQST_UNIT_07_X =				["cwr3_b_soldier_at_m47","AT Specialist (4CP)",4];
blufor_RQST_UNIT_08_X =				["cwr3_b_soldier_aa_stinger","AA Specialist (4CP)",4];
blufor_RQST_UNIT_09_X =				["cwr3_b_soldier_engineer","Engineer (4CP)",4];
blufor_RQST_UNIT_10_X =				["cwr3_b_soldier_marksman","Marksman (3CP)",3];
blufor_RQST_UNIT_11_X =				["cwr3_b_soldier_sniper","Sniper (4CP)",4];
blufor_RQST_UNIT_12_X =				["empty",0,0];
blufor_RQST_UNIT_13_X =				["empty",0,0];
blufor_RQST_UNIT_14_X =				["empty",0,0];


///////////////////////////////
// dialog\request_vehicle.sqf
//   _index = lbCurSel 2102;
// dialog\request_vehicle_fob.sqf
//   _index = lbCurSel 2122;
////////////////////////////////   

blufor_RQST_VEHICLE_01_X =			["cwr3_b_m113a1","M113-A1 (20CP)",20];
blufor_RQST_VEHICLE_02_X =			["cwr3_b_m113a3","M113-A3 (22CP)",22];
blufor_RQST_VEHICLE_03_X =			["cwr3_b_m2a2","M2A2 (24CP)",24];
blufor_RQST_VEHICLE_04_X =			["cwr3_b_m163","M163 AA Vehicle (20CP)",20];
blufor_RQST_VEHICLE_05_X =			["cwr3_b_hmmwv_transport","HMMVW (Transport) (3CP)",3];
blufor_RQST_VEHICLE_06_X =			["cwr3_b_hmmwv_m2","HMMVW (Armed, M2) (5CP)",5];
blufor_RQST_VEHICLE_07_X =			["cwr3_b_hmmwv_tow","HMMVW (Armed, TOW) (8CP)",8];
blufor_RQST_VEHICLE_08_X =			["cwr3_b_m939","M939 (Truck, roof) (5CP)",5];
blufor_RQST_VEHICLE_09_X =			["cwr3_b_m939_empty","M939 (Truck, no roof) (5CP)",5];
blufor_RQST_VEHICLE_10_X =			["cwr3_b_m1a1","M1A1 (30CP)",30];
blufor_RQST_VEHICLE_11_X =			["cwr3_b_m60a3","M60A3 (32CP)",32];
blufor_RQST_VEHICLE_12_X =			["cwr3_b_uh60","UH60 Transp. (30CP)",30];
blufor_RQST_VEHICLE_13_X =			["cwr3_b_ah64_hellfire","AH64 (35CP)",35];
blufor_RQST_VEHICLE_14_X =			["cwr3_b_ch47","CH47 Chinook (32CP)",32];
blufor_RQST_VEHICLE_15_X =			["cwr3_b_c130","C-130 (Transport) (35CP)",35];
blufor_RQST_VEHICLE_16_X =			["cwr3_b_a10_cas","A-10 Warthog (40CP)",40];
blufor_RQST_VEHICLE_17_X =			["B_T_UAV_03_dynamicLoadout_F","MQ-12 UAV (20CP)",20];
blufor_RQST_VEHICLE_18_X =			["cwr3_b_m939_reammo","M939 (Rearm) (50CP)",50];
blufor_RQST_VEHICLE_19_X =			["cwr3_b_m939_refuel","M939 (Refuel) (50CP)",50];
blufor_RQST_VEHICLE_20_X =			["cwr3_b_m939_repair","M939 (Repair) (50CP)",50];
blufor_RQST_VEHICLE_21_X =			["cwr3_b_m163","M163A1 VADS (Anti-Air, Manual) (25CP)",25];
blufor_RQST_VEHICLE_22_X =			["cwr3_b_m270_he","M270 MLRS (HE) (75CP)",75];
blufor_RQST_VEHICLE_23_X =			["cwr3_b_m151","M151 Willys Jeep (Transport) (5CP)",5];
blufor_RQST_VEHICLE_24_X =			["cwr3_b_m151_m2","M151 Willys Jeep (Armed, M2) (10CP)",10];
blufor_RQST_VEHICLE_25_X =			["cwr3_b_ah1f","AH1S Cobra (Fixed Pylons, TOW) (25CP)",25];
blufor_RQST_VEHICLE_26_X =			["cwr3_b_ah6j","AH-6J Littlebird (Armed) (25CP)",25];
blufor_RQST_VEHICLE_27_X =			["cwr3_b_kiowa_dyn","OH-58D Kiowa (Armed) (25CP)",25];
blufor_RQST_VEHICLE_28_X =			["cwr3_b_uh60_x4_esss","UH-60L Blackhawk (4xFFARs) (30CP)",30];
blufor_RQST_VEHICLE_29_X =			["cwr3_b_uh60_unarmed_ffv","UH-60L Blackhawk (Unarmed FFV) (15CP)",15];
blufor_RQST_VEHICLE_30_X =			["cwr3_b_uh60_ffv","UH-60L Blackhawk (M134 FFV) (20CP)",20];
blufor_RQST_VEHICLE_31_X =			["cwr3_b_mh6j","MH-6J Littlebird (Transport) (15CP)",15];
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


