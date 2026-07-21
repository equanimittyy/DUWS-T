
///////////////
///////////////   "BWA3", "BWA3 German Bundeswehr + KSK (Desert)", "BWA3_DES"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"BWA3_Rifleman_G27_Tropen";			//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"BWA3_RiflemanAT_RGW90_Tropen";		//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"BWA3_Grenadier_G27_Tropen";		//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"BWA3_TL_Tropen";					//initHQ\fnc_createpatrolFOB, initHQ\fnc_HQguards
blufor_SOLDIER_SL_X =			"BWA3_SL_Tropen";					//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"BWA3_MachineGunner_MG5_Tropen";	//supports\fnc_paradrop, initHQ\fnc_HQguards
blufor_MARKSMAN_X = 			"BWA3_Marksman_Tropen";				//initHQ\fnc_HQguards
blufor_OFFICER_X =				"BWA3_Officer_Tropen";				//initHQ\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"BWA3_Helipilot";					//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"NH_90_Trop";							//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"B_Heli_Transport_01_F";   						//random patrol
blufor_HELI_ATTACK_X =			"BWA3_Tiger_RMK_Heavy";					//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"B_Plane_CAS_01_dynamicLoadout_F";		//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"BWA3_Dingo2_FLW100_MG3_CG13_Tropen";				//random patrol
blufor_APC_PATROL1_X =			"KGB_B_MRAP_03_hmg_F_DES";						//random patrol
blufor_APC_PATROL2_X =			"BWA3_Puma_Tropen";						//random patrol
blufor_TANK_PATROL1_X =			"BWA3_Leopard2_Tropen";					//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"B_static_AA_F";
blufor_TURRET_AT =				"B_static_AT_F";
blufor_TURRET_HMG =				"B_G_HMG_02_high_F";
blufor_TURRET_GMG =				"B_GMG_01_high_F";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"BWA3_recon_Tropen";					//operator
blufor_SPECOPS_GL_X =			"BWA3_Grenadier_G27_Tropen";			//operator
blufor_SPECOPS_LAT_X =			"BWA3_recon_LAT_Tropen";				//operator
blufor_SPECOPS_HAT_X =			"BWA3_RiflemanAT_PzF3_Tropen";			//operator
blufor_SPECOPS_AA_X =			"BWA3_RiflemanAA_Fliegerfaust_Tropen";	//operator
blufor_SPECOPS_MG_X =			"BWA3_MachineGunner_MG5_Tropen";		//operator
blufor_SPECOPS_MEDIC_X =		"BWA3_recon_Medic_Tropen";				//operator
blufor_SPECOPS_MARK_X =			"BWA3_recon_Marksman_Tropen";			//operator
blufor_SPECOPS_SNIPER_X =		"BWA3_Sniper_G29_Tropen";				//operator
blufor_SPECOPS_EXP_X =			"BWA3_recon_Pioneer_Tropen";			//operator
blufor_SPECOPS_ENG_X = 			"BWA3_recon_Pioneer_Tropen";			//operator





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


