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

// Analysis is not instant: a random up-to-a-minute delay before the award lands, so the turn-in
// reads as work being done rather than an instant payout.
sleep (random 60);

private _title = localize "STR_DUWS_T_INTEL_ANALYSIS_TITLE";

private _finalCP = floor _totalCP;
[_finalCP, "intel_analysis"] remoteExec ["fnc_cp_adjust", 2];

// The reveal is a bonus on top of the guaranteed CP, armed by the per-item rolls above and gated on
// pool stock; at most one per delivery, so a hoarded batch cannot dump the map. Resolve it here --
// fnc_intel_payout does the reveal as its side effect -- so a hit folds into the single award line
// below rather than firing a second card.
private _gotIntel = _revealTriggered && {[getPos _caller, _caller] call fnc_intel_payout};

private _awardKey = ["STR_DUWS_T_INTEL_ANALYSIS_AWARD", "STR_DUWS_T_INTEL_ANALYSIS_AWARD_INTEL"] select _gotIntel;
private _line = format [localize _awardKey, _finalCP];
["info", [_title, _line]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];