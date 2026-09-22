// Locality: server, because the captive state and the cooldown stamp belong to the server.
// One loop per disguised player for both disguises; _kind ("civ" | "enemy") picks the kit test, the
// floor, the ground rate, the cooldown stamp and the break hints. The civilian branch calls the
// helpers fnc_disguiseAsCivilian defines, which always runs first.
params ["_player", "_kind"];

private _civ = _kind isEqualTo "civ";
private _flag = ["DUWS_enemyDisguised", "DUWS_disguised"] select _civ;
private _stampVar = ["DUWS_enemyDisguise_blownAt", "DUWS_disguise_blownAt"] select _civ;
private _warningKeys = [
    "STR_DUWS_T_DISGUISE_WARNING_1", "STR_DUWS_T_DISGUISE_WARNING_2", "STR_DUWS_T_DISGUISE_WARNING_3",
    "STR_DUWS_T_DISGUISE_WARNING_4", "STR_DUWS_T_DISGUISE_WARNING_5", "STR_DUWS_T_DISGUISE_WARNING_6",
    "STR_DUWS_T_DISGUISE_WARNING_7", "STR_DUWS_T_DISGUISE_WARNING_8"
];

// The handler only stamps: the loop decides, because a shot breaks cover only while a unit spots the
// shooter, and that is known at the next tick, not in the handler.
_player setVariable ["DUWS_disguise_firedAt", -1e6];
private _firedEH = _player addEventHandler ["FiredMan", {
    params ["_unit"];
    _unit setVariable ["DUWS_disguise_firedAt", diag_tickTime];
}];

private _fnc_break = {
    params ["_key", "_blown"];
    _player setVariable [_flag, false, true];
    private _text = localize _key;
    if (_blown) then {
        _player setVariable [_stampVar, diag_tickTime];
        _text = format [localize "STR_DUWS_T_DISGUISE_BROKEN_FMT", _text];
    };
    [_text] remoteExec ["hint", _player];
};

private _meter = 0;
private _sentKit = [];
private _shown = [];
private _last = diag_tickTime;
while {alive _player && {_player getVariable [_flag, false]}} do {
    private _now = diag_tickTime;
    private _dt = _now - _last;
    _last = _now;

    private _floor = 0;
    private _inBand = false;
    private _stop = false;
    if (_civ) then {
        private _fault = [_player] call fnc_disguise_civFault;
        if (_fault != "") then {
            ["STR_DUWS_T_DISGUISE_BROKEN_" + _fault, true] call _fnc_break;
            _stop = true;
        } else {
            _inBand = [getPosATL _player, DISGUISE_CIV_SITE_WARN] call fnc_disguise_atEnemySite;
            if (_inBand && {!(_player getVariable ["DUWS_disguise_siteWarned", false])}) then {
                [localize "STR_DUWS_T_DISGUISE_WARNING_SITE_HINT"] remoteExec ["hint", _player];
            };
            _player setVariable ["DUWS_disguise_siteWarned", _inBand];
        };
    } else {
        // Taking the uniform off is the player's own choice, not the enemy seeing through it, so no stamp.
        if !((toLowerANSI uniform _player) in (DUWS_enemyKit get "uniform")) then {
            ["STR_DUWS_T_ENEMY_DISGUISE_ENDED_UNIFORM", false] call _fnc_break;
            _stop = true;
        } else {
            private _mismatch = [_player] call fnc_disguise_enemyMismatch;
            _floor = [_mismatch] call fnc_disguise_floor;
            // For the disguise panel, which cannot judge the kit: DUWS_enemyKit is server-only.
            if ([_floor, _mismatch] isNotEqualTo _sentKit) then {
                _sentKit = [_floor, _mismatch];
                _player setVariable ["DUWS_enemyDisguise_kit", _sentKit, true];
            };
        };
    };
    if (_stop) exitWith {};

    private _dists = [_player] call fnc_disguise_spotters;
    private _seen = _dists isNotEqualTo [];

    if (_seen && {_now - (_player getVariable ["DUWS_disguise_firedAt", -1e6]) <= DISGUISE_FIRE_WINDOW}) exitWith {
        [["STR_DUWS_T_ENEMY_DISGUISE_BROKEN_FIRE", "STR_DUWS_T_DISGUISE_BROKEN_THROW"] select _civ, true] call _fnc_break;
    };

    if (_seen && {_inBand} && {[getPosATL _player, 0] call fnc_disguise_atEnemySite}) exitWith {
        ["STR_DUWS_T_DISGUISE_BROKEN_SITE", true] call _fnc_break;
    };

    private _rate = 1;
    private _decayScale = 1;
    if (_seen) then {
        if (((_player nearObjects ["CAManBase", 20]) findIf { !alive _x }) >= 0) then { _rate = DISGUISE_BODY_MULT };
        _rate = _rate * ([DISGUISE_ENEMY_RATE, [DISGUISE_CIV_RATE_OPEN, DISGUISE_CIV_RATE_BAND] select _inBand] select _civ);
        _rate = _rate * (switch (stance _player) do {
            case "CROUCH": { DISGUISE_CROUCH_MULT };
            case "PRONE": { DISGUISE_PRONE_MULT };
            default { 1 };
        });
    } else {
        if (((_player nearEntities [["AllVehicles"], DISGUISE_DECAY_NEAR_RANGE]) findIf {
            ((crew _x) findIf { alive _x && {side group _x == east} }) >= 0
        }) >= 0) then { _decayScale = DISGUISE_DECAY_NEAR_SCALE };
    };

    private _prev = _meter;
    _meter = [_meter, _floor, _dists, _rate, _dt, _decayScale] call fnc_disguise_suspicion_step;
    if (_seen && {_meter >= 100}) exitWith {
        ["STR_DUWS_T_DISGUISE_BROKEN_SUSPICION", true] call _fnc_break;
    };
    if (_civ && {_prev < 50} && {_meter >= 50}) then {
        [localize "STR_DUWS_T_DISGUISE_OPFOR_SPEAKER", localize (selectRandom _warningKeys)] remoteExec ["fnc_duws_dialogue", _player];
    };
    // Only the owner reads the meter, and only a new bar segment changes what it draws; a public
    // variable would reach every client twice a second.
    private _view = [round (_meter / 5), round (_floor / 5)];
    if (_view isNotEqualTo _shown) then {
        [_meter, _floor, _civ] remoteExec ["fnc_disguise_meter", _player];
        _shown = _view;
    };

    sleep 0.5;
};

if (!isNull _player) then {
    _player setVariable [_flag, false, true];
    if (alive _player) then {
        _player setCaptive false;
        [false] remoteExec ["fnc_disguise_setCaptiveLocal", _player];
    };
    _player removeEventHandler ["FiredMan", _firedEH];
    [] remoteExec ["fnc_disguise_meter", _player];
    _player setVariable ["DUWS_disguise_monitorRunning", false];
};
