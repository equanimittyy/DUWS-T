///////////////
///////////////   "TFC", "Task Force Canada (Tmpr-OTW) + USMC", "TFC_TEMP"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"TFC_C_Soldier_OTW_Rifleman_TW_F";			//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"TFC_C_Soldier_OTW_M72_TW_F";				//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"TFC_C_Soldier_OTW_Grenadier_TW_F";			//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"TFC_C_Soldier_OTW_IC_TW_F";				//initHQ\fnc_createpatrolFOB, initHQ\fnc_HQguards
blufor_SOLDIER_SL_X =			"TFC_C_Soldier_OTW_2IC_TW_F";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"TFC_C_Soldier_OTW_C9_TW_F";				//supports\fnc_paradrop, initHQ\fnc_HQguards
blufor_MARKSMAN_X = 			"TFC_C_Soldier_OTW_Rifleman_Lite_TW_F";		//initHQ\fnc_HQguards
blufor_OFFICER_X =				"TFC_C_Instructor_Army_Inf_TW";				//initHQ\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"TFC_C_Soldier_Aircrew_Pilot_Helo_TW_F";	//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"rhsusf_mkvsoc";			//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";			//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"TFC_CH146430_unarmed_F";					//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"TFC_CH146408_unarmed_F";   				//random patrol
blufor_HELI_ATTACK_X =			"TFC_CH146451_dynamicLoadout_F";			//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"RHS_A10";									//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"TFC_vs_luvw_armed_F";						//random patrol
blufor_APC_PATROL1_X =			"TFC_Wheeled_LAV6_ISC";						//random patrol
blufor_APC_PATROL2_X =			"TFC_Wheeled_LAV6_ISC";						//random patrol
blufor_TANK_PATROL1_X =			"TFC_Leopard2A_4_cannon_TW";				//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"RHS_Stinger_AA_pod_USMC_WD";
blufor_TURRET_AT =				"RHS_TOW_TriPod_USMC_WD";
blufor_TURRET_HMG =				"RHS_M2StaticMG_USMC_WD";
blufor_TURRET_GMG =				"B_G_HMG_02_high_F";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"TFC_C_Soldier_OTW_Rifleman_MT_F";				//operator
blufor_SPECOPS_GL_X =			"TFC_C_Soldier_OTW_Grenadier_MT_F";				//operator
blufor_SPECOPS_LAT_X =			"TFC_C_Soldier_OTW_M72_MT_F";					//operator
blufor_SPECOPS_HAT_X =			"TFC_C_Soldier_OTW_CarlG_MT_F";					//operator
blufor_SPECOPS_AA_X =			"TFC_C_Soldier_OTW_CarlG_MT_F";					//operator
blufor_SPECOPS_MG_X =			"TFC_C_Soldier_OTW_C9_MT_F";					//operator
blufor_SPECOPS_MEDIC_X =		"TFC_C_Soldier_OTW_Medic_MT_F";					//operator
blufor_SPECOPS_MARK_X =			"TFC_C_Soldier_OTW_Rifleman_Lite_MT_F";			//operator
blufor_SPECOPS_SNIPER_X =		"rhsusf_usmc_recon_marpat_wd_sniper_M107";		//operator
blufor_SPECOPS_EXP_X =			"TFC_C_Soldier_OTW_2IC_MT_F";					//operator
blufor_SPECOPS_ENG_X = 			"TFC_C_Soldier_OTW_Engineer_MT_F";				//operator





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


