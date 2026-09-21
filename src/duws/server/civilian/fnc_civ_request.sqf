// Locality: server. Every conversational row of the civilian menu lands here. The reputation
// read, the reaction roll and the spend all happen on this machine, because a client that owns
// any one of them can retry until it likes the answer.
if (!isServer) exitWith {};

params ["_civilian", "_caller", ["_row", ""]];

if (isNull _civilian || isNull _caller) exitWith {};
if (!alive _civilian) exitWith {};

private _bribe = [_row] call fnc_civ_rowPrice;

// Fail closed and say nothing back: rows only ever arrive over the wire, so there is no
// legitimate path that reaches this with a row the menu never drew.
if (_bribe < 0) exitWith {
    ["ERROR", "CIV", format ["Menu row '%1' is not a request (from %2)", _row, name _caller]] call fnc_log;
};

// The conditions below are the ones the menu greys client-side. Greying spares the player a
// pointless click and decides nothing; these reads are what actually hold. Conversation range
// matches the 3 m the menu greys at.
if (_caller distance _civilian > 3) exitWith {};
if (_civilian getVariable ["DUWS_civ_closed", false]) exitWith {};

// An arrest in flight is an exchange in flight. fnc_civ_arrest claims its own flag and never the
// closed one, so without this a second player whose dialog was already open can still talk to
// someone who is being held at gunpoint.
if (_civilian getVariable ["DUWS_civ_arrested", false]) exitWith {};

// Intel alone is capped per player, one ask per 30-minute economy tick -- the same window and
// the same clock the body search spends, cleared for everyone by fnc_zonesundercontrol. Flat
// rather than nested: `exitWith` inside a `then` block leaves the block, not this function.
if (((toUpper _row) isEqualTo "INTEL") && {_caller getVariable ["DUWS_civ_intel_asked", false]}) exitWith {};

private _opener = switch (toUpper _row) do {
    case "AID": { "STR_DUWS_T_ASK_AID_hi" };
    case "TOOLKIT": { "STR_DUWS_T_ASK_TOOLKIT_hi" };
    default { "STR_DUWS_T_askopforloc" };
};
// Both spends land on the attempt, not on the answer, exactly as the body search spends its own.
// A refusal that cost nothing would let a player work a hostile town asking every local in it
// until one said yes, which is the farming the reaction curve exists to price.
//
// The civilian is claimed here rather than where the roll resolves, three seconds below. Two
// players can be stood at the same local in co-op, and a flag written only on the way out leaves
// the check above passing for both of them: the same person then answers twice, paying two
// medikits or two intel drops.
_civilian setVariable ["DUWS_civ_closed", true, true];
if ((toUpper _row) isEqualTo "INTEL") then {
    _caller setVariable ["DUWS_civ_intel_asked", true, true];
};

[name _caller, localize _opener] remoteExec ["fnc_duws_dialogue", _caller];

// Held still for the exchange, then released by whichever branch below runs. A civilian who
// walks off mid-sentence reads as a bug rather than as an answer.
_civilian disableAI "PATH";
sleep 3;
_civilian enableAI "PATH";

if (isNull _civilian || isNull _caller) exitWith {};

private _rep = [_civilian getVariable ["civ_locIndex", -1]] call fnc_civ_repAt;
([_rep] call fnc_civ_reaction_weights) params ["_acceptChance", "_bribeChance"];

// One roll walks the three weights in order, so they must sum to 1 or the last branch silently
// absorbs the remainder -- which is what the unit tests pin.
private _roll = random 1;

if (_roll < _acceptChance) exitWith {
    [_civilian, _caller, _row] call fnc_civ_serve;
};

if (_roll < _acceptChance + _bribeChance) exitWith {
    // The offer lives here, not on the client. The prompt's Accept sends only "I accept" -- it
    // names neither the row nor the price -- so a client cannot claim a bribe it was never
    // offered, name its own price, or answer a prompt raised for someone else.
    _civilian setVariable ["DUWS_civ_pending", [_caller, _row, _bribe]];
    [netId _civilian, _bribe] remoteExec ["fnc_civ_bribe_prompt", _caller];
};

[_civilian, _caller, _row] call fnc_civ_close;
