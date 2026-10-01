// Locality: server -- the OPCOM half of the intel system: how a plotted enemy unit reads on the map,
// and the reveal that puts it there. Executed by the registry rather than stored as one function:
// this file defines two.
//
// A contact is a snapshot, never a tracker. The markers hold the position and heading the tasking
// carried at the moment the intel landed, and they never move; a later payout replaces them with
// fresh ones. A tasking marches every OPCOM tick, so a live contact would cost a marker update per
// tick per contact for the whole team -- and it would hand the player a feed of ground they have not
// found, which is the thing the intel channel is not (docs/info/gameplay/intel_system.md). Stale
// intel therefore reads as stale, and the contact expires on its own clock.
if (!isServer) exitWith {};

// Tasking id -> the markers plotting it now; server-local, like the tasking store it keys into. A re-plot
// takes fresh marker names rather than reusing the old ones, so the thread fading the old markers can tell
// that it no longer owns the unit.
DUWS_intel_contacts = createHashMap;
DUWS_intel_contactSeq = 0;

// The OPFOR unit set (docs/info/external/arma3_markers.md), keyed by recruit-menu row rather than by
// moveType as the OPCOM debug overlay is: a recon car and a supply truck are both "wheeled", and telling
// those two apart is most of what a contact is worth.
DUWS_intel_contactIcons = createHashMapFromArray [
    ["rifles", "o_inf"], ["weapons_team", "o_inf"], ["car", "o_motor_inf"],
    ["apc", "o_mech_inf"], ["ifv", "o_mech_inf"], ["mbt", "o_armor"],
    ["attack_heli", "o_air"], ["recon_heli", "o_air"], ["trans_heli", "o_air"], ["jet", "o_plane"],
    ["recon_foot", "o_recon"], ["recon_car", "o_recon"],
    ["truck", "o_support"], ["boat", "o_naval"]
];

// Under this the heading arrow and the unit icon overlap into one unreadable stamp at map zoom.
#define CONTACT_ARROW_OFFSET 120

// Markers are global (created on the server, no *Local): a contact lands on every player's map, so the
// team is told.
//
// It does not announce, where the other reveal writers do: one payout plots a whole batch, and a line
// per contact would queue eight of them behind each other. The batch line is spoken at the payout.
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

    if (_id in DUWS_intel_contacts) then { { deleteMarker _x } forEach (DUWS_intel_contacts get _id) };
    private _mk = format ["intel_contact_%1", DUWS_intel_contactSeq];
    DUWS_intel_contactSeq = DUWS_intel_contactSeq + 1;
    createMarker [_mk, _pos];
    _mk setMarkerShape "ICON";
    _mk setMarkerType (DUWS_intel_contactIcons getOrDefault [_t getOrDefault ["menu", ""], "o_unknown"]);
    _mk setMarkerColor "ColorOPFOR";
    private _mks = [_mk];

    if (([_t] call DUWS_fnc_opcom_marching) && {count _to >= 2}) then {
        private _dir = _pos getDir _to;
        private _am = _mk + "_dir";
        createMarker [_am, _pos getPos [CONTACT_ARROW_OFFSET, _dir]];
        _am setMarkerShape "ICON";
        _am setMarkerType "mil_arrow_noShadow";
        _am setMarkerColor "ColorOPFOR";
        _am setMarkerSize [0.8, 0.8];
        _am setMarkerDir _dir;
        _mks pushBack _am;
    };

    DUWS_intel_contacts set [_id, _mks];
    ["INFO", "INTEL", format ["contact plotted: tasking %1 (%2) at %3",
        _id, _t getOrDefault ["menu", "?"], mapGridPosition _pos]] call fnc_log;

    // One thread per contact, each holding only its id and markers: the alternative is a sweep on a
    // clock this system does not otherwise need. The tasking may die, arrive or be re-ordered inside
    // the window and the markers stay put -- last known position is what they say. Twenty fade steps,
    // not a smooth fade: each setMarkerAlpha on a global marker is a network broadcast.
    [_id, _mks] spawn {
        params ["_id", "_mks"];
        for "_i" from 19 to 0 step -1 do {
            sleep (DUWS_intel_contact_life / 20);
            if ((DUWS_intel_contacts getOrDefault [_id, []]) isNotEqualTo _mks) exitWith {};
            if (_i == 0) exitWith { { deleteMarker _x } forEach _mks; DUWS_intel_contacts deleteAt _id };
            { _x setMarkerAlpha (_i / 20) } forEach _mks;
        };
    };
};
