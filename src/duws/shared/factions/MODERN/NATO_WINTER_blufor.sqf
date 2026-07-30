
///////////////
///////////////   "NATO_WINTER", "NATO (Winter)", "NATO_WINTER"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"NATO_WINTER_SOLDIER";			//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"NATO_WINTER_SOLDIER_LAT";		//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"NATO_WINTER_SOLDIER_GL";		//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"NATO_WINTER_SOLDIER_TL";		//init_hq\fnc_createpatrolFOB, init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"NATO_WINTER_SOLDIER_SL";		//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"NATO_WINTER_SOLDIER_AR";		//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"NATO_WINTER_SOLDIER_M";		//init_hq\fnc_HQguards
blufor_OFFICER_X =				"NATO_WINTER_OFFICER";			//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"NATO_WINTER_HELIPILOT";		//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"B_Boat_Armed_01_minigun_F";	//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"NATO_WINTER_SOLDIER";			//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"NATO_WINTER_HELI_TRANSPORT_GHOSTHAWK";		  //supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"NATO_WINTER_HELI_TRANSPORT_HURON_UNARMED";   //random patrol
blufor_HELI_ATTACK_X =			"NATO_WINTER_HELI_ATTACK";		//dialog\fnc_request_hcATTchop
blufor_PLANE_CAS_X =			"B_Plane_CAS_01_F";				//dialog\fnc_request_hcCAS
blufor_CAR_PATROL1_X =			"NATO_WINTER_LSV";				//random patrol
blufor_APC_PATROL1_X =			"NATO_WINTER_AMV";				//random patrol
blufor_APC_PATROL2_X =			"NATO_WINTER_AA";				//random patrol
blufor_TANK_PATROL1_X =			"NATO_WINTER_MBT_TUSK";			//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"NATO_WINTER_STATIC_AA";
blufor_TURRET_AT =				"NATO_WINTER_STATIC_AT";
blufor_TURRET_HMG =				"NATO_WINTER_STATIC_HMG_HIGH";
blufor_TURRET_GMG =				"NATO_WINTER_STATIC_GMG_HIGH";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"NATO_WINTER_RECON";					//operator
blufor_SPECOPS_GL_X =			"NATO_WINTER_RECON_JTAC";				//operator
blufor_SPECOPS_LAT_X =			"NATO_WINTER_RECON_LAT";				//operator
blufor_SPECOPS_HAT_X =			"NATO_WINTER_SOLDIER_AT";				//operator
blufor_SPECOPS_AA_X =			"NATO_WINTER_SOLDIER_AA";				//operator
blufor_SPECOPS_MG_X =			"NATO_WINTER_SOLDIER_HEAVYGUNNER";		//operator
blufor_SPECOPS_MEDIC_X =		"NATO_WINTER_RECON_MEDIC";				//operator
blufor_SPECOPS_MARK_X =			"NATO_WINTER_RECON_M";					//operator
blufor_SPECOPS_SNIPER_X =		"NATO_WINTER_FULLGHILLEE";				//operator
blufor_SPECOPS_EXP_X =			"NATO_WINTER_RECON_EXP";				//operator
blufor_SPECOPS_ENG_X = 			"NATO_WINTER_SOLDIER_ENGINEER";			//operator





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
	["NATO_WINTER_SOLDIER","Rifleman (2CP)",2],
	["NATO_WINTER_SOLDIER_GL","Grenadier (3CP)",3],
	["NATO_WINTER_SOLDIER_AR","Automatic Rifleman (3CP)",3],
	["NATO_WINTER_SOLDIER_HEAVYGUNNER","Heavy Gunner (4CP)",4],
	["NATO_WINTER_SOLDIER_MEDIC","Medic (4CP)",4],
	["NATO_WINTER_SOLDIER_LAT","AT Rifleman (3CP)",3],
	["NATO_WINTER_SOLDIER_AT","AT Specialist (4CP)",4],
	["NATO_WINTER_SOLDIER_AA","AA Specialist (4CP)",4],
	["NATO_WINTER_SOLDIER_ENGINEER","Engineer (4CP)",4],
	["NATO_WINTER_SOLDIER_M","Marksman (3CP)",3],
	["NATO_WINTER_SNIPER","Sniper (4CP)",4]
];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////   

