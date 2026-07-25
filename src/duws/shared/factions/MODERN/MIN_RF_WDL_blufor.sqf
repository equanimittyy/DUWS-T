
///////////////
///////////////   "MIN_RF", "Russia 2035 (Wood)", "MIN_RF_WDL"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"MIN_RF_SOLDIER";					//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"MIN_RF_SOLDIER_LAT";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"MIN_RF_SOLDIER_GL";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"MIN_RF_SOLDIER_TL";				//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"MIN_RF_SOLDIER_SL";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"MIN_RF_SOLDIER_AR";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"MIN_RF_SOLDIER_M";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"MIN_RF_OFFICER";					//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"MIN_RF_HELIPILOT";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"O_Boat_Armed_01_hmg_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"C_Man_UtilityWorker_01_F";		//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"MIN_RF_HELI_LIGHT_GREY";		//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"MIN_RF_HELI_LIGHT_UNARMED_GREY";   		//random patrol
blufor_HELI_ATTACK_X =			"MIN_RF_KA_52_GREY";	//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"MIN_RF_SU_34";		//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"MIN_RF_GAZ_2330_HMG";						//random patrol
blufor_APC_PATROL1_X =			"MIN_RF_T_15";			//random patrol
blufor_APC_PATROL2_X =			"MIN_RF_SA_22";			//random patrol
blufor_TANK_PATROL1_X =			"MIN_RF_T_14";					//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"O_static_AA_F";
blufor_TURRET_AT =				"O_static_AT_F";
blufor_TURRET_HMG =				"O_HMG_01_high_F";
blufor_TURRET_GMG =				"O_GMG_01_high_F";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"MIN_RF_RECON";					//operator
blufor_SPECOPS_GL_X =			"MIN_RF_RECON_JTAC";				//operator
blufor_SPECOPS_LAT_X =			"MIN_RF_RECON_LAT";				//operator
blufor_SPECOPS_HAT_X =			"MIN_RF_SOLDIER_AT";				//operator
blufor_SPECOPS_AA_X =			"MIN_RF_SOLDIER_AA";				//operator
blufor_SPECOPS_MG_X =			"MIN_RF_RECON_AR";				//operator
blufor_SPECOPS_MEDIC_X =		"MIN_RF_RECON_Medic";				//operator
blufor_SPECOPS_MARK_X =			"MIN_RF_RECON_M";					//operator
blufor_SPECOPS_SNIPER_X =		"MIN_RF_SPETSNAZ_M";					//operator
blufor_SPECOPS_EXP_X =			"MIN_RF_RECON_EXP";				//operator
blufor_SPECOPS_ENG_X = 			"MIN_RF_RECON_SABOTEUR";					//operator





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


blufor_RQST_UNIT_01_X = 			["MIN_RF_SOLDIER","Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				["MIN_RF_SOLDIER_GL","Grenadier (3CP)",3];
blufor_RQST_UNIT_03_X =				["MIN_RF_SOLDIER_AR","Automatic Rifleman (3CP)",3];
blufor_RQST_UNIT_04_X =				["O_HeavyGunner_F","Heavy Gunner (4CP)",4];
blufor_RQST_UNIT_05_X =				["MIN_RF_MEDIC","Medic (4CP)",4];
blufor_RQST_UNIT_06_X =				["MIN_RF_SOLDIER_LAT","AT Rifleman (3CP)",3];
blufor_RQST_UNIT_07_X =				["MIN_RF_SOLDIER_AT","AT Specialist (4CP)",4];
blufor_RQST_UNIT_08_X =				["MIN_RF_SOLDIER_AA","AA Specialist (4CP)",4];
blufor_RQST_UNIT_09_X =				["MIN_RF_ENGINEER","Engineer (4CP)",4];
blufor_RQST_UNIT_10_X =				["MIN_RF_SOLDIER_M","Marksman (3CP)",3];
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

blufor_RQST_VEHICLE_01_X =			["O_Quadbike_01_F","ATV (1CP)",1];
blufor_RQST_VEHICLE_02_X =			["C_Offroad_01_F","SF Offroader (2CP)",2];
blufor_RQST_VEHICLE_03_X =			["I_G_Van_01_transport_F","Transport Truck (6CP)",6];
blufor_RQST_VEHICLE_04_X =			["O_MRAP_02_F","Ifrit Unarmed (5CP)",5];
blufor_RQST_VEHICLE_05_X =			["O_MRAP_02_hmg_F","Ifrit HMG (18CP)",18];
blufor_RQST_VEHICLE_06_X =			["O_MRAP_02_gmg_F","Ifrit GMG (25CP)",25];
blufor_RQST_VEHICLE_07_X =			["MIN_RF_GAZ_2330","GAZ Unarmed (5CP)",5];
blufor_RQST_VEHICLE_08_X =			["MIN_RF_GAZ_2330_HMG","GAZ HMG (15CP)",15];
blufor_RQST_VEHICLE_09_X =			["O_LSV_02_AT_F","Qilin AT (20CP)",20];
blufor_RQST_VEHICLE_10_X =			["O_Truck_03_transport_F","Tempest Transport Uncovered (8CP)",8];
blufor_RQST_VEHICLE_11_X =			["O_Truck_03_covered_F","Tempest Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_12_X =			["O_Truck_02_box_F","Zamak Repair (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["O_Truck_02_Ammo_F","Zamak Ammo (50CP)",50];
blufor_RQST_VEHICLE_14_X =			["O_Truck_02_fuel_F","Zamak Fuel (50CP)",50];
blufor_RQST_VEHICLE_15_X =			["MIN_RF_HELI_LIGHT_GREY","Ka-60 Kasatka (25CP)",25];
blufor_RQST_VEHICLE_16_X =			["MIN_RF_KA_52_GREY","Ka-52 Black Shark (35CP)",35];
blufor_RQST_VEHICLE_17_X =			["MIN_RF_T_15","T-15 IFV (30CP)",30];
blufor_RQST_VEHICLE_18_X =			["MIN_RF_T_14","T-14 ARMADA (40CP)",40];
blufor_RQST_VEHICLE_19_X =			["O_MBT_02_cannon_F","T-100 Varsuk (40CP)",40];
blufor_RQST_VEHICLE_20_X =			["O_MBT_04_command_F","T-140K Angara (40CP)",40];
blufor_RQST_VEHICLE_21_X =			["I_Truck_02_MRL_F","Zamak MRL Rocket (60CP)",60];
blufor_RQST_VEHICLE_22_X =			["O_Plane_CAS_02_dynamicLoadout_F","TO-199 Neophron CAS (45CP)",45];
blufor_RQST_VEHICLE_23_X =			["MIN_RF_SU_34","SU-34 Fullback (40CP)",40];
blufor_RQST_VEHICLE_24_X =			["O_UAV_01_F","UAV AR-2 Tayran (5CP)",5];
blufor_RQST_VEHICLE_25_X =			["O_UAV_02_dynamicLoadout_F","UAV K-40 Ababil-3 (15CP)",15];
blufor_RQST_VEHICLE_26_X =			["O_UGV_01_F","UGV Saif (10CP)",10];
blufor_RQST_VEHICLE_27_X =			["O_UGV_01_rcws_F","UGV Saif RCWS (20CP)",20];
blufor_RQST_VEHICLE_28_X =			["empty",0,0];
blufor_RQST_VEHICLE_29_X =			["empty",0,0];
blufor_RQST_VEHICLE_30_X =			["empty",0,0];
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

