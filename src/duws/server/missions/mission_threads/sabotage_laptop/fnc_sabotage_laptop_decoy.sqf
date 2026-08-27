// Locality: server -- the decoy laptop's addAction body (fnc_sabotage_laptop_mission.sqf) remoteExecs
// here to target 2, the same split the success path uses: the action's own removal stays on the
// activating client, everything else is decided on the server.
//
// A sabotaged decoy is spent and revealed only to the player who used it. A third of decoys are rigged:
// those warn that one player, then detonate a mortar round on the laptop after a short fuse, so a
// careless search of the wrong building is punished. The 33% roll is fixed at spawn and handed in here.
params ["_decoy", "_caller", ["_rigged", false]];
if (!isServer) exitWith {};

// The hold action hides itself once DUWS_laptop_done is set on the decoy (in the hold's own completion,
// before this runs). Dropping the queued JIP add stops a late joiner from re-adding it.
remoteExec ["", format ["sabotage_action_%1", netId _decoy]];

if (!_rigged) exitWith {
    // The searcher's own squad reports the dud, in their voice and only on their screen -- local, like
    // a civilian's answer to an ask -- over the hint that tells them to keep looking.
    [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_laptopnothing", "", name _caller] remoteExec ["fnc_duws_dialogue", _caller];
    [{ hint localize "STR_DUWS_T_laptopdecoy" }] remoteExec ["BIS_fnc_Spawn", _caller];
};

// Rigged: the warning card is held past the fuse (notifications.hpp) so it does not clear before the
// blast, and goes only to the player who triggered it. Position captured before the fuse in case the
// object is torn down in the gap -- the bomb still goes off where the laptop was.
["rigged_decoy"] remoteExec ["BIS_fnc_showNotification", _caller];
[getPosATL _decoy, _decoy, _decoy getVariable ["DUWS_laptop_table", objNull]] spawn {
    params ["_p", "_lap", "_table"];
    sleep 6;
    // Driven down, not pinned in place: a shell created at rest never runs its impact fuze and sits
    // inert (the old setPosATL nailed it to the ground stationary). Spawned just above the spot with a
    // downward velocity, it impacts at once and detonates. Server-created, so the blast is authoritative
    // and replicates to every client.
    private _bomb = createVehicle ["Sh_82mm_AMOS", [_p select 0, _p select 1, (_p select 2) + 0.5], [], 0, "CAN_COLLIDE"];
    _bomb setVelocity [0, 0, -30];
    // Clear the laptop and its table with the blast: both are invulnerable props, so the shell would
    // otherwise leave them standing on the crater. Deleted here on the server, where both are local.
    deleteVehicle _lap;
    deleteVehicle _table;
};