blufor_RQST_VEHICLES = [
	["NATO_WINTER_QUADBIKE","ATV (1CP)",1],
	["C_Offroad_01_F","SF Offroader (2CP)",2],
	["I_G_Van_01_transport_F","Transport Truck (6CP)",6],
	["NATO_WINTER_MRAP","Hunter Unarmed (5CP)",5],
	["NATO_WINTER_MRAP_HMG","Hunter HMG (18CP)",18],
	["NATO_WINTER_MRAP_GMG","Hunter GMG (25CP)",25],
	["NATO_WINTER_LSVU","Prowler Unarmed (5CP)",5],
	["NATO_WINTER_LSV","Prowler HMG (15CP)",15],
	["NATO_WINTER_LSVAT","Prowler AT (20CP)",20],
	["NATO_WINTER_HEMTT_TRANSPORT","HEMTT Transport Uncovered (8CP)",8],
	["NATO_WINTER_HEMTT_COVERED","HEMTT Transport Covered (8CP)",8],
	["NATO_WINTER_HEMTT_REPAIR","HEMTT Repair (50CP)",50],
	["NATO_WINTER_HEMTT_AMMO","HEMTT Ammo (50CP)",50],
	["NATO_WINTER_HEMTT_FUEL","HEMTT Fuel (50CP)",50],
	["NATO_WINTER_AMV","AMV-7 Marshall (35CP)",35],
	["NATO_WINTER_AA","IFV-6a Cheetah (30CP)",30],
	["NATO_WINTER_AFV","Rhino MGS (35CP)",35],
	["NATO_WINTER_AFV_UP","Rhino MGS UP (35CP)",35],
	["NATO_WINTER_CRV","CRV-6e Bobcat (28CP)",28],
	["NATO_WINTER_APC","IFV-6c Panther (25CP)",25],
	["NATO_WINTER_MBT","M2A1 Slammer (40CP)",40],
	["NATO_WINTER_MBT_TUSK","M2A4 Slammer UP (40CP)",40],
	["NATO_WINTER_ARTY","M4 Scorcher Artillery (75CP)",75],
	["NATO_WINTER_MLRS","M5 Sandstorm MLRS (75CP)",75],
	["NATO_WINTER_HELI_LIGHT_ARMED","AH-9 Pawnee (25CP)",25],
	["NATO_WINTER_HELI_LIGHT","MH-9 Hummingbird (15CP)",15],
	["NATO_WINTER_HELI_ATTACK","AH-99 Blackfoot (45CP)",45],
	["B_T_VTOL_01_armed_F","V-44 X Armed (40CP",40],
	["NATO_WINTER_HELI_TRANSPORT_GHOSTHAWK","UH-80 Ghosthawk (22CP)",22],
	["NATO_WINTER_HELI_TRANSPORT_HURON_UNARMED","CH-67 Huron Unarmed (26CP)",26],
	["NATO_WINTER_HELI_TRANSPORT_HURON","CH-67 Huron Armed (26CP)",26],
	["B_Plane_CAS_01_dynamicLoadout_F","A-164 Wipeout CAS (45CP)",45],
	["B_Plane_Fighter_01_F","FA-181 Black Wasp II (50CP)",50],
	["B_Plane_Fighter_01_Stealth_F","FA-181 Black Wasp II Stealth (60CP)",60],
	["NATO_WINTER_UAV_AR2","UAV Darter(5CP)",5],
	["B_UAV_02_dynamicLoadout_F","UAV MQ-4A Greyhawk (15CP)",15],
	["NATO_WINTER_UGV_","UGV Stomper Recon (10CP)",10],
	["NATO_WINTER_UGV_RCWS","UGV Stomper RCWS (20CP)",20],
	["B_T_UAV_03_dynamicLoadout_F","MQ-12 UAV (20CP)",20]
];



