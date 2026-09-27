// Locality: server -- the OPCOM half of the intel system: how a plotted enemy unit reads on the map,
// and the reveal that puts it there. Executed by the registry rather than stored as one function:
// this file defines two.
//
// A contact is a snapshot, never a tracker. The marker holds the position and heading the tasking
// carried at the moment the intel landed, and it never moves; a later payout replaces it with a
// fresh one. A tasking marches every OPCOM tick, so a live contact would cost a marker update per
// tick per contact for the whole team -- and it would hand the player a feed of ground they have not
// found, which is the thing the intel channel is not (docs/info/gameplay/intel_system.md). Stale
// intel therefore reads as stale, and the contact expires on its own clock.
if (!isServer) exitWith {};

// Tasking id -> the marker plotting it now; server-local, like the tasking store it keys into. A re-plot
// takes a fresh marker name rather than reusing the old one, so the thread fading the old marker can tell
// that it no longer owns the unit.
DUWS_intel_contacts = createHashMap;
DUWS_intel_contactSeq = 0;

// Plots one tasking and returns whether it plotted anything, the same contract fnc_zone_reveal and
// fnc_hardpoint_reveal keep, so fnc_intel_payout can tell a reveal from a no-op. Markers are global
// (created on the server, no *Local): a contact lands on every player's map, so the team is told.
//
// It does not announce, where the other reveal writers do: one payout plots a whole batch, and a line
// per contact would queue eight of them behind each other. The batch line is spoken at the payout.
//
// One arrow and nothing else. A fix reports where something was and which way it was going; a type
// icon and an order label answer what the enemy is doing, which is the live feed this channel is not.
DUWS_fnc_intel_contactReveal = {
    params ["_t"];
    private _id = _t get "id";
    private _pos = _t get "pos";

    // Heading off the leg the unit is walking now, the target only once the route is spent: a route
    // bends around terrain, so the final point is not where the unit is heading next.
    private _route = _t getOrDefault ["route", []];
    private _leg = _t getOrDefault ["leg", 0];
    private _to = if (_leg < count _route) then { _route select _leg } else { _t getOrDefault ["target", []] };
    // A live group walks its waypoints and its record's leg stops advancing, so the leg can point behind it.
    private _grp = groupFromNetId (_t get "grp");
    if (alive leader _grp) then {
        _pos = getPosASL leader _grp;
        private _wp = currentWaypoint _grp;
        _to = if (_wp < count waypoints _grp) then { waypointPosition [_grp, _wp] }
            else { _t getOrDefault ["target", []] };
    };
    // The arrow is the whole contact, so a unit with nowhere left to go has nothing to plot.
    if (count _to < 2) exitWith { false };

    private _dir = _pos getDir _to;
    if (_id in DUWS_intel_contacts) then { deleteMarker (DUWS_intel_contacts get _id) };
    private _mk = format ["intel_contact_%1", DUWS_intel_contactSeq];
    DUWS_intel_contactSeq = DUWS_intel_contactSeq + 1;
    createMarker [_mk, _pos];
    _mk setMarkerShape "ICON";
    _mk setMarkerType "mil_arrow_noShadow";
    _mk setMarkerColor "ColorOPFOR";
    _mk setMarkerSize [0.5, 0.5];
    _mk setMarkerDir _dir;

    DUWS_intel_contacts set [_id, _mk];
    ["INFO", "INTEL", format ["contact plotted: tasking %1 (%2) at %3",
        _id, _t getOrDefault ["menu", "?"], mapGridPosition _pos]] call fnc_log;

    // One thread per contact, each holding only its id and marker: the alternative is a sweep on a
    // clock this system does not otherwise need. The tasking may die, arrive or be re-ordered inside
    // the window and the marker stays put -- last known position is what it says. Twenty fade steps,
    // not a smooth fade: each setMarkerAlpha on a global marker is a network broadcast.
    [_id, _mk] spawn {
        params ["_id", "_mk"];
        for "_i" from 19 to 0 step -1 do {
            sleep (DUWS_intel_contact_life / 20);
            if ((DUWS_intel_contacts getOrDefault [_id, ""]) isNotEqualTo _mk) exitWith {};
            if (_i == 0) exitWith { deleteMarker _mk; DUWS_intel_contacts deleteAt _id };
            _mk setMarkerAlpha (_i / 20);
        };
    };
    true
};
