// Locality: server -- creates the unit; the interaction actions it broadcasts run on clients.
/*
    Creates one civilian for a town, wired for interaction, reputation and recycling.
    Params: [_locIndex, _pos, _unitType, _isZombie, _isVendor]. Returns the unit, or objNull.

    A vendor is a civilian in everything the town weighs -- the locIndex tag and the reputation
    handler below are the same -- and neither of the two things a passer-by gets: see each skip.
*/
if (!isServer) exitWith { objNull };
params ["_locIndex", "_pos", "_unitType", ["_isZombie", false], ["_isVendor", false]];

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
//
// So are vendors. A panicking civilian runs 200 m and stays calm-locked for a minute, which for a
// shopkeeper means abandoning the shop -- and the fixed building is the whole point of the placement.
// fnc_civ_panic refuses them as well, because its alarm sweep reaches civilians that never heard the shot.
if (!_isZombie && !_isVendor) then {
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
        // A vendor answers none of the civilian pair -- fnc_civ_menuAction's talk/intel/arrest/recruit
        // menu and fnc_civ_stopCommand's call-over -- so it carries its own one action and nothing else.
        private _fn = ["fnc_civ_clientActions", "fnc_vendor_menuAction"] select _isVendor;
        [_unit] remoteExec [_fn, 0, _unit];
    };
};

_unit
