// Recruitment reports through a hint box on purpose, not folded into the spoken dialogue the way
// the other civilian interactions are: stock DUWS confirms a recruit this way and players read it
// as the confirmation. The RAVAGE/WBK path this sits on is due a wider pass; the channel is not
// the part to change.
params ["_civilian", "_caller", "_civNetId", "_callerUID"];

if (!isServer) exitWith {};

// Re-fetched to guard against network latency invalidating the object.
if (isNull _civilian) then {
    _civilian = objectFromNetId _civNetId;
};
if (isNull _caller) then {
    {
        if (getPlayerUID _x == _callerUID) exitWith { _caller = _x; };
    } forEach allPlayers;
};

if (isNull _civilian || isNull _caller) exitWith {
    ["ERROR", "CIV", "Error: civilian or caller is null"] call fnc_log;
};
if (!alive _civilian) exitWith {
    [localize "STR_DUWS_T_RECRUIT_DEAD"] remoteExec ["hint", _caller];
};
if (_civilian getVariable ["recruit_processed_server", false]) exitWith {
    [localize "STR_DUWS_T_RECRUIT_ALREADY"] remoteExec ["hint", _caller];
};

_civilian setVariable ["recruit_processed_server", true];

// Kept for the cleanup below once the civilian leaves this group.
private _oldGroup = group _civilian;
private _locIndex = _civilian getVariable ["civ_locIndex", -1];

if (random 1 < 0.95) then {
    [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_RECRUITconv1"] remoteExec ["fnc_duws_dialogue", _caller];
    sleep 3;
    [localize "STR_DUWS_T_survivor", localize "STR_DUWS_T_RECRUITconv2"] remoteExec ["fnc_duws_dialogue", _caller];
    
    private _roamHandle = _civilian getVariable ["roamScript", scriptNull];
    if (!isNull _roamHandle) then {
        terminate _roamHandle;
        _civilian setVariable ["roamScript", nil];
    };
    
    // joinSilent also reassigns side, so no separate faction change is needed here.
    [_civilian] joinSilent (group _caller);
    // Off its town's roster as it changes hands, or the next teardown of that town deletes a man
    // standing in the player's squad. The tag goes with it, for the readers that still ask.
    if (_locIndex >= 0) then {
        [[_locIndex] call fnc_town_site_key, _civilian, "crowd"] call fnc_site_roster_drop;
    };
    _civilian setVariable ["civ_locIndex", nil];

    _civilian setCaptive false;
    _civilian stop false;
    _civilian enableAI "MOVE";
    _civilian enableAI "PATH";
    _civilian enableAI "AUTOTARGET";
    _civilian enableAI "TARGET";
    _civilian setUnitPos "AUTO";

    if (!isNull _oldGroup) then {
        if (count units _oldGroup == 0) then {
            deleteGroup _oldGroup;
        };
        if (_locIndex != -1) then {
            private _groupsVar = format ["civ_groups_%1", _locIndex];
            private _groups = missionNamespace getVariable [_groupsVar, []];
            _groups = _groups - [_oldGroup];
            missionNamespace setVariable [_groupsVar, _groups];
        };
    };
    
    ["INFO", "CIV", format ["Civilian %1 successfully recruited by %2", _civilian, name _caller]] call fnc_log;
    
    sleep 3;
    [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_RECRUITconv3"] remoteExec ["fnc_duws_dialogue", _caller];
    [_civilian] joinSilent (group _caller);
    _civilian setVariable ["civ_locIndex", nil];
    
    [_civilian, _caller] spawn {
        params ["_unit", "_caller"];
        private _hqPos = PosOfBLUHQ;
        waitUntil {
            sleep 5;
            (!alive _unit) || (_unit distance _hqPos < 50)
        };
        if (alive _unit && _unit distance _hqPos < 50) then {
            [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_RECRUITconv4"] remoteExec ["fnc_duws_dialogue", _caller];
            sleep 3;
            [localize "STR_DUWS_T_survivor", localize "STR_DUWS_T_RECRUITconv5"] remoteExec ["fnc_duws_dialogue", _caller];
            deleteVehicle _unit;
            
            private _reward = 5;
            if (CIV_PRESENCE == "WBK") then {
                _reward = 8;
            };
            [_reward, "civilian_recruited"] remoteExec ["fnc_cp_adjust", 2];
            
            private _desc = format [localize "STR_DUWS_T_RECRUIT_gainCP", _reward];
            ["repup", [localize "STR_DUWS_T_RECRUIT_SUCCESS2", _desc]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];
        };
    };
    
    [localize "STR_DUWS_T_RECRUIT_SUCCESS_MSG"] remoteExec ["hint", _caller];

} else {
    _civilian setBehaviour "CARELESS";
    _civilian doMove (getPos _civilian getPos [random 50, random 360]);
    [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_RECRUITconv1"] remoteExec ["fnc_duws_dialogue", _caller];
    sleep 3;
    [localize "STR_DUWS_T_survivor", localize "STR_DUWS_T_RECRUITconv6"] remoteExec ["fnc_duws_dialogue", _caller];
    [localize "STR_DUWS_T_RECRUIT_FAIL_MSG"] remoteExec ["hint", _caller];
    sleep 3;
    [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_RECRUITconv7"] remoteExec ["fnc_duws_dialogue", _caller];
};