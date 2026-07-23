// Server-side build of a CUSTOM faction from the pasted text. The paste screen's
// submit handler (fnc_custom_faction_capture) validates the base rifleman class
// before the player can leave that screen, so an invalid class normally never
// reaches here; the guard below is defence-in-depth for a server/client addon
// mismatch. On failure it logs and leaves the faction-data holder unset, which
// surfaces as server_init's wait stalling rather than a broken faction shipping.

params ["_side"];

switch (_side) do {

    case "blufor": {
        if (BLUfactionDataTemp != "" && {BLUFOR_Faction_X == "CUSTOM"}) then {
            (["blufor", BLUfactionDataTemp] call fnc_custom_faction_parse) params ["_pairs", "_valid"];
            diag_log format ["BLUFOR CUSTOM FACTION: %1", str _pairs];
            if (_valid) then {
                BLUfactionData = _pairs;
                publicVariable "BLUfactionData";
            } else {
                diag_log "BLUFOR CUSTOM FACTION: base rifleman class invalid on server; build aborted.";
            };
        };
    };

    case "opfor": {
        if (OPFfactionDataTemp != "" && {OPFOR_Faction_X == "CUSTOM"}) then {
            (["opfor", OPFfactionDataTemp] call fnc_custom_faction_parse) params ["_pairs", "_valid"];
            diag_log format ["OPFOR CUSTOM FACTION: %1", str _pairs];
            if (_valid) then {
                OPFfactionData = _pairs;
            } else {
                diag_log "OPFOR CUSTOM FACTION: base rifleman class invalid on server; build aborted.";
            };
        };
    };
};
