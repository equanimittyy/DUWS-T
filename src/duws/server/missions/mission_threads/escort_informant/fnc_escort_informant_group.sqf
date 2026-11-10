// Locality: server, scheduled -- the escort's Join / Leave Group actions remoteExec this to target 2, and
// fnc_squad_leaderLeft runs the leave, with no caller, when the escort's squad has no human left.
//
// MOVE toggles follow (on) vs hold-where-dropped (off); PATH is never touched, so his pathing stays
// usable. The leader check is client-side in the action, so this runs only for a legitimate recruit.
if (!isServer) exitWith {};
params ["_inf", "_caller", ["_join", true]];
if (isNull _inf || { !alive _inf } || { _join && { isNull _caller || { _inf getVariable ["DUWS_escortOver", false] } } }) exitWith {};

// enableAI, disableAI and setUnitPos bind only where he is local, and the join moves him to the leader's
// machine while the leave brings him back. So the join sets them first and the leave waits for him.
if (_join) then {
    _inf enableAI "MOVE";
    _inf setUnitPos "AUTO";
    [_inf] joinSilent (group _caller);
    _inf setVariable ["DUWS_escort", true];
} else {
    [_inf] joinSilent (createGroup [WEST, true]);
    private _by = time + 5;
    waitUntil { sleep 0.1; local _inf || time > _by };
    _inf disableAI "MOVE";
    _inf setUnitPos "MIDDLE";
};
