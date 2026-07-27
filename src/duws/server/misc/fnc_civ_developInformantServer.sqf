// Locality: server; the trigger bodies below run on the machine that triggers them, not here.
/*
    fnc_civ_developInformantServer.sqf
    参数: [_unit, _caller, _locIndex]
    修改：消耗 5 个 Money_roll 而不是 CP
*/
params ["_unit", "_caller", "_locIndex"];

if (!isServer) exitWith {};

if (missionNamespace getVariable [format ["civ_informant_active_%1", _locIndex], false]) exitWith {
    [localize "STR_DUWS_T_INFORMANT_ALREADY_ACTIVE"] remoteExec ["hint", _caller];
};

private _rep = missionNamespace getVariable ["Player_Reputation", 0];
if (_rep <= 0) exitWith {
    sleep 4;
    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_norepinf"] remoteExec ["fnc_duws_dialogue", _caller];
    [localize "STR_DUWS_T_DEV_INFORMANT_FAIL_REP"] remoteExec ["hint", _caller];
};

private _chance = (_rep min 3) * 0.05;
if (random 1 > _chance) exitWith {
    sleep 4;
    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_failinf"] remoteExec ["fnc_duws_dialogue", _caller];
    [localize "STR_DUWS_T_DEV_INFORMANT_FAIL"] remoteExec ["hint", _caller];
};

// 扣除 5 个 Money_roll
private _moneyRemoved = 0;
{
    if (_x == "Money_roll" && _moneyRemoved < 5) then {
        _caller removeItem "Money_roll";
        _moneyRemoved = _moneyRemoved + 1;
    };
} forEach (items _caller);
if (_moneyRemoved < 5) then {
    {
        if (_x == "Money_roll" && _moneyRemoved < 5) then {
            _caller removeMagazineGlobal "Money_roll";
            _moneyRemoved = _moneyRemoved + 1;
        };
    } forEach (magazines _caller);
};

if (_moneyRemoved < 5) exitWith {
    sleep 4;
    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_nocpinf"] remoteExec ["fnc_duws_dialogue", _caller];
    [localize "STR_DUWS_T_nocpinf2"] remoteExec ["hint", _caller];
};

sleep 4;
[localize "STR_DUWS_T_civ", localize "STR_DUWS_T_successinf"] remoteExec ["fnc_duws_dialogue", _caller];

missionNamespace setVariable [format ["civ_informant_active_%1", _locIndex], true];
publicVariable format ["civ_informant_active_%1", _locIndex];
sleep 2;

_unit removeAllEventHandlers "Killed";
private _runDir = random 360;
private _runDist = 50 + random 50;
private _runPos = (getPos _unit) getPos [_runDist, _runDir];
_unit doMove _runPos;
[_unit] spawn {
    params ["_u"];
    sleep 25;
    if (!isNull _u) then { deleteVehicle _u; };
};

["info", [localize "STR_DUWS_T_infomat", localize "STR_DUWS_T_DEV_INFORMANT_SUCCESS"]] remoteExec ["BIS_fnc_showNotification", 0];

private _locations = missionNamespace getVariable ["civ_locations", []];
if (_locIndex >= count _locations) exitWith { ["ERROR", "CIV", "Invalid locIndex"] call fnc_log; };
private _centerPos = getPos (_locations select _locIndex);

private _markerArea = createMarker [format ["informant_area_%1", _locIndex], _centerPos];
_markerArea setMarkerShape "ELLIPSE";
_markerArea setMarkerBrush "SolidBorder";
_markerArea setMarkerColor "ColorWhite";
_markerArea setMarkerSize [700, 700];
_markerArea setMarkerAlpha 0.5;

private _trg = createTrigger ["EmptyDetector", _centerPos];
_trg setTriggerArea [700, 700, 0, false];
_trg setTriggerActivation ["EAST", "PRESENT", false];
_trg setTriggerStatements ["this", "", ""];

[_trg, _centerPos, _locIndex, _markerArea] spawn {
    params ["_trg", "_centerPos", "_locIndex", "_markerArea"];
    private _duration = 3600 + random 7200;
    private _endTime = time + _duration;
    private _lastNotifyTime = 0;
    while {time < _endTime} do {
        sleep 60;
        private _eastUnits = list _trg;
        if (count _eastUnits > 0 && {time - _lastNotifyTime >= 600}) then {
            ["info", [localize "STR_DUWS_T_infomat", localize "STR_DUWS_T_infosts"]] remoteExec ["BIS_fnc_showNotification", 0];
            _lastNotifyTime = time;
        };
        {
            private _unit = _x;
            if (alive _unit) then {
                private _markerName = format ["informant_red_%1_%2_%3", _locIndex, round(diag_tickTime * 1000), floor random 1000];
                private _marker = createMarker [_markerName, getPos _unit];
                _marker setMarkerShape "ELLIPSE";
                _marker setMarkerBrush "SolidBorder";
                _marker setMarkerColor "ColorRed";
                _marker setMarkerSize [4, 4];
                _marker setMarkerAlpha 1;
                [_markerName] spawn {
                    params ["_m"];
                    sleep 60;
                    deleteMarker _m;
                };
            };
        } forEach _eastUnits;
    };
    deleteMarker _markerArea;
    deleteVehicle _trg;
    missionNamespace setVariable [format ["civ_informant_active_%1", _locIndex], nil];
    publicVariable format ["civ_informant_active_%1", _locIndex];
    ["info", [localize "STR_DUWS_T_infomat", localize "STR_DUWS_T_INFORMANT_EXPIRED"]] remoteExec ["BIS_fnc_showNotification", 0];
};