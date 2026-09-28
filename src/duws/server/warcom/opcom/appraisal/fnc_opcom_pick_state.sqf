// Locality: server, [] call'd at load. The pick's mode and pace, set from the OPCOM debug page, and the event feed the
// AI overlay reads.
if (!isServer) exitWith {};

DUWS_opcom_aiMode = "weighted";
DUWS_opcom_pickOnce = "";
// Carried as a debt, so a rate below 1 picks once every few ticks.
DUWS_opcom_picksPerTick = 1;
DUWS_opcom_pickDebt = 0;
DUWS_opcom_aiEvents = [];
DUWS_opcom_aiSeq = 0;

// Read by sequence (fnc_debug_opcom_ai), so every watcher sees each line once whenever it polls.
DUWS_fnc_opcom_aiEvent = {
    params ["_text"];
    DUWS_opcom_aiSeq = DUWS_opcom_aiSeq + 1;
    DUWS_opcom_aiEvents pushBack [DUWS_opcom_aiSeq, _text];
    if (count DUWS_opcom_aiEvents > 10) then { DUWS_opcom_aiEvents deleteAt 0 };
};
