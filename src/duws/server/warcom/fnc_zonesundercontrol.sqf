if (!isServer) exitWith {};
/*
    The campaign economy tick: one pass paying the zone AP trickle (both sides), town income
    (BLUFOR CP, OPFOR AP) and kill income together, run every 30 minutes by the one clock
    WARCOM init spawns. One clock, not one timer per faucet of the same nominal period: a
    suspended thread resumes only when the scheduler reaches it, so separate loops accrue their own
    slop and walk apart over a session. Driven from WARCOM init because that runs unconditionally,
    while the civilian economy only runs when CIV_PRESENCE is not "NONE" -- driving the tick from there
    would delete zone income on a civs-off campaign. Civs off leaves the town arrays empty,
    so town income pays nobody, but the zone trickle still pays: it reads no town. BLUFOR's
    passive CP therefore goes to zero on civs-off, which the mission-CP lift restores
    (server/missions/fnc_mission_reward.sqf).
*/
// The tick's own sequence number, so anything that wants a "once per payout window" cap can
// key off this clock rather than start a second one that drifts out of phase with it.
// Server-local: no client reads it.
econ_tick = econ_tick + 1;

// Hands every player their one ask of a local back. Cleared from here rather than compared
// against econ_tick on the client, because the menu's greying has to read it, and
// broadcasting a boolean per player is cheaper than broadcasting the clock for clients to
// subtract. A local is a finite population the reaction curve already prices, so its per-tick
// reset lives here; a body search is gated by the materiel the player fought through, not a
// clock, so it is not reset on this tick.
{ _x setVariable ["DUWS_civ_intel_asked", false, true] } forEach allPlayers;

// Income is not gated on zone holdings: the enemy banking its towns while the player holds
// nothing is exactly the case the town economy exists to model. Territory type decides the
// pool -- a banded town pays its holder, as CP for BLUFOR and AP for OPFOR.
private _reps = missionNamespace getVariable ["civ_town_rep", []];
private _worth = missionNamespace getVariable ["civ_town_ap", []];
private _locs = missionNamespace getVariable ["civ_locations", []];
private _bluTownWorth = 0;
private _opfTownWorth = 0;
private _towns = [];
// Tier I buys reach only; each tier above it adds 1 to the drift.
private _bluPush = DUWS_bluforRadioLevel - 1;
// BLUFOR's radio drift first, then income on the result -- so a town that crosses a band this
// tick pays on its new side the same tick. Asymmetric by design: OPFOR has no passive push and moves a
// town only by buying Rapport. Silent: no card per town; the marker colour and the tick's hint below
// carry it (see fnc_town_rep_adjust).
{
    if (_bluPush > 0 && {[getPos (_locs select _forEachIndex)] call fnc_aoi_blufor_covers}) then {
        [_forEachIndex, _bluPush, "aoi_drift", true] call fnc_town_rep_adjust;
    };

    // Income on the post-drift reputation, read back from the array the adjust just wrote.
    // The worth is the same figure either way; the side it lands on decides which pool it pays.
    private _rep = (missionNamespace getVariable ["civ_town_rep", []]) select _forEachIndex;
    ([_rep, _worth param [_forEachIndex, 0]] call fnc_civ_townIncome) params ["_income", "_side"];
    if (_side isEqualTo "BLU") then { _bluTownWorth = _bluTownWorth + _income };
    if (_side isEqualTo "OPF") then { _opfTownWorth = _opfTownWorth + _income };
    _towns pushBack [_x, _rep];
} forEach _reps;

