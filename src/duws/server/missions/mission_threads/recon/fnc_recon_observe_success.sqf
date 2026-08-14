// Locality: server -- the client observe layer (client/missions/fnc_recon_observe_layer.sqf) remoteExecs
// here to target 2 when a player finishes the hold. The win itself is decided in the thread's monitor;
// this only raises the flag it waits on, so a second player finishing a fraction later, or a stale JIP
// report, cannot pay the reward twice -- the monitor reads the flag once and clears DUWS_recon_active.
if (!isServer) exitWith {};
if (!(missionNamespace getVariable ["DUWS_recon_active", false])) exitWith {};
DUWS_recon_done = true;
