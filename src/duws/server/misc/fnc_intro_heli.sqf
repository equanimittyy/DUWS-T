
if (!isServer) exitWith {};

// Released on every exit below, not only the successful one. Clients hold the map open until the
// insertion flight is up or this says it is not coming, and the drop-in teleport is gated on it too
// -- so an intro that gives up silently leaves every player parked on the map screen.
private _abandon = {
    params ["_why"];
    ["ERROR", "INTRO", format ["Intro abandoned: %1. Releasing clients.", _why]] call fnc_log;
    missionNamespace setVariable ["intro_heli_done", true, true];
    publicVariable "intro_heli_done";
};

if (!isNil "intro_heli_executed") exitWith { ["WARN", "INTRO", "Already executed, skipping."] call fnc_log; };
missionNamespace setVariable ["intro_heli_executed", true, true];

// Publishing done with nobody boarded routes every client through client_init's
// intro_completed==false fallback, which teleports them to base.
if (missionNamespace getVariable ["DUWS_debug_skip_intro", false]) exitWith {
    ["INFO", "INTRO", "Debug quickstart: skipping insertion flight."] call fnc_log;
    missionNamespace setVariable ["intro_heli_done", true, true];
    publicVariable "intro_heli_done";
};

// Late joiners are placed by the client, not here: client_init waits on intro_heli_done and
// teleports any player whose intro_completed is false. That path also clears the black screen,
// which the server never did.

waitUntil { sleep 0.5; count allPlayers > 0 };

private _hqPos = missionNamespace getVariable ["PosOfBLUHQ", []];
if (_hqPos isEqualTo []) exitWith { ["PosOfBLUHQ not defined"] call _abandon; };

private _spawnPos = [_hqPos, 1000, 700, 10, 0.2, []] call fnc_safe_pos;
if (_spawnPos isEqualTo []) then {
    private _angle = random 360;
    private _dist = 250 + random 50;
    _spawnPos = _hqPos getPos [_dist, _angle];
    ["WARN", "INTRO", format ["Using fallback spawn position: %1", _spawnPos]] call fnc_log;
};
_spawnPos set [2, 50];

// Coerced to a single classname: a role global may hold the pool AutoDetect built for the key
// rather than one class, and BIS_fnc_spawnVehicle takes a string -- handed an array it returns a
// null vehicle and an empty group, with no error of its own. The vanilla default covers a key that
// resolved to nothing at all, which no faction file guarantees against.
private _heliType = missionNamespace getVariable ["blufor_TRANS_HELI_X", ""];
if (_heliType isEqualType []) then { _heliType = _heliType param [0, ""]; };
if (_heliType isEqualTo "") then { _heliType = "B_Heli_Transport_01_F"; };

private _veh = [_spawnPos, 0, _heliType, WEST] call BIS_fnc_spawnVehicle;
private _heli = _veh select 0;
private _heliGroup = _veh select 2;

// Checked rather than assumed: a classname this faction does not ship leaves _heli null, and every
// line below it then works on nothing -- the flight never arrives, and the clients waiting on it
// sit on the map screen while the intro talks over them.
if (isNull _heli) exitWith {
    [format ["%1 did not spawn", _heliType]] call _abandon;
};

_heliGroup deleteGroupWhenEmpty true;
["INFO", "INTRO", format ["Helicopter spawned: %1, group ID: %2", _heliType, groupId _heliGroup]] call fnc_log;

private _pilot = driver _heli;
if (isNull _pilot) then {
    private _driverGroup = createGroup WEST;
    _pilot = _driverGroup createUnit [blufor_SOLDIER_X, [0,0,0], [], 0, "NONE"];
    _pilot moveInDriver _heli;
    _pilot joinSilent _heliGroup;
    deleteGroup _driverGroup;
};

_heli allowDamage false;
_heli setVehicleAmmo 0;
_heli engineOn true;
_heli flyInHeight 50;

_pilot allowDamage false;
_pilot setCaptive true;
_pilot disableAI "TARGET";
_pilot disableAI "AUTOTARGET";
_pilot disableAI "AUTOCOMBAT";
_pilot setBehaviour "CARELESS";
_pilot allowFleeing 0;

{ _x setVariable ["Vcm_Disable", true] } forEach units _heliGroup;

missionNamespace setVariable ["intro_heli_object", _heli, true];
private _players = call BIS_fnc_listPlayers;
private _boardedPlayers = [];
private _unboardedPlayers = [];

private _cargoSeats = _heli emptyPositions "cargo";
private _gunnerSeats = _heli emptyPositions "gunner";
private _commanderSeats = _heli emptyPositions "commander";
private _availableSeats = _cargoSeats + _gunnerSeats + _commanderSeats;

