
///////////////
///////////////   "LOP_UA", "PrOpfor Eastern Bloc Insurgents", "LOP_EASTBLOC"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"LOP_UA_Infantry_Rifleman_2";		//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"rhsgref_nat_grenadier_rpg";		//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"LOP_UA_Infantry_GL";				//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"LOP_US_Infantry_TL";				//initHQ\fnc_createpatrolFOB, initHQ\fnc_HQguards
blufor_SOLDIER_SL_X =			"rhsgref_nat_commander";			//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"rhsgref_nat_machinegunner";		//supports\fnc_paradrop, initHQ\fnc_HQguards
blufor_MARKSMAN_X = 			"LOP_US_Infantry_Marksman";			//initHQ\fnc_HQguards
blufor_OFFICER_X =				"LOP_US_Infantry_Officer";			//initHQ\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"LOP_SLA_Infantry_Pilot";			//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"LOP_SLA_Mi8MTV3_UPK23";			//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"LOP_SLA_Mi8MT_Cargo";   			//random patrol
blufor_HELI_ATTACK_X =			"LOP_UKR_Mi24V_UPK23";				//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"rhsgref_cdf_su25";					//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"LOP_US_UAZ_DshKM";					//random patrol
blufor_APC_PATROL1_X =			"rhsgref_nat_btr70";				//random patrol
blufor_APC_PATROL2_X =			"LOP_UA_BMP2";						//random patrol
blufor_TANK_PATROL1_X =			"LOP_UA_T72BB";						//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"RHS_ZU23_MSV";						// also "rhs_Igla_AA_pod_msv"
blufor_TURRET_AT =				"rhs_Kornet_9M133_2_msv";			// also "rhs_SPG9M_MSV"
blufor_TURRET_HMG =				"LOP_IA_Static_DSHKM";
blufor_TURRET_GMG =				"LOP_IA_Static_DSHKM";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"rhsgref_nat_pmil_rifleman_akm";		//operator
blufor_SPECOPS_GL_X =			"rhsgref_nat_pmil_grenadier";			//operator
blufor_SPECOPS_LAT_X =			"rhsgref_cdf_reg_rifleman_rpg75";		//operator
blufor_SPECOPS_HAT_X =			"rhsgref_nat_pmil_grenadier_rpg";		//operator
blufor_SPECOPS_AA_X =			"rhsgref_nat_pmil_specialist_aa";		//operator
blufor_SPECOPS_MG_X =			"rhsgref_nat_pmil_machinegunner";		//operator
blufor_SPECOPS_MEDIC_X =		"rhsgref_nat_pmil_medic";				//operator
blufor_SPECOPS_MARK_X =			"rhsgref_nat_pmil_hunter";				//operator
blufor_SPECOPS_SNIPER_X =		"rhsgref_nat_pmil_hunter";				//operator
blufor_SPECOPS_EXP_X =			"rhsgref_nat_pmil_saboteur";			//operator
blufor_SPECOPS_ENG_X = 			"LOP_SLA_Infantry_Engineer";			//operator





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


