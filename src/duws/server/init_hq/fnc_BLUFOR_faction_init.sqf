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

// Cleared before the file runs, because a faction file only assigns the keys it defines -- it never
// clears the ones it does not. Stepping back through the setup screens and picking a second faction
// would otherwise leave the first one's class standing in every key the second omits, and
// fnc_faction_backfill would read that leftover as a role this faction fields.
// fnc_custom_faction_parse clears the same way, for the same reason.
{
	missionNamespace setVariable [_x select 0, ""];
	// Same leftover trap for the row's tier: a hand-written file that assigns the key but not a tier
	// would otherwise show the previous faction's colour. Cleared to 0 (white) so a file that defines
	// a key straight reads as the faction's own choice unless resolution or backfill says otherwise.
	missionNamespace setVariable [format ["DUWS_factionTier_%1", _x select 0], 0];
} forEach (["blufor"] call fnc_faction_schema);

_factionFile = "duws\shared\factions\" + VERSION_X + "\" + BLUFOR_FactionFile_X + "_blufor.sqf";
fnc_BLUFOR_FactionFile_X = compile preprocessFileLineNumbers _factionFile;
[] call fnc_BLUFOR_FactionFile_X;
sleep 1;

["INFO", "FACTION", "Faction init Faction file done"] call fnc_log;

publicVariable "BLUFOR_Faction_X";
publicVariable "BLUFOR_FactionFile_X";
publicVariable "fnc_BLUFOR_FactionFile_X";
