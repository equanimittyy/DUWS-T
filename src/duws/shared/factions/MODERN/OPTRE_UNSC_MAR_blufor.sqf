
///////////////
///////////////   "OPTRE_UNSC", "UNSCDF (Marines)", "OPTRE_UNSC_MAR"
///////////////

//////////////////////////////////////////////////////////////////////
/////  UNITS, VEHICLES WITH FIXED, ONE-OFF ROLES
/////   - Patrols, Guards, Support Units, Task Forces, Side Missions
/////
/////  TRY NOT TO ALTER THE UNIT TYPES.  THESE UNITS HAVE FIXED ROLES
//////////////////////////////////////////////////////////////////////

blufor_SOLDIER_X =				"OPTRE_UNSC_Marine_Soldier_Rifleman_BR";				//patrol, fortify, paradrop
blufor_SOLDIER_LAT_X =			"OPTRE_UNSC_Marine_Soldier_Rifleman_AT";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"OPTRE_UNSC_Marine_Soldier_Grenadier";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"OPTRE_UNSC_Marine_Soldier_TeamLead";			//init_hq\fnc_HQguards
blufor_SOLDIER_SL_X =			"OPTRE_UNSC_Marine_Soldier_SquadLead";			//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"OPTRE_UNSC_Marine_Soldier_Rifleman_AR";		//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARKSMAN_X = 			"OPTRE_UNSC_Marine_Soldier_Marksman";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"OPTRE_UNSC_Marine_Soldier_Officer";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"OPTRE_UNSC_Marine_Pilot";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"optre_catfish_mg_f";			//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"OPTRE_UNSC_Marine_Soldier_Crewman";				//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"OPTRE_UNSC_falcon";						//supports\taxi\fnc_helotaxi, random patrol
blufor_HELI_TRANS_UNARM_X =		"OPTRE_Pelican_armed";  						//random patrol
blufor_HELI_ATTACK_X =			"OPTRE_UNSC_hornet_CAS";						//dialog\fnc_request_hcATTchop, random patrol
blufor_PLANE_CAS_X =			"OPTRE_AV22A_Sparrowhawk";							//dialog\fnc_request_hcCAS, random patrol
blufor_CAR_PATROL1_X =			"OPTRE_M813_TT";				//random patrol
blufor_APC_PATROL1_X =			"OPTRE_M412_IFV_UNSC";		//random patrol
blufor_APC_PATROL2_X =			"OPTRE_M413_MGS_UNSC";				//random patrol
blufor_TANK_PATROL1_X =			"OPTRE_M808B_UNSC";			//random patrol


///////////////////////////////////
//  STATIC WEAPONS - HQ and FOBs
///////////////////////////////////

blufor_TURRET_AA = 				"OPTRE_Static_AA";
blufor_TURRET_AT =				"OPTRE_Static_ATGM";
blufor_TURRET_HMG =				"OPTRE_Static_M41";
blufor_TURRET_GMG =				"OPTRE_Static_Gauss";


/////////////////////////
//  OPERATOR REQUEST
/////////////////////////

blufor_SPECOPS_X =				"OPTRE_UNSC_ODST_Soldier_Rifleman_AR";				//operator
blufor_SPECOPS_GL_X =			"OPTRE_UNSC_ODST_Soldier_DemolitionsExpert";	//operator
blufor_SPECOPS_LAT_X =			"OPTRE_UNSC_ODST_Soldier_Scout_AT";		//operator 
blufor_SPECOPS_HAT_X =			"OPTRE_UNSC_ODST_Soldier_Rifleman_AT";			//operator
blufor_SPECOPS_AA_X =			"OPTRE_UNSC_ODST_Soldier_Rifleman_AT";					//operator
blufor_SPECOPS_MG_X =			"OPTRE_UNSC_ODST_Soldier_Automatic_Rifleman";	//operator
blufor_SPECOPS_MEDIC_X =		"OPTRE_UNSC_ODST_Soldier_Paramedic";		 		//operator
blufor_SPECOPS_MARK_X =			"OPTRE_UNSC_ODST_Soldier_Marksman";			//operator
blufor_SPECOPS_SNIPER_X =		"OPTRE_UNSC_ODST_Soldier_Scout_Sniper";		//operator
blufor_SPECOPS_EXP_X =			"OPTRE_UNSC_ODST_Soldier_DemolitionsExpert";			//operator
blufor_SPECOPS_ENG_X =			"OPTRE_UNSC_ODST_Soldier_DemolitionsExpert"; 	//operator





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
	["OPTRE_UNSC_Marine_Soldier_Rifleman_BR","Rifleman (UNSC) (2CP)",2],
	["OPTRE_UNSC_Marine_Soldier_Grenadier","Grenadier (UNSC) (3CP)",3],
	["OPTRE_UNSC_Marine_Soldier_Rifleman_AR","Automatic Rifleman (UNSC) (3CP)",3],
	["OPTRE_UNSC_Marine_Soldier_Autorifleman","Heavy Gunner (UNSC) (4CP)",4],
	["OPTRE_UNSC_Marine_Soldier_Corpsman","Medic (UNSC) (4CP)",4],
	["OPTRE_UNSC_Marine_Soldier_Rifleman_AT","AT Rifleman (UNSC) (3CP)",3],
	["OPTRE_UNSC_Marine_Soldier_AT_Specialist","AT Specialist (UNSC) (4CP)",4],
	["OPTRE_UNSC_Marine_Soldier_AA_Specialist","AA Specialist (UNSC) (4CP)",4],
	["OPTRE_UNSC_Marine_Soldier_Engineer","Engineer (UNSC) (4CP)",4],
	["OPTRE_UNSC_Marine_Soldier_Marksman","Marksman (UNSC) (3CP)",3],
	["OPTRE_UNSC_Marine_Soldier_Sniper","Sniper (UNSC) (4CP)",4]
];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////

blufor_RQST_VEHICLES = [
	["OPTRE_M12_FAV","Warthog (Unarmed) (2CP)",2],
	["OPTRE_M813_TT","Warthog Transport (6CP)",6],
	["OPTRE_m1087_stallion_unsc","Stallion Transport (8CP)",8],
	["OPTRE_M12_LRV","Warthog MG (15CP)",15],
	["OPTRE_M12A1_LRV","Warthog Rocket (20CP)",20],
	["OPTRE_M12G1_LRV","Warthog Gauss (25CP)",25],
	["OPTRE_M12R_AA","Warthog AA (30CP)",30],
	["OPTRE_M808B_UNSC","Scorpion (45CP)",45],
	["OPTRE_UNSC_hornet","Hornet (15CP)",15],
	["OPTRE_AV22_Sparrowhawk","AV22 Sparrowhawk (25CP)",25],
	["OPTRE_AV22A_Sparrowhawk","AV22A Sparrowhawk (35CP)",35],
	["OPTRE_UNSC_falcon","Falcon (22CP)",22],
	["OPTRE_Pelican_unarmed","Pelican (Unarmed) (26CP)",26],
	["OPTRE_Pelican_armed","Pelican (Armed) (30CP)",30],
	["OPTRE_M412_IFV_UNSC","Bison IFV (40CP)",40],
	["OPTRE_M413_MGS_UNSC","Bison MGS (50CP)",50],
	["OPTRE_M808S","Heavy Scorpion (50CP)",50],
	["OPTRE_M313_UNSC","Elephant (30CP)",30]
];
