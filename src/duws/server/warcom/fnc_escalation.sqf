// Locality: server -- spawned from server/server_init.sqf.
// Replaces the war-crimes script, which charged reputation on a curve that dampened rather
// than escalated -- levelling a hundred buildings cost four points -- and discarded any
// remainder below its threshold each tick, so one building a minute was free forever.
if (!isServer) exitWith {};

// A zombie apocalypse has no civil standing to lose and nobody to raise prices, and both modes
// already bailed out of every reputation path they could reach.
if (CIV_PRESENCE == "RAVAGE" || CIV_PRESENCE == "WBK") exitWith {};

// A whole-map census counts every House on the terrain, the overwhelming majority of them in
// settlements no campaign ever visits, so the raw total is far larger than anything a player
// could plausibly destroy. A fifty-third of it is the loss condition, so a level costs a
// five-hundred-and-eighty-third of the map -- thirty houses on Altis.
#define ESCALATION_FRACTION (1 / 53)
#define ESCALATION_MAX_LEVEL 11
// Floor the per-level step, not the budget: on a house-sparse map the fraction drives the step
// toward zero, which would make every single house its own level. Pin it to an absolute minimum so
// the loss threshold is a real count of ruin rather than a fraction of a tiny census -- keeps this
// portable off Altis. Inert on Altis, where the fraction already yields thirty.
#define ESCALATION_MIN_TIER 15

// The census is one engine call that cannot yield -- 5.03 s for Altis's 17472 houses -- so it is
// a frame stall, not 5 s of shared scheduler time, and no rearranging here changes that. Instead
// it gets a banner and a slot in the generation sequence, landing the stall inside a wait the
// player is already watching, not the frame they take control.
//
// The banner has to be up before the stall starts. fnc_map_prompt is remoteExec'd and a
// remoteExec to your own machine still runs a frame later, so a blocking call on the next line
// would freeze before anything drew.
//
// Waits on the draw itself rather than on a fixed delay: DUWS_map_prompt_shown is written by
// fnc_map_prompt as it commits the control, so a slow frame extends the wait and a fast one is
// not charged for it. The map being shut here can never satisfy it and never needs to -- that is
// a dedicated server, which draws nothing locally and freezes no player's client -- so it
// short-circuits rather than burning the whole deadline on every dedicated start. The deadline
// is a backstop against a draw that never arrives wedging generation, not the mechanism.
private _banner = "Finalising campaign...<br/>surveying structures";
[_banner] remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];

private _deadline = diag_tickTime + 3;
waitUntil {
    isNull (findDisplay 12)
    || {(missionNamespace getVariable ["DUWS_map_prompt_shown", ""]) isEqualTo _banner}
    || {diag_tickTime > _deadline}
};

// Radius reaches the map's far corner from its centre, which is worldSize * sqrt(2)/2, not
// worldSize. The square is fully covered either way; the larger radius just scans twice the
// area for the same answer.
//
// sortByDistance false: ordering an array of many thousands of entries is the bulk of the
// avoidable cost, and nothing here cares about the order.
private _censusStart = diag_tickTime;
private _total = count (nearestTerrainObjects
    [[worldSize / 2, worldSize / 2, 0], ["House"], worldSize * 0.7072, false]);
private _censusCost = diag_tickTime - _censusStart;

escalation_tier = (round (_total * ESCALATION_FRACTION / ESCALATION_MAX_LEVEL)) max ESCALATION_MIN_TIER;
escalation_budget = escalation_tier * ESCALATION_MAX_LEVEL;
escalation_destroyed = 0;
escalation_level = 0;
// Read by the request menus to show what a purchase will actually cost, so it has to travel.
escalation_multiplier = 1;
publicVariable "escalation_multiplier";

["INFO", "ECON", format ["Escalation census: %1 houses on %2 in %3s, budget %4, tier %5",
    _total, worldName, (round (_censusCost * 100)) / 100,
    escalation_budget, round escalation_tier]] call fnc_log;

// Every second the census is up is a frozen frame, so the first frame the player can actually
// see is the one after this clears -- the banner reads as a flash. Held with the game live
// instead, and after the state above is set so nothing waits on it. uiSleep, not sleep: it is
// measured in real time, so the banner holds its full 1.5s regardless of the sim clock.
uiSleep 1.5;
[""] remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];

// Counts ruin done, not buildings lost: ungated, and a house damaged then levelled counts twice --
// both sides worsen the war, which the budget is sized for. BuildingChanged is a local event, so a
// change a client simulated never reached this server-only handler (escalation was dead on a
// dedicated server); each machine now watches its own (fnc_escalation_watch) and forwards here.
fnc_escalation_report = {
    if (!isServer) exitWith {};
    params [["_pos", [0,0,0]]];

    // A collapsed house is two facts: escalation counts total ruin; reputation charges the town it
    // stood in, only with a player inside 200 m (a proxy for fault, so a WARCOM assault in an empty
    // town cannot hand it over). Ungated by escalation_enabled -- this is reputation, not escalation.
    if (CIV_PRESENCE != "NONE" && {[_pos] call fnc_civ_playerNear}) then {
        private _town = [_pos] call fnc_civ_townAt;
        if (_town >= 0) then {
            [_town, -1, "building_destroyed"] call fnc_town_rep_adjust;
        };
    };

    // Defaults on, matching the menu, so a campaign that never reached the environment screen
    // escalates rather than silently running without its price and loss pressure.
    if !(missionNamespace getVariable ["escalation_enabled", true]) exitWith {};

    escalation_destroyed = escalation_destroyed + 1;
    // Clamped: with the ending off, the ceiling is a plateau, not prices climbing without limit.
    private _level = (floor (escalation_destroyed / escalation_tier)) min ESCALATION_MAX_LEVEL;
    if (_level <= escalation_level) exitWith {};

    escalation_level = _level;
    escalation_multiplier = 1 + (_level / 10);
    publicVariable "escalation_multiplier";
    ["INFO", "ECON", format ["Escalation level %1 (%2 destroyed of %3), prices x%4",
        _level, escalation_destroyed, escalation_budget, escalation_multiplier]] call fnc_log;

    // Lose conditions Full (0) or Escalation Only (2).
    if (_level >= ESCALATION_MAX_LEVEL
        && {(["DUWS_LoseConditions", 0] call BIS_fnc_getParamValue) in [0, 2]}) exitWith {
        campaign_lost = true;
        campaign_lost_body = "STR_DUWS_T_CAMPAIGN_LOST";
        campaign_lost_ending = "island_ruined";
        publicVariable "campaign_lost";
        publicVariable "campaign_lost_body";
        ["INFO", "ECON", "Escalation reached its ceiling: campaign lost"] call fnc_log;
    };

    ["alert", [localize "STR_DUWS_T_escalation_title",
        format [localize "STR_DUWS_T_escalation_level", _level]]]
        remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];
};

// Arm only now, past the RAVAGE/WBK early return, so those modes never forward. This machine
// directly; clients + JIP by broadcast (-2 skips the host, already covered; the fn is idempotent).
call fnc_escalation_watch;
remoteExec ["fnc_escalation_watch", -2, "DUWS_esc_watch_jip"];
