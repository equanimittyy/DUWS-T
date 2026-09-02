// Locality: server -- creates the unit; the interaction actions it broadcasts run on clients.
/*
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
// Read by the waypoint pass and by the panic sweep, both of which have to tell the living from
// the undead long after the flag that decided it has gone out of scope.
_unit setVariable ["civ_isZombie", _isZombie];
// Defined by the RAVAGE handler and meaningful only there: salvaged military kit is what tells
// that mode's crowd from a living one. Gated here rather than inside the function, because the
// plain path no longer defines it at all and calling a nil throws.
if (CIV_PRESENCE == "RAVAGE") then { [_unit, _isZombie, _unitType, 0] call fnc_applyEquipment };
_unit addEventHandler ["Killed", missionNamespace getVariable "CIV_KILLED_HANDLER"];
_unit addEventHandler ["HandleHeal", fnc_civ_healed];

// Added on the server alone, so this is the only copy of the handler that exists. Zombies are
// left out: a crowd of undead scattering from gunfire is not what the mode spawns them for.
if (!_isZombie) then {
    _unit addEventHandler ["FiredNear", {
        params ["_unit", "_firer"];
        [_unit, _firer] call fnc_civ_panic;
    }];
};

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
