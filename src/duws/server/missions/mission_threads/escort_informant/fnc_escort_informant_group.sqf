// Locality: server -- the informant's Join / Leave Group actions remoteExec this to target 2.
//
// MOVE toggles follow (on) vs hold-where-dropped (off); PATH is never touched, so his pathing stays
// usable. The leader check is client-side in the action, so this runs only for a legitimate recruit.
if (!isServer) exitWith {};
params ["_inf", "_caller", ["_join", true]];
if (isNull _inf || { !alive _inf } || { isNull _caller }) exitWith {};

if (_join) then {
    [_inf] joinSilent (group _caller);
    _inf enableAI "MOVE";
    _inf setUnitPos "AUTO";
} else {
    [_inf] joinSilent (createGroup [WEST, true]);
    _inf disableAI "MOVE";
};
