
///////////////
///////////////   "UK3CB_BAF", "3CB British AF (DPMW)", "UK3CB_BAF_DPMW"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"UK3CB_BAF_Pointman_DPMW";		//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"UK3CB_BAF_LAT_ILAW_DPMW";		//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"UK3CB_BAF_Grenadier_DPMW";		//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"UK3CB_BAF_FT_DPMW";            //init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"UK3CB_BAF_SC_DPMW";            //Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"UK3CB_BAF_LSW_DPMW";			//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"UK3CB_BAF_Marksman_DPMW";		//init_hq\fnc_HQguards
blufor_OFFICER_X =				"UK3CB_BAF_Officer_DPMW";		//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"UK3CB_BAF_HeliPilot_Army_DPMW";    //Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"UK3CB_BAF_RHIB_HMG_DPMW";	    //supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"UK3CB_BAF_GunnerStatic_DPMW";	//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"UK3CB_BAF_Merlin_HC3_18_GPMG_DPMW";    //supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"UK3CB_BAF_Merlin_HC3_18_DPMW";         //random patrol
blufor_HELI_ATTACK_X =			"UK3CB_BAF_Apache_AH1_DPMW";            //dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"B_Plane_CAS_01_F";                     //dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"UK3CB_BAF_Jackal2_L2A1_W_DPMW";        //random patrol
blufor_APC_PATROL1_X =			"UK3CB_BAF_FV432_Mk3_RWS_Green_DPMW";   //random patrol
blufor_APC_PATROL2_X =			"UK3CB_BAF_FV432_Mk3_GPMG_Green_DPMW";  //random patrol
blufor_TANK_PATROL1_X =			"B_T_MBT_01_TUSK_F";                    //random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"B_T_Static_AA_F";
blufor_TURRET_AT =				"B_T_Static_AT_F";
blufor_TURRET_HMG =				"UK3CB_BAF_Static_L111A1_Deployed_High_DPMW";
blufor_TURRET_GMG =				"UK3CB_BAF_Static_L134A1_Deployed_High_DPMW";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"UK3CB_BAF_Pointman_DPMW_REC";	//operator
blufor_SPECOPS_GL_X =			"UK3CB_BAF_FAC_DPMW_REC";		//operator
blufor_SPECOPS_LAT_X =			"UK3CB_BAF_LAT_DPMW";           //operator
blufor_SPECOPS_HAT_X =			"UK3CB_BAF_MAT_DPMW";           //operator
blufor_SPECOPS_AA_X =			"B_T_Soldier_AA_F";				//operator
blufor_SPECOPS_MG_X =			"UK3CB_BAF_MGLMG_DPMW_REC";		//operator
blufor_SPECOPS_MEDIC_X =		"UK3CB_BAF_Medic_DPMW_REC";		//operator
blufor_SPECOPS_MARK_X =			"UK3CB_BAF_Marksman_DPMW_REC";	//operator
blufor_SPECOPS_SNIPER_X =		"UK3CB_BAF_Sniper_DPMW_Ghillie_L115";   //operator
blufor_SPECOPS_EXP_X =			"UK3CB_BAF_Explosive_DPMW_REC";	//operator
blufor_SPECOPS_ENG_X = 			"UK3CB_BAF_Engineer_DPMW";		//operator





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


