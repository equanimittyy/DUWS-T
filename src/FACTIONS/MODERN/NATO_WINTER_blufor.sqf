
///////////////
///////////////   "NATO_WINTER", "NATO (Winter)", "NATO_WINTER"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"NATO_WINTER_SOLDIER";			//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"NATO_WINTER_SOLDIER_LAT";		//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"NATO_WINTER_SOLDIER_GL";		//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"NATO_WINTER_SOLDIER_TL";		//initHQ\fnc_createpatrolFOB, initHQ\fnc_HQguards
blufor_SOLDIER_SL_X =			"NATO_WINTER_SOLDIER_SL";		//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"NATO_WINTER_SOLDIER_AR";		//supports\fnc_paradrop, initHQ\fnc_HQguards
blufor_MARKSMAN_X = 			"NATO_WINTER_SOLDIER_M";		//initHQ\fnc_HQguards
blufor_OFFICER_X =				"NATO_WINTER_OFFICER";			//initHQ\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"NATO_WINTER_HELIPILOT";		//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";	//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"NATO_WINTER_SOLDIER";			//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"NATO_WINTER_HELI_TRANSPORT_GHOSTHAWK";		  //supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"NATO_WINTER_HELI_TRANSPORT_HURON_UNARMED";   //random patrol
blufor_HELI_ATTACK_X =			"NATO_WINTER_HELI_ATTACK";		//dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"B_Plane_CAS_01_F";				//dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"NATO_WINTER_LSV";				//random patrol
blufor_APC_PATROL1_X =			"NATO_WINTER_AMV";				//random patrol
blufor_APC_PATROL2_X =			"NATO_WINTER_AA";				//random patrol
blufor_TANK_PATROL1_X =			"NATO_WINTER_MBT_TUSK";			//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"NATO_WINTER_STATIC_AA";
blufor_TURRET_AT =				"NATO_WINTER_STATIC_AT";
blufor_TURRET_HMG =				"NATO_WINTER_STATIC_HMG_HIGH";
blufor_TURRET_GMG =				"NATO_WINTER_STATIC_GMG_HIGH";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"NATO_WINTER_RECON";					//operator
blufor_SPECOPS_GL_X =			"NATO_WINTER_RECON_JTAC";				//operator
blufor_SPECOPS_LAT_X =			"NATO_WINTER_RECON_LAT";				//operator
blufor_SPECOPS_HAT_X =			"NATO_WINTER_SOLDIER_AT";				//operator
blufor_SPECOPS_AA_X =			"NATO_WINTER_SOLDIER_AA";				//operator
blufor_SPECOPS_MG_X =			"NATO_WINTER_SOLDIER_HEAVYGUNNER";		//operator
blufor_SPECOPS_MEDIC_X =		"NATO_WINTER_RECON_MEDIC";				//operator
blufor_SPECOPS_MARK_X =			"NATO_WINTER_RECON_M";					//operator
blufor_SPECOPS_SNIPER_X =		"NATO_WINTER_FULLGHILLEE";				//operator
blufor_SPECOPS_EXP_X =			"NATO_WINTER_RECON_EXP";				//operator
blufor_SPECOPS_ENG_X = 			"NATO_WINTER_SOLDIER_ENGINEER";			//operator





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


