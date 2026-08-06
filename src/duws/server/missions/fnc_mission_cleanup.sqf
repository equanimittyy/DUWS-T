// Locality: server -- called by mission threads only, all server-side.
/*
    Tears a finished side mission down: hands its composition to the map cleanup, then, once the
    player has had time to leave, deletes what the mission raised.

    Reached through fnc_mission_end, which owns the rest of a thread's exit and takes the same
    arguments; call it directly only for a teardown that is not a mission ending.

    _compKey        composition to release, or "" for a mission that owns no built objects.
    _sweepFriendly  also delete BLUFOR-configured leftovers in the radius pass. Off by default: most
                    missions spawn nothing on that side, and that pass is a blunt proximity delete.
    _token          which mission instance this is tearing down, from fnc_mission_begin.

    Two passes. The ownership pass finishes the job: map-wide, deleting exactly what fnc_mission_claim
    filed under this mission, so a guard ring that patrolled a kilometre out is still collected. The
    radius pass is the backstop for anything raised without a claim, and is blunt -- proximity cannot
    tell a mission's leftovers from a neighbouring garrison, which is why it stands down near an enemy
    zone.
*/

params ["_targetpos", "_radius", ["_compKey", ""], ["_sweepFriendly", false], ["_token", -1]];
["INFO", "MISSION", format ["cleanup queued for %1 within %2 m, composition %3, token %4",
    _targetpos, _radius, ["none", _compKey] select (_compKey != ""), _token]] call fnc_log;

// Released before the countdown, not after it: release only drops the protection and sets a
// deadline, so the map sweep still holds these inside its keep-radius. Waiting out the countdown
// here as well would put the objective's own props on a different clock to everything else the
// player leaves behind.
if (_compKey != "") then { [_compKey] call fnc_duws_release };

// Five minutes to strip the area, warned at the last minute. Two notices: a countdown only needs
// its start and its edge, and the ten-second call this replaces was too late to act on.
["missionclean", [localize "STR_DUWS_T_missioncleanup", localize "STR_DUWS_T_missioncleanup2"]]
    remoteExec ['BIS_fnc_showNotification', [0,-2] select isDedicated, false];
sleep 240;
["missionclean", [localize "STR_DUWS_T_missioncleanup", localize "STR_DUWS_T_missioncleanup4"]]
    remoteExec ['BIS_fnc_showNotification', [0,-2] select isDedicated, false];
sleep 60;

// Map-wide, and held back this far on purpose: bodies at the objective carry the intel several
// missions point the player at, so the sweep must not run until the countdown has finished.
{deleteVehicle _x} forEach allDeadMen;

// Crew before their vehicle, or deleting the vehicle first ejects whoever is inside it. A claimed
// vehicle goes whether or not it still has crew.
if (_token >= 0) then {
    private _owned = (allUnits + vehicles) select {_x getVariable ["DUWS_missionOwner", -1] == _token};
    {
        if (_x isKindOf "CAManBase") then { deleteVehicle _x };
    } forEach _owned;
    {
        if (!(_x isKindOf "CAManBase") && {!isNull _x}) then {
            deleteVehicleCrew _x;
            deleteVehicle _x;
        };
    } forEach _owned;
    ["INFO", "MISSION", format ["token %1: %2 claimed entities deleted", _token, count _owned]] call fnc_log;
};

_close = false;
{
    if ((_targetpos distance _x) < (zones_max_radius * 1.2)) exitWith {_close = true};
} forEach WARCOM_zones_controled_by_OPFOR;

private _zombieClasses = ["zombie_runner", "zombie_bolter", "zombie_walker"];

if (_close == false) then {
    _missObj = _targetpos nearObjects (_radius * 1.2);

    // Everything any site currently owns, built once for this teardown. A side mission lands where
    // it lands, and one drawn on a town disc used to delete that town's garrison on the way out --
    // the town then measured its survivors against its baseline, recorded a mauling nobody
    // inflicted, and returned thinned every visit after.
    //
    // Read from the site store rather than from a flag stamped on each unit. The flag was a second
    // record of the same fact, kept in step by hand at every spawner, and a spawner that forgot it
    // failed silently a campaign later. Vehicles ride along with their crew: deleting a transport
    // takes its occupants regardless of who owns them.
    private _siteOwned = [];
    {
        private _key = _x;
        {
            private _r = [_key, _x get "kind"] call fnc_site_roster;
            _siteOwned append _r;
            { if (vehicle _x != _x) then { _siteOwned pushBackUnique (vehicle _x) } } forEach _r;
        } forEach (DUWS_occupants getOrDefault [_key, []]);
    } forEach DUWS_sites;

    private _protected = [];
    {
        private _player = _x;
        _protected pushBackUnique _player;
        {
            _protected pushBackUnique _x;
            private _veh = vehicle _x;
            if (_veh != _x) then { _protected pushBackUnique _veh };
        } forEach (units group _player);
        private _veh = vehicle _player;
        if (_veh != _player) then { _protected pushBackUnique _veh };
    } forEach allPlayers;

    {
        // WBK dresses its friendly civilians as WEST, so that side is spared whatever the
        // caller asked for -- _sweepFriendly exists to collect a mission's own BLUFOR-configured
        // emplacements, and it must not become a licence to delete the townspeople.
        private _sparedSide = (side _x == CIVILIAN)
            || {side _x == WEST && {!_sweepFriendly || CIV_PRESENCE == "WBK"}}
            || {side _x == INDEPENDENT && CIV_PRESENCE == "WBK"};

        // The persistent flag outranks proximity. This is a blunt radius delete, and a side
        // mission drawn near a player FOB or the HQ puts their buildings inside it -- without
        // this the teardown would take a standing composition apart on its way past.
        //
        // The site set above is the same rule for men rather than buildings, and a mission never
        // raises a unit any site owns, so this needs no owner test.
        if (!(_x in _protected)
            && !(_x getVariable ["persistent", false])
            && !(_x in _siteOwned)
            && !_sparedSide
            && !(typeOf _x in _zombieClasses)) then {
            deleteVehicleCrew _x;
            deleteVehicle _x;
        };
    } forEach _missObj;
};
