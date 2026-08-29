// Locality: client; the map-click body below runs on the machine that triggers it, not
// here (passed as an addAction function value in client/supports/fnc_helolift.sqf:427).

params ["_target", "_caller", "_actionId", "_arguments"];

// The map-click slot is the thing actually being contended, so this takes the shared claim rather
// than a private lock: a per-machine lock written as a player mutex never broadcasts its owner, and
// a diag_tickTime timeout is not restored across a savegame -- a campaign loaded after the stamp
// was taken sees the lock as either permanently held or permanently free.
private _liftClickHandler = "player setVariable ['LIFT_TMPPOS', _pos]; player setVariable ['LIFT_CLICKED', true];";
if (!(["LIFT", _liftClickHandler] call fnc_mapclick_claim)) exitWith {};

private _timer = 3000;                     // timeout counter (5 min = 3000 * 0.1s)
private _waypoints = [];
private _markers = [];
private _clickPos = [];
private _safePos = [];
private _markerName = "";
private _marker = "";

if (isNil {player getVariable "LiftTakeOff"}) then {player setVariable ["LiftTakeOff", false]};
if (isNil {player getVariable "LiftWaypoints"}) then {player setVariable ["LiftWaypoints", []]};
if (isNil {player getVariable "LiftWaypointMarkers"}) then {player setVariable ["LiftWaypointMarkers", []]};

openMap true;
// Drawn on the map rather than hinted: the map is force-open for this whole routine, and
// the hint box renders beneath it.
[localize "STR_DUWS_T_liftwp_brief"] call fnc_map_prompt;

while {_timer > 0 && count _waypoints < 3} do {
    if (!visibleMap) then {
        openMap true;
    };

    // Re-claiming as the current holder, which the slot allows: each waypoint reinstalls the
    // same handler.
    ["LIFT", _liftClickHandler] call fnc_mapclick_claim;

    waitUntil {
        sleep 0.1;
        if (!visibleMap) then {
            openMap true;
        };
        player getVariable ["LIFT_CLICKED", false]
    };

    _clickPos = player getVariable ["LIFT_TMPPOS", []];
    player setVariable ["LIFT_TMPPOS", nil];
    player setVariable ["LIFT_CLICKED", false];

    // check the click is on flat, reachable ground
    _safePos = [_clickPos, 0, 50, 5, 0, 0.2, 0, [], [_clickPos, _clickPos]] call BIS_fnc_findSafePos;
    if (_safePos isEqualTo [0,0]) then {
    } else {
        _waypoints pushBack _safePos;

        // Same marker convention as the helo taxi: yellow objective icons for the route
        // legs, a green end icon for the destination. The two supports draw on the same
        // map and a player should not have to learn two symbol sets.
        _markerName = format ["liftwp_%1_%2_%3", _myUID, floor random 10000, count _waypoints];
        _marker = createMarker [_markerName, _safePos];
        if ((count _waypoints) == 3) then {
            _marker setMarkerType "hd_end";
            _marker setMarkerColor "ColorGreen";
            _marker setMarkerText localize "STR_DUWS_T_liftwp_drop";
        } else {
            _marker setMarkerType "hd_objective";
            _marker setMarkerColor "ColorYellow";
            _marker setMarkerText format [localize "STR_DUWS_T_liftwp_leg", count _waypoints];
        };
        _markers pushBack _marker;

        // Per-leg confirmation, as the taxi picker gives.
        if ((count _waypoints) < 3) then {
            [localize ([
                "STR_DUWS_T_liftwp1marked", "STR_DUWS_T_liftwp2marked"
            ] select ((count _waypoints) - 1))] call fnc_map_prompt;
        };
    };

    _timer = _timer - 1;
    sleep 1.0;
};

player setVariable ["LiftWaypoints", _waypoints];

if (count _waypoints == 3) then {
    // all three chosen: hand the marker array to the main script to clear after release
    player setVariable ["LiftWaypointMarkers", _markers];
} else {
    // incomplete (timed out): delete the markers now
    { deleteMarker _x } forEach _markers;
    player setVariable ["LiftWaypointMarkers", []];
};

player setVariable ["LiftTakeOff", true];

openMap false;

// The pilot's verdict, spoken once the map is closed and the route committed.
if (count _waypoints == 3) then {
    [localize "STR_DUWS_T_crane", localize "STR_DUWS_T_liftwp_set"] remoteExec ["fnc_duws_dialogue", 0];
} else {
    [localize "STR_DUWS_T_crane", localize "STR_DUWS_T_liftwp_abort"] remoteExec ["fnc_duws_dialogue", 0];
};

["LIFT"] call fnc_mapclick_release;
player setVariable ["LIFT_CLICKED", nil];
player setVariable ["LIFT_TMPPOS", nil];