// Locality: server. Answers the bribe prompt raised by fnc_civ_request.
//
// The client sends only whether the player accepted. Which row was offered and what it costs are
// read from the server's own record, so a client cannot claim a bribe it was never offered or
// name its own price.
if (!isServer) exitWith {};

params ["_civilian", "_caller", ["_accepted", false]];

if (isNull _civilian || isNull _caller) exitWith {};

private _pending = _civilian getVariable ["DUWS_civ_pending", []];

// Cleared before anything below can fail or exit: an offer answered once is gone, so a
// duplicated or replayed message cannot buy the same row twice.
_civilian setVariable ["DUWS_civ_pending", nil];

if (count _pending < 3) exitWith {};
_pending params ["_offeredTo", "_row", "_bribe"];

// Two players can be stood at the same civilian in co-op. The offer belongs to whoever the roll
// was made for.
if !(_offeredTo isEqualTo _caller) exitWith {};

if (!_accepted) exitWith {
    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_CIV_BRIBE_DECLINED"] remoteExec ["fnc_duws_dialogue", _caller];
    [_civilian, _caller, _row] call fnc_civ_close;
};

// The prompt greys Accept when the player is short, but that count came from magazines player on
// their machine, and in co-op two players can spend the same coins. This read is the one that
// decides. Coins land in either slot depending on how they were picked up, so both are counted
// and both are drained, matching fnc_blackMarketPurchase.
private _coins = { _x == "Money_roll" } count (itemsWithMagazines _caller);
if (_coins < _bribe) exitWith {
    [localize "STR_DUWS_T_nocpinf2"] remoteExec ["hint", _caller];
    [_civilian, _caller, _row] call fnc_civ_close;
};

private _removed = 0;
{
    if (_x == "Money_roll" && _removed < _bribe) then {
        _caller removeItem "Money_roll";
        _removed = _removed + 1;
    };
} forEach (items _caller);
if (_removed < _bribe) then {
    {
        if (_x == "Money_roll" && _removed < _bribe) then {
            _caller removeMagazineGlobal "Money_roll";
            _removed = _removed + 1;
        };
    } forEach (magazines _caller);
};

[_civilian, _caller, _row] call fnc_civ_serve;