blufor_RQST_UNIT_01_X = 			["UK3CB_BAF_Pointman_DPMW","Point Man (DPMW) (2CP)",2];
blufor_RQST_UNIT_02_X =				["UK3CB_BAF_Grenadier_DPMW","Grenadier (DPMW) (3CP)",3];
blufor_RQST_UNIT_03_X =				["UK3CB_BAF_LSW_DPMW","Automatic Rifleman (DPMW) (3CP)",3];
blufor_RQST_UNIT_04_X =				["UK3CB_BAF_MGGPMG_DPMW","Heavy Gunner (DPMW) (4CP)",4];
blufor_RQST_UNIT_05_X =				["UK3CB_BAF_Medic_DPMW","Medic (DPMW) (4CP)",4];
blufor_RQST_UNIT_06_X =				["UK3CB_BAF_LAT_ILAW_DPMW","AT Rifleman (DPMW) (3CP)",3];
blufor_RQST_UNIT_07_X =				["UK3CB_BAF_MAT_DPMW","AT Specialist (DPMW) (4CP)",4];
blufor_RQST_UNIT_08_X =				["UK3CB_BAF_Engineer_DPMW","Engineer (DPMW) (4CP)",4];
blufor_RQST_UNIT_09_X =				["UK3CB_BAF_Repair_DPMW","Repair Specialist (DPMW) (4CP)",4];
blufor_RQST_UNIT_10_X =				["UK3CB_BAF_Explosive_DPMW","Explosive Specialist (DPMW) (4CP)",4];
blufor_RQST_UNIT_11_X =				["UK3CB_BAF_Spotter_DPMW_Ghillie_L129","Spotter (DPMW) (3CP)",3];
blufor_RQST_UNIT_12_X =				["UK3CB_BAF_Marksman_DPMW","Marksman (DPMW) (3CP)",3];
blufor_RQST_UNIT_13_X =				["UK3CB_BAF_Sniper_DPMW_Ghillie_L115","Sniper (DPMW) (4CP)",4];
blufor_RQST_UNIT_14_X =				["empty",0,0];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////   