blufor_RQST_UNIT_01_X = 			["BWA3_Rifleman_G27_Tropen","Rifleman (Desert) (2CP)",2];
blufor_RQST_UNIT_02_X =				["BWA3_Grenadier_G27_Tropen","Grenadier (Desert) (3CP)",3];
blufor_RQST_UNIT_03_X =				["BWA3_MachineGunner_MG3_Tropen","Automatic Rifleman (Desert) (3CP)",3];
blufor_RQST_UNIT_04_X =				["BWA3_MachineGunner_MG5_Tropen","Heavy Gunner (Desert) (4CP)",4];
blufor_RQST_UNIT_05_X =				["BWA3_Medic_Tropen","Medic (Desert) (4CP)",4];
blufor_RQST_UNIT_06_X =				["BWA3_RiflemanAT_RGW90_Tropen","AT Specialist (Desert) (4CP)",4];
blufor_RQST_UNIT_07_X =				["BWA3_RiflemanAA_Fliegerfaust_Tropen","AA Specialist (Desert) (4CP)",4];
blufor_RQST_UNIT_08_X =				["BWA3_Engineer_Tropen","Engineer (Desert) (4CP)",4];
blufor_RQST_UNIT_09_X =				["BWA3_Marksman_Tropen","Marksman (Desert) (3CP)",3];
blufor_RQST_UNIT_10_X =				["BWA3_Sniper_G29_Tropen","Sniper (Desert) (4CP)",4];
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
blufor_RQST_VEHICLE_04_X =			["B_LSV_01_unarmed_F","Prowler Unarmed (5CP)",5];
blufor_RQST_VEHICLE_05_X =			["B_LSV_01_armed_F","Prowler HMG (15CP)",15];
blufor_RQST_VEHICLE_06_X =			["B_LSV_01_AT_F","Prowler AT (20CP)",20];
blufor_RQST_VEHICLE_07_X =			["BWA3_Eagle_Tropen","Eagle Unarmed (5CP)",5];
blufor_RQST_VEHICLE_08_X =			["BWA3_Eagle_FLW100_Tropen","Eagle IV HMG (15CP)",15];
blufor_RQST_VEHICLE_09_X =			["BWA3_Dingo2_FLW200_M2_CG13_Tropen","Dingo 2-GE M2 (18CP)",18];
blufor_RQST_VEHICLE_10_X =			["BWA3_Dingo2_FLW100_MG3_CG13_Tropen","Dingo 2-GE MG3 (18CP)",18];
blufor_RQST_VEHICLE_11_X =			["BWA3_Dingo2_FLW200_GMW_CG13_Tropen","Dingo 2-GE GMG (20CP)",20];
blufor_RQST_VEHICLE_12_X =			["KGB_B_MRAP_03_F_DES","Fennek Unarmed (8CP)",8];
blufor_RQST_VEHICLE_13_X =			["KGB_B_MRAP_03_hmg_F_DES","Fennek HMG (18CP)",18];
blufor_RQST_VEHICLE_14_X =			["KGB_B_MRAP_03_gmg_F_DES","Fennek GMG (20CP)",20];
blufor_RQST_VEHICLE_15_X =			["BW_LKW_Transport_offen_Tropen","LKW Transport Uncovered (8CP)",8];
blufor_RQST_VEHICLE_16_X =			["BW_LKW_Transport_Tropen","LKW Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_17_X =			["BW_LKW_Reparatur_Tropen","LKW Repair Truck(50CP)",50];
blufor_RQST_VEHICLE_18_X =			["BW_LKW_Munition_Tropen","LKW Ammo Truck (50CP)",50];
blufor_RQST_VEHICLE_19_X =			["BW_LKW_Treibstoff_Tropen","LKW Fuel Truck (50CP)",50];
blufor_RQST_VEHICLE_20_X =			["BWA3_Puma_Tropen","Puma IFV (35CP)",35];
blufor_RQST_VEHICLE_21_X =			["B_APC_Tracked_01_rcws_F","IFV-6c Panther (25CP)",25];
blufor_RQST_VEHICLE_22_X =			["B_APC_Tracked_01_CRV_F","CRV-6e Bobcat (28CP)",28];
blufor_RQST_VEHICLE_23_X =			["B_APC_Tracked_01_AA_F","IFV-6c Cheetah (35CP)",35];
blufor_RQST_VEHICLE_24_X =			["B_APC_Wheeled_01_cannon_F","AMV-7 Marshall (35CP)",35];
blufor_RQST_VEHICLE_25_X =			["B_MBT_01_cannon_F","M2A1 Slammer (40CP)",40];
blufor_RQST_VEHICLE_26_X =			["BWA3_Leopard2_Tropen","Leopard 2 MBT (50CP)",50];
blufor_RQST_VEHICLE_27_X =			["B_MBT_01_arty_F","M4 Scorcher (75CP)",75];
blufor_RQST_VEHICLE_28_X =			["B_MBT_01_mlrs_F","M5 Sandstorm MLRS (75CP)",75];
blufor_RQST_VEHICLE_29_X =			["MH6_Littlebird_BW_Tropen","MH-6 Littlebird (15CP)",15];
blufor_RQST_VEHICLE_30_X =			["AH6_Littlebird_BW_Tropen","AH-6 Littlebird Armed (25CP)",25];
blufor_RQST_VEHICLE_31_X =			["AW159_BW_Trop_Unbewaffnet","AW-159 Wildcat Trans (22CP)",22];
blufor_RQST_VEHICLE_32_X =			["AW159_BW_Trop","AW-159 Wildcat Gunship (26CP)",26];
blufor_RQST_VEHICLE_33_X =			["NH_90_Trop","NH-90 Trans Heli (30CP)",30];
blufor_RQST_VEHICLE_34_X =			["BWA3_Tiger_RMK_Heavy","UH Tiger RMK Heavy (45CP)",45];
blufor_RQST_VEHICLE_35_X =			["B_T_VTOL_01_armed_F","V-44 X Armed (40CP",40];
blufor_RQST_VEHICLE_36_X =			["B_Plane_CAS_01_dynamicLoadout_F","A-164 Wipeout (45CP)",45];
blufor_RQST_VEHICLE_37_X =			["B_Plane_Fighter_01_F","FA-181 Black Wasp (50CP)",50];
blufor_RQST_VEHICLE_38_X =			["B_UAV_01_F","UAV Darter(5CP)",5];
blufor_RQST_VEHICLE_39_X =			["B_UAV_02_dynamicLoadout_F","UAV MQ-4A Greyhawk (15CP)",15];
blufor_RQST_VEHICLE_40_X =			["B_UGV_01_F","UGV Stomper Recon (10CP)",10];
blufor_RQST_VEHICLE_41_X =			["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20];
blufor_RQST_VEHICLE_42_X =			["B_T_UAV_03_dynamicLoadout_F","MQ-12 UAV (20CP)",20];
blufor_RQST_VEHICLE_43_X =			["empty",0,0];
blufor_RQST_VEHICLE_44_X =			["empty",0,0];
blufor_RQST_VEHICLE_45_X =			["empty",0,0];
blufor_RQST_VEHICLE_46_X =			["empty",0,0];
blufor_RQST_VEHICLE_47_X =			["empty",0,0];
blufor_RQST_VEHICLE_48_X =			["empty",0,0];
blufor_RQST_VEHICLE_49_X =			["empty",0,0];
blufor_RQST_VEHICLE_50_X =			["empty",0,0];


