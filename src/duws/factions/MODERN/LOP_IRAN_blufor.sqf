
///////////////
///////////////   "LOP_IRAN", "PrOpfor IRAN Army", "LOP_IRAN"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"LOP_IRAN_Infantry_Rifleman_2";			//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"LOP_IRAN_Infantry_RPG";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"LOP_IRAN_Infantry_Grenadier";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"LOP_IRAN_Infantry_junior_sergeant";	//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"LOP_IRAN_Infantry_sergeant";			//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"LOP_IRAN_Infantry_AR";					//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"LOP_IRAN_Infantry_Marksman";			//init_hq\fnc_HQguards
blufor_OFFICER_X =				"LOP_IRAN_Infantry_officer";			//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"LOP_IRAN_Infantry_pilot";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"O_Boat_Armed_01_hmg_F";			//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"LOP_IRAN_Mi8MTV3_UPK23";			//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"LOP_IRAN_CH47F";  					//random patrol
blufor_HELI_ATTACK_X =			"LOP_IRAN_AH1Z_CS";					//dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"O_Plane_CAS_02_dynamicLoadout_F";	//dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"LOP_IRAN_UAZ_DshKM";				//random patrol
blufor_APC_PATROL1_X =			"LOP_IRAN_BTR80";					//random patrol
blufor_APC_PATROL2_X =			"LOP_IRAN_BMP2";					//random patrol
blufor_TANK_PATROL1_X =			"LOP_IRAN_T72BA";					//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"rhs_Igla_AA_pod_msv";			// also "RHS_ZU23_MSV"
blufor_TURRET_AT =				"rhs_Kornet_9M133_2_msv";
blufor_TURRET_HMG =				"LOP_IA_Static_DSHKM";
blufor_TURRET_GMG =				"LOP_IA_Static_DSHKM";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"LOP_IRAN_Infantry_SF_Rifleman";					//operator
blufor_SPECOPS_GL_X =			"LOP_IRAN_Infantry_SF_Grenadier";					//operator
blufor_SPECOPS_LAT_X =			"LOP_IRAN_Infantry_SF_LAT";							//operator
blufor_SPECOPS_HAT_X =			"LOP_IRAN_Infantry_SF_RPG";							//operator
blufor_SPECOPS_AA_X =			"LOP_IRAN_Infantry_AA";								//operator
blufor_SPECOPS_MG_X =			"LOP_IRAN_Infantry_SF_AR";							//operator
blufor_SPECOPS_MEDIC_X =		"LOP_IRAN_Infantry_SF_medic";						//operator
blufor_SPECOPS_MARK_X =			"LOP_IRAN_Infantry_SF_Marksman";					//operator
blufor_SPECOPS_SNIPER_X =		"LOP_IRAN_Infantry_SF_Marksman";					//operator
blufor_SPECOPS_EXP_X =			"I_C_Soldier_Para_8_F";								//operator
blufor_SPECOPS_ENG_X = 			"LOP_IRAN_Infantry_SF_engineer";					//operator





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


