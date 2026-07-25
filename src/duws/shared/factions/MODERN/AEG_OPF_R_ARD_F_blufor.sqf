
///////////////
///////////////   "OPF_R_arid_F", "Aegis Russia - 2035 (Arid)", "AEG_OPF_R_ARD_F"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"O_R_Soldier_ard_F";					//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"O_R_Soldier_LAT_ard_F";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"O_R_Soldier_GL_ard_F";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"O_R_Soldier_TL_ard_F";				//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"O_R_Soldier_SL_ard_F";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"O_R_Soldier_AR_ard_F";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"O_R_soldier_M_ard_F";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"O_R_OFFICER_ard_F";					//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"O_R_helipilot_ard_F";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"O_R_Boat_Armed_01_hmg_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"C_Man_UtilityWorker_01_F";		//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"O_R_Heli_Light_02_dynamicLoadout_ard_F";		//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"O_R_Heli_Transport_04_bench_ard_F";   			//random patrol
blufor_HELI_ATTACK_X =			"O_R_Heli_Attack_02_dynamicLoadout_ard_F";		//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"O_R_Plane_CAS_02_dynamicLoadout_ard_F";		//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"O_R_LSV_02_armed_ard_F";					//random patrol
blufor_APC_PATROL1_X =			"O_R_APC_Wheeled_04_cannon_ard_F";			//random patrol
blufor_APC_PATROL2_X =			"O_R_APC_Tracked_02_cannon_ard_F";			//random patrol
blufor_TANK_PATROL1_X =			"O_R_MBT_04_command_ard_F";						//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"B_static_AA_F";
blufor_TURRET_AT =				"B_static_AT_F";
blufor_TURRET_HMG =				"B_HMG_01_high_F";
blufor_TURRET_GMG =				"B_GMG_01_high_F";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"O_R_recon_ard_F";					//operator
blufor_SPECOPS_GL_X =			"O_R_recon_JTAC_ard_F";				//operator
blufor_SPECOPS_LAT_X =			"O_R_recon_LAT_ard_F";				//operator
blufor_SPECOPS_HAT_X =			"O_R_Soldier_HAT_ard_F";				//operator
blufor_SPECOPS_AA_X =			"O_R_soldier_AA_ard_F";				//operator
blufor_SPECOPS_MG_X =			"O_R_Soldier_ar_ard_F";				//operator
blufor_SPECOPS_MEDIC_X =		"O_R_recon_medic_ard_F";				//operator
blufor_SPECOPS_MARK_X =			"O_R_recon_M_ard_F";					//operator
blufor_SPECOPS_SNIPER_X =		"O_R_sniper_ard_F";					//operator
blufor_SPECOPS_EXP_X =			"O_R_recon_exp_ard_F";				//operator
blufor_SPECOPS_ENG_X = 			"O_R_engineer_ard_F";					//operator





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


