// Locality: server -- spawned from server/server_init.sqf.
/*
    fnc_escalation.sqf
    战争升级：全图统计民用建筑总数，记录被摧毁的数量，按等级抬高 CP/AP 价格，
    满级则战役失败。同时把城镇范围内的破坏计入该城镇声望。

    Replaces the war-crimes script, which charged reputation on a curve that dampened rather
    than escalated -- levelling a hundred buildings cost four points -- and discarded any
    remainder below its threshold each tick, so one building a minute was free forever.
*/
if (!isServer) exitWith {};

// A zombie apocalypse has no civil standing to lose and nobody to raise prices, and both modes
// already bailed out of every reputation path they could reach.
if (CIV_PRESENCE == "RAVAGE" || CIV_PRESENCE == "WBK") exitWith {};

// A whole-map census counts every House on the terrain, the overwhelming majority of them in
// settlements no campaign ever visits, so the raw total is far larger than anything a player
// could plausibly destroy. A tenth of it is the loss condition and a ninetieth advances a level.
#define ESCALATION_FRACTION 0.1
#define ESCALATION_MAX_LEVEL 11

// sortByDistance false: ordering an array of many thousands of entries is the bulk of the
// avoidable cost, and nothing here cares about the order.
private _censusStart = diag_tickTime;
private _total = count (nearestTerrainObjects
    [[worldSize / 2, worldSize / 2, 0], ["House"], worldSize, false]);
private _censusCost = diag_tickTime - _censusStart;

escalation_budget = round (_total * ESCALATION_FRACTION) max ESCALATION_MAX_LEVEL;
escalation_tier = escalation_budget / ESCALATION_MAX_LEVEL;
escalation_destroyed = 0;
escalation_level = 0;
// Read by the request menus to show what a purchase will actually cost, so it has to travel.
escalation_multiplier = 1;
publicVariable "escalation_multiplier";

["INFO", "ECON", format ["Escalation census: %1 houses in %2s, budget %3, tier %4",
    _total, (round (_censusCost * 100)) / 100, escalation_budget, round escalation_tier]] call fnc_log;

// The counter is ungated and carries no attribution: not who did it, not whether anyone was
// watching, not whether it stood in a town. The war is getting worse and both sides are making
// it worse, which is what makes per-building damage handlers and setShotParents unnecessary.
// The reputation charge below is the only part that asks where the building stood.
//
// BuildingChanged is a local event and this runs server-only. Whether a dedicated server sees
// it for damage a client caused is unconfirmed; if it does not, this has never worked in
// dedicated MP and neither did the script it replaces.
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

    if (isNil "escalation_enabled" || {!escalation_enabled}) exitWith {};

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
        format [localize "STR_DUWS_T_escalation_level", _level, escalation_multiplier]]]
        remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];
}];
