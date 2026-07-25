// fnc_intelAnalysis.sqf
if (!isServer) exitWith {};

params ["_caller"];
if (isNull _caller) exitWith {};

// 定义情报物品与对应 CP 值
private _intelItems = [
    ["SmartPhone", 4],
    ["MobilePhone", 2],
    ["FlashDisk", 2.5],
    ["Files", 2],
    ["FilesSecret", 8],
    ["Wallet_ID", 1.5],
    ["FileTopSecret", 8]
];

private _totalCP = 0;
private _removedItems = [];

// 获取玩家弹匣和物品
private _playerMags = magazines _caller;
private _playerItems = items _caller;

{
    private _itemClass = _x select 0;
    private _cpValue = _x select 1;

    // 统计在弹匣中的数量
    private _countMags = 0;
    { if (_x == _itemClass) then { _countMags = _countMags + 1; }; } forEach _playerMags;
    // 统计在物品中的数量
    private _countItems = 0;
    { if (_x == _itemClass) then { _countItems = _countItems + 1; }; } forEach _playerItems;

    private _totalCount = _countMags + _countItems;

    if (_totalCount > 0) then {
        // 移除弹匣
        for "_i" from 1 to _countMags do {
            _caller removeMagazineGlobal _itemClass;
        };
        // 移除物品
        for "_i" from 1 to _countItems do {
            _caller removeItem _itemClass;
        };

        private _reward = _totalCount * _cpValue;
        _totalCP = _totalCP + _reward;
        _removedItems pushBack format ["%1 x%2", _itemClass, _totalCount];
    };
} forEach _intelItems;

if (_totalCP == 0) exitWith {
    [localize "STR_DUWS_T_INTEL_ANALYSIS_NO_ITEMS"] remoteExec ["hint", _caller];
};
[([localize "STR_DUWS_T_actionteam"] call fnc_cs), ([localize "STR_DUWS_T_INTEL_ANALYSIS_rqst"] call fnc_cs)] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 5;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_INTEL_ANALYSIS_roger"] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 5;
private _finalCP = floor _totalCP;
[_finalCP, "intel_analysis"] remoteExec ["fnc_cp_adjust", 2];

private _itemsList = _removedItems joinString ", ";
private _title = localize "STR_DUWS_T_INTEL_ANALYSIS_TITLE";
private _desc = format [localize "STR_DUWS_T_INTEL_ANALYSIS_BROADCAST", name _caller, _itemsList, _finalCP];
["info", [_title, _desc]] remoteExec ["BIS_fnc_showNotification", 0];

private _hintMsg = format [localize "STR_DUWS_T_INTEL_ANALYSIS_HINT", _finalCP, _itemsList];
_hintMsg remoteExec ["hint", 0];