blufor_RQST_UNIT_01_X = 			["O_R_Soldier_ard_F","Rifleman (2CP)",2];
blufor_RQST_UNIT_02_X =				["O_R_Soldier_GL_ard_F","Grenadier (3CP)",3];
blufor_RQST_UNIT_03_X =				["O_R_Soldier_AR_ard_F","Automatic Rifleman (3CP)",3];
blufor_RQST_UNIT_04_X =				["O_R_Soldier_uav_ard_F","Drone Operator (4CP)",4];
blufor_RQST_UNIT_05_X =				["O_R_Medic_ard_F","Medic (4CP)",4];
blufor_RQST_UNIT_06_X =				["O_R_Soldier_LAT_ard_F","AT Rifleman (3CP)",3];
blufor_RQST_UNIT_07_X =				["O_R_Soldier_AT_ard_F","AT Specialist (4CP)",4];
blufor_RQST_UNIT_08_X =				["O_R_soldier_AA_ard_F","AA Specialist (4CP)",4];
blufor_RQST_UNIT_09_X =				["O_R_Engineer_ard_F","Engineer (4CP)",4];
blufor_RQST_UNIT_10_X =				["O_R_soldier_M_ard_F","Marksman (3CP)",3];
blufor_RQST_UNIT_11_X =				["O_R_sniper_ard_F","Sniper (4CP)",4];
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
blufor_RQST_VEHICLE_04_X =			["O_R_MRAP_02_ard_F","Galkin Unarmed (5CP)",5];
blufor_RQST_VEHICLE_05_X =			["O_R_MRAP_02_hmg_ard_F","Galkin HMG (18CP)",18];
blufor_RQST_VEHICLE_06_X =			["O_R_MRAP_02_gmg_ard_F","Galkin GMG (25CP)",25];
blufor_RQST_VEHICLE_07_X =			["O_R_LSV_02_unarmed_ard_F","Takhion Unarmed (5CP)",5];
blufor_RQST_VEHICLE_08_X =			["O_R_LSV_02_armed_ard_F","Takhion HMG (15CP)",15];
blufor_RQST_VEHICLE_09_X =			["O_R_LSV_02_AT_ard_F","Takhion AT (20CP)",20];
blufor_RQST_VEHICLE_10_X =			["O_Truck_03_transport_F","Tempest Transport Uncovered (8CP)",8];
blufor_RQST_VEHICLE_11_X =			["O_Truck_03_covered_F","Tempest Transport Covered (8CP)",8];
blufor_RQST_VEHICLE_12_X =			["O_Truck_02_box_F","Zamak Repair (50CP)",50];
blufor_RQST_VEHICLE_13_X =			["O_Truck_02_Ammo_F","Zamak Ammo (50CP)",50];
blufor_RQST_VEHICLE_14_X =			["O_Truck_02_fuel_F","Zamak Fuel (50CP)",50];
blufor_RQST_VEHICLE_15_X =			["O_APC_Wheeled_02_rcws_v2_F","MSE-3 Marid (35CP)",35];
blufor_RQST_VEHICLE_16_X =			["O_R_APC_Wheeled_04_cannon_ard_F","BTR-100 Bogatyr (35CP)",35];
blufor_RQST_VEHICLE_17_X =			["I_APC_tracked_03_cannon_F","Mora Cannon (35CP)",35];
blufor_RQST_VEHICLE_18_X =			["O_R_APC_Tracked_02_cannon_ard_F","BTR-K Kamysh (40CP)",40];
blufor_RQST_VEHICLE_19_X =			["O_R_MBT_02_cannon_ard_F","T-100 Varsuk (40CP)",40];
blufor_RQST_VEHICLE_20_X =			["O_R_MBT_04_command_ard_F","T-140K Angara (40CP)",40];
blufor_RQST_VEHICLE_21_X =			["I_MBT_03_cannon_F","MBT-52 Kuma (50CP)",50];
blufor_RQST_VEHICLE_22_X =			["O_R_Truck_02_MRL_ard_F","Zamak MRL Rocket (60CP)",60];
blufor_RQST_VEHICLE_23_X =			["O_R_MBT_02_arty_ard_F","2S9 Sochor (75CP)",75];
blufor_RQST_VEHICLE_24_X =			["C_Heli_Light_01_civil_F","Heli Civilian Light (22CP)",22];
blufor_RQST_VEHICLE_25_X =			["I_Heli_light_03_unarmed_F","Hellcat Unarmed (15CP)",15];
blufor_RQST_VEHICLE_26_X =			["O_R_Heli_Light_02_dynamicLoadout_ard_F","PO-30 Orca Armed (30CP)",30];
blufor_RQST_VEHICLE_27_X =			["I_Heli_Transport_02_F","CH-49 Mohawk (35CP",35];
blufor_RQST_VEHICLE_28_X =			["O_R_Heli_Attack_02_dynamicLoadout_ard_F","MI-48 Kajman Attack (45CP)",45];
blufor_RQST_VEHICLE_29_X =			["O_R_Plane_CAS_02_dynamicLoadout_ard_F","TO-199 Neophron CAS (45CP)",45];
blufor_RQST_VEHICLE_30_X =			["O_R_Plane_Fighter_02_ard_F","TO-201 Shikra (50CP)",50];
blufor_RQST_VEHICLE_31_X =			["O_R_Plane_Fighter_02_Stealth_ard_F","TO-201 Shikra Stealth (60CP)",60];
blufor_RQST_VEHICLE_32_X =			["O_UAV_01_F","UAV AR-2 Tayran (5CP)",5];
blufor_RQST_VEHICLE_33_X =			["O_UAV_02_dynamicLoadout_F","UAV K-40 Ababil-3 (15CP)",15];
blufor_RQST_VEHICLE_34_X =			["O_UGV_01_F","UGV Saif (10CP)",10];
blufor_RQST_VEHICLE_35_X =			["O_UGV_01_rcws_F","UGV Saif RCWS (20CP)",20];
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

