
///////////////
///////////////   "BLU_A_tna_F", "Aegis British - 2035 (Pacific)", "AEG_BLU_A_TNA_F"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"B_A_Soldier_TNA_F";					//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"B_A_Soldier_LAT_tna_F";				//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"B_A_Soldier_GL_tna_F";				//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"B_A_Soldier_TL_tna_F";				//initHQ\fnc_createpatrolFOB, initHQ\fnc_HQguards
blufor_SOLDIER_SL_X =			"B_A_Soldier_SL_tna_F";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"B_A_Soldier_AR_tna_F";				//supports\fnc_paradrop, initHQ\fnc_HQguards
blufor_MARKSMAN_X = 			"B_A_soldier_M_tna_F";				//initHQ\fnc_HQguards
blufor_OFFICER_X =				"B_A_OFFICER_tna_F";				//initHQ\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"B_A_Helipilot_tna_F";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_A_Boat_Armed_01_hmg_F";			//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"B_A_Heli_Light_03_dynamicloadout_F";		//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"B_A_Heli_Light_03_unarmed_F";   			//random patrol
blufor_HELI_ATTACK_X =			"B_A_Heli_Attack_01_dynamicloadout_F";		//dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"B_Plane_CAS_01_F";							//dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"B_A_LSV_01_armed_tna_F";					//random patrol
blufor_APC_PATROL1_X =			"B_A_MRAP_03_HMG_tna_F";					//random patrol
blufor_APC_PATROL2_X =			"B_A_APC_tracked_03_cannon_v2_tna_F";		//random patrol
blufor_TANK_PATROL1_X =			"B_T_MBT_01_cannon_F";						//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"B_A_static_AA_tna_F";
blufor_TURRET_AT =				"B_A_static_AT_tna_F";
blufor_TURRET_HMG =				"B_A_HMG_02_high_tna_F";
blufor_TURRET_GMG =				"B_A_GMG_01_high_tna_F";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"B_A_recon_tna_F";					//operator
blufor_SPECOPS_GL_X =			"B_A_recon_JTAC_tna_F";				//operator
blufor_SPECOPS_LAT_X =			"B_A_recon_LAT_tna_F";				//operator
blufor_SPECOPS_HAT_X =			"B_A_Soldier_AT_tna_F";		//operator
blufor_SPECOPS_AA_X =			"B_A_soldier_AA_tna_F";				//operator
blufor_SPECOPS_MG_X =			"B_A_Recon_MG_tna_F";		//operator
blufor_SPECOPS_MEDIC_X =		"B_A_recon_medic_tna_F";				//operator
blufor_SPECOPS_MARK_X =			"B_A_recon_M_tna_F";					//operator
blufor_SPECOPS_SNIPER_X =		"B_A_Recon_Sharpshooter_tna_F";					//operator
blufor_SPECOPS_EXP_X =			"B_A_recon_exp_tna_F";				//operator
blufor_SPECOPS_ENG_X = 			"B_A_Engineer_tna_F";			//operator





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


