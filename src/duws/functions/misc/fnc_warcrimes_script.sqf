// WARCRIMES SCRIPT (最终修复版：60秒统一播报，声望正确显示)
if (!isServer) exitWith {};

private _threshold = 1;
private _levelIncrement = 2;
private _lastBuildingCount = 0;

addMissionEventhandler ["BuildingChanged", {
    params ["_old", "_damagedObject", "_isRuin"];
    if (CIV_PRESENCE == "RAVAGE") exitWith {};
    if (CIV_PRESENCE == "WBK") exitWith {};

    private _cfg = configFile >> "CfgVehicles" >> typeOf _damagedObject;
    private _eden = getText(_cfg >> "editorSubcategory");
    private _objType = (_old call BIS_fnc_objectType) select 1;
    private _playersNear = {
        (_x distance _damagedObject) < 750
    } count (call BIS_fnc_listPlayers) > 0;

    if (_eden != "EdSubcat_Military" && _objType == "House" && _playersNear) then {
        damagedBuildings pushBack _damagedObject;
    };
}];

while {true} do {
    sleep 60;

    if (CIV_PRESENCE == "WBK") then {
        damagedBuildings = [];
        _threshold = 1;
        _lastBuildingCount = 0;
        continue;
    };

    private _currentTotal = count damagedBuildings;
    private _delta = _currentTotal - _lastBuildingCount;
    private _repLoss = 0;

    while {_delta >= _threshold} do {
        _repLoss = _repLoss + 0.4;
        _delta = _delta - _threshold;
        _threshold = _threshold + _levelIncrement;
    };

    if (_repLoss > 0) then {
        [-_repLoss] remoteExec ["fnc_rep_adjust", 2];

        // 总损坏建筑数提示
        private _msg = format[localize "STR_DUWS_T_5445z2bn", _currentTotal];
        [_msg] remoteExec ["hint", [0,-2] select isDedicated];
        sleep 2;

        // 第一条通知：惩罚描述
        ["info", [localize "STR_DUWS_T_y9d3jrt6", localize "STR_DUWS_T_g2ehnkc5"]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];
        sleep 6;

        // 第二条通知：当前声望（第三个参数会自动填入模板的 %3）
        ["info", [localize "STR_DUWS_T_y9d3jrt6", localize "STR_DUWS_T_jly4u3ui", Player_Reputation]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];
    };

    _lastBuildingCount = _currentTotal;
};