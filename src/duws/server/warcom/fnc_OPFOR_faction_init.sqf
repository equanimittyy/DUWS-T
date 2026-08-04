// Locality: server -- inherited from server/server_init.sqf.

/////////   OPFOR FACTION INIT  ///////////////////

// Reads the dropdown's token, not OPFOR_Faction_X: see fnc_BLUFOR_faction_init for why the two
// are separate now that resolution re-runs.
{
	if (OPFOR_FactionFile_X == (_x select 2)) then {
		OPFOR_Faction_X = (_x select 0);
	};
} foreach Factions_Available_OPFOR_X;

_factionFile = "duws\shared\factions\" + VERSION_X + "\" + OPFOR_FactionFile_X + "_opfor.sqf";
fnc_OPFOR_FactionFile_X = compile preprocessFileLineNumbers _factionFile;
[] call fnc_OPFOR_FactionFile_X;
sleep 1;

publicVariable "OPFOR_FactionFile_X";
publicVariable "OPFOR_Faction_X";
publicVariable "fnc_OPFOR_FactionFile_X";

// R3F logistics needs to know these values
publicVariable "opfor_TRANS_TRUCK_X";
publicVariable "opfor_AMMO_TRUCK_X";
