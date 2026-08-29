// fnc_capture_zones_task.sqf
// CREATE MAIN TASK/OBJECTIVE
if (!isServer) exitWith {};

if (isNil "ZombieTaskCreated") then {
    ZombieTaskCreated = false;
};

// Orders arrive with the player, not on a timer: a fixed 60 s wait expires part-way through zone
// build-out, and manual placement runs minutes past it, so the task would tell the player to
// capture zones that did not exist yet.
while {!(["ZONES", "mission_init_complete (zones built, civilians registered)",
    {mission_init_complete}, 300] call fnc_waitLogged)} do {};
// Then the fast-rope. Not retried on timeout, unlike the wait above -- fnc_intro_heli has early
// exits that never publish this, and a campaign with no main task has no win condition at all.
// The gate above is what keeps that fall-through from landing back at mission start.
["ZONES", "intro_heli_done (players landed)", {!isNil "intro_heli_done"}, 420] call fnc_waitLogged;
// Then the sitrep radio item, so orders never land before the tool that reports on them.
// Not retried for the same reason as above: only the game_master slot adds the item, so an
// MP session with that slot empty would never publish it.
["ZONES", "sitrep_granted (radio item added)", {!isNil "sitrep_granted"}, 90] call fnc_waitLogged;

// The task ID must never be localized -- the SUCCEEDED update looks it up by this exact string, so a
// localized ID stops matching on a non-English server and the campaign never completes. Created
// server-side, not remoteExec'd: broadcasting BIS_fnc_taskCreate serialises owner/destination as live
// references the map re-resolves by netId every open frame, flooding the rpt with "objectFromNetId"
// errors (docs/info/architecture/arma_engine_gotchas.md). Destination is [] -- capture-all-zones has no
// single pin, and an objNull the draw would try to resolve.
[west, ["Campaign"],
    [localize "STR_DUWS_T_92465yls", localize "STR_DUWS_T_q5xntd8z", localize "STR_DUWS_T_q5xntd8z"], [], true]
    call BIS_fnc_taskCreate;
sleep 2;
if (CIV_PRESENCE == "RAVAGE" && !ZombieTaskCreated) then {
    [west, ["ZombieTask"],
        [localize "STR_DUWS_T_deadboltdesc", localize "STR_DUWS_T_deadbolt", localize "STR_DUWS_T_deadbolt"], [], true]
        call BIS_fnc_taskCreate;
    ZombieTaskCreated = true;
};
if (CIV_PRESENCE == "WBK" && !ZombieTaskCreated) then {
    [west, ["WBKTask"],
        [localize "STR_DUWS_T_WBK_TASK_DESC", localize "STR_DUWS_T_deadbolt", localize "STR_DUWS_T_deadbolt"], [], true]
        call BIS_fnc_taskCreate;
    ZombieTaskCreated = true;
};

waitUntil {sleep 10; WARCOM_init_done};
// The zone count must be checked, not assumed: with none created, 0 >= 0 wins on the first evaluation
// (every zone slot can be dropped by the origin keep-out in fnc_locatorzones_random). Win and loss share
// one waitUntil, not two threads -- this blocks for the whole campaign, so anything appended after it is
// unreachable until an ending fires. Five-second poll: the losses publish the moment they happen, so a
// long interval reads as the campaign not noticing (two variable reads cost nothing).
waitUntil {
    sleep 5;
    (amount_zones_created > 0 && {zoneundercontrolblu >= amount_zones_created})
    || {!isNil "campaign_lost"}
};

// The pause only lets the notification and the task update land before the outro card replaces
// them. The notification takes title and body as separate fields; the hint and side-chat take
// one string, so they need the separator the `+` concatenation was missing -- it ran the
// headline straight into the sentence as "Mission Completed!Every zone...".
private _won = isNil "campaign_lost";
private _title = [localize "STR_DUWS_T_CAMPAIGN_LOST_TITLE", localize "STR_DUWS_T_fo1ihi1n"] select _won;
// The losing body names which ending this was (more than one way to lose now), carried as a stringtable
// key not resolved text -- so the setter needs no stringtable, and this stays the one place the endings
// are worded. The map name is passed to every ending, not just the one reading it: a body without a %1
// discards the surplus arg (docs/info/architecture/arma_engine_gotchas.md), so this stays one call. It is
// the map's config description, not worldName (the internal class -- "Enoch" for Livonia -- not what the
// player calls it).
private _body = format [[localize (missionNamespace getVariable
    ["campaign_lost_body", "STR_DUWS_T_CAMPAIGN_LOST"]), localize "STR_DUWS_T_CAMPAIGN_WON"] select _won,
    getText (configFile >> "cfgWorlds" >> worldName >> "description")];

// Defeat wears the red critical class; a win stays neutral. Losing the campaign must not be
// reported in the same colour as a cost line.
[["critical", "info"] select _won, [_title, _body]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
[format ["%1\n\n%2", _title, _body], {hint _this}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];

["Campaign", ["FAILED", "SUCCEEDED"] select _won] remoteExec ["BIS_fnc_taskSetState", [0,-2] select isDedicated, "Campaign"];
sleep 10;
// The outro card is a CfgDebriefing class and carries its own wording, so ending a loss on the
// win class congratulated the player for capturing the island they had just lost. Each loss setter
// names the class that matches its ending; the fallback covers a loss published without one.
private _ending = [missionNamespace getVariable ["campaign_lost_ending", "island_ruined"],
    "island_captured_win"] select _won;
// Two-argument form: the one-argument call defaults victory to true, which would end a
// flattened Altis on the winning card.
[_ending, _won] call BIS_fnc_endMissionServer;
