// Locality: server -- called by the RAVAGE and WBK civilian handlers and by the gate they share.
//
// Releasing the campaign-wide town mutex is a guard, an assignment and a broadcast, and it was
// written out at fifteen sites across the two handlers. A release that drops the publicVariable
// strands the lock: every other town then waits out the ten-minute timeout before it can fill.
//
// No-op unless this town is the holder, so an abort path may call it without first checking
// whether it ever acquired the lock.
params ["_locIndex"];

if (civ_current_active_location == _locIndex) then {
    civ_current_active_location = -1;
    publicVariable "civ_current_active_location";
};
