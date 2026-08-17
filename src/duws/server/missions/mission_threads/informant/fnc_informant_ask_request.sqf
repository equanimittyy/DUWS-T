// Locality: server -- the "Ask about informant" action remoteExecs it here. Standalone: it owns the
// roll and the accepted ping, and only borrows the shared bribe popup for the bribe branch
// (the popup's answer runs back through fnc_civ_bribe_answer -> fnc_civ_serve, which is why an
// INFORMANT case lives in fnc_civ_serve / fnc_civ_rowPrice).
//
// One answer per civilian, spent on the attempt whatever it returns -- the same shape the civilian
// menu uses -- so the crowd cannot be worked local by local until one talks.
if (!isServer) exitWith {};
params ["_civilian", "_caller"];
if (isNull _civilian || isNull _caller || !alive _civilian) exitWith {};
if (_caller distance _civilian > 3) exitWith {};
if (_civilian getVariable ["DUWS_informant_asked", false]) exitWith {};
// No live hunt -> nothing to ask about.
if (isNull (missionNamespace getVariable ["DUWS_informant_unit", objNull])) exitWith {};

// Claimed before the roll and broadcast, so two players at the same civilian in co-op cannot both
// spend it.
_civilian setVariable ["DUWS_informant_asked", true, true];

// Flat 60 reveal / 10 bribe / 30 refuse, not the civ menu's rep curve: a hunt sits in one town and
// its locals answer the same regardless of standing -- a town hostile enough to shift the odds never
// offers the ask in the first place. 0.70 is the reveal+bribe cutoff, so the last 30 % refuses.
private _roll = random 1;

if (_roll < 0.60) exitWith {
    [_civilian, _caller] call fnc_informant_ask_reveal;
    [_civilian] call fnc_civ_resume;
};

if (_roll < 0.70) exitWith {
    // The offer lives on the server: the popup sends back only yes/no, and fnc_civ_bribe_answer reads
    // the row and price off DUWS_civ_pending, so the client never names either.
    private _price = ["INFORMANT"] call fnc_civ_rowPrice;
    _civilian setVariable ["DUWS_civ_pending", [_caller, "INFORMANT", _price]];
    [netId _civilian, _price] remoteExec ["fnc_civ_bribe_prompt", _caller];
};

[_civilian, _caller, "INFORMANT"] call fnc_civ_close;
