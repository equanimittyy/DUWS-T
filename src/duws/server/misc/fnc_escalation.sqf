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

// The census is one engine call that cannot yield -- measured at 5.03 s for Altis's 17472
// houses -- so it is a frame stall, not 5 s of shared scheduler time, and no amount of
// rearranging inside this function changes that. What it gets instead is a banner and a place
// in the generation sequence, so the stall lands inside a wait the player is already watching
// rather than on the frame they take control.
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

escalation_budget = round (_total * ESCALATION_FRACTION) max ESCALATION_MAX_LEVEL;
escalation_tier = escalation_budget / ESCALATION_MAX_LEVEL;
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
// instead, and after the state above is set so nothing waits on it. uiSleep, not sleep:
// setTimeMultiplier is applied long before this and would scale a delay this short to nothing.
uiSleep 1.5;
[""] remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];

// The counter is ungated and carries no attribution: not who did it, not whether anyone was
// watching, not whether it stood in a town. The war is getting worse and both sides are making
// it worse, which is what makes per-building damage handlers and setShotParents unnecessary.
// The reputation charge below is the only part that asks where the building stood.
//
// BuildingChanged is a local event and this runs server-only. Whether a dedicated server sees
// it for damage a client caused is unconfirmed; if it does not, this has never worked in
// dedicated MP and neither did the script it replaces.
//
// It fires on every state change rather than once per structure, so a house damaged and then
// levelled counts twice. That is the reading the budget is sized against: it measures ruin done,
// not buildings lost, and the census it is a fraction of is only the scale for that.
addMissionEventHandler ["BuildingChanged", {
    params ["_old", "_damagedObject", "_isRuin"];

    // The census counts House on these same terms. Both sides of the ratio have to mean the
    // same thing or the level runs past its maximum on a map that is not flattened. Military
    // structures stay excluded on both sides for a gameplay reason rather than a symmetry one:
    // destroying enemy fortifications is the objective, and counting it would mean every zone
    // capture pushed the campaign toward its own loss condition.
    private _eden = getText (configFile >> "CfgVehicles" >> typeOf _damagedObject >> "editorSubcategory");
    private _objType = (_old call BIS_fnc_objectType) select 1;
    if (_eden == "EdSubcat_Military" || _objType != "House") exitWith {};

    private _pos = getPos _damagedObject;

    // A building inside a town costs that town as well, and only with a player inside 200 m.
    // Both, not either: escalation counts the map's total ruin and reputation records who has
    // to live in it, so the same collapsed house is two different facts. Presence is a proxy
    // for fault, not a replacement -- what it buys is that a WARCOM assault fought in a town
    // the player is nowhere near can no longer hand it to the enemy.
    // Ungated by escalation_enabled: this is civilian reputation, not escalation.
    if (CIV_PRESENCE != "NONE" && {[_pos] call fnc_civ_playerNear}) then {
        private _town = [_pos] call fnc_civ_townAt;
        if (_town >= 0) then {
            [_town, -2, "building_destroyed"] call fnc_town_rep_adjust;
        };
    };

    // Defaults on, matching the menu, so a campaign that never reached the environment screen
    // escalates rather than silently running without its price and loss pressure.
    if !(missionNamespace getVariable ["escalation_enabled", true]) exitWith {};

    escalation_destroyed = escalation_destroyed + 1;
    private _level = floor (escalation_destroyed / escalation_tier);
    if (_level <= escalation_level) exitWith {};

    escalation_level = _level;
    escalation_multiplier = 1 + (_level / 10);
    publicVariable "escalation_multiplier";
    ["INFO", "ECON", format ["Escalation level %1 (%2 destroyed of %3), prices x%4",
        _level, escalation_destroyed, escalation_budget, escalation_multiplier]] call fnc_log;

    if (_level >= ESCALATION_MAX_LEVEL) exitWith {
        escalation_lost = true;
        publicVariable "escalation_lost";
        ["INFO", "ECON", "Escalation reached its ceiling: campaign lost"] call fnc_log;
    };

    ["info", [localize "STR_DUWS_T_escalation_title",
        format [localize "STR_DUWS_T_escalation_level", _level]]]
        remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];
}];
