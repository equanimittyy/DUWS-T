// Locality: server, [] call'd at load. The event feed the AI overlay reads.
if (!isServer) exitWith {};

// Read by sequence (fnc_debug_opcom_ai), so every watcher sees each line once whenever it polls.
DUWS_fnc_opcom_aiEvent = {
    params ["_text"];
    private _seq = (_cmd get "aiSeq") + 1;
    _cmd set ["aiSeq", _seq];
    private _events = _cmd get "aiEvents";
    _events pushBack [_seq, _text];
    if (count _events > 10) then { _events deleteAt 0 };
};
