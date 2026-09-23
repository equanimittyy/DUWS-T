// Locality: server -- the action remoteExecs to target 2, the way the HQ's redeploy does.
//
// One entry point for both halves of a FOB's upkeep, checked and charged once: a FOB's garrison is
// the same job as the HQ's one-action rebuild, on a smaller base.
if (!isServer) exitWith {};

params ["_fob"];
if (isNull _fob) exitWith {};

// Turned away before anything is charged, which is what moving the debit to the server buys: the
// client-side charge could only be handed back after the fact, so the losing player of two
// simultaneous rebuilds paid and was refunded. Both flags, because one action now drives both.
if ((_fob getVariable ["FOB_guard_busy", false]) || {_fob getVariable ["FOB_fortify_busy", false]}) exitWith {
    [localize "STR_DUWS_T_FOB_REDEPLOY_BUSY"] remoteExec ["hint", 0];
};

if (commandpointsblu1 < 2) exitWith {
    [localize "STR_DUWS_T_e95mc4lv"] remoteExec ["hint", [0,-2] select isDedicated];
};

// Lock before charging. The two builders raise these flags too, but they run a frame later as
// spawned threads, so a second click landing before they start would read both flags false at the
// check above, pass it, and charge a second time. Set here, synchronously, it is already up when
// the next request arrives. Each builder clears its own flag when it finishes.
_fob setVariable ["FOB_fortify_busy", true];
_fob setVariable ["FOB_guard_busy", true];

// call, not remoteExec to self, and escalation applied here rather than in fnc_pool_try_spend:
// identical to fnc_redeployHQUnits for the same reason, since this path never reaches the purchase
// handshake either.
[-([2] call fnc_escalation_cost), "fob_redeploy"] call fnc_cp_adjust;

private _pos = getPos _fob;
// Spawned rather than called: both builders sleep, and the second must not wait out the first.
// Each replaces what it owns and sets its own busy flag, so the two do not collide.
[_pos, _fob, true] spawn fnc_fortifyFOB;
[_pos, _fob] spawn fnc_guardsFOB;

[localize "STR_DUWS_T_REDEPLOY_SUCCESS"] remoteExec ["hint", 0];
