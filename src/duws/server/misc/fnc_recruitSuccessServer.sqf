params ["_target", "_caller", "_civNetId"];
if (!isServer) exitWith {};

if (isNull _target) then {
    _target = objectFromNetId _civNetId;
};
if (isNull _caller) exitWith {};
if (isNull _target || !alive _target) exitWith {
    ["ERROR", "CIV", "Server: target is null or dead"] call fnc_log;
};

// Payment is the caller's business, not this function's. Recruiting through the civilian
// menu is free when the town simply agrees and costs a bribe only when it asks for one, so a
// fixed charge here would bill an accepted request and double-bill a bribed one.

_target setCaptive false;
private _netId = netId _target;
[_netId, false] remoteExec ["fnc_globalSetCaptive", 0];

_target removeAllEventHandlers "Killed";
private _oldGroup = group _target;
while {count (waypoints _oldGroup) > 0} do {
    deleteWaypoint ((waypoints _oldGroup) select 0);
};
[_target] joinSilent (group _caller);
_target allowDamage true;
// Repeated joinSilent calls mirror the original code; kept as-is rather than deduplicated.
[_target] joinSilent (group _caller);
[_target] joinSilent (group _caller);
[_target] joinSilent (group _caller);
[_target] joinSilent (group _caller);
[_target] joinSilent (group _caller);

_target enableAI "PATH";
_target setBehaviour "AWARE";
_target setCombatMode "RED";
_target enableAI "AUTOTARGET";
_target enableAI "TARGET";
_target setUnitPos "AUTO";
[_target] joinSilent (group _caller);

private _weaponPool = [
    ["hgun_PDW2000_F", "30Rnd_9x21_Mag"],
    ["arifle_AKS_F", "30Rnd_545x39_Mag_F"],
    ["SMG_05_F", "30Rnd_9x21_Mag_SMG_02"],
    ["sgun_HunterShotgun_01_F", "2Rnd_12Gauge_Pellets"],
    ["sgun_HunterShotgun_01_sawedoff_F", "2Rnd_12Gauge_Pellets"],
    ["srifle_DMR_06_hunter_F", "10Rnd_762x51_Mag"],
    ["hgun_P07_F", "16Rnd_9x21_Mag"],
    ["hgun_Pistol_01_F", "10Rnd_9x21_Mag"]
];
private _weaponEntry = selectRandom _weaponPool;
private _weapon = _weaponEntry select 0;
private _magazine = _weaponEntry select 1;
[_target] joinSilent (group _caller);

removeAllWeapons _target;
for "_i" from 1 to 3 do {
    _target addMagazineGlobal _magazine;
};
_target addWeapon _weapon;
[_target] joinSilent (group _caller);

[localize "STR_DUWS_T_civ", localize "STR_DUWS_T_RECRUIT_SUCCESS"] remoteExec ["fnc_duws_dialogue", _caller];
[_target] joinSilent (group _caller);
