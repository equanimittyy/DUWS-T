// Locality: server -- inherited from server/server_init.sqf.
// Server-side build of a CUSTOM faction from the pasted text. The paste screen's
// submit handler (fnc_custom_faction_capture) validates required keys and their
// classes before the player can leave that screen, so invalid data normally never
// reaches here; the guard below is defence-in-depth for a server/client addon
// mismatch. On failure it logs and leaves the faction-data holder unset, which
// surfaces as server_init's wait stalling rather than a broken faction shipping.

params ["_side"];

switch (_side) do {

    case "blufor": {
        if (BLUfactionDataTemp != "" && {BLUFOR_Faction_X == "CUSTOM"}) then {
            (["blufor", BLUfactionDataTemp] call fnc_custom_faction_parse) params ["_pairs", "_valid", "_bad"];
            ["INFO", "FACTION", format ["BLUFOR CUSTOM FACTION: %1", str _pairs]] call fnc_log;
            if (_valid) then {
                BLUfactionData = _pairs;
                publicVariable "BLUfactionData";
            } else {
                ["ERROR", "FACTION", format ["BLUFOR CUSTOM FACTION: invalid on server (missing/unresolved: %1); build aborted.", _bad]] call fnc_log;
            };
        };
    };

    case "opfor": {
        if (OPFfactionDataTemp != "" && {OPFOR_Faction_X == "CUSTOM"}) then {
            (["opfor", OPFfactionDataTemp] call fnc_custom_faction_parse) params ["_pairs", "_valid", "_bad"];
            ["INFO", "FACTION", format ["OPFOR CUSTOM FACTION: %1", str _pairs]] call fnc_log;
            if (_valid) then {
                OPFfactionData = _pairs;
            } else {
                ["ERROR", "FACTION", format ["OPFOR CUSTOM FACTION: invalid on server (missing/unresolved: %1); build aborted.", _bad]] call fnc_log;
            };
        };
    };
};
