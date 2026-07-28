// Locality: server. The reprisal roll that closes an arrest: half the time the civilian was
// carrying something and turns on whoever searched them.
//
// This is the cost that makes arrest a decision rather than a free frisk, so it runs on the
// server -- a coin flip a client owns is a coin flip a client can retry.
if (!isServer) exitWith {};

params ["_unit", "_caller"];

sleep 5;

if (isNull _unit || !alive _unit) exitWith {};
if (random 1 >= 0.5) exitWith {};

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
(selectRandom _weaponPool) params ["_weapon", "_mag"];

// Out of the surrender animation on every machine, not just this one.
[_unit, ""] remoteExec ["switchMove", 0];

private _oldGroup = group _unit;
private _newGroup = createGroup resistance;
[_unit] joinSilent _newGroup;
if (!isNull _oldGroup && {count units _oldGroup == 0}) then { deleteGroup _oldGroup; };

removeAllWeapons _unit;
for "_i" from 1 to 3 do { _unit addMagazineGlobal _mag; };
_unit addWeapon _weapon;

_unit setBehaviour "COMBAT";
_unit setCombatMode "RED";
// Released here: fnc_civ_arrest leaves PATH disabled through the surrender, so this is what puts
// them back on their feet.
_unit enableAI "PATH";
_unit reveal [_caller, 4];
_unit doWatch _caller;
_unit doTarget _caller;

[localize "STR_DUWS_T_civ", localize "STR_DUWS_T_LOOT_REVENGE"] remoteExec ["fnc_duws_dialogue", 0];
[localize "STR_DUWS_T_LOOT_REVENGE_HINT"] remoteExec ["hint", 0];
sleep 2;
_unit commandFire _caller;
