if (!isServer) exitWith {};
/*
    The campaign economy tick: one 30-minute clock paying territory CP, town Army Power and
    kill income together. Each used to keep its own timer of the same nominal period, which is
    not the same clock -- a suspended thread resumes when the scheduler reaches it, so every
    loop accrues its own slop and they walk apart over a session. Merged this way round because
    this loop is spawned unconditionally by WARCOM init while the civilian economy only runs
    when CIV_PRESENCE is not "NONE" -- hosting the tick there would delete territory income on
    a civs-off campaign. Civs off leaves the town arrays empty, so the AP half pays nothing.
*/
while {true} do {
    sleep 1800;

    // The tick's own sequence number, so anything that wants a "once per payout window" cap can
    // key off this clock rather than start a second one that drifts out of phase with it --
    // which is the failure this loop was merged to end. Server-local: no client reads it.
    econ_tick = econ_tick + 1;

    // Hands every player their one ask of a local back. Cleared from here rather than compared
    // against econ_tick on the client, because the menu's greying has to read it, and
    // broadcasting a boolean per player is cheaper than broadcasting the clock for clients to
    // subtract. The body search used to ride this same tick and no longer does: what limits a
    // search is now the flagged materiel the player fought through, not a clock. A local is a
    // finite population the reaction curve already prices, so this one stays.
    { _x setVariable ["DUWS_civ_intel_asked", false, true] } forEach allPlayers;

    // AP is not gated on zone holdings: the enemy banking its towns while the player holds
    // nothing is exactly the case the town economy exists to model.
    private _reps = missionNamespace getVariable ["civ_town_rep", []];
    private _worth = missionNamespace getVariable ["civ_town_ap", []];
    private _locs = missionNamespace getVariable ["civ_locations", []];
    private _blu = 0;
    private _opf = 0;
    // Passive AoI rep drift first, then income on the result -- so a town that crosses a band this
    // tick pays on its new side the same tick. The pushes are asymmetric by design: OPFOR pushes by
    // holding ground (a flat 1 plus its standing radio towers), BLUFOR only once it has bought a tier
    // (no base). A contested town nets the difference; an uncovered one drifts nothing. Silent: the
    // town's marker colour is the feedback, not a card per town (see fnc_town_rep_adjust).
    {
        private _townPos = getPos (_locs select _forEachIndex);
        private _opforPush = 0;
        private _bluforPush = 0;
        if (_townPos call fnc_aoi_opfor_covers)  then { _opforPush  = 1 + DUWS_opforRadioLevel };
        if (_townPos call fnc_aoi_blufor_covers) then { _bluforPush = DUWS_bluforRadioLevel };
        if (_bluforPush != _opforPush) then {
            [_forEachIndex, _bluforPush - _opforPush, "aoi_drift", true] call fnc_town_rep_adjust;
        };

        // Income on the post-drift reputation, read back from the array the adjust just wrote.
        private _rep = (missionNamespace getVariable ["civ_town_rep", []]) select _forEachIndex;
        ([_rep, _worth param [_forEachIndex, 0]] call fnc_civ_townIncome) params ["_income", "_side"];
        if (_side isEqualTo "BLU") then { _blu = _blu + _income };
        if (_side isEqualTo "OPF") then { _opf = _opf + _income };
    } forEach _reps;
    // Two calls, not one per town: fnc_ap_adjust publicVariables and logs every time, so
    // per-town calls would broadcast the same global twenty times a tick for one net change.
    if (_blu > 0) then { ["BLU", _blu, "civ_town_income"] call fnc_ap_adjust };
    if (_opf > 0) then { ["OPF", _opf, "civ_town_income"] call fnc_ap_adjust };

    // Pays and notifies each player its own kill award; deliberately absent from Overlord's
    // report below, which speaks for territory only. Naming attrition there would advertise
    // kill farming as an income route.
    call fnc_kill_income_sweep;

    private _cp = 0;
    if (zoneundercontrolblu > 0) then {
        _cp = zoneundercontrolblu * 6;
        [_cp, "territory_income"] remoteExec ["fnc_cp_adjust", 2];
    };

    // One line for what territory earned, in place of a notification per faucet: popups
    // landing on the same frame read as spam, and the total is what tells the player whether
    // holding ground is paying.
    if (_cp > 0 || {_blu > 0}) then {
        [localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_econtickreport", _cp, _blu]]
            remoteExec ["fnc_duws_dialogue", 0];
    };
};
