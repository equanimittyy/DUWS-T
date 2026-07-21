if (!isServer) exitWith {};

/////////  BLUFOR INIT  ///////////////////

//hint "BLUFOR INIT";
switch (VERSION_X) do {
	case "MODERN": {
		if (BLUFOR_Faction_X == "BLU_F") then {
			BLUFOR_FactionFile_X = "BLU_F_ARID";
		};
	};
};

{
	if (BLUFOR_Faction_X == (_x select 2)) then {
		BLUFOR_FactionFile_X = (_x select 2);
		BLUFOR_Faction_X = (_x select 0);	
	};
} foreach Factions_Available_BLUFOR_X;

diag_log format ["Faction init: %1", BLUFOR_FactionFile_X];

_factionFile = "duws\FACTIONS\" + VERSION_X + "\" + BLUFOR_FactionFile_X + "_blufor.sqf";
fnc_BLUFOR_FactionFile_X = compile preprocessFileLineNumbers _factionFile;
[] call fnc_BLUFOR_FactionFile_X;
sleep 1;

diag_log format ["Faction init Faction file done"];

publicVariable "BLUFOR_Faction_X";
publicVariable "BLUFOR_FactionFile_X";
publicVariable "fnc_BLUFOR_FactionFile_X";



