// Locality: server; the client layer remoteExecs it with its job's id. It only raises the flag the job's monitor
// reads once, so a second report or a stale JIP one cannot pay twice.
if (!isServer) exitWith {};
params [["_id", "", [""]]];
if (!(missionNamespace getVariable [format ["DUWS_recon_active_%1", _id], false])) exitWith {};
missionNamespace setVariable [format ["DUWS_recon_done_%1", _id], true];