// Every passive faucet is scaled by the same shared campaign-size throttle (DUWS_econ_throttle)
// and rounded once, after scaling, so no fraction reaches a pool writer. Town income routes per
// side (BLUFOR CP, OPFOR AP); the zone trickle pays both sides AP for the ground each holds, on
// that one throttle. OPFOR's wallet carries no per-side income handicap -- it opens holding every
// zone, but that head start is answered on the tier, by the BLUFOR capture bounty and
// DUWS_opfor_payout_tier, not by penalising its faucet.
private _bluCP    = round (_bluTownWorth * DUWS_econ_throttle);
private _opfTownAP = round (_opfTownWorth * DUWS_econ_throttle);
private _bluZoneAP = round (zoneundercontrolblu * zone_ap_trickle * DUWS_econ_throttle);
private _opfZoneAP = round ((count WARCOM_zones_controled_by_OPFOR) * zone_ap_trickle * DUWS_econ_throttle);
private _opfAP = _opfTownAP + _opfZoneAP;
WARCOM_opfor_lastIncome = _opfAP;

// One call per pool per side, not one per town: fnc_ap_adjust/fnc_cp_adjust publicVariable and
// log every time, so per-town calls would broadcast the same global a dozen times a tick.
// Called inline rather than remoteExec'd to self: this tick is server-side, and call lands the
// credit this frame where remoteExec [...,2] queues it for the next.
if (_bluCP > 0)     then { [_bluCP, "civ_town_income"] call fnc_cp_adjust };
if (_bluZoneAP > 0) then { ["BLU", _bluZoneAP, "zone_trickle", _bluZoneAP] call fnc_ap_adjust };
if (_opfAP > 0)     then { ["OPF", _opfAP, "opfor_income", round (_opfAP * DUWS_opfor_payout_tier)] call fnc_ap_adjust };

// Pays and notifies each player its own kill award; deliberately absent from the territory
// hint below. Naming attrition there would advertise kill farming as an income route.
call fnc_kill_income_sweep;

// Only on a paid tick: a reduced-income subtitle with no income to reduce would read as an error.
// An unrevealed town stays off it, or the hint would name what the town reveal keeps hidden.
if (_bluCP > 0 || {_bluZoneAP > 0}) then {
    private _visible = missionNamespace getVariable ["civ_visible", []];
    private _rows = [
        [localize "STR_DUWS_T_econ_hint_cp", format ["+%1", _bluCP], format [localize "STR_DUWS_T_econ_hint_total", commandpointsblu1]],
        [localize "STR_DUWS_T_econ_hint_ap", format ["+%1", _bluZoneAP], format [localize "STR_DUWS_T_econ_hint_total", WARCOM_blufor_ap]]
    ];
    private _gained = [];
    {
        _x params ["_old", "_new"];
        // Compared on the result, not the push: a town at the reputation cap takes a push and does not move.
        if (_new > _old && {_visible param [_forEachIndex, true]}) then {
            private _name = text (_locs select _forEachIndex);
            if (_name isEqualTo "") then { _name = format ["Unnamed%1", _forEachIndex] };
            ([_new, _worth param [_forEachIndex, 0]] call fnc_civ_townIncome) params ["_income", "_side"];
            _gained pushBack [_name, format ["%1 -> %2", _old, _new],
                ["", format [localize "STR_DUWS_T_civ_mapview_income_blu", _income]] select (_side isEqualTo "BLU")];
        };
    } forEach _towns;
    if (_gained isNotEqualTo []) then {
        _rows pushBack localize "STR_DUWS_T_econ_hint_drift";
        _rows pushBack [localize "STR_DUWS_T_econ_hint_push", format ["+%1", _bluPush]];
        _rows append _gained;
    };
    private _subtitle = "";
    if (DUWS_econ_throttle < 1) then {
        _subtitle = format [localize "STR_DUWS_T_econ_reduced_desc", round ((1 - DUWS_econ_throttle) * 100), "%"];
    };
    [localize "STR_DUWS_T_econ_hint_title", _subtitle, _rows, [0, -2] select isDedicated] call fnc_ledger_hint;
    // A cue with no figures: the hint carries them, and a line repeating them would announce the tick twice.
    [localize "STR_DUWS_T_ALLSEER", localize "STR_DUWS_T_econ_report_line"] remoteExec ["fnc_duws_dialogue", 0];
};
