// Locality: client -- invoked from a dialog action.
// Resolve each side's faction choice during setup, BLUFOR first then OPFOR, showing
// only the prompt that side needs: CUSTOM -> its own paste window; AUTODETECT -> its
// picker; a preset or AUTODETECT_RANDOM -> no prompt at all. Captures the paste text
// (*factionDataTemp) or picked faction (selectedFaction_*); the heavy per-side build
// stays deferred to the post-START commit. Runs on the game-master client so every
// popup lands during setup rather than after START.
//
// Back on a paste window sets duws_custom_faction_back; this returns early and
// fnc_startup_faction_flow restarts the faction/HQ selection.
//
// The single-side paste dialog (startup_faction) is reused per side: duws_custom_side
// tells the submit handler which side it is, and the frame/info labels are set here.

private _opfAuto = (OPFOR_FactionFile_X == "AUTODETECT");

// --- BLUFOR ---
switch (BLUFOR_FactionFile_X) do {
    case "CUSTOM": {
        BLUfactionDataTemp = ""; publicVariable "BLUfactionDataTemp";
        duws_custom_side = "blufor";
        createDialog "startup_faction";
        waitUntil {dialog};
        ctrlSetText [1801, localize "STR_DUWS_T_rqdziaei"];   // "BLUFOR faction"
        ctrlSetText [1000, localize "STR_DUWS_T_y3jv4fm6"];   // "Paste your BLUFOR faction here"
        waitUntil { sleep 0.1; duws_custom_faction_back || {BLUfactionDataTemp != ""} };
    };
    case "AUTODETECT": {
        // Keep the picker open for the OPFOR round only when OPFOR also AutoDetects.
        // Never zombies, in any mode: the player's own side is not what the infection fields.
        ["Select Blufor Faction", !_opfAuto, false] call fnc_factionSelector;
        selectedFaction_BLU = selectedFaction; publicVariable "selectedFaction_BLU";
    };
};

if (duws_custom_faction_back) exitWith {};

// --- OPFOR ---
switch (OPFOR_FactionFile_X) do {
    case "CUSTOM": {
        OPFfactionDataTemp = ""; publicVariable "OPFfactionDataTemp";
        duws_custom_side = "opfor";
        createDialog "startup_faction";
        waitUntil {dialog};
        ctrlSetText [1801, localize "STR_DUWS_T_1m1bl9nd"];   // "OPFOR faction"
        ctrlSetText [1000, localize "STR_DUWS_T_13p2iheb"];   // "Paste your OPFOR faction here"
        waitUntil { sleep 0.1; duws_custom_faction_back || {OPFfactionDataTemp != ""} };
    };
    case "AUTODETECT": {
        // The zombie mode picks its enemy from the zombie factions and nothing else; every other
        // mode gets the list with those filtered out.
        ["Select Opfor Faction", true, duws_gamemode isEqualTo "zombies"] call fnc_factionSelector;
        selectedFaction_OPF = selectedFaction; publicVariable "selectedFaction_OPF";
    };
};
