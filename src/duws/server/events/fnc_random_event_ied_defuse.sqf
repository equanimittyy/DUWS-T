// Locality: server -- a client's completed defuse hold reaches here by name (remoteExec to 2 from the
// hold-action set up in fnc_random_event_ied). Re-checks the pile is still a live IED, since it may have
// cooked off or been defused by someone else the same frame, then pays the finder a command point and
// clears the charge. CP awarded straight through fnc_cp_adjust: it is a reward, not a purchase, so it skips
// the escalation the pool-spend handshake applies.
if (!isServer) exitWith {};
params [["_pile", objNull]];
if (isNull _pile) exitWith {};
if ((_pile getVariable ["DUWS_ied_state", "decoy"]) != "live") exitWith {};

_pile setVariable ["DUWS_ied_state", "gone", false];
_pile setVariable ["DUWS_ied_live", false, true];   // drops the hold action on every client
[1, "ied_defused"] call fnc_cp_adjust;
deleteVehicle _pile;
