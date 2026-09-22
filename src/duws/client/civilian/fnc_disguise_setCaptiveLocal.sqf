// Locality: runs on the target client -- both disguise activations and fnc_disguise_monitor remoteExec it
// to toggle the local captive state. Registered from client_init so the client holds it before the server calls.
params ["_state"];
player setCaptive _state;
["INFO", "GEAR", format ["Client setCaptive %1 for %2", _state, name player]] call fnc_log;
