
///////////////
///////////////   "RHSUSF_USMC", "RHS USMC (Desert) + RECON", "RHSUSF_USMC_D"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"rhsusf_usmc_marpat_d_rifleman";			//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"rhsusf_usmc_marpat_d_smaw";				//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"rhsusf_usmc_marpat_d_grenadier";			//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"rhsusf_usmc_marpat_d_teamleader";			//initHQ\fnc_createpatrolFOB, initHQ\fnc_HQguards
blufor_SOLDIER_SL_X =			"rhsusf_usmc_marpat_d_squadleader";			//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"rhsusf_usmc_marpat_d_autorifleman_m249";	//supports\fnc_paradrop, initHQ\fnc_HQguards
blufor_MARKSMAN_X = 			"rhsusf_usmc_marpat_d_marksman";			//initHQ\fnc_HQguards
blufor_OFFICER_X =				"rhsusf_usmc_marpat_d_officer";				//initHQ\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"rhsusf_usmc_marpat_d_helipilot";			//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"C_Man_UtilityWorker_01_F";			//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"rhsusf_CH53E_USMC_GAU21_D";		//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"RHS_UH1Y_d";  						//random patrol
blufor_HELI_ATTACK_X =			"RHS_AH1Z";							//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"RHS_A10";							//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"rhsusf_m1240a1_m2_usmc_d";			//random patrol
blufor_APC_PATROL1_X =			"rhsusf_stryker_m1126_m2_d";		//random patrol
blufor_APC_PATROL2_X =			"RHS_M2A3_BUSKIII";					//random patrol
blufor_TANK_PATROL1_X =			"rhsusf_m1a1fep_d";					//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"RHS_Stinger_AA_pod_D";
blufor_TURRET_AT =				"RHS_TOW_TriPod_D";
blufor_TURRET_HMG =				"B_G_HMG_02_high_F";
blufor_TURRET_GMG =				"B_G_HMG_02_high_F";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"rhsusf_usmc_recon_marpat_d_rifleman";		//operator
blufor_SPECOPS_GL_X =			"rhsusf_usmc_recon_marpat_d_grenadier_m32";	//operator
blufor_SPECOPS_LAT_X =			"rhsusf_usmc_marpat_d_smaw";		 		//operator 
blufor_SPECOPS_HAT_X =			"rhsusf_usmc_marpat_d_javelin";				//operator
blufor_SPECOPS_AA_X =			"rhsusf_usmc_marpat_d_stinger";				//operator
blufor_SPECOPS_MG_X =			"rhsusf_usmc_recon_marpat_d_machinegunner";	//operator
blufor_SPECOPS_MEDIC_X =		"rhsusf_navy_sarc_d";		 				//operator
blufor_SPECOPS_MARK_X =			"rhsusf_usmc_recon_marpat_d_marksman";		//operator
blufor_SPECOPS_SNIPER_X =		"rhsusf_usmc_recon_marpat_d_sniper_M107";	//operator
blufor_SPECOPS_EXP_X =			"rhsusf_usmc_marpat_d_explosives";			//operator
blufor_SPECOPS_ENG_X =			"rhsusf_usmc_marpat_d_engineer"; 			//operator





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


