// fnc_intelAnalysis.sqf
if (!isServer) exitWith {};

params ["_caller"];
if (isNull _caller) exitWith {};

// Two tiers, decided by where an item comes from. `Files` and `Wallet_ID` are what fnc_addRandomLoot
// puts on the enemies that carry loot, so they price a corpse and stay at 1. The rest are only ever
// handed over by a search, so they sit above the corpse tier. Values are kept modest on purpose:
// intel rewards clearing a garrison, it must not out-earn holding ground -- which is why the reward
// is small and the drop is thinned at the source rather than a per-tick cap being bolted on.
//
// Whole numbers throughout: the total is floored once at the end, so a fractional value made two
// of a kind worth more than twice one.
private _intelItems = [
    ["SmartPhone", 4],
    ["MobilePhone", 2],
    ["FlashDisk", 3],
    ["Files", 1],
    ["FilesSecret", 5],
    ["Wallet_ID", 1],
    ["Wallet_traitor", 2],
    ["FileTopSecret", 5]
];

private _totalCP = 0;
private _removedItems = [];

private _playerMags = magazines _caller;
private _playerItems = items _caller;

{
    private _itemClass = _x select 0;
    private _cpValue = _x select 1;

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

// One roll per delivery, the same 10 % a body search pays intel on, so what a document is worth
// is a draw rather than a rate: most turn-ins buy command points, and now and then the analysts
// pull a location out of them instead -- the one a local would have given up for free. The
// payout is only reached when the roll lands, and a dry pool falls through to CP rather than
// swallowing the delivery for nothing.
if (random 1 < 0.10 && {[getPos _caller, _caller] call fnc_intel_payout}) exitWith {
    private _revealDesc = format [localize "STR_DUWS_T_INTEL_ANALYSIS_REVEAL", name _caller, _itemsList];
    ["info", [_title, _revealDesc]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];
};

private _finalCP = floor _totalCP;
[_finalCP, "intel_analysis"] remoteExec ["fnc_cp_adjust", 2];
private _desc = format [localize "STR_DUWS_T_INTEL_ANALYSIS_BROADCAST", name _caller, _itemsList, _finalCP];
["info", [_title, _desc]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];

private _hintMsg = format [localize "STR_DUWS_T_INTEL_ANALYSIS_HINT", _finalCP, _itemsList];
_hintMsg remoteExec ["hint", 0];