blufor_RQST_UNIT_01_X = 			["LOP_UA_Infantry_Rifleman_2","Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				["LOP_UA_Infantry_GL","Grenadier (3CP)",3];
blufor_RQST_UNIT_03_X =				["rhsgref_nat_machinegunner","Heavy Gunner ",4];
blufor_RQST_UNIT_04_X =				["LOP_US_Infantry_Corpsman","Medic (4CP)",4];
blufor_RQST_UNIT_05_X =				["rhsgref_nat_grenadier_rpg","AT Specialist (4CP)",4];
blufor_RQST_UNIT_06_X =				["LOP_US_Infantry_AA","AA Specialist (4CP)",4];
blufor_RQST_UNIT_07_X =				["LOP_SLA_Infantry_Engineer","Engineer (4CP)",4];
blufor_RQST_UNIT_08_X =				["LOP_US_Infantry_Marksman","Sniper (4CP)",4];
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
blufor_RQST_VEHICLE_04_X =			["LOP_UA_UAZ","UAZ Unarmed (5CP)",5];
blufor_RQST_VEHICLE_05_X =			["LOP_UA_UAZ_DshKM","UAZ Unarmed (10CP)",10];
blufor_RQST_VEHICLE_06_X =			["LOP_AM_OPF_Offroad_M2","Offroad HMG (12CP)",12];
blufor_RQST_VEHICLE_07_X =			["LOP_AM_OPF_Offroad_AT","Offroad SPG-9 (15CP)",15];
blufor_RQST_VEHICLE_08_X =			["LOP_UKR_Ural","Ural Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_09_X =			["LOP_UKR_KAMAZ_Transport","KAMAZ Transport Open (8CP)",8];
blufor_RQST_VEHICLE_10_X =			["LOP_UKR_KAMAZ_Repair","KAMAZ Repair (50CP)",50];
blufor_RQST_VEHICLE_11_X =			["LOP_UKR_KAMAZ_Ammo","KAMAZ Ammo (50CP)",50];
blufor_RQST_VEHICLE_12_X =			["LOP_UKR_KAMAZ_Fuel","KAMAZ Fuel (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["rhsgref_BRDM2_msv","BRDM-2 (25CP)",25];
blufor_RQST_VEHICLE_14_X =			["rhsgref_BRDM2_ATGM_msv","BRDM-2 ATGM (28CP)",28];
blufor_RQST_VEHICLE_15_X =			["LOP_UKR_BTR60","BTR-60 (28CP)",28];
blufor_RQST_VEHICLE_15_X =			["LOP_UKR_BTR80","BTR-80 (30CP)",30];
blufor_RQST_VEHICLE_16_X =			["LOP_UKR_BMP1D","BMP-1 (32CP)",32];
blufor_RQST_VEHICLE_17_X =			["LOP_UKR_BMP2D","BMP-2 (35CP)",35];
blufor_RQST_VEHICLE_18_X =			["LOP_AFR_T55","T-55 Tank (40CP)",40];
blufor_RQST_VEHICLE_19_X =			["LOP_UKR_T72BC","T-72 Tank (50CP)",50];
blufor_RQST_VEHICLE_20_X =			["LOP_UKR_ZSU234","BMP-2 ZU-23 (35CP)",35];
blufor_RQST_VEHICLE_21_X =			["LOP_IRAN_BM21","BM-21 Rockets (75CP)",75];
blufor_RQST_VEHICLE_22_X =			["B_Heli_Light_01_F","MH-9 Hummingbird (15CP)",15];
blufor_RQST_VEHICLE_23_X =			["LOP_SLA_Mi8MT_Cargo","MI-8 Cargo (25CP)",25];					
blufor_RQST_VEHICLE_24_X =			["LOP_UKR_Mi24V_UPK23","MI-24V (30CP)",30];
blufor_RQST_VEHICLE_25_X =			["LOP_SLA_Mi8MTV3_UPK23","MI-8MTV (35CP)",35];
blufor_RQST_VEHICLE_26_X =			["rhsgref_cdf_su25","SU-25 Frogfoot(stolen) (50CP)",50];
blufor_RQST_VEHICLE_27_X =			["O_UAV_01_F","UAV AR-2 Tayran (5CP)",5];
blufor_RQST_VEHICLE_28_X =			["CUP_O_Pchela1T_RU","UAV Pchela 1T (15CP)",15];
blufor_RQST_VEHICLE_29_X =			["B_UGV_01_F","UGV Stomper Recon (10CP)",10];
blufor_RQST_VEHICLE_30_X =			["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20];
blufor_RQST_VEHICLE_31_X =			["empty",0,0];
blufor_RQST_VEHICLE_32_X =			["empty",0,0];
blufor_RQST_VEHICLE_33_X =			["empty",0,0];
blufor_RQST_VEHICLE_34_X =			["empty",0,0];
blufor_RQST_VEHICLE_35_X =			["empty",0,0];
blufor_RQST_VEHICLE_36_X =			["empty",0,0];
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


