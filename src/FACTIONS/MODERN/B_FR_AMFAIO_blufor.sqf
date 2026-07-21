
///////////////
///////////////   "B_FR", "AMF AIO French Army (T3 camo)", "B_FR_AMFAIO"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"B_FR_Fusilier_01";						//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"B_FR_Fusilier_AC_01";					//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"B_FR_Grenadier_01";					//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"B_FR_Chef_dEquipe_01";					//initHQ\fnc_createpatrolFOB, initHQ\fnc_HQguards
blufor_SOLDIER_SL_X =			"B_FR_Chef_de_groupe_01";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"B_FR_Gunner_01";						//supports\fnc_paradrop, initHQ\fnc_HQguards
blufor_MARKSMAN_X = 			"B_BFR_Tireur_de_precision_SCAR_H_01";		//initHQ\fnc_HQguards
blufor_OFFICER_X =				"B_BFR_Officier_01";					//initHQ\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"B_FR_Pilote_helico_01";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";			//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";						//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"B_FR_H225_MCaracal_01";				//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"B_FR_AS565_Panther_Marine_Nationale_01";   	//random patrol
blufor_HELI_ATTACK_X =			"B_FR_Helico_dattaque_01";				//dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"B_Plane_CAS_01_dynamicLoadout_F";		//dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"B_FR_VAB_Ultima_TOP_01";				//random patrol
blufor_APC_PATROL1_X =			"B_FR_Marshall_01";						//random patrol
blufor_APC_PATROL2_X =			"B_FR_AMX_10_RCR_SEPAR_01";				//random patrol
blufor_TANK_PATROL1_X =			"B_FR_Leclerc_01";						//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"B_FR_Poste_de_Tir_AA_01";
blufor_TURRET_AT =				"B_FR_Poste_de_tir_AC_01";
blufor_TURRET_HMG =				"B_G_HMG_02_high_F";
blufor_TURRET_GMG =				"B_GMG_01_high_F";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"B_FR_Fusilier_01";				//operator
blufor_SPECOPS_GL_X =			"B_FR_Grenadier_01";			//operator
blufor_SPECOPS_LAT_X =			"B_FR_Fusilier_AC_01";			//operator
blufor_SPECOPS_HAT_X =			"B_FR_Fusilier_Missile_01";		//operator
blufor_SPECOPS_AA_X =			"B_soldier_AA_F";				//operator
blufor_SPECOPS_MG_X =			"B_FR_Gunner_01";				//operator
blufor_SPECOPS_MEDIC_X =		"B_FR_Infirmier_01";			//operator
blufor_SPECOPS_MARK_X =			"B_BFR_Tireur_de_precision_SCAR_H_01";		//operator
blufor_SPECOPS_SNIPER_X =		"B_FR_AMF_Tireur_dElite_01";				//operator
blufor_SPECOPS_EXP_X =			"B_recon_exp_F";				//operator
blufor_SPECOPS_ENG_X = 			"B_FR_Sapeur_01";				//operator





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


