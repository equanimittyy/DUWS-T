// Locality: server, [] call'd at load to define both helpers. A tasking remembers its casualties across a
// stream cycle (mirroring the zone garrison ledger, not the hardpoint path that respawns full): re-virtualise
// recomputes effForce from the survivors, so a shot-up group weighs less on the grid and re-spawns weaker.
if (!isServer) exitWith {};

// A live group's firepower, priced as the sighting sweep prices an enemy: each dismounted man 1, each crewed
// vehicle its class power once scaled by (1 - damage), crew never re-counted (a lost crew refills). Alive only:
// a corpse stays in `units` until the mission GC clears it, so counting it would weigh the dead as force.
DUWS_fnc_opcom_effForceLive = {
    params ["_grp"];
    private _seenVeh = [];
    private _fp = 0;
    {
        private _veh = vehicle _x;
        if (_veh isEqualTo _x) then {
            _fp = _fp + 1;
        } else {
            if !(_veh in _seenVeh) then {
                _seenVeh pushBack _veh;
                _fp = _fp + ([typeOf _veh] call DUWS_fnc_classPower) * (1 - damage _veh);
            };
        };
    } forEach ((units _grp) select { alive _x });
    _fp
};

// Bring a freshly spawned group down to a stored strength (0..1): thin the foot squad proportionally (leader
// kept), damage the vehicles. Light by design, and skipped entirely at strength 1, so it bites only on a
// re-spawn after attrition -- an exact composition rebuild is not attempted.
DUWS_fnc_opcom_matchStrength = {
    params ["_grp", "_strength"];
    if (_strength >= 1) exitWith {};
    private _foot = (units _grp) select { vehicle _x isEqualTo _x };
    private _keep = round ((count _foot) * _strength) max 1;
    // Leader first, then delete the tail: sparing an out-of-order leader as an afterthought kept _keep+1.
    private _lead = leader _grp;
    if (_lead in _foot) then { _foot = [_lead] + (_foot - [_lead]) };
    { if (_forEachIndex >= _keep) then { deleteVehicle _x } } forEach _foot;
    private _dmg = (1 - _strength) min 0.85;   // never spawn a pre-wrecked hull
    { if (vehicle _x != _x) then { (vehicle _x) setDamage _dmg } } forEach (units _grp);
};
