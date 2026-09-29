// Locality: server -- the escort's Join / Leave Group actions remoteExec this to target 2, and
// fnc_squad_leaderLeft runs the leave, with no caller, when the escort's squad has no human left.
//
// MOVE toggles follow (on) vs hold-where-dropped (off); PATH is never touched, so his pathing stays
// usable. The leader check is client-side in the action, so this runs only for a legitimate recruit.
if (!isServer) exitWith {};
params ["_inf", "_caller", ["_join", true]];
if (isNull _inf || { !alive _inf } || { _join && { isNull _caller } }) exitWith {};

if (_join) then {
    [_inf] joinSilent (group _caller);
    _inf setVariable ["DUWS_escort", true];
    _inf enableAI "MOVE";
    _inf setUnitPos "AUTO";
} else {
    [_inf] joinSilent (createGroup [WEST, true]);
    _inf disableAI "MOVE";
    _inf setUnitPos "MIDDLE";
};
