// Locality: server -- the "Ask around" action remoteExecs it here. Owns the roll and the accepted tip.
//
// One answer per local, spent on the attempt whatever it returns (the civilian-menu shape), so the crowd
// cannot be worked person by person until one talks. Flat 80/20, not the rep curve: the raid sits in one
// town whose locals all know the same rumour, and a town hostile enough to shift the odds never offers it.
if (!isServer) exitWith {};
params ["_civilian", "_caller"];
if (isNull _civilian || isNull _caller || !alive _civilian) exitWith {};
if (_caller distance _civilian > 3) exitWith {};
if (_civilian getVariable ["DUWS_safehouse_asked", false]) exitWith {};
if (!(missionNamespace getVariable ["DUWS_safehouse_active", false])) exitWith {};

// Claimed before the roll and broadcast, so two players at one local in co-op cannot both spend it.
_civilian setVariable ["DUWS_safehouse_asked", true, true];

if (random 1 < 0.80) exitWith {
    [_civilian, _caller] call fnc_raid_safehouse_ask_reveal;
    [_civilian] call fnc_civ_resume;
};

[_civilian, _caller, "SAFEHOUSE"] call fnc_civ_close;
