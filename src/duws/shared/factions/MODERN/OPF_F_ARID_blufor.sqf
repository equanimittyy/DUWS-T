
///////////////
///////////////   "OPF_F", "CSAT (Arid)", "OPF_F_ARID"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"O_Soldier_F";					//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"O_Soldier_LAT_F";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"O_Soldier_GL_F";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"O_Soldier_TL_F";				//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"O_Soldier_SL_F";				//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"O_Soldier_AR_F";				//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"O_soldier_M_F";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"O_OFFICER_F";					//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"O_helipilot_F";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"O_Boat_Armed_01_hmg_F";		//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"C_Man_UtilityWorker_01_F";		//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"O_Heli_Light_02_dynamicLoadout_F";		//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"O_Heli_Transport_04_bench_F";   		//random patrol
blufor_HELI_ATTACK_X =			"O_Heli_Attack_02_dynamicLoadout_F";	//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"O_Plane_CAS_02_dynamicLoadout_F";		//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"O_LSV_02_armed_F";						//random patrol
blufor_APC_PATROL1_X =			"O_APC_Wheeled_02_rcws_v2_F";			//random patrol
blufor_APC_PATROL2_X =			"O_APC_Tracked_02_cannon_F";			//random patrol
blufor_TANK_PATROL1_X =			"O_MBT_04_command_F";					//random patrol


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

blufor_SPECOPS_X =				"O_recon_F";					//operator
blufor_SPECOPS_GL_X =			"O_recon_JTAC_F";				//operator
blufor_SPECOPS_LAT_X =			"O_recon_LAT_F";				//operator
blufor_SPECOPS_HAT_X =			"O_Soldier_HAT_F";				//operator
blufor_SPECOPS_AA_X =			"O_soldier_AA_F";				//operator
blufor_SPECOPS_MG_X =			"O_HeavyGunner_F";				//operator
blufor_SPECOPS_MEDIC_X =		"O_recon_medic_F";				//operator
blufor_SPECOPS_MARK_X =			"O_recon_M_F";					//operator
blufor_SPECOPS_SNIPER_X =		"O_sniper_F";					//operator
blufor_SPECOPS_EXP_X =			"O_recon_exp_F";				//operator
blufor_SPECOPS_ENG_X = 			"O_engineer_F";					//operator





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
	["O_Soldier_F","Rifleman (2CP)",2],
	["O_Soldier_GL_F","Grenadier (3CP)",3],
	["O_Soldier_AR_F","Automatic Rifleman (3CP)",3],
	["O_HeavyGunner_F","Heavy Gunner (4CP)",4],
	["O_Medic_F","Medic (4CP)",4],
	["O_Soldier_LAT_F","AT Rifleman (3CP)",3],
	["O_Soldier_AT_F","AT Specialist (4CP)",4],
	["O_soldier_AA_F","AA Specialist (4CP)",4],
	["O_Engineer_F","Engineer (4CP)",4],
	["O_soldier_M_F","Marksman (3CP)",3],
	["O_sniper_F","Sniper (4CP)",4]
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
	["O_MRAP_02_F","Ifrit Unarmed (5CP)",5],
	["O_MRAP_02_hmg_F","Ifrit HMG (18CP)",18],
	["O_MRAP_02_gmg_F","Ifrit GMG (25CP)",25],
	["O_LSV_02_unarmed_F","Qilin Unarmed (5CP)",5],
	["O_LSV_02_armed_F","Qilin HMG (15CP)",15],
	["O_LSV_02_AT_F","Qilin AT (20CP)",20],
	["O_Truck_03_transport_F","Tempest Transport Uncovered (8CP)",8],
	["O_Truck_03_covered_F","Tempest Transport Covered (8CP)",8],
	["O_Truck_02_box_F","Zamak Repair (50CP)",50],
	["O_Truck_02_Ammo_F","Zamak Ammo (50CP)",50],
	["O_Truck_02_fuel_F","Zamak Fuel (50CP)",50],
	["O_APC_Wheeled_02_rcws_v2_F","MSE-3 Marid (35CP)",35],
	["I_APC_Wheeled_03_cannon_F","AFV-4 Gorgon (35CP)",35],
	["I_APC_tracked_03_cannon_F","Mora Cannon (35CP)",35],
	["O_APC_Tracked_02_cannon_F","BTR-K Kamysh (40CP)",40],
	["O_MBT_02_cannon_F","T-100 Varsuk (40CP)",40],
	["O_MBT_04_command_F","T-140K Angara (40CP)",40],
	["I_MBT_03_cannon_F","MBT-52 Kuma (50CP)",50],
	["I_Truck_02_MRL_F","Zamak MRL Rocket (60CP)",60],
	["O_MBT_02_arty_F","2S9 Sochor (75CP)",75],
	["C_Heli_Light_01_civil_F","Heli Civilian Light (22CP)",22],
	["I_Heli_light_03_unarmed_F","Hellcat Unarmed (15CP)",15],
	["O_Heli_Light_02_dynamicLoadout_F","PO-30 Orca Armed (30CP)",30],
	["I_Heli_Transport_02_F","CH-49 Mohawk (35CP",35],
	["O_Heli_Attack_02_dynamicLoadout_F","MI-48 Kajman Attack (45CP)",45],
	["O_Plane_CAS_02_dynamicLoadout_F","TO-199 Neophron CAS (45CP)",45],
	["O_Plane_Fighter_02_F","TO-201 Shikra (50CP)",50],
	["O_Plane_Fighter_02_Stealth_F","TO-201 Shikra Stealth (60CP)",60],
	["O_UAV_01_F","UAV AR-2 Tayran (5CP)",5],
	["O_UAV_02_dynamicLoadout_F","UAV K-40 Ababil-3 (15CP)",15],
	["O_UGV_01_F","UGV Saif (10CP)",10],
	["O_UGV_01_rcws_F","UGV Saif RCWS (20CP)",20]
];

