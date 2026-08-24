// Locality: server -- the "Ask about informant" action remoteExecs it here. Standalone: it owns the
// roll and the accepted ping.
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

// The informant never fingers himself. Asked, he answers like a local with nothing -- the ask is
// spent above and greys out, so he reads no different from the third who refuse. Guarded before the
// roll: he never reaches the reveal or bribe that would sell his own position.
if (_civilian isEqualTo (missionNamespace getVariable ["DUWS_informant_unit", objNull])) exitWith {
    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_INTEL_INFORMANT_ASK_MISS"] remoteExec ["fnc_duws_dialogue", _caller];
};

// Flat 80 reveal / 20 refuse, not the civ menu's rep curve: a hunt sits in one town, its locals
// answer the same regardless of standing, and a town hostile enough to shift odds never offers it.
private _roll = random 1;

if (_roll < 0.80) exitWith {
    [_civilian, _caller] call fnc_informant_ask_reveal;
    [_civilian] call fnc_civ_resume;
};

[_civilian, _caller, "INFORMANT"] call fnc_civ_close;
