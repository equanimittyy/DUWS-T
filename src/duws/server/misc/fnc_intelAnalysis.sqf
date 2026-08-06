// fnc_intelAnalysis.sqf
if (!isServer) exitWith {};

params ["_caller"];
if (isNull _caller) exitWith {};

// Two tiers, and which tier an item is in is decided by where it comes from. `Files` and
// `Wallet_ID` are what fnc_addRandomLoot puts on 80 % of enemies, so they price a corpse and stay
// low. The rest are only ever handed over by a search, whose whole point is that it beat the 1-3
// CP the pool pays on the spot -- so every one of them clears 3.
//
// Whole numbers throughout: the total is floored once at the end, so a fractional value made two
// of a kind worth more than twice one.
private _intelItems = [
    ["SmartPhone", 6],
    ["MobilePhone", 4],
    ["FlashDisk", 5],
    ["Files", 2],
    ["FilesSecret", 8],
    ["Wallet_ID", 1],
    ["Wallet_traitor", 4],
    ["FileTopSecret", 8]
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