
///////////////
///////////////   "ASZ_EI", "PEDAGNE Italian Army + SOF (Vegecam + Vegetata)", "ASZ_EI"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"ASZ_EI_rifleman_06A";				//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"ASZ_EI_operator_AT_A";				//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"ASZ_EI_riflemanGL_04A";			//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"ASZ_EI_commander_03A";				//initHQ\fnc_createpatrolFOB, initHQ\fnc_HQguards
blufor_SOLDIER_SL_X =			"ASZ_EI_commander_03A";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"ASZ_EI_mg_02A";					//supports\fnc_paradrop, initHQ\fnc_HQguards
blufor_MARKSMAN_X = 			"ASZ_EI_marksman_01A";				//initHQ\fnc_HQguards
blufor_OFFICER_X =				"ASZ_EI_commander_08Acap";			//initHQ\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"ASZ_Pilot_Hely_AM";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"ASZ_NH90_EI_reos";					//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"ASZ_CH47_EI";   					//random patrol
blufor_HELI_ATTACK_X =			"ASZ_A129_AT";						//dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"ASZ_AV8B_MM_GBU";					//dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"ASZ_VTML_EI_M2";					//random patrol
blufor_APC_PATROL1_X =			"ASZ_VCC1_EI_camo";					//random patrol
blufor_APC_PATROL2_X =			"ASZ_SuperAV_EI_battlefield";		//random patrol
blufor_TANK_PATROL1_X =			"ASZ_Ariete_camo_plus";				//random patrol


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

blufor_SPECOPS_X =				"ASZ_SOF_operator_landing";				//operator
blufor_SPECOPS_GL_X =			"ASZ_SOF_operator_05";					//operator
blufor_SPECOPS_LAT_X =			"ASZ_SOF_operator_AT";					//operator
blufor_SPECOPS_HAT_X =			"ASZ_EI_HAT_01Llanding";				//operator
blufor_SPECOPS_AA_X =			"ASZ_SOF_operator_AA";					//operator
blufor_SPECOPS_MG_X =			"ASZ_SOF_operatorMG";					//operator
blufor_SPECOPS_MEDIC_X =		"ASZ_SOF_operator_Medic";				//operator
blufor_SPECOPS_MARK_X =			"ASZ_SOF_operator_04";					//operator
blufor_SPECOPS_SNIPER_X =		"ASZ_Ghillie_SniperTOP";				//operator
blufor_SPECOPS_EXP_X =			"ASZ_SOF_sabotatore";					//operator
blufor_SPECOPS_ENG_X = 			"B_Patrol_Engineer_F";					//operator





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


