
///////////////
///////////////   "CUP_B_USMC", "CUP USMC SpecOps Desert", "CUP_B_USMC_D"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"CUP_B_USMC_Soldier_FROG_DES";				//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"CUP_B_USMC_Soldier_AT_FROG_DES";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"CUP_B_USMC_Soldier_GL_FROG_DES";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"CUP_B_FR_Soldier_TL_DES";					//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"CUP_B_USMC_Soldier_SL_FROG_DES";			//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"CUP_B_USMC_Soldier_AR_FROG_DES";			//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"CUP_B_USMC_Soldier_Marksman_FROG_DES";		//init_hq\fnc_HQguards
blufor_OFFICER_X =				"CUP_B_USMC_Officer_FROG_DES";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"CUP_B_USMC_Pilot";							//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"CUP_B_RHIB_USMC";						//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"C_Man_UtilityWorker_01_F";				//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"CUP_B_MH60L_DAP_4x_USN";				//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"CUP_B_CH53E_VIV_USMC";  				//random patrol
blufor_HELI_ATTACK_X =			"CUP_B_AH1Z_Dynamic_USMC";				//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"CUP_B_A10_DYN_USA";						//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"CUP_B_M1151_M2_DSRT_USMC";				//random patrol
blufor_APC_PATROL1_X =			"CUP_B_LAV25_HQ_desert_USMC";			//random patrol
blufor_APC_PATROL2_X =			"CUP_B_LAV25M240_desert_USMC";			//random patrol
blufor_TANK_PATROL1_X =			"CUP_B_M1A2_TUSK_MG_DES_USMC";			//random patrol


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

blufor_SPECOPS_X =				"CUP_B_USMC_Soldier_FROG_DES";			//operator
blufor_SPECOPS_GL_X =			"CUP_B_USMC_Soldier_GL_FROG_DES";		//operator
blufor_SPECOPS_LAT_X =			"CUP_B_USMC_Soldier_AT_FROG_DES";		//operator 
blufor_SPECOPS_HAT_X =			"CUP_B_USMC_Soldier_HAT_FROG_DES";		//operator
blufor_SPECOPS_AA_X =			"CUP_B_USMC_Soldier_AA_FROG_DES";		//operator
blufor_SPECOPS_MG_X =			"CUP_B_USMC_Soldier_MG_FROG_DES";		//operator
blufor_SPECOPS_MEDIC_X =		"CUP_B_USMC_Medic_FROG_DES";			//operator
blufor_SPECOPS_MARK_X	=		"CUP_B_USMC_Soldier_Marksman_FROG_DES";		//operator
blufor_SPECOPS_SNIPER_X =		"CUP_B_FR_Story_Sykes_DES";				//operator
blufor_SPECOPS_EXP_X =			"CUP_B_FR_Soldier_Exp_DES";				//operator
blufor_SPECOPS_ENG_X =			"CUP_B_USMC_Engineer_FROG_DES"; 		//operator





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


