// Locality: server -- called by mission threads only, all server-side.
/*
    NAME: missions\fnc_mission_cleanup.sqf

    DESCRIPTION:
    Tears a finished side mission down: hands its composition to the map cleanup, then sweeps
    the leftover hostiles around the objective once the player has had time to leave.

    USAGE: reached through fnc_mission_end, which owns the rest of a thread's exit and takes the
    same arguments. Call it directly only for a teardown that is not a mission ending.
        [_targetpos, _radius] call fnc_mission_end;
        [_targetpos, _radius, "mission_holdpos", true] call fnc_mission_end;

    _compKey    composition to release, or "" for a mission that owns no built objects.
    _sweepFriendly  also delete BLUFOR-configured leftovers. Off by default: most missions
                spawn nothing on that side, and the sweep is a blunt proximity delete.
*/

params ["_targetpos", "_radius", ["_compKey", ""], ["_sweepFriendly", false]];
["INFO", "MISSION", format ["cleanup queued for %1 within %2 m, composition %3",
    _targetpos, _radius, ["none", _compKey] select (_compKey != "")]] call fnc_log;

// Released before the countdown, not after it: release only drops the protection and sets a
// deadline, so the map sweep still holds these inside its keep-radius. Waiting out the six
// minutes here as well would put the objective's own props on a different clock to everything
// else the player leaves behind.
if (_compKey != "") then { [_compKey] call fnc_duws_release };

sleep 20;
private _hintMsg = localize "STR_DUWS_T_MISSION_CLEANUP_START";
[_hintMsg] remoteExec ["hint", 0];
["missionclean", [localize "STR_DUWS_T_renwuqingli", localize "STR_DUWS_T_renwuqingli2"]] remoteExec ['BIS_fnc_showNotification', [0,-2] select isDedicated, false];
sleep 280;
["missionclean", [localize "STR_DUWS_T_renwuqingli", localize "STR_DUWS_T_renwuqingli4"]] remoteExec ['BIS_fnc_showNotification', [0,-2] select isDedicated, false];
sleep 50;
["missionclean", [localize "STR_DUWS_T_renwuqingli", localize "STR_DUWS_T_renwuqingli5"]] remoteExec ['BIS_fnc_showNotification', [0,-2] select isDedicated, false];
sleep 10;
_close = false;
{
    if ((_targetpos distance _x) < (zones_max_radius * 1.2)) exitWith {_close = true};
} forEach WARCOM_zones_controled_by_OPFOR;

// 定义僵尸类名列表
private _zombieClasses = ["zombie_runner", "zombie_bolter", "zombie_walker"];

if (_close == false) then {
    _missObj = _targetpos nearObjects (_radius * 1.2);

    // 构建受保护对象列表（玩家自身及组员、载具）
    private _protected = [];
    {
        private _player = _x;
        _protected pushBackUnique _player;
        {
            _protected pushBackUnique _x;
            private _veh = vehicle _x;
            if (_veh != _x) then { _protected pushBackUnique _veh };
        } forEach (units group _player);
        private _veh = vehicle _player;
        if (_veh != _player) then { _protected pushBackUnique _veh };
    } forEach allPlayers;

    {
        private _isHostile = _x getVariable ["isHostile", false];

        // WBK dresses its friendly civilians as WEST, so that side is spared whatever the
        // caller asked for -- _sweepFriendly exists to collect a mission's own BLUFOR-configured
        // emplacements, and it must not become a licence to delete the townspeople.
        private _sparedSide = (side _x == CIVILIAN)
            || {side _x == WEST && {!_sweepFriendly || CIV_PRESENCE == "WBK"}}
            || {side _x == INDEPENDENT && CIV_PRESENCE == "WBK"};

        // The persistent flag outranks proximity. This is a blunt radius delete, and a side
        // mission drawn near a player FOB or the HQ puts their buildings inside it -- without
        // this the teardown would take a standing composition apart on its way past.
        if (!(_x in _protected)
            && !(_x getVariable ["persistent", false])
            && !_sparedSide
            && !(typeOf _x in _zombieClasses)
            && !_isHostile) then {
            deleteVehicleCrew _x;
            deleteVehicle _x;
        };
    } forEach _missObj;
};
