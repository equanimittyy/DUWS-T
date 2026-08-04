if (!isServer) exitWith {};

/////////  BLUFOR INIT  ///////////////////

// Resolves the dropdown's answer (BLUFOR_FactionFile_X) to a faction file and runs it. Runs once
// when the confirmation screen asks for a preview and again at the commit, and re-runs whenever
// the setup screens are stepped back through -- so it must read the token rather than
// BLUFOR_Faction_X, which the loop below overwrites with the faction class the random vehicle
// patrols want. A second pass reading that overwritten value matches no row and silently keeps
// the previous faction's file.
{
	if (BLUFOR_FactionFile_X == (_x select 2)) then {
		BLUFOR_Faction_X = (_x select 0);
	};
} foreach Factions_Available_BLUFOR_X;

["INFO", "FACTION", format ["Faction init: %1", BLUFOR_FactionFile_X]] call fnc_log;

_factionFile = "duws\shared\factions\" + VERSION_X + "\" + BLUFOR_FactionFile_X + "_blufor.sqf";
fnc_BLUFOR_FactionFile_X = compile preprocessFileLineNumbers _factionFile;
[] call fnc_BLUFOR_FactionFile_X;
sleep 1;

["INFO", "FACTION", "Faction init Faction file done"] call fnc_log;

publicVariable "BLUFOR_Faction_X";
publicVariable "BLUFOR_FactionFile_X";
publicVariable "fnc_BLUFOR_FactionFile_X";
