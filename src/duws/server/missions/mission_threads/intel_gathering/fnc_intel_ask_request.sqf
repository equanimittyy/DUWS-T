// Locality: server -- the "Ask about informant" action remoteExecs it here. Standalone: it owns the
// reputation roll and the accepted ping, and only borrows the shared bribe popup for the bribe branch
// (the popup's answer runs back through fnc_civ_bribe_answer -> fnc_civ_serve, which is why an
// INFORMANT case lives in fnc_civ_serve / fnc_civ_rowPrice).
//
// One answer per civilian, spent on the attempt whatever it returns -- the same shape the civilian
// menu uses -- so a hostile town cannot be worked local by local until one talks for free.
if (!isServer) exitWith {};
params ["_civilian", "_caller"];
if (isNull _civilian || isNull _caller || !alive _civilian) exitWith {};
if (_caller distance _civilian > 3) exitWith {};
if (_civilian getVariable ["DUWS_intel_asked", false]) exitWith {};
// No live hunt -> nothing to ask about.
if (isNull (missionNamespace getVariable ["DUWS_intel_informant", objNull])) exitWith {};

// Claimed before the roll and broadcast, so two players at the same civilian in co-op cannot both
// spend it.
_civilian setVariable ["DUWS_intel_asked", true, true];

private _rep = [_civilian getVariable ["civ_locIndex", -1]] call fnc_civ_repAt;
([_rep] call fnc_civ_reaction_weights) params ["_accept", "_bribe"];
private _roll = random 1;

if (_roll < _accept) exitWith {
    [_civilian, _caller] call fnc_intel_ask_reveal;
    [_civilian] call fnc_civ_resume;
};

if (_roll < _accept + _bribe) exitWith {
    // The offer lives on the server: the popup sends back only yes/no, and fnc_civ_bribe_answer reads
    // the row and price off DUWS_civ_pending, so the client never names either.
    private _price = ["INFORMANT"] call fnc_civ_rowPrice;
    _civilian setVariable ["DUWS_civ_pending", [_caller, "INFORMANT", _price]];
    [netId _civilian, _price] remoteExec ["fnc_civ_bribe_prompt", _caller];
};

[_civilian, _caller, "INFORMANT"] call fnc_civ_close;