blufor_RQST_VEHICLE_01_X =			["B_T_Quadbike_01_F","ATV (1CP)",1];
blufor_RQST_VEHICLE_02_X =			["C_Offroad_01_F","SF Offroader (2CP)",2];
blufor_RQST_VEHICLE_03_X =			["I_C_Van_01_transport_F","Transport Truck (6CP)",6];
blufor_RQST_VEHICLE_04_X =			["B_T_MRAP_01_F","Hunter Unarmed (5CP)",5];
blufor_RQST_VEHICLE_05_X =			["UK3CB_BAF_Husky_Passenger_HMG_Green_DPMW","Husky HMG (18CP)",18];
blufor_RQST_VEHICLE_06_X =			["UK3CB_BAF_Husky_Passenger_GMG_Green_DPMW","Husky GMG (25CP)",25];
blufor_RQST_VEHICLE_07_X =			["UK3CB_BAF_LandRover_Hard_FFR_Green_B_DPMW","Land Rover Unarmed (5CP)",5];
blufor_RQST_VEHICLE_08_X =			["UK3CB_BAF_LandRover_WMIK_HMG_FFR_Green_B_DPMW","Land Rover HMG (15CP)",15];
blufor_RQST_VEHICLE_09_X =			["UK3CB_BAF_LandRover_WMIK_Milan_FFR_Green_B_DPMW","Land Rover AT (20CP)",20];
blufor_RQST_VEHICLE_10_X =			["B_T_Truck_01_transport_F","HEMTT Transport Uncovered (8CP)",8];
blufor_RQST_VEHICLE_11_X =			["UK3CB_BAF_MAN_HX58_Transport_Green_DPMW","MAN Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_12_X =			["UK3CB_BAF_MAN_HX58_Repair_Green_DPMW","MAN Repair (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["UK3CB_BAF_MAN_HX58_Cargo_Green_B_DPMW","MAN Cargo (50CP)",50];
blufor_RQST_VEHICLE_14_X =			["UK3CB_BAF_MAN_HX58_Fuel_Green_DPMW","MAN Fuel (50CP)",50];
blufor_RQST_VEHICLE_15_X =			["B_T_APC_Wheeled_01_cannon_F","AMV-7 Marshall (35CP)",35];
blufor_RQST_VEHICLE_16_X =			["B_T_APC_Tracked_01_AA_F","IFV-6c Cheetah (30CP)",30];
blufor_RQST_VEHICLE_17_X =			["B_T_AFV_Wheeled_01_cannon_F","Rhino MGS (35CP)",35];
blufor_RQST_VEHICLE_18_X =			["B_T_AFV_Wheeled_01_up_cannon_F","Rhino MGS UP (35CP)",35];
blufor_RQST_VEHICLE_19_X =			["UK3CB_BAF_LandRover_Panama_Green_A_DPMW","Land Rover ROV (10CP)",10];
blufor_RQST_VEHICLE_20_X =			["UK3CB_BAF_FV432_Mk3_RWS_Green_DPMW","FV432/3 Bulldog HMG (25CP)",25];
blufor_RQST_VEHICLE_21_X =			["UK3CB_BAF_FV432_Mk3_GPMG_Green_DPMW","FV432/3 Bulldog GPMG (35CP)",35];
blufor_RQST_VEHICLE_22_X =			["B_T_MBT_01_cannon_F","M2A1 Slammer (40CP)",40];
blufor_RQST_VEHICLE_23_X =			["B_T_MBT_01_TUSK_F","M2A4 Slammer UP (40CP)",40];
blufor_RQST_VEHICLE_24_X =			["B_T_MBT_01_cannon_F","MBT-52 Kuma (50CP)",50];
blufor_RQST_VEHICLE_25_X =			["B_T_MBT_01_arty_F","M4 Scorcher Artillery (75CP)",75];
blufor_RQST_VEHICLE_26_X =			["B_T_MBT_01_mlrs_F","M5 Sandstorm MLRS (75CP)",75];
blufor_RQST_VEHICLE_27_X =			["B_Heli_Light_01_dynamicLoadout_F","AH-9 Pawnee (25CP)",25];
blufor_RQST_VEHICLE_28_X =			["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15];
blufor_RQST_VEHICLE_29_X =			["UK3CB_BAF_Apache_AH1_DPMW","Apache AH1 (45CP)",45];
blufor_RQST_VEHICLE_30_X =			["B_T_VTOL_01_armed_F","V-44 X Armed (40CP",40];
blufor_RQST_VEHICLE_31_X =			["UK3CB_BAF_Wildcat_AH1_TRN_8A_DPMW","Wildcat AH1 Transport (22CP)",22];
blufor_RQST_VEHICLE_32_X =			["UK3CB_BAF_Merlin_HC3_18_DPMW","Merlin HC3 Unarmed (26CP)",26];
blufor_RQST_VEHICLE_33_X =			["UK3CB_BAF_Merlin_HC3_18_GPMG_DPMW","Merlin HC3 Armed (26CP)",26];
blufor_RQST_VEHICLE_34_X =			["B_Plane_CAS_01_dynamicLoadout_F","A-164 Wipeout CAS (45CP)",45];
blufor_RQST_VEHICLE_35_X =			["B_Plane_Fighter_01_F","FA-181 Black Wasp II (50CP)",50];
blufor_RQST_VEHICLE_36_X =			["B_Plane_Fighter_01_Stealth_F","FA-181 Black Wasp II Stealth (60CP)",60];
blufor_RQST_VEHICLE_37_X =			["B_UAV_01_F","UAV Darter(5CP)",5];
blufor_RQST_VEHICLE_38_X =			["UK3CB_BAF_MQ9_Reaper_DPMW","MQ-9 Reaper (15CP)",15];
blufor_RQST_VEHICLE_39_X =			["B_T_UGV_01_olive_F","UGV Stomper Recon (10CP)",10];
blufor_RQST_VEHICLE_40_X =			["B_T_UGV_01_rcws_olive_F","UGV Stomper RCWS (20CP)",20];
blufor_RQST_VEHICLE_41_X =			["B_T_UAV_03_dynamicLoadout_F","MQ-12 UAV (20CP)",20];
blufor_RQST_VEHICLE_42_X =			["empty",0,0];
blufor_RQST_VEHICLE_43_X =			["empty",0,0];
blufor_RQST_VEHICLE_44_X =			["empty",0,0];
blufor_RQST_VEHICLE_45_X =			["empty",0,0];
blufor_RQST_VEHICLE_46_X =			["empty",0,0];
blufor_RQST_VEHICLE_47_X =			["empty",0,0];
blufor_RQST_VEHICLE_48_X =			["empty",0,0];
blufor_RQST_VEHICLE_49_X =			["empty",0,0];
blufor_RQST_VEHICLE_50_X =			["empty",0,0];


