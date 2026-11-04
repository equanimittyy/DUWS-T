// Locality: server, [] call'd at load. The pick's mode and pace, set from the OPCOM debug page, and the event feed the
// AI overlay reads.
if (!isServer) exitWith {};

DUWS_fnc_opcom_pickStateInit = {
    _cmd set ["aiMode", "weighted"];
    _cmd set ["pickOnce", ""];
    // Carried as a debt, so a rate below 1 picks once every few ticks.
    _cmd set ["picksPerTick", 0.5];
    _cmd set ["pickDebt", 0];
    _cmd set ["aiEvents", []];
    _cmd set ["aiSeq", 0];
    _cmd set ["archetype", "balanced"];
    _cmd set ["tickCache", createHashMap];
};

// Read by sequence (fnc_debug_opcom_ai), so every watcher sees each line once whenever it polls.
DUWS_fnc_opcom_aiEvent = {
    params ["_text"];
    private _seq = (_cmd get "aiSeq") + 1;
    _cmd set ["aiSeq", _seq];
    private _events = _cmd get "aiEvents";
    _events pushBack [_seq, _text];
    if (count _events > 10) then { _events deleteAt 0 };
};
