// Locality: server, scheduled -- waits for the seat to empty.
//
// Out of the seat before out of the group: while he is in a player's group he is local to that player's
// machine, so the eject goes there, and a peel first would move him back to the server under the call.
// Unassigned too, or a vehicle the group held stays his and he climbs back in.
params ["_u"];
if (vehicle _u != _u) then {
    _u remoteExec ["unassignVehicle", _u];
    _u remoteExec ["moveOut", _u];
    private _outBy = time + 5;
    waitUntil { sleep 0.1; vehicle _u == _u || time > _outBy };
};
[_u] joinSilent (createGroup [WEST, true]);
