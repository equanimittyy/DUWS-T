if (!isServer) exitWith {};
/*
    The campaign economy tick: one 30-minute clock paying the zone AP trickle (both sides), town
    income (BLUFOR CP, OPFOR AP), the OPFOR flat floor and kill income together. Each used to keep
    its own timer of the same nominal period, which is not the same clock -- a suspended thread
    resumes when the scheduler reaches it, so every loop accrues its own slop and they walk apart
    over a session. Merged this way round because this loop is spawned unconditionally by WARCOM
    init while the civilian economy only runs when CIV_PRESENCE is not "NONE" -- hosting the tick
    there would delete zone income on a civs-off campaign. Civs off leaves the town arrays empty,
    so town income pays nobody, but the zone trickle and the OPFOR flat floor still pay: neither
    reads a town. BLUFOR's passive CP therefore goes to zero on civs-off, which the mission-CP lift
    restores (server/missions/fnc_mission_reward.sqf).
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

    // Income is not gated on zone holdings: the enemy banking its towns while the player holds
    // nothing is exactly the case the town economy exists to model. Territory type decides the
    // pool -- a banded town pays its holder, as CP for BLUFOR and AP for OPFOR.
    private _reps = missionNamespace getVariable ["civ_town_rep", []];
    private _worth = missionNamespace getVariable ["civ_town_ap", []];
    private _locs = missionNamespace getVariable ["civ_locations", []];
    private _bluTownWorth = 0;
    private _opfTownWorth = 0;
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
        // The worth is the same figure either way; the side it lands on decides which pool it pays.
        private _rep = (missionNamespace getVariable ["civ_town_rep", []]) select _forEachIndex;
        ([_rep, _worth param [_forEachIndex, 0]] call fnc_civ_townIncome) params ["_income", "_side"];
        if (_side isEqualTo "BLU") then { _bluTownWorth = _bluTownWorth + _income };
        if (_side isEqualTo "OPF") then { _opfTownWorth = _opfTownWorth + _income };
    } forEach _reps;

    // Every passive faucet is scaled by the campaign-size throttle and rounded once, after
    // scaling, so no fraction reaches a pool writer. Town income routes per side (BLUFOR CP,
    // OPFOR AP); the zone trickle pays both sides AP for the ground each holds; OPFOR also draws
    // an unthrottled flat floor. Held zone counts: BLUFOR from zoneundercontrolblu, OPFOR from
    // the control list.
    private _bluCP    = round (_bluTownWorth * DUWS_econ_throttle);
    private _opfTownAP = round (_opfTownWorth * DUWS_econ_throttle);
    private _bluZoneAP = round (zoneundercontrolblu * zone_ap_trickle * DUWS_econ_throttle);
    private _opfZoneAP = round ((count WARCOM_zones_controled_by_OPFOR) * zone_ap_trickle * DUWS_econ_throttle);
    private _opfAP = _opfTownAP + _opfZoneAP + opfor_flat_ap_income;

    // One call per pool per side, not one per town: fnc_ap_adjust/fnc_cp_adjust publicVariable and
    // log every time, so per-town calls would broadcast the same global a dozen times a tick.
    // Called inline rather than remoteExec'd to self: this loop is server-side, and call lands the
    // credit this frame where remoteExec [...,2] queues it for the next.
    if (_bluCP > 0)     then { [_bluCP, "civ_town_income"] call fnc_cp_adjust };
    // The 4th arg is the tier-crediting portion. BLUFOR's zone trickle is a faucet it earns, so the
    // whole delta credits the counter. OPFOR's tier climbs on town and flat income but NOT its zone
    // trickle: it holds every zone at hour zero, so crediting the trickle would front-load a tier it
    // never fought for. So the OPFOR wallet takes all three, the counter only town + flat.
    if (_bluZoneAP > 0) then { ["BLU", _bluZoneAP, "zone_trickle", _bluZoneAP] call fnc_ap_adjust };
    if (_opfAP > 0)     then { ["OPF", _opfAP, "opfor_income", _opfTownAP + opfor_flat_ap_income] call fnc_ap_adjust };

    // Pays and notifies each player its own kill award; deliberately absent from Overlord's
    // report below, which speaks for territory only. Naming attrition there would advertise
    // kill farming as an income route.
    call fnc_kill_income_sweep;

    // One line for what territory earned BLUFOR this tick, in place of a notification per faucet:
    // popups on the same frame read as spam, and the pair is what tells the player whether holding
    // ground is paying. CP is the town faucet, AP the zone trickle.
    if (_bluCP > 0 || {_bluZoneAP > 0}) then {
        [localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_econtickreport", _bluCP, _bluZoneAP]]
            remoteExec ["fnc_duws_dialogue", 0];

        // Carded, not spoken: the throttle is a standing campaign condition (fixed at generation as
        // (REF_ZONES/zones)^k), not a line of this tick's report, and folding it into the dialogue
        // would reword Overlord every tick with a number that never changes. Team news, so an A3
        // card to all rather than a per-player hint. Only when it bites, and only alongside a paid
        // tick -- "reduced" with no income line to reduce would read as an error.
        if (DUWS_econ_throttle < 1) then {
            private _cut = round ((1 - DUWS_econ_throttle) * 100);
            ["sitrepinfo", [localize "STR_DUWS_T_econ_reduced_title", format [localize "STR_DUWS_T_econ_reduced_desc", _cut]]]
                remoteExec ["BIS_fnc_showNotification", [0, -2] select isDedicated, false];
        };
    };
};
