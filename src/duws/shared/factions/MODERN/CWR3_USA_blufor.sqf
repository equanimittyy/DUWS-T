
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
// Ordered lists, no padding and no fixed length: the menus offer every entry in the order
// written here, so position in the list is the display order. A faction may list as many
// or as few as it has.
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


blufor_RQST_UNITS = [
	["cwr3_b_soldier","Rifleman (2CP)",2],
	["cwr3_b_soldier_gl","Grenadier (3CP)",3],
	["cwr3_b_soldier_ar","Automatic Rifleman (3CP)",3],
	["cwr3_b_soldier_mg","Heavy Gunner (4CP)",4],
	["cwr3_b_soldier_medic","Medic (4CP)",4],
	["cwr3_b_soldier_aat_m47","Asst. AT Specialist (3CP)",3],
	["cwr3_b_soldier_at_m47","AT Specialist (4CP)",4],
	["cwr3_b_soldier_aa_stinger","AA Specialist (4CP)",4],
	["cwr3_b_soldier_engineer","Engineer (4CP)",4],
	["cwr3_b_soldier_marksman","Marksman (3CP)",3],
	["cwr3_b_soldier_sniper","Sniper (4CP)",4]
];


///////////////////////////////
// dialog\request_vehicle.sqf
//   _index = lbCurSel 2102;
// dialog\request_vehicle_fob.sqf
//   _index = lbCurSel 2122;
////////////////////////////////   

blufor_RQST_VEHICLES = [
	["cwr3_b_m113a1","M113-A1 (20CP)",20],
	["cwr3_b_m113a3","M113-A3 (22CP)",22],
	["cwr3_b_m2a2","M2A2 (24CP)",24],
	["cwr3_b_m163","M163 AA Vehicle (20CP)",20],
	["cwr3_b_hmmwv_transport","HMMVW (Transport) (3CP)",3],
	["cwr3_b_hmmwv_m2","HMMVW (Armed, M2) (5CP)",5],
	["cwr3_b_hmmwv_tow","HMMVW (Armed, TOW) (8CP)",8],
	["cwr3_b_m939","M939 (Truck, roof) (5CP)",5],
	["cwr3_b_m939_empty","M939 (Truck, no roof) (5CP)",5],
	["cwr3_b_m1a1","M1A1 (30CP)",30],
	["cwr3_b_m60a3","M60A3 (32CP)",32],
	["cwr3_b_uh60","UH60 Transp. (30CP)",30],
	["cwr3_b_ah64_hellfire","AH64 (35CP)",35],
	["cwr3_b_ch47","CH47 Chinook (32CP)",32],
	["cwr3_b_c130","C-130 (Transport) (35CP)",35],
	["cwr3_b_a10_cas","A-10 Warthog (40CP)",40],
	["B_T_UAV_03_dynamicLoadout_F","MQ-12 UAV (20CP)",20],
	["cwr3_b_m939_reammo","M939 (Rearm) (50CP)",50],
	["cwr3_b_m939_refuel","M939 (Refuel) (50CP)",50],
	["cwr3_b_m939_repair","M939 (Repair) (50CP)",50],
	["cwr3_b_m163","M163A1 VADS (Anti-Air, Manual) (25CP)",25],
	["cwr3_b_m270_he","M270 MLRS (HE) (75CP)",75],
	["cwr3_b_m151","M151 Willys Jeep (Transport) (5CP)",5],
	["cwr3_b_m151_m2","M151 Willys Jeep (Armed, M2) (10CP)",10],
	["cwr3_b_ah1f","AH1S Cobra (Fixed Pylons, TOW) (25CP)",25],
	["cwr3_b_ah6j","AH-6J Littlebird (Armed) (25CP)",25],
	["cwr3_b_kiowa_dyn","OH-58D Kiowa (Armed) (25CP)",25],
	["cwr3_b_uh60_x4_esss","UH-60L Blackhawk (4xFFARs) (30CP)",30],
	["cwr3_b_uh60_unarmed_ffv","UH-60L Blackhawk (Unarmed FFV) (15CP)",15],
	["cwr3_b_uh60_ffv","UH-60L Blackhawk (M134 FFV) (20CP)",20],
	["cwr3_b_mh6j","MH-6J Littlebird (Transport) (15CP)",15]
];