blufor_RQST_UNIT_01_X = 			["LOP_IRAN_Infantry_Rifleman_2","Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				["LOP_IRAN_Infantry_Grenadier","Grenadier (3CP)",3];
blufor_RQST_UNIT_03_X =				["LOP_IRAN_Infantry_AR","Heavy Gunner (4CP)",4];
blufor_RQST_UNIT_04_X =				["LOP_IRAN_Infantry_medic","Medic (3CP)",3];
blufor_RQST_UNIT_05_X =				["LOP_IRAN_Infantry_RPG","AT Specialist (4CP)",4];
blufor_RQST_UNIT_06_X =				["LOP_IRAN_Infantry_AA","AA Specialist (4CP)",4];
blufor_RQST_UNIT_07_X =				["LOP_IRAN_Infantry_engineer","Engineer (4CP)",4];
blufor_RQST_UNIT_08_X =				["LOP_IRAN_Infantry_Marksman","Sniper (4CP)",4];
blufor_RQST_UNIT_09_X =				["empty",0,0];
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
blufor_RQST_VEHICLE_05_X =			["LOP_IRAN_UAZ","UAZ Unarmed (5CP)",5];
blufor_RQST_VEHICLE_06_X =			["LOP_IRAN_UAZ_DshKM","UAZ HMG (15CP)",15];
blufor_RQST_VEHICLE_07_X =			["LOP_IRAN_UAZ_SPG","UAZ SPG-9 (20CP)",20];
blufor_RQST_VEHICLE_08_X =			["rhs_tigr_sts_3camo_vdv","GAZ Tigr HMG/GMG (22CP)",22];
blufor_RQST_VEHICLE_09_X =			["rhsgref_BRDM2_b","BRDM-2 (22CP)",22];
blufor_RQST_VEHICLE_10_X =			["LOP_IRAN_Ural","URAL Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_11_X =			["LOP_IRAN_KAMAZ_Transport","KAMAZ Transport Open (8CP)",8];
blufor_RQST_VEHICLE_12_X =			["LOP_IRAN_KAMAZ_Repair","KAMAZ Repair (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["LOP_IRAN_KAMAZ_Ammo","KAMAZ Ammo (50CP)",50];
blufor_RQST_VEHICLE_14_X =			["LOP_IRAN_KAMAZ_Fuel","KAMAZ Fuel (50CP)",50];
blufor_RQST_VEHICLE_15_X =			["LOP_IRAN_M113_C","M113 HMG (22CP)",22];
blufor_RQST_VEHICLE_16_X =			["LOP_IRAN_BTR60","BTR-60 (25CP)",25];
blufor_RQST_VEHICLE_17_X =			["LOP_IRAN_BTR80","BTR-80 (30CP)",30];
blufor_RQST_VEHICLE_18_X =			["rhs_btr80a_vmf","BTR-80A (32CP)",32];
blufor_RQST_VEHICLE_19_X =			["LOP_IRAN_BMP1","BMP-1P (35CP)",35];
blufor_RQST_VEHICLE_20_X =			["LOP_IRAN_BMP2","BMP-2 (40CP)",40];
blufor_RQST_VEHICLE_21_X =			["LOP_SYR_T55","T-55 Tank (40CP)",45];
blufor_RQST_VEHICLE_22_X =			["LOP_IRAN_T72BA","T-72 Tank (50CP)",50];
blufor_RQST_VEHICLE_23_X =			["LOP_IRAN_ZSU234","ZSU-23 Tunguska (50CP)",50];
blufor_RQST_VEHICLE_24_X =			["LOP_IRAN_BM21","BM-21 Rockets (75CP)",75];
blufor_RQST_VEHICLE_25_X =			["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15];
blufor_RQST_VEHICLE_26_X =			["LOP_IRAN_Mi8MT_Cargo","MI-8 Trans (20CP)",20];
blufor_RQST_VEHICLE_27_X =			["LOP_UKR_Mi24V_UPK23","MI-24V (25CP)",25];
blufor_RQST_VEHICLE_28_X =			["LOP_IRAN_CH47F","MH-47 Trans (28CP)",28];
blufor_RQST_VEHICLE_29_X =			["LOP_IRAN_Mi8MTV3_UPK23","MI-8 Armed (30CP)",30];
blufor_RQST_VEHICLE_30_X =			["LOP_IRAN_AH1Z_CS","AH-1Z Attack Heli (40CP",40];
blufor_RQST_VEHICLE_31_X =			["O_Plane_CAS_02_dynamicLoadout_F","CSAT TO-199 (45CP)",45];
blufor_RQST_VEHICLE_32_X =			["O_Plane_Fighter_02_F","TO-201 Shikra CSAT (60CP)",60];
blufor_RQST_VEHICLE_33_X =			["O_UAV_01_F","UAV AR-2 Tayran (5CP)",5];
blufor_RQST_VEHICLE_34_X =			["rhs_pchela1t_vvs","UAV Pchela-1T (15CP)",15];
blufor_RQST_VEHICLE_35_X =			["B_UGV_01_F","UGV Stomper Recon (10CP)",10];
blufor_RQST_VEHICLE_36_X =			["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20];
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


