
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
blufor_SOLDIER_LAT_X =			"OPTRE_UNSC_Marine_Soldier_Rifleman_AT";				//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_GL_X =			"OPTRE_UNSC_Marine_Soldier_Grenadier";			//initHQ\fnc_HQguards, supports\fnc_paradrop
blufor_SOLDIER_TL_X =			"OPTRE_UNSC_Marine_Soldier_TeamLead";			//initHQ\fnc_createpatrolFOB, initHQ\fnc_HQguards
blufor_SOLDIER_SL_X =			"OPTRE_UNSC_Marine_Soldier_SquadLead";			//Comms voice, Multiplayer slot
blufor_SOLDIER_AR_X =			"OPTRE_UNSC_Marine_Soldier_Rifleman_AR";		//supports\fnc_paradrop, initHQ\fnc_HQguards
blufor_MARKSMAN_X = 			"OPTRE_UNSC_Marine_Soldier_Marksman";				//initHQ\fnc_HQguards
blufor_OFFICER_X =				"OPTRE_UNSC_Marine_Soldier_Officer";				//initHQ\fnc_BluHQinit
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


blufor_RQST_UNIT_01_X = 			["OPTRE_UNSC_Marine_Soldier_Rifleman_BR","Rifleman (UNSC) (2CP)",2];
blufor_RQST_UNIT_02_X =				["OPTRE_UNSC_Marine_Soldier_Grenadier","Grenadier (UNSC) (3CP)",3];
blufor_RQST_UNIT_03_X =				["OPTRE_UNSC_Marine_Soldier_Rifleman_AR","Automatic Rifleman (UNSC) (3CP)",3];
blufor_RQST_UNIT_04_X =				["OPTRE_UNSC_Marine_Soldier_Autorifleman","Heavy Gunner (UNSC) (4CP)",4];
blufor_RQST_UNIT_05_X =				["OPTRE_UNSC_Marine_Soldier_Corpsman","Medic (UNSC) (4CP)",4];
blufor_RQST_UNIT_06_X =				["OPTRE_UNSC_Marine_Soldier_Rifleman_AT","AT Rifleman (UNSC) (3CP)",3];
blufor_RQST_UNIT_07_X =				["OPTRE_UNSC_Marine_Soldier_AT_Specialist","AT Specialist (UNSC) (4CP)",4];
blufor_RQST_UNIT_08_X =				["OPTRE_UNSC_Marine_Soldier_AA_Specialist","AA Specialist (UNSC) (4CP)",4];
blufor_RQST_UNIT_09_X =				["OPTRE_UNSC_Marine_Soldier_Engineer","Engineer (UNSC) (4CP)",4];
blufor_RQST_UNIT_10_X =				["OPTRE_UNSC_Marine_Soldier_Marksman","Marksman (UNSC) (3CP)",3];
blufor_RQST_UNIT_11_X =				["OPTRE_UNSC_Marine_Soldier_Sniper","Sniper (UNSC) (4CP)",4];
blufor_RQST_UNIT_12_X =				["empty",0,0];
blufor_RQST_UNIT_13_X =				["empty",0,0];
blufor_RQST_UNIT_14_X =				["empty",0,0];


///////////////////////////////
// dialog\fnc_request_vehicle
//   _index = lbCurSel 2102;
// dialog\fnc_request_vehicle_fob
//   _index = lbCurSel 2122;
////////////////////////////////

blufor_RQST_VEHICLE_01_X =			["OPTRE_M12_FAV","Warthog (Unarmed) (2CP)",2];
blufor_RQST_VEHICLE_02_X =			["OPTRE_M813_TT","Warthog Transport (6CP)",6];
blufor_RQST_VEHICLE_03_X =			["OPTRE_m1087_stallion_unsc","Stallion Transport (8CP)",8];
blufor_RQST_VEHICLE_04_X =			["OPTRE_M12_LRV","Warthog MG (15CP)",15];
blufor_RQST_VEHICLE_05_X =			["OPTRE_M12A1_LRV","Warthog Rocket (20CP)",20];
blufor_RQST_VEHICLE_06_X =			["OPTRE_M12G1_LRV","Warthog Gauss (25CP)",25];
blufor_RQST_VEHICLE_07_X =			["OPTRE_M12R_AA","Warthog AA (30CP)",30];
blufor_RQST_VEHICLE_08_X =			["OPTRE_M808B_UNSC","Scorpion (45CP)",45];
blufor_RQST_VEHICLE_09_X =			["OPTRE_UNSC_hornet","Hornet (15CP)",15];
blufor_RQST_VEHICLE_10_X =			["OPTRE_AV22_Sparrowhawk","AV22 Sparrowhawk (25CP)",25];
blufor_RQST_VEHICLE_11_X =			["OPTRE_AV22A_Sparrowhawk","AV22A Sparrowhawk (35CP)",35];
blufor_RQST_VEHICLE_12_X =			["OPTRE_UNSC_falcon","Falcon (22CP)",22];
blufor_RQST_VEHICLE_13_X =			["OPTRE_Pelican_unarmed","Pelican (Unarmed) (26CP)",26];
blufor_RQST_VEHICLE_14_X =			["OPTRE_Pelican_armed","Pelican (Armed) (30CP)",30];
blufor_RQST_VEHICLE_15_X =			["OPTRE_M412_IFV_UNSC","Bison IFV (40CP)",40];
blufor_RQST_VEHICLE_16_X =			["OPTRE_M413_MGS_UNSC","Bison MGS (50CP)",50];
blufor_RQST_VEHICLE_17_X =			["OPTRE_M808S","Heavy Scorpion (50CP)",50];
blufor_RQST_VEHICLE_18_X =			["OPTRE_M313_UNSC","Elephant (30CP)",30];
blufor_RQST_VEHICLE_19_X =			["empty",0,0];
blufor_RQST_VEHICLE_20_X =			["empty",0,0];
blufor_RQST_VEHICLE_21_X =			["empty",0,0];
blufor_RQST_VEHICLE_22_X =			["empty",0,0];
blufor_RQST_VEHICLE_23_X =			["empty",0,0];
blufor_RQST_VEHICLE_24_X =			["empty",0,0];
blufor_RQST_VEHICLE_25_X =			["empty",0,0];
blufor_RQST_VEHICLE_26_X =			["empty",0,0];
blufor_RQST_VEHICLE_27_X =			["empty",0,0];
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
