// Locality: server. The body is base-game FIA so no Bandits setting can field a DLC unit. The caller
// gives orders and claims the group for teardown.
//
// Contract: [_pos, _roles] -> _group (grpNull when nothing spawns)
//   _roles  one man per token: rifleman|autogunner|grenadier|at|medic.
if (!isServer) exitWith { grpNull };
params ["_pos", "_roles"];

private _specs = createHashMapFromArray [
    ["rifleman",   ["vest", "assault_rifle"]],
    ["autogunner", ["vest", "machinegun"]],
    ["grenadier",  ["vest", "grenadier"]],
    ["at",         ["vest", ["submachinegun", "assault_rifle"], "launcher"]],
    ["medic",      ["vest", ["submachinegun", "assault_rifle"], "medic"]]
];

private _known = _roles select { _x in _specs };
if (count _known < count _roles) then {
    ["WARN", "BANDIT", format ["unknown bandit roles skipped: %1", _roles - _known]] call fnc_log;
};
private _looks = missionNamespace getVariable ["DUWS_banditLooks", []];
if (_known isEqualTo [] || {_looks isEqualTo []}) exitWith { grpNull };

private _group = [_pos, INDEPENDENT, _known apply { "I_G_Soldier_F" }, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;

{
    // Each slot draws its own source, so an outfit mixes factions the way scavenged clothes would.
    private _uniform = selectRandom ((selectRandom _looks) select 0);
    private _hat = selectRandom ((selectRandom _looks) select 1);
    _x setUnitLoadout [[], [], [], [_uniform, []], [], [], _hat, goggles _x, [],
        ["ItemMap", "", "ItemRadio", "ItemCompass", "ItemWatch", ""]];
    [[_x], "IND", ["opfor", "blufor"], _specs get (_known select _forEachIndex), [false]] call fnc_civ_arm;
} forEach units _group;

_group
