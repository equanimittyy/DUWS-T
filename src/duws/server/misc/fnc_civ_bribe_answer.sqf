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
    [_civilian, _caller, _row, false] call fnc_civ_close;
};

// The prompt greys Accept when the player is short, but that count came from the player's own
// machine and in co-op two players can spend the same coins. fnc_coins_spend is the read that
// decides, and it tests and deducts in one place so nothing lands between the two.
if !([_caller, _bribe] call fnc_coins_spend) exitWith {
    [_civilian, _caller, _row] call fnc_civ_close;
};

[_civilian, _caller, _row] call fnc_civ_serve;