blufor_RQST_UNIT_01_X = 			["B_A_Soldier_tna_F","Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				["B_A_Soldier_GL_tna_F","Grenadier (3CP)",3];
blufor_RQST_UNIT_03_X =				["B_A_Soldier_AR_tna_F","Automatic Rifleman (3CP)",3];
blufor_RQST_UNIT_04_X =				["B_A_HeavyGunner_tna_F","Heavy Gunner (4CP)",4];
blufor_RQST_UNIT_05_X =				["B_A_Medic_tna_F","Medic (4CP)",4];
blufor_RQST_UNIT_06_X =				["B_A_Soldier_LAT_tna_F","AT Rifleman (3CP)",3];
blufor_RQST_UNIT_07_X =				["B_A_Soldier_AT_tna_F","AT Specialist (4CP)",4];
blufor_RQST_UNIT_08_X =				["B_A_soldier_AA_tna_F","AA Specialist (4CP)",4];
blufor_RQST_UNIT_09_X =				["B_A_Engineer_tna_F","Engineer (4CP)",4];
blufor_RQST_UNIT_10_X =				["B_A_soldier_M_tna_F","Marksman (3CP)",3];
blufor_RQST_UNIT_11_X =				["B_A_sniper_tna_F","Sniper (4CP)",4];
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
blufor_RQST_VEHICLE_03_X =			["B_A_APC_TRACKED_03_CANNON_v2_tna_F","Lancer APC (30CP)",30];
blufor_RQST_VEHICLE_04_X =			["B_A_MRAP_03_tna_F","Strider Unarmed (5CP)",5];
blufor_RQST_VEHICLE_05_X =			["B_A_MRAP_03_hmg_tna_F","Strider HMG (18CP)",18];
blufor_RQST_VEHICLE_06_X =			["B_A_MRAP_03_gmg_tna_F","Strider GMG (25CP)",25];
blufor_RQST_VEHICLE_07_X =			["B_LSV_01_unarmed_tna_F","Prowler Unarmed (5CP)",5];
blufor_RQST_VEHICLE_08_X =			["B_LSV_01_armed_tna_F","Prowler HMG (15CP)",15];
blufor_RQST_VEHICLE_09_X =			["B_LSV_01_tna_AT_F","Prowler AT (20CP)",20];
blufor_RQST_VEHICLE_10_X =			["B_T_Truck_01_transport_F","HEMTT Transport Uncovered (8CP)",8];
blufor_RQST_VEHICLE_11_X =			["B_T_Truck_01_covered_F","HEMTT Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_12_X =			["B_T_Truck_01_Repair_F","HEMTT Repair (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["B_T_Truck_01_ammo_F","HEMTT Ammo (50CP)",50];
blufor_RQST_VEHICLE_14_X =			["B_T_Truck_01_fuel_F","HEMTT Fuel (50CP)",50];
blufor_RQST_VEHICLE_15_X =			["B_T_APC_Wheeled_01_cannon_F","AMV-7 Marshall (35CP)",35];
blufor_RQST_VEHICLE_16_X =			["B_T_APC_Tracked_01_AA_F","IFV-6c Cheetah (30CP)",30];
blufor_RQST_VEHICLE_17_X =			["B_T_AFV_Wheeled_01_cannon_F","Rhino MGS (35CP)",35];
blufor_RQST_VEHICLE_18_X =			["B_T_AFV_Wheeled_01_up_cannon_F","Rhino MGS UP (35CP)",35];
blufor_RQST_VEHICLE_19_X =			["B_T_APC_Tracked_01_CRV_F","CRV-6e Bobcat (28CP)",28];
blufor_RQST_VEHICLE_20_X =			["B_T_APC_Tracked_01_rcws_F","IFV-6c Panther (25CP)",25];
blufor_RQST_VEHICLE_21_X =			["I_APC_Wheeled_03_cannon_F","AFV-4 Gorgon (35CP)",35];
blufor_RQST_VEHICLE_22_X =			["B_T_MBT_01_cannon_F","M2A1 Slammer (40CP)",40];
blufor_RQST_VEHICLE_23_X =			["B_T_MBT_01_TUSK_F","M2A4 Slammer UP (40CP)",40];
blufor_RQST_VEHICLE_24_X =			["I_MBT_03_cannon_F","MBT-52 Kuma (50CP)",50];
blufor_RQST_VEHICLE_25_X =			["B_T_MBT_01_arty_F","M4 Scorcher Artillery (75CP)",75];
blufor_RQST_VEHICLE_26_X =			["B_T_MBT_01_mlrs_F","M5 Sandstorm MLRS (75CP)",75];
blufor_RQST_VEHICLE_27_X =			["B_Heli_Light_01_dynamicLoadout_F","AH-9 Pawnee (25CP)",25];
blufor_RQST_VEHICLE_28_X =			["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15];
blufor_RQST_VEHICLE_29_X =			["B_Heli_Attack_01_dynamicLoadout_F","AH-99 Blackfoot (45CP)",45];
blufor_RQST_VEHICLE_30_X =			["B_T_VTOL_01_armed_F","V-44 X Armed (40CP",40];
blufor_RQST_VEHICLE_31_X =			["B_Heli_Transport_01_F","UH-80 Ghosthawk (22CP)",22];
blufor_RQST_VEHICLE_32_X =			["B_Heli_Transport_03_unarmed_F","CH-67 Huron Unarmed (26CP)",26];
blufor_RQST_VEHICLE_33_X =			["B_Heli_Transport_03_F","CH-67 Huron Armed (26CP)",26];
blufor_RQST_VEHICLE_34_X =			["B_Plane_CAS_01_dynamicLoadout_F","A-164 Wipeout CAS (45CP)",45];
blufor_RQST_VEHICLE_35_X =			["B_Plane_Fighter_01_F","FA-181 Black Wasp II (50CP)",50];
blufor_RQST_VEHICLE_36_X =			["B_Plane_Fighter_01_Stealth_F","FA-181 Black Wasp II Stealth (60CP)",60];
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


