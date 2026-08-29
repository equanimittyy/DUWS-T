
///////////////   "OPTRE_UNSC", "UNSCDF (Woodland)", "OPTRE_UNSC_WDL"


blufor_SOLDIER_X =				"OPTRE_UNSC_Army_Soldier_Rifleman_BR_WDL";				//patrol, fortify, paradrop
blufor_LAT_SOLDIER_X =			"OPTRE_UNSC_Army_Soldier_Rifleman_AT_WDL";				//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_GL_SOLDIER_X =			"OPTRE_UNSC_Army_Soldier_Grenadier_WDL";			//init_hq\fnc_HQguards, supports\fnc_paradrop
blufor_TL_SOLDIER_X =			"OPTRE_UNSC_Army_Soldier_TeamLead_WDL";			//init_hq\fnc_HQguards
blufor_SL_SOLDIER_X =			"OPTRE_UNSC_Army_Soldier_SquadLead_WDL";			//Comms voice, Multiplayer slot
blufor_AR_SOLDIER_X =			"OPTRE_UNSC_Army_Soldier_Autorifleman_WDL";		//supports\fnc_paradrop, init_hq\fnc_HQguards
blufor_MARK_SOLDIER_X =			"OPTRE_UNSC_Army_Soldier_Marksman_WDL";				//init_hq\fnc_HQguards
blufor_OFFICER_X =				"OPTRE_UNSC_Army_Soldier_Officer_WDL";				//init_hq\fnc_BluHQinit
blufor_HELI_PILOT_X	=			"OPTRE_UNSC_Airforce_Soldier_Airman";				//Rescue Pilot mission

blufor_BOAT_ARMED_X	=			"optre_catfish_mg_f";			//supports\taxi\fnc_boatTaxi
blufor_BOAT_CREW_X =			"OPTRE_UNSC_Marine_Soldier_Rifleman_AR";				//supports\taxi\fnc_boatTaxi

blufor_HELI_TRANS_ARM_X =		"OPTRE_UNSC_falcon";						//supports\taxi\fnc_helotaxi, random patrol
blufor_TRANS_HELI_X =			"OPTRE_Pelican_armed";  						//random patrol
blufor_ATTACK_HELI_X =			"OPTRE_UNSC_hornet_CAS";						//dialog\fnc_request_hcATTchop, random patrol
blufor_MISC_AIR_X =				"OPTRE_AV22A_Sparrowhawk";							//dialog\fnc_request_hcCAS, random patrol
blufor_ARMED_CAR1_X =			"OPTRE_M813_TT";				//random patrol
blufor_APC1_X =					"OPTRE_M412_IFV_UNSC";		//random patrol
blufor_APC2_X =					"OPTRE_M413_MGS_UNSC";				//random patrol
blufor_MBT_TANK1_X =			"OPTRE_M808B_UNSC";			//random patrol



blufor_TURRET_AA = 				"OPTRE_Static_AA";
blufor_TURRET_AT =				"OPTRE_Static_ATGM";
blufor_TURRET_HMG =				"OPTRE_Static_M41";
blufor_TURRET_GMG =				"OPTRE_Static_Gauss";



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





// REQUEST Units/Vehicles
// Ordered lists, no padding and no fixed length: the menus offer every entry in the order
// written here, so position in the list is the display order. A faction may list as many
// or as few as it has.

// REQUEST MENU defines labels/index for all request menu units/vehicles (not Operators)

// request_vehicle, request_vehicle_fob, request_unit, request_unit_fob 
// - these files contain the classnames referenced by the label/index


// dialog\fnc_request_unit
//   _index = lbCurSel 2100;
// dialog\fnc_request_unit_fob
//   _index = lbCurSel 2120;


blufor_RQST_UNITS = [
	["OPTRE_UNSC_Army_Soldier_Rifleman_BR_WDL","Rifleman (UNSC) (2CP)",2],
	["OPTRE_UNSC_Army_Soldier_Grenadier_WDL","Grenadier (UNSC) (3CP)",3],
	["OPTRE_UNSC_Army_Soldier_Rifleman_AR_WDL","Automatic Rifleman (UNSC) (3CP)",3],
	["OPTRE_UNSC_Army_Soldier_Autorifleman_WDL","Heavy Gunner (UNSC) (4CP)",4],
	["OPTRE_UNSC_Army_Soldier_Medic_WDL","Medic (UNSC) (4CP)",4],
	["OPTRE_UNSC_Army_Soldier_Rifleman_AT_WDL","AT Rifleman (UNSC) (3CP)",3],
	["OPTRE_UNSC_Army_Soldier_AT_Specialist_WDL","AT Specialist (UNSC) (4CP)",4],
	["OPTRE_UNSC_Army_Soldier_AA_Specialist_WDL","AA Specialist (UNSC) (4CP)",4],
	["OPTRE_UNSC_Army_Soldier_Engineer_WDL","Engineer (UNSC) (4CP)",4],
	["OPTRE_UNSC_Army_Soldier_Marksman_WDL","Marksman (UNSC) (3CP)",3],
	["OPTRE_UNSC_Army_Soldier_Sniper_WDL","Sniper (UNSC) (4CP)",4]
];


// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;

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