blufor_RQST_UNIT_01_X = 			["B_FR_Fusilier_01","Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				["B_FR_Grenadier_01","Grenadier (3CP)",3];
blufor_RQST_UNIT_03_X =				["B_FR_Fusilier_auto_01","Automatic Rifleman (3CP)",3];
blufor_RQST_UNIT_04_X =				["B_FR_Gunner_01","Heavy Gunner (4CP)",4];
blufor_RQST_UNIT_05_X =				["B_FR_Infirmier_01","Medic (4CP)",4];
blufor_RQST_UNIT_06_X =				["B_FR_Fusilier_AC_01","AT Rifleman (3CP)",3];
blufor_RQST_UNIT_07_X =				["B_FR_Fusilier_Missile_01","AT Specialist (4CP)",4];
blufor_RQST_UNIT_08_X =				["B_FR_Sapeur_01","Engineer (4CP)",4];
blufor_RQST_UNIT_09_X =				["B_FR_Spotteur_01","Spotter (3CP)",3];
blufor_RQST_UNIT_10_X =				["B_BFR_Tireur_de_precision_SCAR_H_01","Marksman (3CP)",3];
blufor_RQST_UNIT_11_X =				["B_FR_AMF_Tireur_dElite_01","Sniper (4CP)",4];
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
blufor_RQST_VEHICLE_05_X =			["B_FR_VAB_Ultima_01","VAB Ultima Unarmed (15CP)",15];
blufor_RQST_VEHICLE_06_X =			["B_FR_VAB_Ultima_TOP_01","VAB Ultima  HMG (20CP)",20];
blufor_RQST_VEHICLE_07_X =			["B_LSV_01_unarmed_F","Prowler Unarmed (5CP)",5];
blufor_RQST_VEHICLE_08_X =			["B_LSV_01_armed_F","Prowler HMG (15CP)",15];
blufor_RQST_VEHICLE_09_X =			["B_LSV_01_AT_F","Prowler AT (20CP)",20];
blufor_RQST_VEHICLE_10_X =			["B_Truck_01_transport_F","HEMTT Transport Uncovered (8CP)",8];
blufor_RQST_VEHICLE_11_X =			["B_FR_Zamak_Transport_couvert_01","Zamak Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_12_X =			["B_FR_Zamak_Maintenance_01","Zamak Repair (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["B_FR_Zamak_Munitions_01","Zamak Ammo (50CP)",50];
blufor_RQST_VEHICLE_14_X =			["B_FR_Zamak_Carburant_01","MTVR Fuel (50CP)",50];
blufor_RQST_VEHICLE_15_X =			["B_FR_Marshall_01","Marshall (35CP)",35];
blufor_RQST_VEHICLE_16_X =			["B_APC_Tracked_01_rcws_F","IFV-6A Cheetah (35CP)",35];
blufor_RQST_VEHICLE_17_X =			["B_FR_AMX_10_RCR_SEPAR_01","AMX-10 SEPAR (35CP)",35];
blufor_RQST_VEHICLE_18_X =			["B_APC_Tracked_01_CRV_F","CRV-6e Bobcat (28CP)",28];
blufor_RQST_VEHICLE_19_X =			["B_MBT_01_cannon_F","M2A1 Slammer (40CP)",40];
blufor_RQST_VEHICLE_20_X =			["B_FR_Leclerc_01","Leclerc MBT (45CP)",40];
blufor_RQST_VEHICLE_21_X =			["B_FR_LRM_01","LRM Arty (75CP)",75];
blufor_RQST_VEHICLE_22_X =			["B_FR_Scorcher_01","Scorcher Arty (75CP)",75];
blufor_RQST_VEHICLE_23_X =			["B_Heli_Light_01_dynamicLoadout_F","AH-9 Pawnee (25CP)",25];
blufor_RQST_VEHICLE_24_X =			["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15];
blufor_RQST_VEHICLE_25_X =			["B_FR_AS565_Panther_Marine_Nationale_01","Panther Trans Heli (22CP)",22];
blufor_RQST_VEHICLE_26_X =			["B_FR_H225_MCaracal_01","Caracel Trans Armed (26CP)",26];
blufor_RQST_VEHICLE_27_X =			["B_T_VTOL_01_armed_F","V-44 X Armed (40CP",40];
blufor_RQST_VEHICLE_28_X =			["B_FR_Helico_dattaque_01","Kajman Attack Heli (45CP)",45];
blufor_RQST_VEHICLE_29_X =			["B_Plane_CAS_01_dynamicLoadout_F","A-164 Wipeout CAS (45CP)",45];
blufor_RQST_VEHICLE_30_X =			["B_FR_Mirage_2000_5F_01","Mirage 2000 (50CP)",50];
blufor_RQST_VEHICLE_31_X =			["B_FR_Rafale_M_01","Rafale M (60CP)",60];
blufor_RQST_VEHICLE_32_X =			["B_UAV_01_F","UAV Darter(5CP)",5];
blufor_RQST_VEHICLE_33_X =			["B_UAV_02_dynamicLoadout_F","UAV MQ-4A Greyhawk (15CP)",15];
blufor_RQST_VEHICLE_34_X =			["B_UGV_01_F","UGV Stomper Recon (10CP)",10];
blufor_RQST_VEHICLE_35_X =			["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20];
blufor_RQST_VEHICLE_36_X =			["B_T_UAV_03_dynamicLoadout_F","MQ-12 UAV (20CP)",20];
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


