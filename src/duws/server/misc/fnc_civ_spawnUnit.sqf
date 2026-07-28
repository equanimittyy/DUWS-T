// Locality: server -- creates the unit; the interaction actions it broadcasts run on clients.
/*
    fnc_civ_spawnUnit.sqf
    Creates one civilian for a town, wired for interaction, reputation and recycling.
    Params: [_locIndex, _pos, _unitType, _isZombie]. Returns the unit, or objNull.
*/
if (!isServer) exitWith { objNull };
params ["_locIndex", "_pos", "_unitType", ["_isZombie", false]];

private _group = createGroup [CIVILIAN, true];
private _unit = _group createUnit [_unitType, _pos, [], 0, "NONE"];
if (isNull _unit) exitWith {
    deleteGroup _group;
    ["ERROR", "CIV", format ["Could not create %1 for location %2", _unitType, _locIndex]] call fnc_log;
    objNull
};

// Every other civilian pass keys on this tag: the recycle tick, the reputation handler and town
// cleanup all find their units through it. Recruitment clears it, which is how a recruited
// civilian leaves the system without any pass needing an exemption for it.
_unit setVariable ["civ_locIndex", _locIndex];
[_unit] call fnc_addCivilianMoney;
[_unit, _isZombie, _unitType, 0] call fnc_applyEquipment;
_unit addEventHandler ["Killed", missionNamespace getVariable "CIV_KILLED_HANDLER"];
_unit addEventHandler ["HandleHeal", fnc_civ_healed];

// The unit as the JIP id throughout, never `true`: a recycled town creates and deletes civilians
// for the whole campaign, and an auto-generated id would leave one queued message per unit for
// every client that ever joins.
if (CIV_PRESENCE == "RAVAGE") then {
    if (_isZombie) then {
        [_unit, 2.2] remoteExec ["setAnimSpeedCoef", 0, _unit];
    } else {
        [_unit] remoteExec ["fnc_addRecruitAction", 0, _unit];
    };
} else {
    if (side _unit == CIVILIAN) then {
        [_unit] remoteExec ["fnc_civ_clientActions", 0, _unit];
    };
};

_unit