blufor_RQST_UNIT_01_X = 			["NATO_WINTER_SOLDIER","Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				["NATO_WINTER_SOLDIER_GL","Grenadier (3CP)",3];
blufor_RQST_UNIT_03_X =				["NATO_WINTER_SOLDIER_AR","Automatic Rifleman (3CP)",3];
blufor_RQST_UNIT_04_X =				["NATO_WINTER_SOLDIER_HEAVYGUNNER","Heavy Gunner (4CP)",4];
blufor_RQST_UNIT_05_X =				["NATO_WINTER_SOLDIER_MEDIC","Medic (4CP)",4];
blufor_RQST_UNIT_06_X =				["NATO_WINTER_SOLDIER_LAT","AT Rifleman (3CP)",3];
blufor_RQST_UNIT_07_X =				["NATO_WINTER_SOLDIER_AT","AT Specialist (4CP)",4];
blufor_RQST_UNIT_08_X =				["NATO_WINTER_SOLDIER_AA","AA Specialist (4CP)",4];
blufor_RQST_UNIT_09_X =				["NATO_WINTER_SOLDIER_ENGINEER","Engineer (4CP)",4];
blufor_RQST_UNIT_10_X =				["NATO_WINTER_SOLDIER_M","Marksman (3CP)",3];
blufor_RQST_UNIT_11_X =				["NATO_WINTER_SNIPER","Sniper (4CP)",4];
blufor_RQST_UNIT_12_X =				["empty",0,0];
blufor_RQST_UNIT_13_X =				["empty",0,0];
blufor_RQST_UNIT_14_X =				["empty",0,0];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////   

blufor_RQST_VEHICLE_01_X =			["NATO_WINTER_QUADBIKE","ATV (1CP)",1];
blufor_RQST_VEHICLE_02_X =			["C_Offroad_01_F","SF Offroader (2CP)",2];
blufor_RQST_VEHICLE_03_X =			["I_G_Van_01_transport_F","Transport Truck (6CP)",6];
blufor_RQST_VEHICLE_04_X =			["NATO_WINTER_MRAP","Hunter Unarmed (5CP)",5];
blufor_RQST_VEHICLE_05_X =			["NATO_WINTER_MRAP_HMG","Hunter HMG (18CP)",18];
blufor_RQST_VEHICLE_06_X =			["NATO_WINTER_MRAP_GMG","Hunter GMG (25CP)",25];
blufor_RQST_VEHICLE_07_X =			["NATO_WINTER_LSVU","Prowler Unarmed (5CP)",5];
blufor_RQST_VEHICLE_08_X =			["NATO_WINTER_LSV","Prowler HMG (15CP)",15];
blufor_RQST_VEHICLE_09_X =			["NATO_WINTER_LSVAT","Prowler AT (20CP)",20];
blufor_RQST_VEHICLE_10_X =			["NATO_WINTER_HEMTT_TRANSPORT","HEMTT Transport Uncovered (8CP)",8];
blufor_RQST_VEHICLE_11_X =			["NATO_WINTER_HEMTT_COVERED","HEMTT Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_12_X =			["NATO_WINTER_HEMTT_REPAIR","HEMTT Repair (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["NATO_WINTER_HEMTT_AMMO","HEMTT Ammo (50CP)",50];
blufor_RQST_VEHICLE_14_X =			["NATO_WINTER_HEMTT_FUEL","HEMTT Fuel (50CP)",50];
blufor_RQST_VEHICLE_15_X =			["NATO_WINTER_AMV","AMV-7 Marshall (35CP)",35];
blufor_RQST_VEHICLE_16_X =			["NATO_WINTER_AA","IFV-6a Cheetah (30CP)",30];
blufor_RQST_VEHICLE_17_X =			["NATO_WINTER_AFV","Rhino MGS (35CP)",35];
blufor_RQST_VEHICLE_18_X =			["NATO_WINTER_AFV_UP","Rhino MGS UP (35CP)",35];
blufor_RQST_VEHICLE_19_X =			["NATO_WINTER_CRV","CRV-6e Bobcat (28CP)",28];
blufor_RQST_VEHICLE_20_X =			["NATO_WINTER_APC","IFV-6c Panther (25CP)",25];
blufor_RQST_VEHICLE_21_X =			["NATO_WINTER_MBT","M2A1 Slammer (40CP)",40];
blufor_RQST_VEHICLE_22_X =			["NATO_WINTER_MBT_TUSK","M2A4 Slammer UP (40CP)",40];
blufor_RQST_VEHICLE_23_X =			["NATO_WINTER_ARTY","M4 Scorcher Artillery (75CP)",75];
blufor_RQST_VEHICLE_24_X =			["NATO_WINTER_MLRS","M5 Sandstorm MLRS (75CP)",75];
blufor_RQST_VEHICLE_25_X =			["NATO_WINTER_HELI_LIGHT_ARMED","AH-9 Pawnee (25CP)",25];
blufor_RQST_VEHICLE_26_X =			["NATO_WINTER_HELI_LIGHT","MH-9 Hummingbird (15CP)",15];
blufor_RQST_VEHICLE_27_X =			["NATO_WINTER_HELI_ATTACK","AH-99 Blackfoot (45CP)",45];
blufor_RQST_VEHICLE_28_X =			["B_T_VTOL_01_armed_F","V-44 X Armed (40CP",40];
blufor_RQST_VEHICLE_29_X =			["NATO_WINTER_HELI_TRANSPORT_GHOSTHAWK","UH-80 Ghosthawk (22CP)",22];
blufor_RQST_VEHICLE_30_X =			["NATO_WINTER_HELI_TRANSPORT_HURON_UNARMED","CH-67 Huron Unarmed (26CP)",26];
blufor_RQST_VEHICLE_31_X =			["NATO_WINTER_HELI_TRANSPORT_HURON","CH-67 Huron Armed (26CP)",26];
blufor_RQST_VEHICLE_32_X =			["B_Plane_CAS_01_dynamicLoadout_F","A-164 Wipeout CAS (45CP)",45];
blufor_RQST_VEHICLE_33_X =			["B_Plane_Fighter_01_F","FA-181 Black Wasp II (50CP)",50];
blufor_RQST_VEHICLE_34_X =			["B_Plane_Fighter_01_Stealth_F","FA-181 Black Wasp II Stealth (60CP)",60];
blufor_RQST_VEHICLE_35_X =			["NATO_WINTER_UAV_AR2","UAV Darter(5CP)",5];
blufor_RQST_VEHICLE_36_X =			["B_UAV_02_dynamicLoadout_F","UAV MQ-4A Greyhawk (15CP)",15];
blufor_RQST_VEHICLE_37_X =			["NATO_WINTER_UGV_","UGV Stomper Recon (10CP)",10];
blufor_RQST_VEHICLE_38_X =			["NATO_WINTER_UGV_RCWS","UGV Stomper RCWS (20CP)",20];
blufor_RQST_VEHICLE_39_X =			["B_T_UAV_03_dynamicLoadout_F","MQ-12 UAV (20CP)",20];
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