{
    if (count _boardedPlayers < _availableSeats) then {
        private _seatType = "";
        if (_cargoSeats > 0) then {
            _seatType = "cargo";
            _cargoSeats = _cargoSeats - 1;
        } else {
            if (_gunnerSeats > 0) then {
                _seatType = "gunner";
                _gunnerSeats = _gunnerSeats - 1;
            } else {
                if (_commanderSeats > 0) then {
                    _seatType = "commander";
                    _commanderSeats = _commanderSeats - 1;
                };
            };
        };
        if (_seatType != "") then {
            [netId _heli, _seatType, _x] remoteExec ["fnc_remoteBoard", _x];
            _boardedPlayers pushBack _x;
        } else {
            _unboardedPlayers pushBack _x;
        };
    } else {
        _unboardedPlayers pushBack _x;
    };
} forEach _players;

// Wait for clients to finish boarding.
sleep 5;
["INFO", "INTRO", format ["Boarded players: %1, Unboarded: %2", count _boardedPlayers, count _unboardedPlayers]] call fnc_log;

missionNamespace setVariable ["intro_heli_fadein", true, true];
[["", "BLACK IN", 1]] remoteExec ["titleCut", 0];
// The insertion flight is one of only two places music plays; the other is a side mission opening.
// Kept to events, never a loop running underneath the whole campaign, so music reads as an event
// rather than weather. Double brackets for the same reason as the titleText below.
[["LeadTrack01_F_EPA", 0]] remoteExec ["playMusic", 0];
[] spawn fnc_bottom_right_message;
sleep 0.5;
private _hoverPos = _hqPos getPos [20, random 360];
_hoverPos set [2, 50];
// Init before the waypoint, never after: the heli covers the 700-1000 m to the hover point in
// ~10-14 s, well inside the dialogue block below, so the completion statement fires the flag early.
// A reset placed after the waypoint stomps that true, and a completed MOVE waypoint never re-fires
// -- the arrival waitUntil would then only ever exit on the 120 s timeout.
missionNamespace setVariable ["intro_heli_arrived", false];
private _wp = _heliGroup addWaypoint [_hoverPos, 0];
_wp setWaypointType "MOVE";
_wp setWaypointBehaviour "CARELESS";
_wp setWaypointSpeed "FULL";
_wp setWaypointCompletionRadius 30;
_wp setWaypointStatements ["true", "missionNamespace setVariable ['intro_heli_arrived', true, true];"];

