
///////////////
///////////////   "CUP_B_US_Army", "CUP US Army (OCP Woodland)","CUP_B_USArmy_OCP_Woodland"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"CUP_B_US_Soldier_ACOG_OCP";					//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"CUP_B_US_Soldier_LAT_OCP";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"CUP_B_US_Soldier_GL_OCP";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"CUP_B_US_Soldier_TL_OCP";				//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"CUP_B_US_Soldier_SL_OCP";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"CUP_B_US_Soldier_AR_OCP";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"CUP_B_US_Soldier_Marksman_OCP";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"CUP_B_US_Officer_OCP";					//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CUP_B_US_Soldier_Crew_OCP";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"CFP_B_USRANGERS_Assault_Boat_WDL_01";	//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"CUP_B_US_Soldier_Crew_OCP";				//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CUP_B_UH60M_US";		//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"CUP_B_UH60M_Unarmed_US";   //random patrol
blufor_HELI_ATTACK_X =			"CUP_B_AH64_DL_USA";			//dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"CUP_B_A10_DYN_USA";				//dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"CUP_B_RG31_M2_OD_USA";				//random patrol
blufor_APC_PATROL1_X =			"CUP_B_M1126_ICV_MK19_Woodland";	//random patrol
blufor_APC_PATROL2_X =			"CUP_B_M2A3Bradley_USA_W";		//random patrol
blufor_TANK_PATROL1_X =			"CUP_B_M1A2_TUSK_MG_US_Army";				//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"CUP_B_CUP_Stinger_AA_pod_US";
blufor_TURRET_AT =				"CUP_B_TOW2_TriPod_US";
blufor_TURRET_HMG =				"CUP_B_M2StaticMG_US";
blufor_TURRET_GMG =				"CUP_B_MK19_TriPod_US";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"CUP_B_US_SpecOps";					//operator
blufor_SPECOPS_GL_X =			"CUP_B_US_SpecOps_Assault";				//operator
blufor_SPECOPS_LAT_X =			"CUP_B_US_Soldier_AT_OCP";				//operator
blufor_SPECOPS_HAT_X =			"CUP_B_US_Soldier_HAT_OCP";		//operator
blufor_SPECOPS_AA_X =			"CUP_B_US_Soldier_AA_OCP";				//operator
blufor_SPECOPS_MG_X =			"CUP_B_US_SpecOps_MG";		//operator
blufor_SPECOPS_MEDIC_X =		"CUP_B_US_SpecOps_Medic";				//operator
blufor_SPECOPS_MARK_X =			"CUP_B_US_SpecOps_M";					//operator
blufor_SPECOPS_SNIPER_X =		"CUP_B_US_Sniper_OCP";					//operator
blufor_SPECOPS_EXP_X =			"CUP_B_US_Soldier_Engineer_EOD_OCP";				//operator
blufor_SPECOPS_ENG_X = 			"CUP_B_US_Soldier_Engineer_OCP";			//operator





/////////////////////////////////////////////////////////////////
// REQUEST Units/Vehicles
//
// THESE HAVE FIXED AMOUNTS -fill the ends with ["empty",0,0];
//
// - Units = 				14
// - Vehicles/Statics = 	50
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


