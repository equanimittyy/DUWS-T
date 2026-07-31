if (!isServer) exitWith {};
// Squad list order is a contract with the request dialogs: fnc_request_squad reads lbCurSel 2101
// and fnc_request_squad_fob reads the same listbox, so reordering here silently remaps both menus.

["INFO", "BOOT", "Squad File Init"] call fnc_log;

switch (VERSION_X) do {
	case "MODERN": {

		// Create a squad/team
		_reconteam = [blufor_SPECOPS_X, blufor_SPECOPS_GL_X, blufor_SPECOPS_MG_X, blufor_SPECOPS_LAT_X];
		_infteam  = [blufor_SOLDIER_TL_X, blufor_SOLDIER_GL_X, blufor_SOLDIER_LAT_X, blufor_SOLDIER_AR_X];
		_squad = [blufor_SOLDIER_SL_X, blufor_SOLDIER_X, blufor_SOLDIER_X, blufor_SOLDIER_GL_X, blufor_SOLDIER_GL_X, blufor_SOLDIER_LAT_X, blufor_SOLDIER_LAT_X, blufor_SOLDIER_AR_X];

		// Combine vehicle with squad/team
		_motor = [selectRandom [blufor_CAR_PATROL1_X,blufor_CAR_PATROL1_X]] + _reconteam;
		_mech  = [selectRandom [blufor_APC_PATROL1_X,blufor_APC_PATROL2_X]] + _infteam;
		_armor = [selectRandom [blufor_TANK_PATROL1_X,blufor_TANK_PATROL1_X]] + _infteam;

		// Define Squad variable
		blufor_RECON_TEAM_X = [_reconteam,"Recon Team (8CP)",8];
		blufor_INF_SQUAD_X = [_squad,"Infantry Squad (12CP)",12];
		blufor_MOTOR_SECTION_X = [_motor,"Motorized Team (25CP)",25];
		blufor_MECH_SECTION_X = [_mech,"Mechanized Team (40CP)",40];
		blufor_ARMOR_SECTION_X = [_armor,"Armor Section (50CP)",50];

		publicVariable "blufor_RECON_TEAM_X";
		publicVariable "blufor_INF_SQUAD_X";
		publicVariable "blufor_MOTOR_SECTION_X";
		publicVariable "blufor_MECH_SECTION_X";
		publicVariable "blufor_ARMOR_SECTION_X";

	};
};

["INFO", "BOOT", format ["Squad file Armor Section: %1", str blufor_ARMOR_SECTION_X]] call fnc_log;



