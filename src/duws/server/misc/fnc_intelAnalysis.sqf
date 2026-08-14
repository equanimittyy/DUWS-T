// fnc_intelAnalysis.sqf
if (!isServer) exitWith {};

params ["_caller"];
if (isNull _caller) exitWith {};

// Each entry is [class, CP, revealChance]. The two numbers are independent axes: CP is paid on
// every turn-in, the reveal chance is a separate per-item roll for a bonus map reveal on top. An
// item can be CP-heavy and reveal-light (SmartPhone) or the reverse (FlashDisk) -- what a document
// is good for is not just its cash.
//
// CP is kept modest: the turn-in rewards clearing enemies, it must not out-earn holding ground.
// Whole numbers, floored once at the end, so a fractional value cannot make two of a kind worth
// more than twice one.
private _intelItems = [
    ["SmartPhone", 2, 0.10],
    ["MobilePhone", 1, 0.05],
    ["FlashDisk", 3, 0.50],
    ["Files", 4, 0.50],
    ["FilesSecret", 5, 1.00],
    ["Wallet_ID", 1, 0.05],
    ["FileTopSecret", 5, 1.00]
];

private _totalCP = 0;
private _revealTriggered = false;
private _removedItems = [];

private _playerMags = magazines _caller;
private _playerItems = items _caller;

{
    private _itemClass = _x select 0;
    private _cpValue = _x select 1;
    private _revealChance = _x select 2;

    private _countMags = 0;
    { if (_x == _itemClass) then { _countMags = _countMags + 1; }; } forEach _playerMags;
    private _countItems = 0;
    { if (_x == _itemClass) then { _countItems = _countItems + 1; }; } forEach _playerItems;

    private _totalCount = _countMags + _countItems;

    if (_totalCount > 0) then {
        for "_i" from 1 to _countMags do {
            _caller removeMagazineGlobal _itemClass;
        };
        for "_i" from 1 to _countItems do {
            _caller removeItem _itemClass;
        };

        private _reward = _totalCount * _cpValue;
        _totalCP = _totalCP + _reward;
        _removedItems pushBack format ["%1 x%2", _itemClass, _totalCount];

        // Rolled per instance, so more (or better) documents raise the odds; one hit anywhere in the
        // delivery arms the single reveal below.
        for "_i" from 1 to _totalCount do {
            if (random 1 < _revealChance) then { _revealTriggered = true };
        };
    };
} forEach _intelItems;

if (_totalCP == 0) exitWith {
    [localize "STR_DUWS_T_INTEL_ANALYSIS_NO_ITEMS"] remoteExec ["hint", _caller];
};
[localize "STR_DUWS_T_actionteam", ([localize "STR_DUWS_T_INTEL_ANALYSIS_rqst"] call fnc_cs)] remoteExec ["fnc_duws_dialogue", 0];
sleep 5;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_INTEL_ANALYSIS_roger"] remoteExec ["fnc_duws_dialogue", 0];
sleep 5;
private _itemsList = _removedItems joinString ", ";
private _title = localize "STR_DUWS_T_INTEL_ANALYSIS_TITLE";

private _finalCP = floor _totalCP;
[_finalCP, "intel_analysis"] remoteExec ["fnc_cp_adjust", 2];
private _desc = format [localize "STR_DUWS_T_INTEL_ANALYSIS_BROADCAST", name _caller, _itemsList, _finalCP];
["info", [_title, _desc]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];

private _hintMsg = format [localize "STR_DUWS_T_INTEL_ANALYSIS_HINT", _finalCP, _itemsList];
_hintMsg remoteExec ["hint", 0];

// The reveal is a bonus on top of the guaranteed CP now, not a replacement. The per-item rolls
// above arm it; one reveal at most per delivery, so a hoarded batch cannot dump the map, and it is
// still gated on pool stock -- a dry pool pays the CP and reveals nothing.
if (_revealTriggered && {[getPos _caller, _caller] call fnc_intel_payout}) then {
    private _revealDesc = format [localize "STR_DUWS_T_INTEL_ANALYSIS_REVEAL", name _caller, _itemsList];
    ["info", [_title, _revealDesc]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];
};