blufor_RQST_UNIT_01_X = 			["TFC_C_Soldier_OTW_Rifleman_TW_F","Rifleman (Temperate) (2CP)",2];
blufor_RQST_UNIT_02_X =				["TFC_C_Soldier_OTW_Grenadier_TW_F","Grenadier (Temperate) (3CP)",3];
blufor_RQST_UNIT_03_X =				["TFC_C_Soldier_OTW_C9_TW_F","Automatic Rifleman (Temperate) (3CP)",3];
blufor_RQST_UNIT_04_X =				["TFC_C_Soldier_OTW_C6_TW_F","Heavy Gunner (Temperate) (4CP)",4];
blufor_RQST_UNIT_05_X =				["TFC_C_Soldier_OTW_Medic_TW_F","Medic (Temperate) (4CP)",4];
blufor_RQST_UNIT_06_X =				["TFC_C_Soldier_OTW_M72_TW_F","Rifleman AT (Temperate) (4CP)",4];
blufor_RQST_UNIT_07_X =				["TFC_C_Soldier_OTW_CarlG_TW_F","AT Specialist (Temperate) (4CP)",4];
blufor_RQST_UNIT_08_X =				["TFC_C_Soldier_OTW_Engineer_TW_F","Engineer (Temperate) (4CP)",4];
blufor_RQST_UNIT_09_X =				["TFC_C_Soldier_OTW_Rifleman_Lite_TW_F","Marksman (Temperate) (3CP)",3];
blufor_RQST_UNIT_10_X =				["rhsusf_socom_marsoc_sniper_m107","Sniper (Temperate) (4CP)",4];
blufor_RQST_UNIT_11_X =				["TFC_C_soldier_OTW_Paratrooper_TW_F","Paratrooper (Temperate) (4CP)",4];
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
blufor_RQST_VEHICLE_04_X =			["rhsusf_m1043_w_s","HMMWV Unarmed (5CP)",5];
blufor_RQST_VEHICLE_05_X =			["rhsusf_m1151_m240_v3_usmc_wd","HMMWV HMG (15CP)",15];
blufor_RQST_VEHICLE_06_X =			["rhsusf_m1151_mk19_v3_usmc_wd","HMMWV GMG (20CP)",20];
blufor_RQST_VEHICLE_07_X =			["rhsusf_m1045_w_s","HMMWV TOW (25CP)",25];
blufor_RQST_VEHICLE_08_X =			["rhsusf_m1240a1_m240_usmc_wd","M-1240 Oshkosh HMG (16CP)",16];
blufor_RQST_VEHICLE_09_X =			["rhsusf_CGRCAT1A2_M2_usmc_wd","CGR MRAP CAT1A2 HMG (20CP)",20];
blufor_RQST_VEHICLE_10_X =			["rhsusf_CGRCAT1A2_Mk19_usmc_wd","CGR MRAP CAT1A2 GMG (25CP)",25];
blufor_RQST_VEHICLE_11_X =			["rhsusf_M1083A1P2_WD_fmtv_usarmy","M-1083 Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_12_X =			["rhsusf_M977A4_REPAIR_usarmy_wd","M-977 Repair (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["rhsusf_M977A4_AMMO_usarmy_wd","M-977 Ammo (50CP)",50];
blufor_RQST_VEHICLE_14_X =			["rhsusf_M978A4_usarmy_wd","M-978 Fuel (50CP)",50];
blufor_RQST_VEHICLE_15_X =			["rhsusf_stryker_m1126_m2_wd","M1126 Stryker HMG crows (25CP)",25];
blufor_RQST_VEHICLE_16_X =			["rhsusf_m113_usarmy","M-113A3 HMG (28CP)",28];
blufor_RQST_VEHICLE_17_X =			["rhsusf_m113_usarmy_MK19","M-113A3 GMG (30CP)",30];
blufor_RQST_VEHICLE_18_X =			["RHS_M2A2_BUSKI_wd","M2A2 Bradley BUSK1 (35CP)",35];
blufor_RQST_VEHICLE_19_X =			["RHS_M2A3_BUSKIII_wd","M2A3 Bradley BUSK3 (35CP)",35];
blufor_RQST_VEHICLE_20_X =			["RHS_M6_wd","M6A2 Bradley (35CP)",35];
blufor_RQST_VEHICLE_21_X =			["rhsusf_m1a1fep_wd","M1A1 FEP Tank (40CP)",40];
blufor_RQST_VEHICLE_22_X =			["rhsusf_m1a2sep1wd_usarmy","M1A2 SEP (40CP)",40];
blufor_RQST_VEHICLE_23_X =			["rhsusf_m1a2sep1tuskiiwd_usarmy","M1A2 TUSK 3 (50CP)",50];
blufor_RQST_VEHICLE_24_X =			["rhsusf_M142_usarmy_WD","M-142 HIMARS (50CP)",50];
blufor_RQST_VEHICLE_25_X =			["rhsusf_m109_usarmy","M-109A6 Arty (75CP)",75];
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
blufor_RQST_VEHICLE_39_X =			["TFC_vs_luvw_F","LUVW unarmed (5CP)",5];
blufor_RQST_VEHICLE_40_X =			["TFC_vs_luvw_armed_F","LUVW armed (15CP)",15];
blufor_RQST_VEHICLE_41_X =			["C_TFC_VS_LSVW_transport_uncovered_F","LSWV Transport Uncovered (8CP)",8];
blufor_RQST_VEHICLE_42_X =			["C_TFC_VS_LSVW_transport_covered_F","LSWV Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_43_X =			["TFC_Wheeled_LAV6_ISC","LAV 6.0 IFV (25CP)",25];
blufor_RQST_VEHICLE_44_X =			["TFC_Leopard2A_4_cannon_TW","Leopard2A4 (50CP)",50];
blufor_RQST_VEHICLE_45_X =			["TFC_CH146402_unarmed_F","CH146402 EGRESS Griffon (15CP)",15];
blufor_RQST_VEHICLE_46_X =			["TFC_CH146444_dynamicLoadout_F","CH146444 CAS Griffon (25CP)",25];
blufor_RQST_VEHICLE_47_X =			["TFC_AIR_CC130J_Cargo","CC130J Hercules Cargo (50CP)",50];
blufor_RQST_VEHICLE_48_X =			["TFC_AIR_CC130J","CC130J Hercules Troop Transport (50CP)",50];
blufor_RQST_VEHICLE_49_X =			["empty",0,0];
blufor_RQST_VEHICLE_50_X =			["empty",0,0];