// The body says "Knight 1-5 to HQ" under a "Pilot" slot on purpose: the insertion flight has
// its own callsign, but the player is in the cabin hearing a person rather than on the net
// hearing a callsign. Do not reconcile the two -- it is intro flavour, not an attribution bug.
[localize "STR_DUWS_T_pilot_intro", localize "STR_DUWS_T_heli_moving"] remoteExec ["fnc_duws_dialogue", 0];
sleep 1;
// Held 3 s -- half the KillaTomata memorial card below.
[["5U5 and equanimity presents...", "PLAIN", 1]] remoteExec ["titleText", 0];
sleep 3;
[2] remoteExec ["titleFadeOut", 0];
sleep 2;
[["DUWST", "PLAIN", 0, true]] remoteExec ["cutRsc", 0];
sleep 8;
// Double brackets: remoteExec hands the command an argument list, so a unary command whose one
// argument is itself an array needs the outer pair. Written flat, titleText is passed the string
// alone and throws on the type -- which is the memorial card silently not displaying at all.
[["In memory of KillaTomata, the creator of the original DUWS_X.", "PLAIN", 1]] remoteExec ["titleText", 0];
sleep 6;
// titleFadeOut, not an empty titleText: the speed argument times the *new* card fading in, so an
// empty one replaces the memorial the instant it is issued and the card snaps off screen.
[2] remoteExec ["titleFadeOut", 0];
sleep 3;
[["", "PLAIN", 5]] remoteExec ["cutText", 0];
[localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_heli_ttgtw"] remoteExec ["fnc_duws_dialogue", 0];
private _arrivedVar = "intro_heli_arrived";
private _startTime = time;
private _timeout = 120;

waitUntil {
    sleep 0.5;
    private _arrived = missionNamespace getVariable [_arrivedVar, false];
    private _timeoutReached = (time - _startTime) > _timeout;
    if (_timeoutReached) then {
        ["WARN", "INTRO", format ["Helicopter waypoint timeout after %1 seconds, forcing arrival.", _timeout]] call fnc_log;
        missionNamespace setVariable [_arrivedVar, true];
    };
    _arrived || !alive _heli || _timeoutReached
};

[localize "STR_DUWS_T_pilot_intro", localize "STR_DUWS_T_heli_inpos"] remoteExec ["fnc_duws_dialogue", 0];
sleep 3;

// Catch players who joined while the script ran -- they missed the boarding assignment.
private _allPlayersNow = call BIS_fnc_listPlayers;
private _processedPlayers = _boardedPlayers + _unboardedPlayers;
{
    if (!(_x in _processedPlayers) && !(_x getVariable ["intro_completed", false])) then {
        _unboardedPlayers pushBack _x;
    };
} forEach _allPlayersNow;

private _heliPos2D = getPos _heli;
private _groundPosASL = [(_heliPos2D select 0), (_heliPos2D select 1), getTerrainHeightASL [_heliPos2D select 0, _heliPos2D select 1]];

// The whole stick ropes at once, not one player after another: serialised on the server, a
// player's black screen would only begin once the player before them was on the ground -- about
// 13.5 s each, most of a minute of nothing for the last man of a four.
private _dropThreads = [];
private _dropping = (_boardedPlayers apply {[_x, true]}) + (_unboardedPlayers apply {[_x, false]});
{
    _x params ["_dropPlayer", "_wasBoarded"];
    _dropThreads pushBack ([_dropPlayer, _wasBoarded, _groundPosASL, _forEachIndex, count _dropping] spawn {
        params ["_player", "_wasBoarded", "_groundPosASL", "_index", "_total"];

        // Boarded players get the black screen and rope SFX; unboarded just wait the same beat.
        if (_wasBoarded) then {
            [["", "BLACK OUT", 1.5]] remoteExec ["titleCut", _player];
            sleep 3;
            "rappel" remoteExec ["playSound", _player];
            sleep 10;
        } else {
            sleep 3;
        };

        moveOut _player;
        sleep 0.5;

        // Fanned around the rope point rather than dropped onto it: the serial version arrived
        // 13 s apart and could share one spot, but a stick landing together ends up inside one
        // another, which the engine resolves by shoving them apart. Sized for a full cabin --
        // the ring holds a fixed radius, so the more players it seats the tighter the spacing.
        private _ringRadius = 10;
        private _angle = 360 * _index / _total;
        private _landing = [(_groundPosASL select 0) + (sin _angle) * _ringRadius, (_groundPosASL select 1) + (cos _angle) * _ringRadius, 0];
        _landing set [2, getTerrainHeightASL [_landing select 0, _landing select 1]];
        _player setPosASL _landing;
        _player setVariable ["intro_completed", true, true];

        [["", "BLACK IN", 1]] remoteExec ["titleCut", _player];
        [localize "STR_DUWS_T_actionteam", ([localize "STR_DUWS_T_ground_reached"] call fnc_cs)] remoteExec ["fnc_duws_dialogue", _player];
    });
} forEach _dropping;

// Held until the last man is down: the flyaway below moves the helicopter off the point every
// one of these threads is placing a player on.
waitUntil {sleep 0.5; (_dropThreads findIf {!scriptDone _x}) isEqualTo -1};

missionNamespace setVariable ["intro_heli_done", true, true];
publicVariable "intro_heli_done";

// Flyaway issued before the Overlord lines, so the aircraft leaves as the stick lands, not after the whole exchange.
sleep 2;
_heli flyInHeight 100;
private _flyAwayPos = _hqPos getPos [15000, random 360];
_flyAwayPos set [2, 100];
private _wp2 = _heliGroup addWaypoint [_flyAwayPos, 0];
_wp2 setWaypointType "MOVE";
_wp2 setWaypointBehaviour "CARELESS";

sleep 4;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_heli_roger"] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_vzjqx5tp"] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_heli_money"] remoteExec ["fnc_duws_dialogue", 0];

// Despawn on distance plus a hard cap, like the helo taxi -- never on the flyaway waypoint
// completing. The exit point is 15 km out and routinely off-map, so the group can orbit the
// boundary indefinitely and a completion-gated wait would leave the heli parked over the base.
private _leaveStart = time;
waitUntil {
    sleep 1;
    (_heli distance2D _hqPos > 2000) || !alive _heli || (time - _leaveStart) > 180
};
if (alive _heli && {_heli distance2D _hqPos < 2000}) then {
    ["WARN", "INTRO", "Helicopter never cleared the base; deleting on timeout."] call fnc_log;
};

sleep 30;
{ deleteVehicle _x } forEach units _heliGroup;
deleteVehicle _heli;
["INFO", "INTRO", "Helicopter and crew deleted."] call fnc_log;