blufor_RQST_UNIT_01_X = 			["ASZ_EI_rifleman_06A","Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				["ASZ_EI_riflemanGL_04A","Grenadier (3CP)",3];
blufor_RQST_UNIT_03_X =				["ASZ_EI_mg_02A","Heavy Gunner (4CP)",4];
blufor_RQST_UNIT_04_X =				["ASZ_EI_medic_A","Medic (4CP)",4];
blufor_RQST_UNIT_05_X =				["ASZ_EI_operator_AT_A","AT Rifleman (3CP)",3];
blufor_RQST_UNIT_06_X =				["ASZ_EI_operator_AA_A","AA Specialist (4CP)",4];
blufor_RQST_UNIT_07_X =				["B_engineer_F","NATO Engineer (4CP)",4];
blufor_RQST_UNIT_08_X =				["ASZ_EI_marksman_01A","Marksman (3CP)",3];
blufor_RQST_UNIT_09_X =				["ASZ_Ghillie_SniperTOP","Sniper (4CP)",4];
blufor_RQST_UNIT_10_X =				["empty",0,0];
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
blufor_RQST_VEHICLE_05_X =			["ASZ_LR90_EIs","LR-90 Unarmed (10CP)",10];
blufor_RQST_VEHICLE_06_X =			["ASZ_VM90spop","VM-90 SpecOps (15CP)",15];
blufor_RQST_VEHICLE_07_X =			["ASZ_VTML_EI_M2","Lince VTML HMG (15CP)",15];
blufor_RQST_VEHICLE_08_X =			["ASZ_VTML_EI_MK19","Lince VTML GMG (18CP)",18];
blufor_RQST_VEHICLE_09_X =			["ASZ_VTML_EI_TOW","Lince VTML TOW (20CP)",20];
blufor_RQST_VEHICLE_10_X =			["B_Truck_01_transport_F","HEMTT Transport Uncovered (8CP)",8];
blufor_RQST_VEHICLE_11_X =			["ASZ_ACTL4x4_EI","Astra Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_12_X =			["ASZ_ACTL6x6_EI_repair","Astra Repair (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["ASZ_ACTL6x6_EI_logistic","Astra Ammo (50CP)",50];
blufor_RQST_VEHICLE_14_X =			["ASZ_ACTL6x6_EI_fuel","Astra Fuel (50CP)",50];
blufor_RQST_VEHICLE_15_X =			["ASZ_VCC1_EI_camo_plus","VCC1 HMG (25CP)",25];
blufor_RQST_VEHICLE_16_X =			["ASZ_SuperAV_EI_battlefield","Super AV (30CP)",30];
blufor_RQST_VEHICLE_17_X =			["ASZ_PUMA4x4_M2","PUMA HMG (32CP)",32];
blufor_RQST_VEHICLE_18_X =			["ASZ_PUMA4x4_TOW","PUMA TOW (35CP)",35];
blufor_RQST_VEHICLE_19_X =			["ASZ_PUMA6x6_hitrole","PUMA Hitrole (35CP)",35];
blufor_RQST_VEHICLE_20_X =			["ASZ_Centauro_B1","Blindo Centauro (40CP)",40];
blufor_RQST_VEHICLE_21_X =			["ASZ_Ariete_camo_plus","Ariete MBT (45CP)",40];
blufor_RQST_VEHICLE_22_X =			["B_MBT_01_mlrs_F","Sandstorm MLRS (75CP)",75];
blufor_RQST_VEHICLE_23_X =			["B_MBT_01_arty_F","M4 Scorcher (75CP)",75];
blufor_RQST_VEHICLE_24_X =			["B_Heli_Light_01_dynamicLoadout_F","AH-9 Pawnee (25CP)",25];
blufor_RQST_VEHICLE_25_X =			["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15];
blufor_RQST_VEHICLE_26_X =			["ASZ_NH90_EI_reos","NH-90 Armed Heli (22CP)",22];
blufor_RQST_VEHICLE_27_X =			["ASZ_CH47_EI","CH-47 Transport (26CP)",26];
blufor_RQST_VEHICLE_28_X =			["B_T_VTOL_01_armed_F","V-44 X Armed (40CP",40];
blufor_RQST_VEHICLE_29_X =			["ASZ_A129_AT","A-129 Attack Chopper (45CP)",45];
blufor_RQST_VEHICLE_30_X =			["ASZ_AV8B_MM_GBU","AV-8B Harrier GBU (45CP)",45];
blufor_RQST_VEHICLE_31_X =			["ASZ_EFA_AM_AA","Typhoon AA (50CP)",50];
blufor_RQST_VEHICLE_32_X =			["B_Plane_Fighter_01_Stealth_F","Black Wasp 2 Stealth (60CP)",60];
blufor_RQST_VEHICLE_33_X =			["B_UAV_01_F","UAV Darter(5CP)",5];
blufor_RQST_VEHICLE_34_X =			["B_UAV_02_dynamicLoadout_F","UAV MQ-4A Greyhawk (15CP)",15];
blufor_RQST_VEHICLE_35_X =			["B_UGV_01_F","UGV Stomper Recon (10CP)",10];
blufor_RQST_VEHICLE_36_X =			["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20];
blufor_RQST_VEHICLE_37_X =			["B_T_UAV_03_dynamicLoadout_F","MQ-12 UAV (20CP)",20];
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


