if (!isServer) exitWith {};
/*
    The campaign economy tick: one 30-minute clock paying territory CP and town Army Power
    together. AP used to keep its own timer in server/misc/fnc_civ_rep_economy.sqf and drifted
    out of phase with this one, which stalls for as long as BLUFOR holds nothing. Merged this
    way round because this loop is spawned unconditionally by WARCOM init while the civilian
    economy only runs when CIV_PRESENCE is not "NONE" -- hosting the tick there would delete
    territory income on a civs-off campaign. Civs off leaves the town arrays empty, so the AP
    half sums nothing and pays nothing.
*/
while {true} do {
    sleep 1800;

    // The tick's own sequence number, so anything that wants a "once per payout window" cap can
    // key off this clock rather than start a second one that drifts out of phase with it --
    // which is the failure this loop was merged to end. Server-local: no client reads it.
    econ_tick = econ_tick + 1;

    // AP is not gated on zone holdings: the enemy banking its towns while the player holds
    // nothing is exactly the case the town economy exists to model.
    private _reps = missionNamespace getVariable ["civ_town_rep", []];
    private _worth = missionNamespace getVariable ["civ_town_ap", []];
    private _blu = 0;
    private _opf = 0;
    {
        private _ap = _worth param [_forEachIndex, 0];
        if (_x >= 10) then { _blu = _blu + _ap };
        if (_x <= -10) then { _opf = _opf + _ap };
    } forEach _reps;
    // Two calls, not one per town: fnc_ap_adjust publicVariables and logs every time, so
    // per-town calls would broadcast the same global twenty times a tick for one net change.
    if (_blu > 0) then { ["BLU", _blu, "civ_town_income"] call fnc_ap_adjust };
    if (_opf > 0) then { ["OPF", _opf, "civ_town_income"] call fnc_ap_adjust };

    if (zoneundercontrolblu > 0) then {
        ["CPzonehold",[(zoneundercontrolblu*6),zoneundercontrolblu]] remoteExec ['BIS_fnc_showNotification', [0,-2] select isDedicated,false];
        [zoneundercontrolblu*6, "territory_income"] remoteExec ["fnc_cp_adjust", 2];
        [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_zonesundercontrol"] remoteExec ["fnc_duws_dialogue", 0];
    };
};