blufor_RQST_UNIT_01_X = 			["CUP_B_USMC_Soldier_FROG_DES","Rifleman (USMC) (2CP)",2];
blufor_RQST_UNIT_02_X =				["CUP_B_USMC_Soldier_GL_FROG_DES","Grenadier (USMC) (3CP)",3];
blufor_RQST_UNIT_03_X =				["CUP_B_USMC_Soldier_AR_FROG_DES","Automatic Rifleman (USMC) (3CP)",3];
blufor_RQST_UNIT_04_X =				["CUP_B_USMC_Soldier_MG_FROG_DES","Heavy Gunner (USMC) (4CP)",4];
blufor_RQST_UNIT_05_X =				["CUP_B_USMC_Medic_FROG_DES","Medic (USMC) (4CP)",4];
blufor_RQST_UNIT_06_X =				["CUP_B_USMC_Soldier_AT_FROG_DES","AT Rifleman (USMC) (3CP)",3];
blufor_RQST_UNIT_07_X =				["CUP_B_USMC_Soldier_HAT_FROG_DES","AT Specialist (USMC) (4CP)",4];
blufor_RQST_UNIT_08_X =				["CUP_B_USMC_Soldier_AA_FROG_DES","AA Specialist (USMC) (4CP)",4];
blufor_RQST_UNIT_09_X =				["CUP_B_USMC_Engineer_FROG_DES","Engineer (USMC) (4CP)",4];
blufor_RQST_UNIT_10_X =				["CUP_B_FR_Soldier_Exp_DES","Explosive Specialist (USMC) (4CP)",4];
blufor_RQST_UNIT_11_X =				["CUP_B_USMC_Soldier_Marksman_FROG_DES","Marksman (USMC) (3CP)",3];
blufor_RQST_UNIT_12_X =				["CUP_B_FR_Story_Sykes_DES","Sniper (USMC) (4CP)",4];
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
blufor_RQST_VEHICLE_04_X =			["CUP_B_M1151_DSRT_USMC","HMMWV Unarmed (5CP)",5];
blufor_RQST_VEHICLE_05_X =			["CUP_B_M1151_M2_DSRT_USMC","HMMWV HMG (8CP)",8];
blufor_RQST_VEHICLE_06_X =			["CUP_B_M1151_Mk19_DSRT_USMC","HMMWV GMG (18CP)",18];
blufor_RQST_VEHICLE_07_X =			["CUP_B_M1167_DSRT_USMC","HMMWV TOW (25CP)",25];
blufor_RQST_VEHICLE_08_X =			["CUP_B_RG31_M2_USMC","RG-31 HMG (10CP)",10];
blufor_RQST_VEHICLE_09_X =			["CUP_B_RG31_Mk19_USMC","RG-31 GMG (18CP)",18];
blufor_RQST_VEHICLE_10_X =			["CUP_B_RG31E_M2_USMC","RG-31E Mk5E (25CP)",25];
blufor_RQST_VEHICLE_11_X =			["CUP_B_MTVR_USA","MTVR Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_12_X =			["CUP_B_MTVR_Repair_USA","MTVR Repair (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["CUP_B_MTVR_Ammo_USA","MTVR Ammo (50CP)",50];
blufor_RQST_VEHICLE_14_X =			["CUP_B_MTVR_Refuel_USA","MTVR Fuel (50CP)",50];
blufor_RQST_VEHICLE_15_X =			["CUP_B_M1126_ICV_M2_Desert","M1126 HMG crows (25CP)",25];
blufor_RQST_VEHICLE_16_X =			["CUP_B_M1126_ICV_MK19_Desert","M1126 GMG crows (28CP)",28];
blufor_RQST_VEHICLE_17_X =			["CUP_B_M1128_MGS_Desert","M1126 MGS cannon (30CP)",30];
blufor_RQST_VEHICLE_18_X =			["CUP_B_LAV25_desert_USMC","LAV-25 Bushmaster (30CP)",30];
blufor_RQST_VEHICLE_19_X =			["CUP_B_LAV25M240_desert_USMC","LAV-25 Bush/M240 (32CP)",32];
blufor_RQST_VEHICLE_20_X =			["CUP_B_AAV_USMC","AAVP7 (35CP)",35];
blufor_RQST_VEHICLE_21_X =			["CUP_B_M2A3Bradley_USA_D","Bradley ERA (35CP)",35];
blufor_RQST_VEHICLE_22_X =			["CUP_B_M60A3_TTS_USMC","M-60A3 Tank  (38CP)",38];
blufor_RQST_VEHICLE_23_X =			["CUP_B_M1A1_DES_USMC","M1A1 Tank (40CP)",40];
blufor_RQST_VEHICLE_24_X =			["CUP_B_M1A2_TUSK_MG_DES_USMC","M1A2 TUSK (45CP)",45];
blufor_RQST_VEHICLE_25_X =			["CUP_B_M270_DPICM_USA","M270 DPICM Artillery (60CP)",60];
blufor_RQST_VEHICLE_26_X =			["CUP_B_M270_HE_USA","M270 HE Artillery (65CP)",65];
blufor_RQST_VEHICLE_27_X =			["CUP_B_MH6J_USA","MH-6J Littlebird (15CP)",15];
blufor_RQST_VEHICLE_28_X =			["CUP_B_AH6M_USA","AH-6M Armed (25CP)",25];
blufor_RQST_VEHICLE_29_X =			["CUP_B_UH1Y_Gunship_Dynamic_USMC","UH-1Y Venom Gunship (25CP",25];
blufor_RQST_VEHICLE_30_X =			["CUP_B_AH1Z_Dynamic_USMC","AH-1Z Cobra (40CP)",40];
blufor_RQST_VEHICLE_31_X =			["CUP_B_MH60S_USMC","MH-60S Seahawk (22CP)",22];
blufor_RQST_VEHICLE_32_X =			["CUP_B_MH60L_DAP_4x_USN","MH-60L Knighthawk ESSSx4 (35CP)",35];
blufor_RQST_VEHICLE_33_X =			["CUP_B_CH53E_USMC","CH-53E SeaKnight (26CP)",26];
blufor_RQST_VEHICLE_34_X =			["CUP_B_A10_DYN_USA","A-10 Warthog (45CP)",45];
blufor_RQST_VEHICLE_35_X =			["CUP_B_AV8B_DYN_USMC","AV-8B Harrier (50CP)",50];
blufor_RQST_VEHICLE_36_X =			["CUP_B_F35B_USMC","F-35B Lightning (55CP)",55];
blufor_RQST_VEHICLE_37_X =			["CUP_B_MV22_USMC_RAMPGUN","MV-22 OSPREY (30CP)",30];
blufor_RQST_VEHICLE_38_X =			["B_UAV_01_F","UAV Darter(5CP)",5];
blufor_RQST_VEHICLE_39_X =			["CUP_B_USMC_DYN_MQ9","UAV MQ-9 Reaper (USMC)(15CP)",15];
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
