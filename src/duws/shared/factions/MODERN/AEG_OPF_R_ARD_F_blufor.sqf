
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
blufor_LAT_SOLDIER_X =			"O_R_Soldier_LAT_ard_F";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"O_R_Soldier_GL_ard_F";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"O_R_Soldier_TL_ard_F";				//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"O_R_Soldier_SL_ard_F";				//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"O_R_Soldier_AR_ard_F";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"O_R_soldier_M_ard_F";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"O_R_OFFICER_ard_F";					//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"O_R_helipilot_ard_F";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"O_R_Boat_Armed_01_hmg_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"C_Man_UtilityWorker_01_F";		//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"O_R_Heli_Light_02_dynamicLoadout_ard_F";		//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"O_R_Heli_Transport_04_bench_ard_F";   			//random patrol
blufor_ATTACK_HELI_X =			"O_R_Heli_Attack_02_dynamicLoadout_ard_F";		//dialog\fnc_request_hcATTchop, random patrol
blufor_MISC_AIR_X =				"O_R_Plane_CAS_02_dynamicLoadout_ard_F";		//dialog\fnc_request_hcCAS, random patrol
blufor_ARMED_CAR1_X =			"O_R_LSV_02_armed_ard_F";					//random patrol
blufor_APC1_X =					"O_R_APC_Wheeled_04_cannon_ard_F";			//random patrol
blufor_APC2_X =					"O_R_APC_Tracked_02_cannon_ard_F";			//random patrol
blufor_MBT_TANK1_X =			"O_R_MBT_04_command_ard_F";						//random patrol


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
// Ordered lists, no padding and no fixed length: the menus offer every entry in the order
// written here, so position in the list is the display order. A faction may list as many
// or as few as it has.
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


blufor_RQST_UNITS = [
	["O_R_Soldier_ard_F","Rifleman (2CP)",2],
	["O_R_Soldier_GL_ard_F","Grenadier (3CP)",3],
	["O_R_Soldier_AR_ard_F","Automatic Rifleman (3CP)",3],
	["O_R_Soldier_uav_ard_F","Drone Operator (4CP)",4],
	["O_R_Medic_ard_F","Medic (4CP)",4],
	["O_R_Soldier_LAT_ard_F","AT Rifleman (3CP)",3],
	["O_R_Soldier_AT_ard_F","AT Specialist (4CP)",4],
	["O_R_soldier_AA_ard_F","AA Specialist (4CP)",4],
	["O_R_Engineer_ard_F","Engineer (4CP)",4],
	["O_R_soldier_M_ard_F","Marksman (3CP)",3],
	["O_R_sniper_ard_F","Sniper (4CP)",4]
];



///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////

blufor_RQST_VEHICLES = [
	["O_Quadbike_01_F","ATV (1CP)",1],
	["C_Offroad_01_F","SF Offroader (2CP)",2],
	["I_G_Van_01_transport_F","Transport Truck (6CP)",6],
	["O_R_MRAP_02_ard_F","Galkin Unarmed (5CP)",5],
	["O_R_MRAP_02_hmg_ard_F","Galkin HMG (18CP)",18],
	["O_R_MRAP_02_gmg_ard_F","Galkin GMG (25CP)",25],
	["O_R_LSV_02_unarmed_ard_F","Takhion Unarmed (5CP)",5],
	["O_R_LSV_02_armed_ard_F","Takhion HMG (15CP)",15],
	["O_R_LSV_02_AT_ard_F","Takhion AT (20CP)",20],
	["O_Truck_03_transport_F","Tempest Transport Uncovered (8CP)",8],
	["O_Truck_03_covered_F","Tempest Transport Covered (8CP)",8],
	["O_Truck_02_box_F","Zamak Repair (50CP)",50],
	["O_Truck_02_Ammo_F","Zamak Ammo (50CP)",50],
	["O_Truck_02_fuel_F","Zamak Fuel (50CP)",50],
	["O_APC_Wheeled_02_rcws_v2_F","MSE-3 Marid (35CP)",35],
	["O_R_APC_Wheeled_04_cannon_ard_F","BTR-100 Bogatyr (35CP)",35],
	["I_APC_tracked_03_cannon_F","Mora Cannon (35CP)",35],
	["O_R_APC_Tracked_02_cannon_ard_F","BTR-K Kamysh (40CP)",40],
	["O_R_MBT_02_cannon_ard_F","T-100 Varsuk (40CP)",40],
	["O_R_MBT_04_command_ard_F","T-140K Angara (40CP)",40],
	["I_MBT_03_cannon_F","MBT-52 Kuma (50CP)",50],
	["O_R_Truck_02_MRL_ard_F","Zamak MRL Rocket (60CP)",60],
	["O_R_MBT_02_arty_ard_F","2S9 Sochor (75CP)",75],
	["C_Heli_Light_01_civil_F","Heli Civilian Light (22CP)",22],
	["I_Heli_light_03_unarmed_F","Hellcat Unarmed (15CP)",15],
	["O_R_Heli_Light_02_dynamicLoadout_ard_F","PO-30 Orca Armed (30CP)",30],
	["I_Heli_Transport_02_F","CH-49 Mohawk (35CP",35],
	["O_R_Heli_Attack_02_dynamicLoadout_ard_F","MI-48 Kajman Attack (45CP)",45],
	["O_R_Plane_CAS_02_dynamicLoadout_ard_F","TO-199 Neophron CAS (45CP)",45],
	["O_R_Plane_Fighter_02_ard_F","TO-201 Shikra (50CP)",50],
	["O_R_Plane_Fighter_02_Stealth_ard_F","TO-201 Shikra Stealth (60CP)",60],
	["O_UAV_01_F","UAV AR-2 Tayran (5CP)",5],
	["O_UAV_02_dynamicLoadout_F","UAV K-40 Ababil-3 (15CP)",15],
	["O_UGV_01_F","UGV Saif (10CP)",10],
	["O_UGV_01_rcws_F","UGV Saif RCWS (20CP)",20]
];

