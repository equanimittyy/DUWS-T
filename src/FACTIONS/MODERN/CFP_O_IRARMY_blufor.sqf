
///////////////
///////////////   "CFP_O_IRARMY", "CFP Iranian Army", "CFP_O_IRARMY"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"CFP_O_IRARMY_Rifleman_01";				//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"CFP_O_IRARMY_Rifleman_AT_01";			//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"CFP_O_IRARMY_Grenadier_01";			//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"CFP_O_IRARMY_Squad_Leader_01";			//initHQ\fnc_createpatrolFOB, initHQ\fnc_HQguards
blufor_SOLDIER_SL_X =			"CFP_O_IRARMY_Squad_Leader_01";			//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"CFP_O_IRARMY_Machine_Gunner_01";		//supports\fnc_paradrop, initHQ\fnc_HQguards
blufor_MARKSMAN_X = 			"CFP_O_IRARMY_Sniper_55th_AB_Div_01";	//initHQ\fnc_HQguards
blufor_OFFICER_X =				"CFP_O_IRARMY_Team_Leader_65th_AB_01";	//initHQ\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CFP_O_IRARMY_Pilot_01";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"CUP_I_RHIB_RACS";					//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"B_Competitor_F";					//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CFP_O_WAGNER_Mi24_D_DESERT_01";	//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"CFP_O_IRARMY_Mi_8MT_01";  			//random patrol
blufor_HELI_ATTACK_X =			"CFP_O_IRARMY_Toufan_II_01";		//dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"CFP_O_IRARMY_SU25_Frogfoot_01";	//dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"CFP_O_IRARMY_Safir_DShKM_01";		//random patrol
blufor_APC_PATROL1_X =			"CFP_O_IRARMY_BTR_80A_01";			//random patrol
blufor_APC_PATROL2_X =			"CFP_O_IRARMY_BMP2_01";				//random patrol
blufor_TANK_PATROL1_X =			"CFP_O_IRARMY_T72_01";				//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"CUP_O_Igla_AA_pod_RU";			// also "CUP_O_ZU23_TK"
blufor_TURRET_AT =				"CUP_O_Kornet_RU";
blufor_TURRET_HMG =				"CUP_O_DSHKM_SLA";
blufor_TURRET_GMG =				"CUP_O_DSHKM_SLA";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"CFP_O_IRARMY_Rifleman_55th_AB_Div_01";				//operator
blufor_SPECOPS_GL_X =			"CFP_O_IRARMY_Grenadier_55th_AB_Div_01";			//operator
blufor_SPECOPS_LAT_X =			"CFP_O_IRARMY_Rifleman_AT_55th_AB_Div_01";			//operator
blufor_SPECOPS_HAT_X =			"CFP_O_IRARMY_Rifleman_AT_55th_AB_Div_01";			//operator
blufor_SPECOPS_AA_X =			"CFP_O_IRARMY_AA_Specialist_01";					//operator
blufor_SPECOPS_MG_X =			"CFP_O_IRARMY_Machine_Gunner_55th_AB_Div_01";		//operator
blufor_SPECOPS_MEDIC_X =		"CFP_O_IRARMY_Medic_55th_AB_Div_01";				//operator
blufor_SPECOPS_MARK_X =			"CFP_O_IRARMY_Sniper_55th_AB_Div_01";				//operator
blufor_SPECOPS_SNIPER_X =		"CFP_O_IRARMY_Sniper_55th_AB_Div_01";				//operator
blufor_SPECOPS_EXP_X =			"CFP_O_IRARMY_Explosive_Specialist_55th_AB_Div_01";	//operator
blufor_SPECOPS_ENG_X = 			"CFP_O_IRARMY_Engineer_01";							//operator





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