blufor_RQST_UNIT_01_X = 			["CUP_B_US_Soldier_ACOG_OCP","Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				["CUP_B_US_Soldier_GL_OCP","Grenadier (3CP)",3];
blufor_RQST_UNIT_03_X =				["CUP_B_US_Soldier_AR_OCP","Automatic Rifleman (3CP)",3];
blufor_RQST_UNIT_04_X =				["CUP_B_US_Soldier_MG_OCP","Heavy Gunner (4CP)",4];
blufor_RQST_UNIT_05_X =				["CUP_B_US_Medic_OCP","Medic (4CP)",4];
blufor_RQST_UNIT_06_X =				["CUP_B_US_Soldier_LAT_OCP","AT Rifleman (3CP)",3];
blufor_RQST_UNIT_07_X =				["CUP_B_US_Soldier_AT_OCP","AT Specialist (4CP)",4];
blufor_RQST_UNIT_08_X =				["CUP_B_US_Soldier_AA_OCP","AA Specialist (4CP)",4];
blufor_RQST_UNIT_09_X =				["CUP_B_US_Soldier_Engineer_OCP","Engineer (4CP)",4];
blufor_RQST_UNIT_10_X =				["CUP_B_US_Soldier_Marksman_OCP","Marksman (3CP)",3];
blufor_RQST_UNIT_11_X =				["CUP_B_US_Sniper_M107_OCP","Sniper (4CP)",4];
blufor_RQST_UNIT_12_X =				["empty",0,0];
blufor_RQST_UNIT_13_X =				["empty",0,0];
blufor_RQST_UNIT_14_X =				["empty",0,0];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////   

blufor_RQST_VEHICLE_01_X =			["CUP_B_M1030_USA","Motorcycle (1CP)",1];
blufor_RQST_VEHICLE_02_X =			["CUP_B_M1152_WDL_USA","Humvee Uncovered (2CP)",2];
blufor_RQST_VEHICLE_03_X =			["CFP_B_USARMY_HMMWV_Transport_USA","Humvee Transport (6CP)",6];
blufor_RQST_VEHICLE_04_X =			["CUP_B_M1151_WDL_USA","Humvee Unarmed (5CP)",5];
blufor_RQST_VEHICLE_05_X =			["CUP_B_M1151_M2_WDL_USA","Humvee HMG (18CP)",18];
blufor_RQST_VEHICLE_06_X =			["CUP_B_M1151_MK19_WDL_USA","Humvee GMG (25CP)",25];
blufor_RQST_VEHICLE_07_X =			["CFP_B_USARMY_HMMWV_Terminal_USA","Humvee Unarmed Cargo (5CP)",5];
blufor_RQST_VEHICLE_08_X =			["CUP_B_M1165_GMV_WDL_USA","Humvee Minigun (15CP)",15];
blufor_RQST_VEHICLE_09_X =			["CUP_B_M1167_WDL_USA","Humvee AT (20CP)",20];
blufor_RQST_VEHICLE_10_X =			["CFP_B_USARMY_HMMWV_Ambulance_USA","Humvee Transport Cargo (8CP)",8];
blufor_RQST_VEHICLE_11_X =			["CFP_B_USARMY_MTVR_USA","MTVR Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_12_X =			["CFP_B_USARMY_MTVR_Repair_USA","MTVR Repair (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["CFP_B_USARMY_MTVR_Ammo_USA","MTVR Ammo (50CP)",50];
blufor_RQST_VEHICLE_14_X =			["CFP_B_USARMY_MTVR_Refuel_USA","MTVR Fuel (50CP)",50];
blufor_RQST_VEHICLE_15_X =			["CUP_B_M1128_MGS_Woodland","M1128 MGS APC (35CP)",35];
blufor_RQST_VEHICLE_16_X =			["CUP_B_M1126_ICV_MK19_Woodland","M1126 MK19 APC (30CP)",30];
blufor_RQST_VEHICLE_17_X =			["CUP_B_M2Bradley_USA_W","M2 Bradley (35CP)",35];
blufor_RQST_VEHICLE_18_X =			["CUP_B_M2A3Bradley_USA_W","M2A3 Bradley (35CP)",35];
blufor_RQST_VEHICLE_19_X =			["CUP_B_M1130_CV_M2_Woodland","M1130 M2 APC (28CP)",28];
blufor_RQST_VEHICLE_20_X =			["CUP_B_M1126_ICV_M2_Woodland","M1126 M2 APC (25CP)",25];
blufor_RQST_VEHICLE_21_X =			["CUP_B_M1135_ATGMV_Woodland","M1135 ATGMV APC (35CP)",35];
blufor_RQST_VEHICLE_22_X =			["CUP_B_M1A1_Woodland_US_Army","M1A1 Tank (40CP)",40];
blufor_RQST_VEHICLE_23_X =			["CUP_B_M1A2_TUSK_MG_US_Army","M1A2 Tusk Tank (50CP)",50];
blufor_RQST_VEHICLE_24_X =			["CUP_B_AH6J_USA","AH6J Armed Heli (25CP)",25];
blufor_RQST_VEHICLE_25_X =			["CUP_B_MH6J_USA","MH6J Little Bird Heli (15CP)",15];
blufor_RQST_VEHICLE_26_X =			["CUP_B_AH64_DL_USA","AH64 Attack Heli (45CP)",45];
blufor_RQST_VEHICLE_27_X =			["CUP_B_MH47E_US","MH47 Heli (40CP)",40];
blufor_RQST_VEHICLE_28_X =			["CUP_B_UH60M_US","UH60 Blackhawk Heli (22CP)",22];
blufor_RQST_VEHICLE_29_X =			["CUP_B_CH47F_VIV_USA","CH47 Sidemounted Heli (26CP)",26];
blufor_RQST_VEHICLE_30_X =			["CUP_B_CH47F_USA","CH47 Fullmounted Heli (26CP)",26];
blufor_RQST_VEHICLE_31_X =			["CUP_B_CESSNA_T41_ARMED_USA","T41 Armed Plane (45CP)",45];
blufor_RQST_VEHICLE_32_X =			["CUP_B_AC47_SPOOKY_USA","AC47 Armed Plane (50CP)",50];
blufor_RQST_VEHICLE_33_X =			["CUP_B_A10_DYN_USA","A10 Thunderbolt Plane (60CP)",60];
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


