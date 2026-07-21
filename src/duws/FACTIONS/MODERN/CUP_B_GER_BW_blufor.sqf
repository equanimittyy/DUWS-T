
///////////////
///////////////   "CUP_B_GER", "German Bundeswehr + KSK Desert", "CUP_B_GER_BW"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"CUP_B_GER_BW_Soldier";					//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"CUP_B_GER_BW_Soldier_AT";				//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"CUP_B_GER_BW_Soldier_GL";				//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"CUP_B_GER_BW_Soldier_TL";				//initHQ\fnc_createpatrolFOB, initHQ\fnc_HQguards
blufor_SOLDIER_SL_X =			"CUP_B_GER_BW_Soldier_TL";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"CUP_B_GER_BW_Soldier_MG";				//supports\fnc_paradrop, initHQ\fnc_HQguards
blufor_MARKSMAN_X = 			"CUP_B_GER_BW_Soldier_Marksman";		//initHQ\fnc_HQguards
blufor_OFFICER_X =				"CUP_B_GER_Soldier_TL";					//initHQ\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CUP_B_GER_HPilot";						//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";			//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";						//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CUP_B_UH1D_gunship_GER_KSK_Des";		//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"CUP_B_CH53E_GER";   					//random patrol
blufor_HELI_ATTACK_X =			"CUP_B_UH1D_gunship_GER_KSK_Des";		//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"CUP_B_A10_DYN_USA";					//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"CUP_B_Dingo_GER_Des";					//random patrol
blufor_APC_PATROL1_X =			"CUP_I_FENNEK_HMG_ION";					//random patrol        
blufor_APC_PATROL2_X =			"CUP_B_Boxer_HMG_GER_DES";				//random patrol     
blufor_TANK_PATROL1_X =			"CUP_B_Leopard2A6DST_GER";				//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"CUP_B_CUP_Stinger_AA_pod_US";
blufor_TURRET_AT =				"CUP_B_TOW_TriPod_US";
blufor_TURRET_HMG =				"B_G_HMG_02_high_F";
blufor_TURRET_GMG =				"B_G_HMG_02_high_F";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"CUP_B_GER_Soldier";				//operator
blufor_SPECOPS_GL_X =			"CUP_B_GER_Operator_GL";			//operator
blufor_SPECOPS_LAT_X =			"CUP_B_GER_Soldier_AT";				//operator
blufor_SPECOPS_HAT_X =			"CUP_B_GER_Soldier_AT";				//operator
blufor_SPECOPS_AA_X =			"CUP_B_GER_Soldier_AA";				//operator
blufor_SPECOPS_MG_X =			"CUP_B_GER_Soldier_MG3";			//operator
blufor_SPECOPS_MEDIC_X =		"CUP_B_GER_Operator_Medic";			//operator
blufor_SPECOPS_MARK_X =			"CUP_B_GER_BW_Soldier_Marksman";	//operator
blufor_SPECOPS_SNIPER_X =		"CUP_B_GER_Soldier_Sniper";			//operator
blufor_SPECOPS_EXP_X =			"CUP_B_GER_Operator_EXP";			//operator
blufor_SPECOPS_ENG_X = 			"CUP_B_GER_Soldier_Engineer";		//operator





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


blufor_RQST_UNIT_01_X = 			["CUP_B_GER_BW_Soldier","Rifleman (Desert) (2CP)",2];
blufor_RQST_UNIT_02_X =				["CUP_B_GER_BW_Soldier_GL","Grenadier (Desert) (3CP)",3];
blufor_RQST_UNIT_03_X =				["CUP_B_GER_BW_Soldier_MG","Automatic Rifleman (Desert) (3CP)",3];
blufor_RQST_UNIT_04_X =				["CUP_B_GER_BW_Soldier_MG3","Heavy Gunner (Desert) (4CP)",4];
blufor_RQST_UNIT_05_X =				["CUP_B_GER_BW_Medic","Medic (Desert) (4CP)",4];
blufor_RQST_UNIT_06_X =				["CUP_B_GER_BW_Soldier_AT","AT Specialist (Desert) (4CP)",4];
blufor_RQST_UNIT_07_X =				["CUP_B_GER_BW_Soldier_AA","AA Specialist (Desert) (4CP)",4];
blufor_RQST_UNIT_08_X =				["CUP_B_GER_BW_Soldier_Engineer","Engineer (Desert) (4CP)",4];
blufor_RQST_UNIT_09_X =				["CUP_B_GER_BW_Soldier_Marksman","Marksman (Desert) (3CP)",3];
blufor_RQST_UNIT_10_X =				["CUP_B_GER_BW_Soldier_Sniper","Sniper (Desert) (4CP)",4];
blufor_RQST_UNIT_11_X =				["empty",0,0];
blufor_RQST_UNIT_12_X =				["empty",0,0];
blufor_RQST_UNIT_13_X =				["empty",0,0];
blufor_RQST_UNIT_14_X =				["empty",0,0];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////

