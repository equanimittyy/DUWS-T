
///////////////
///////////////   "CSAT_WINTER", "CSAT (Winter)", "CSAT_WINTER"
///////////////
//Using Hex variants since I like it the most of the four options
//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"RIFLEMAN_WINTER_HEX";				//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"RIFLEMAN_AT_WINTER_HEX";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"GRENADIER_WINTER_HEX";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"TEAM_LEADER_WINTER_HEX";			//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"SQUAD_LEADER_WINTER_HEX";			//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"AUTORIFLEMAN_WINTER_HEX";			//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"MARKSMAN_WINTER_HEX";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"OFFICER_COLONEL_WINTER_HEX";		//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"HELICOPTER_PILOT_WINTER_HEX";		//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"O_Boat_Armed_01_hmg_F";			//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"C_Man_UtilityWorker_01_F";			//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"ORCA_ARMED_WINTER_HEX";				//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"ORCA_UNARMED_WINTER_HEX";   			//random patrol
blufor_HELI_ATTACK_X =			"KAJMAN_WINTER_HEX";					//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"NEOPHRON_WINTER_HEX";					//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"QILIN_MINIGUN_WINTER_HEX";				//random patrol
blufor_APC_PATROL1_X =			"MSE_MARID_WINTER_HEX";					//random patrol
blufor_APC_PATROL2_X =			"BTR_K_KAMYSH_WINTER_HEX";				//random patrol
blufor_TANK_PATROL1_X =			"T140_ANGARA_WINTER_HEX";				//random patrol
//blufor_TANK_PATROL1_X =		"T100_VARSUK_WINTER_HEX";				Considered using T-100 to nerf player CSAT, but I didn't want to mess with anything


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"STATIC_AA_WINTER_HEX";
blufor_TURRET_AT =				"STATIC_AT_WINTER_HEX";
blufor_TURRET_HMG =				"MK30_R_WINTER_HEX";
blufor_TURRET_GMG =				"MK32_R_WINTER_HEX";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"RECON_SCOUT_WINTER_HEX";				//operator
blufor_SPECOPS_GL_X =			"RECON_JTAC_WINTER_HEX";				//operator
blufor_SPECOPS_LAT_X =			"RECON_SCOUT_AT_WINTER_HEX";			//operator
blufor_SPECOPS_HAT_X =			"MISSILE_SPECIALIST_AT_WINTER_HEX";		//operator
blufor_SPECOPS_AA_X =			"MISSILE_SPECIALIST_AA_WINTER_HEX";		//operator
blufor_SPECOPS_MG_X =			"HEAVY_GUNNER_WINTER_HEX";				//operator
blufor_SPECOPS_MEDIC_X =		"RECON_PARAMEDIC_WINTER_HEX";			//operator
blufor_SPECOPS_MARK_X =			"RECON_MARKSMAN_WINTER_HEX";			//operator
blufor_SPECOPS_SNIPER_X =		"SNIPER_WINTER_HEX";					//operator
blufor_SPECOPS_EXP_X =			"RECON_DEMO_SPECIALIST_WINTER_HEX";		//operator
blufor_SPECOPS_ENG_X = 			"ENGINEER_WINTER_HEX";					//operator





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
	["RIFLEMAN_WINTER_HEX","Rifleman (2CP)",2],
	["GRENADIER_WINTER_HEX","Grenadier (3CP)",3],
	["AUTORIFLEMAN_WINTER_HEX","Automatic Rifleman (3CP)",3],
	["HEAVYGUNNER_WINTER_HEX","Heavy Gunner (4CP)",4],
	["MEDIC_WINTER_HEX","Medic (4CP)",4],
	["RIFLEMAN_AT_WINTER_HEX","AT Rifleman (3CP)",3],
	["MISSILE_SPECIALIST_AT_WINTER_HEX","AT Specialist (4CP)",4],
	["MISSILE_SPECIALIST_AA_WINTER_HEX","AA Specialist (4CP)",4],
	["ENGINEER_WINTER_HEX","Engineer (4CP)",4],
	["MARKSMAN_WINTER_HEX","Marksman (3CP)",3],
	["SNIPER_WINTER_HEX","Sniper (4CP)",4]
];



///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////

blufor_RQST_VEHICLES = [
	["QUADBIKE_WINTER_HEX","ATV (1CP)",1],
	["C_Offroad_01_F","SF Offroader (2CP)",2],
	["I_G_Van_01_transport_F","Transport Truck (6CP)",6],
	["IFRIT_WINTER_HEX","Ifrit Unarmed (5CP)",5],
	["IFRIT_HMG_WINTER_HEX","Ifrit HMG (18CP)",18],
	["IFRIT_GMG_WINTER_HEX","Ifrit GMG (25CP)",25],
	["QILIN_WINTER_HEX","Qilin Unarmed (5CP)",5],
	["QILIN_MINIGUN_WINTER_HEX","Qilin HMG (15CP)",15],
	["QILIN_AT_WINTER_HEX","Qilin AT (20CP)",20],
	["TEMPEST_TRANSPORT_WINTER_HEX","Tempest Transport Uncovered (8CP)",8],
	["TEMPEST_TRANSPORT_COVERED_WINTER_HEX","Tempest Transport Covered (8CP)",8],
	["ZAMAK_REPAIR_WINTER_HEX","Zamak Repair (50CP)",50],
	["ZAMAK_AMMO_WINTER_HEX","Zamak Ammo (50CP)",50],
	["ZAMAK_FUEL_WINTER_HEX","Zamak Fuel (50CP)",50],
	["MSE_MARID_WINTER_HEX","MSE-3 Marid (35CP)",35],
	["ZSU39_TIGRIS_WINTER_HEX","ZSU-39 Tigris (30CP)",30],
	["BTR_K_KAMYSH_WINTER_HEX","BTR-K Kamysh (40CP)",40],
	["T100_VARSUK_WINTER_HEX","T-100 Varsuk (40CP)",40],
	["T140K_ANGARA_WINTER_HEX","T-140K Angara (50CP)",50],
	["SOCHOR_WINTER_HEX","2S9 Sochor (75CP)",75],
	["C_Heli_Light_01_civil_F","Heli Civilian Light (22CP)",22],
	["ORCA_UNARMED_WINTER_HEX","PO-30 Orca Unarmed (15CP)",15],
	["ORCA_ARMED_WINTER_HEX","PO-30 Orca Armed (30CP)",30],
	["TARU_TRANSPORT_WINTER_HEX","Mi-290 Taru Transport (35CP",35],
	["KAJMAN_WINTER_HEX","MI-48 Kajman Attack (45CP)",45],
	["NEOPHRON_WINTER_HEX","TO-199 Neophron CAS (45CP)",45],
	["SHIKRA_WINTER_HEX","TO-201 Shikra (50CP)",50],
	["SHIKRA_STEALTH_WINTER_HEX","TO-201 Shikra Stealth (60CP)",60],
	["TAYRAN_A2_WINTER_HEX","UAV AR-2 Tayran (5CP)",5],
	["K40_ABABIL_WINTER_HEX","UAV K-40 Ababil-3 (15CP)",15],
	["UGV_SAIF_UNARMED_WINTER_HEX","UGV Saif (10CP)",10],
	["UGV_SAIF_RCWS_WINTER_HEX","UGV Saif RCWS (20CP)",20]
];

