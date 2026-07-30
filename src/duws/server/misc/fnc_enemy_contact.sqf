// Locality: server -- named by the zone and HQ presence triggers, both created server-local so
// the alert is raised once however the engine treats a global trigger's statement.
//
// A notification rather than a radio line: the dialogue channel is for things somebody says, and a
// contact report the player has to act on was scrolling past under the chatter. Not a hint either
// -- a hint draws beneath an open map, which is exactly where a player checking a contact is.
params ["_place", ["_units", []]];
if (!isServer) exitWith {};

["info", [localize "STR_DUWS_T_enemy_contact_title",
    format [localize "STR_DUWS_T_enemy_contact", _place]]]
    remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated, false];

// One mark per group, on the leader. A squad crossing the wire is one contact, and a mark per
// rifleman is a stack of icons the map cannot be read through. The position is stamped once and
// never updated: this is a sighting, not a tracker, and a mark that followed the enemy around
// would hand the player free reconnaissance for as long as it lived.
private _seen = [];
private _marks = [];
{
    private _grp = group _x;
    if (_grp in _seen) then { continue };
    _seen pushBack _grp;

    private _leader = leader _grp;
    if (isNull _leader || {!alive _leader}) then { continue };

    DUWS_contact_seq = (missionNamespace getVariable ["DUWS_contact_seq", 0]) + 1;
    private _mk = createMarker [format ["DUWS_contact_%1", DUWS_contact_seq], getPos _leader];
    _mk setMarkerType "mil_warning";
    _mk setMarkerColor "ColorRed";
    _mk setMarkerSize [0.8, 0.8];
    _marks pushBack _mk;
} forEach _units;

if (_marks isEqualTo []) exitWith {};

// Five minutes, then gone. A contact mark that outlives its own accuracy is worse than none: the
// enemy has moved and the player is being told where they were.
_marks spawn {
    sleep 300;
    { deleteMarker _x } forEach _this;
};