blufor_RQST_VEHICLE_01_X =			["B_Quadbike_01_F","ATV (1CP)",1];
blufor_RQST_VEHICLE_02_X =			["C_Offroad_01_F","SF Offroader (2CP)",2];
blufor_RQST_VEHICLE_03_X =			["I_G_Van_01_transport_F","Transport Truck (6CP)",6];
blufor_RQST_VEHICLE_04_X =			["B_MRAP_01_F","Hunter Unarmed (5CP)",5];
blufor_RQST_VEHICLE_05_X =			["CUP_B_Dingo_GER_Des","Dingo HMG (18CP)",18];
blufor_RQST_VEHICLE_06_X =			["CUP_B_Dingo_GL_GER_Des","Dingo GMG (25CP)",25];
blufor_RQST_VEHICLE_07_X =			["CUP_B_FENNEK_GER_Des","Fennek Unarmed (8CP)",8];
blufor_RQST_VEHICLE_08_X =			["CUP_I_FENNEK_HMG_ION","Fennek HMG (15CP)",15];
blufor_RQST_VEHICLE_09_X =			["B_LSV_01_AT_F","Prowler AT (20CP)",20];
blufor_RQST_VEHICLE_10_X =			["B_Truck_01_transport_F","HEMTT Transport Uncovered (8CP)",8];
blufor_RQST_VEHICLE_11_X =			["B_Truck_01_covered_F","HEMTT Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_12_X =			["B_Truck_01_Repair_F","HEMTT Repair (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["B_Truck_01_ammo_F","HEMTT Ammo (50CP)",50];
blufor_RQST_VEHICLE_14_X =			["B_Truck_01_fuel_F","HEMTT Fuel (50CP)",50];
blufor_RQST_VEHICLE_15_X =			["B_APC_Wheeled_01_cannon_F","AMV-7 Marshall (35CP)",35];
blufor_RQST_VEHICLE_16_X =			["O_APC_Wheeled_02_rcws_v2_F","MSE-3 Marid (35CP)",35];
blufor_RQST_VEHICLE_17_X =			["CUP_B_Boxer_HMG_GER_DES","GTK Boxer HMG (35CP)",35];
blufor_RQST_VEHICLE_18_X =			["CUP_B_Boxer_GMG_GER_DES","GTK Boxer GMG (35CP)",35];
blufor_RQST_VEHICLE_19_X =			["B_APC_Tracked_01_CRV_F","CRV-6e Bobcat (28CP)",28];
blufor_RQST_VEHICLE_20_X =			["B_APC_Tracked_01_rcws_F","IFV-6c Panther (25CP)",25];
blufor_RQST_VEHICLE_21_X =			["B_APC_Tracked_01_AA_F","IFV-6c Cheetah (35CP)",35];
blufor_RQST_VEHICLE_22_X =			["B_MBT_01_cannon_F","M2A1 Slammer (40CP)",40];
blufor_RQST_VEHICLE_23_X =			["CUP_B_M1A2_TUSK_MG_DES_US_Army","M1A2 TUSK (40CP)",40];
blufor_RQST_VEHICLE_24_X =			["CUP_B_Leopard2A6DST_GER","Leopard 2A6 Desert (50CP)",50];
blufor_RQST_VEHICLE_25_X =			["B_MBT_01_arty_F","M4 Scorcher Artillery (75CP)",75];
blufor_RQST_VEHICLE_26_X =			["B_MBT_01_mlrs_F","M5 Sandstorm MLRS (75CP)",75];
blufor_RQST_VEHICLE_27_X =			["B_Heli_Light_01_dynamicLoadout_F","AH-9 Pawnee (25CP)",25];
blufor_RQST_VEHICLE_28_X =			["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15];
blufor_RQST_VEHICLE_29_X =			["CUP_B_UH1D_slick_GER_KSK_Des","UH-1D Heli Slick (22CP)",22];
blufor_RQST_VEHICLE_30_X =			["CUP_B_UH1D_gunship_GER_KSK_Des","UH-1D Gunship (26CP)",26];
blufor_RQST_VEHICLE_31_X =			["CUP_B_AH1_DL_BAF","AH-1H Cobra (45CP)",45];
blufor_RQST_VEHICLE_32_X =			["CUP_B_CH53E_GER","CH-53 Super Stallion (30CP)",30];
blufor_RQST_VEHICLE_33_X =			["B_T_VTOL_01_armed_F","V-44 X Armed (40CP",40];
blufor_RQST_VEHICLE_34_X =			["CUP_B_A10_DYN_USA","A-10 Warthog (45CP)",45];
blufor_RQST_VEHICLE_35_X =			["CUP_B_AV8B_DYN_USMC","AV-8B Harrier (50CP)",50];
blufor_RQST_VEHICLE_36_X =			["CUP_B_F35B_USMC","F-35B Lightning (55CP)",55];
blufor_RQST_VEHICLE_37_X =			["B_UAV_01_F","UAV Darter(5CP)",5];
blufor_RQST_VEHICLE_38_X =			["B_UAV_02_dynamicLoadout_F","UAV MQ-4A Greyhawk (15CP)",15];
blufor_RQST_VEHICLE_39_X =			["B_UGV_01_F","UGV Stomper Recon (10CP)",10];
blufor_RQST_VEHICLE_40_X =			["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20];
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


