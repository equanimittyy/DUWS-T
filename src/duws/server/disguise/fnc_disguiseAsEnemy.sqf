if (!isServer) exitWith {};

params ["_player"];
if (isNull _player) exitWith {};

private _fnc_refuse = {
    params ["_key"];
    [localize _key] remoteExec ["hint", _player];
};

private _cooldownRemaining = 600 - (diag_tickTime - (_player getVariable ["DUWS_enemyDisguise_blownAt", -600]));
if (_cooldownRemaining > 0) exitWith {
    private _msg = format [localize "STR_DUWS_T_DISGUISE_COOLDOWN_FMT", floor (_cooldownRemaining / 60), floor (_cooldownRemaining % 60)];
    [_msg] remoteExec ["hint", _player];
};
if (CIV_PRESENCE in ["NONE", "RAVAGE", "WBK"]) exitWith { ["STR_DUWS_T_DISGUISE_CANT_ZOMBIE"] call _fnc_refuse };
if (_player getVariable ["DUWS_disguised", false]) exitWith { ["STR_DUWS_T_DISGUISE_CANT_OTHER"] call _fnc_refuse };
if ([_player] call fnc_disguise_hunted || {([_player] call fnc_disguise_spotters) isNotEqualTo []}) exitWith {
    ["STR_DUWS_T_DISGUISE_CANT_HUNTED"] call _fnc_refuse;
};
if (isNil "DUWS_enemyKit") exitWith { ["STR_DUWS_T_ENEMY_DISGUISE_CANT_NOKIT"] call _fnc_refuse };

if !((toLowerANSI uniform _player) in (DUWS_enemyKit get "uniform")) exitWith { ["STR_DUWS_T_ENEMY_DISGUISE_CANT_UNIFORM"] call _fnc_refuse };

_player setVariable ["DUWS_enemyDisguised", true, true];
_player setCaptive true;
[true] remoteExec ["fnc_disguise_setCaptiveLocal", _player];

private _mismatch = [_player] call fnc_disguise_enemyMismatch;
private _msg = format [localize "STR_DUWS_T_ENEMY_DISGUISE_ACTIVATED_FMT", [_mismatch apply { _x select 0 }] call fnc_disguise_floor];
if (_mismatch isNotEqualTo []) then {
    private _names = _mismatch apply {
        _x params ["_slot", "_cls"];
        private _root = ["CfgWeapons", "CfgVehicles"] select (_slot in ["backpack", "vehicle"]);
        getText (configFile >> _root >> _cls >> "displayName")
    };
    _msg = _msg + " " + format [localize "STR_DUWS_T_ENEMY_DISGUISE_MISMATCH_FMT", _names joinString ", "];
};
[_msg] remoteExec ["hint", _player];

if (!(_player getVariable ["DUWS_disguise_monitorRunning", false])) then {
    _player setVariable ["DUWS_disguise_monitorRunning", true];
    [_player, "enemy"] spawn fnc_disguise_monitor;
};