blufor_RQST_UNIT_01_X = 			["CFP_O_IRARMY_Rifleman_01","Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				["CFP_O_IRARMY_Grenadier_01","Grenadier (3CP)",3];
blufor_RQST_UNIT_03_X =				["CFP_O_IRARMY_Machine_Gunner_01","Heavy Gunner (4CP)",4];
blufor_RQST_UNIT_04_X =				["CFP_O_IRARMY_Medic_01","Medic (3CP)",3];
blufor_RQST_UNIT_05_X =				["CFP_O_IRARMY_Rifleman_AT_01","AT Specialist (4CP)",4];
blufor_RQST_UNIT_06_X =				["CFP_O_IRARMY_AA_Specialist_01","AA Specialist (4CP)",4];
blufor_RQST_UNIT_07_X =				["CFP_O_IRARMY_Engineer_01","Engineer (4CP)",4];
blufor_RQST_UNIT_08_X =				["CFP_O_IRARMY_Sniper_55th_AB_Div_01","Sniper (4CP)",4];
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
blufor_RQST_VEHICLE_05_X =			["CFP_O_IRARMY_Safir_01","Safir Unarmed (5CP)",5];
blufor_RQST_VEHICLE_06_X =			["CFP_O_IRARMY_Safir_DShKM_01","Safir HMG (15CP)",15];
blufor_RQST_VEHICLE_07_X =			["CFP_O_IRARMY_Safir_Metis_01","Safir METIS (20CP)",20];
blufor_RQST_VEHICLE_08_X =			["CUP_O_GAZ_Vodnik_AGS_RU","GAZ Vodnik GMG (25CP)",25];
blufor_RQST_VEHICLE_09_X =			["CFP_O_RUARMY_GAZ_Vodnik_BPPU_DES_01","GAZ Vodnik BPPU (25CP)",25];
blufor_RQST_VEHICLE_10_X =			["B_Truck_01_transport_F","HEMTT Transport Uncovered (10CP)",10];
blufor_RQST_VEHICLE_11_X =			["CFP_O_IRARMY_Ural_01","URAL Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_12_X =			["CFP_O_IRARMY_Ural_Repair_01","URAL Repair (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["CFP_O_IRARMY_Ural_Ammo_01","URAL Ammo (50CP)",50];
blufor_RQST_VEHICLE_14_X =			["CFP_O_IRARMY_Ural_Fuel_01","URAL Fuel (50CP)",50];
blufor_RQST_VEHICLE_15_X =			["CFP_O_IRARMY_M113_01","M113 HMG (25CP)",25];
blufor_RQST_VEHICLE_16_X =			["CFP_O_IRARMY_BTR_60_01","BTR-60 (25CP)",25];
blufor_RQST_VEHICLE_17_X =			["CFP_O_IRARMY_BTR_80_01","BTR-80 (30CP)",30];
blufor_RQST_VEHICLE_18_X =			["CFP_O_IRARMY_BTR_80A_01","BTR-80A (32CP)",32];
blufor_RQST_VEHICLE_19_X =			["CFP_O_IRARMY_BTR_90_01","BTR-90 (35CP)",35];
blufor_RQST_VEHICLE_20_X =			["CFP_O_IRARMY_BMP1_01","BMP-1P (35CP)",35];
blufor_RQST_VEHICLE_21_X =			["CFP_O_IRARMY_BMP2_01","BMP-2 (40CP)",40];
blufor_RQST_VEHICLE_22_X =			["CFP_O_IRARMY_M60_Patton_01","M-60 Tank (40CP)",40];
blufor_RQST_VEHICLE_23_X =			["CFP_O_IRARMY_T55_01","T-55 Tank (40CP)",45];
blufor_RQST_VEHICLE_24_X =			["CFP_O_IRARMY_T72_01","T-72 Tank (50CP)",50];
blufor_RQST_VEHICLE_25_X =			["CUP_O_ZSU23_SLA","ZSU-23 Tunguska (50CP)",50];
blufor_RQST_VEHICLE_26_X =			["CUP_O_BM21_SLA","BM-21 Rockets (75CP)",75];
blufor_RQST_VEHICLE_27_X =			["CUP_I_AH6J_RACS","AH-6 Littlebird (15CP)",15];
blufor_RQST_VEHICLE_28_X =			["CFP_O_IRARMY_Mi_8MT_01","MI-8 Trans (20CP)",20];
blufor_RQST_VEHICLE_29_X =			["CFP_O_WAGNER_Mi24_D_DESERT_01","MI-24P (25CP)",25];
blufor_RQST_VEHICLE_30_X =			["CFP_O_WAGNER_Mi8_DESERT_01","MI-8 Armed (28CP)",28];
blufor_RQST_VEHICLE_31_X =			["CUP_O_Ka52_RU","KA-52 Attack Heli (40CP",40];
blufor_RQST_VEHICLE_32_X =			["CFP_O_IRARMY_Toufan_II_01","Toufan Attack Heli (40CP)",40];
blufor_RQST_VEHICLE_33_X =			["CUP_O_MI6T_RU","MI-6T Hook Trans (30CP)",30];
blufor_RQST_VEHICLE_34_X =			["CFP_O_IRARMY_SU25_Frogfoot_01","L-39 CAS (45CP)",45];
blufor_RQST_VEHICLE_35_X =			["CUP_O_SU34_CSAT","SU-34 CSAT (50CP)",50];
blufor_RQST_VEHICLE_36_X =			["O_Plane_Fighter_02_F","TO-201 Shikra CSAT (60CP)",60];
blufor_RQST_VEHICLE_37_X =			["O_UAV_01_F","UAV AR-2 Tayran (5CP)",5];
blufor_RQST_VEHICLE_38_X =			["rhs_pchela1t_vvs","UAV Pchela-1T (15CP)",15];
blufor_RQST_VEHICLE_39_X =			["B_UGV_01_F","UGV Stomper Recon (10CP)",10];
blufor_RQST_VEHICLE_40_X =			["B_UGV_01_rcws_F","UGV Stomper RCWS (20CP)",20];
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