blufor_RQST_UNIT_01_X = 			["rhsusf_usmc_marpat_d_rifleman","Rifleman (USMC) (2CP)",2];
blufor_RQST_UNIT_02_X =				["rhsusf_usmc_marpat_d_grenadier","Grenadier (USMC) (3CP)",3];
blufor_RQST_UNIT_03_X =				["rhsusf_usmc_marpat_d_autorifleman_m249","Automatic Rifleman (USMC) (3CP)",3];
blufor_RQST_UNIT_04_X =				["rhsusf_usmc_marpat_d_machinegunner","Heavy Gunner (USMC) (4CP)",4];
blufor_RQST_UNIT_05_X =				["rhsusf_navy_marpat_d_medic","Medic (USMC) (4CP)",4];
blufor_RQST_UNIT_06_X =				["rhsusf_usmc_marpat_d_smaw","AT Rifleman (USMC) (3CP)",3];
blufor_RQST_UNIT_07_X =				["rhsusf_usmc_marpat_d_javelin","AT Specialist (USMC) (4CP)",4];
blufor_RQST_UNIT_08_X =				["rhsusf_usmc_marpat_d_stinger","AA Specialist (USMC) (4CP)",4];
blufor_RQST_UNIT_09_X =				["rhsusf_usmc_marpat_d_engineer","Engineer (USMC) (4CP)",4];
blufor_RQST_UNIT_10_X =				["rhsusf_usmc_marpat_d_marksman","Marksman (USMC) (3CP)",3];
blufor_RQST_UNIT_11_X =				["rhsusf_usmc_marpat_d_sniper","Sniper (USMC) (4CP)",4];
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
blufor_RQST_VEHICLE_04_X =			["rhsusf_m1043_d_s","HMMWV Unarmed (5CP)",5];
blufor_RQST_VEHICLE_05_X =			["rhsusf_m1043_d_s_m2","HMMWV HMG (15CP)",15];
blufor_RQST_VEHICLE_06_X =			["rhsusf_m1043_d_s_mk19","HMMWV GMG (20CP)",20];
blufor_RQST_VEHICLE_07_X =			["rhsusf_m1045_d_s","HMMWV TOW (25CP)",25];
blufor_RQST_VEHICLE_08_X =			["rhsusf_m1240a1_m2_usmc_d","M-1240 Oshkosh HMG (16CP)",16];
blufor_RQST_VEHICLE_09_X =			["rhsusf_CGRCAT1A2_M2_usmc_d","CGR MRAP CAT1A2 HMG (20CP)",20];
blufor_RQST_VEHICLE_10_X =			["rhsusf_CGRCAT1A2_Mk19_usmc_d","CGR MRAP CAT1A2 GMG (25CP)",25];
blufor_RQST_VEHICLE_11_X =			["rhsusf_M1083A1P2_D_fmtv_usarmy","M-1083 Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_12_X =			["rhsusf_M977A4_REPAIR_usarmy_d","M-977 Repair (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["rhsusf_M977A4_AMMO_usarmy_d","M-977 Ammo (50CP)",50];
blufor_RQST_VEHICLE_14_X =			["rhsusf_M978A4_usarmy_d","M-978 Fuel (50CP)",50];
blufor_RQST_VEHICLE_15_X =			["rhsusf_stryker_m1126_m2_d","M1126 Stryker HMG crows (25CP)",25];
blufor_RQST_VEHICLE_16_X =			["rhsusf_m113d_usarmy","M-113A3 HMG (28CP)",28];
blufor_RQST_VEHICLE_17_X =			["rhsusf_m113d_usarmy_MK19","M-113A3 GMG (30CP)",30];
blufor_RQST_VEHICLE_18_X =			["RHS_M2A2_BUSKI","M2A2 Bradley BUSK1 (35CP)",35];
blufor_RQST_VEHICLE_19_X =			["RHS_M2A3_BUSKIII","M2A3 Bradley BUSK3 (35CP)",35];
blufor_RQST_VEHICLE_20_X =			["RHS_M6","M6A2 Bradley (35CP)",35];
blufor_RQST_VEHICLE_21_X =			["rhsusf_m1a1fep_d","M1A1 FEP Tank (40CP)",40];
blufor_RQST_VEHICLE_22_X =			["rhsusf_m1a2sep1d_usarmy","M1A2 SEP (40CP)",40];
blufor_RQST_VEHICLE_23_X =			["rhsusf_m1a2sep1tuskiid_usarmy","M1A2 TUSK 3 (50CP)",50];
blufor_RQST_VEHICLE_24_X =			["rhsusf_M142_usarmy_D","M-142 HIMARS (50CP)",50];
blufor_RQST_VEHICLE_25_X =			["rhsusf_m109d_usarmy","M-109A6 Arty (75CP)",75];
blufor_RQST_VEHICLE_26_X =			["RHS_MELB_MH6M","MH-6M Littlebird (15CP)",15];
blufor_RQST_VEHICLE_27_X =			["RHS_MELB_AH6M","AH-6M Armed (25CP)",25];
blufor_RQST_VEHICLE_28_X =			["RHS_AH1Z","AH-1Z Viper (45CP)",45];
blufor_RQST_VEHICLE_29_X =			["RHS_UH60M_d","UH-60M Blackhawk Unarmed (22CP)",22];
blufor_RQST_VEHICLE_30_X =			["rhsusf_CH53E_USMC_GAU21_D","CH-53E Sea Stallion (26CP)",26];
blufor_RQST_VEHICLE_31_X =			["RHS_A10","A-10 Warthog (45CP)",45];
blufor_RQST_VEHICLE_32_X =			["rhsusf_f22","F-22 Raptor (50CP)",50];
blufor_RQST_VEHICLE_33_X =			["B_Plane_Fighter_01_Stealth_F","FA-181 Black Wasp II Stealth (60CP)",60];
blufor_RQST_VEHICLE_34_X =			["B_UAV_01_F","UAV Darter(5CP)",5];
blufor_RQST_VEHICLE_35_X =			["B_UAV_02_dynamicLoadout_F","UAV MQ-4A Greyhawk (15CP)",15];
blufor_RQST_VEHICLE_36_X =			["B_UGV_01_F","UGV Stomper Recon (10CP)",10];
blufor_RQST_VEHICLE_37_X =			["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20];
blufor_RQST_VEHICLE_38_X =			["B_T_UAV_03_dynamicLoadout_F","MQ-12 UAV (20CP)",20];
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

