// Locality: server -- the OPCOM half of the intel system: how a plotted enemy unit reads on the map,
// and the reveal that puts it there. Executed by the registry rather than stored as one function:
// this file defines two.
//
// A contact is a snapshot, never a tracker. The markers hold the position, heading and order the
// tasking carried at the moment the intel landed, and they never move again. A tasking is a virtual
// record that marches every OPCOM tick, so a live contact would cost a marker update per tick per
// contact for the whole team -- and it would hand the player a feed of ground they have not found,
// which is the thing the intel channel is not (docs/info/gameplay/intel_system.md). Stale intel
// therefore reads as stale, and the contact expires on its own clock.
if (!isServer) exitWith {};

// Tasking ids standing on the map right now, so intel never plots the same unit twice. Written by
// the reveal and cleared by its own expiry; server-local, like the tasking store it keys into.
DUWS_intel_contactIds = [];

// A tasking record -> [icon, order-label key]. Pure, and it hands back a stringtable key rather than
// a line so the caller localises and the whole read stays testable off the engine -- the icon table
// lives in here for that, and a reveal is rare enough that rebuilding it per call costs nothing.
//
// The icons are the OPFOR unit set (docs/info/external/arma3_markers.md), keyed by recruit-menu row
// rather than by moveType as the OPCOM debug overlay is: a recon car and a supply truck are both
// "wheeled", and telling those two apart is most of what a contact is worth.
//
// An errand is what a march is for, and every errand rides a "move", so it outranks the order
// carrying it. Capture and intercept come first regardless: a recon car sent to hunt a BLUFOR group
// is hunting, whatever it was hired as.
DUWS_fnc_intel_contactRead = {
    params ["_t"];
    private _icons = createHashMapFromArray [
        ["rifles", "o_inf"], ["weapons_team", "o_inf"],
        ["apc", "o_mech_inf"], ["ifv", "o_mech_inf"], ["mbt", "o_armor"],
        ["attack_heli", "o_air"], ["recon_heli", "o_air"], ["trans_heli", "o_air"], ["jet", "o_plane"],
        ["recon_foot", "o_recon"], ["recon_car", "o_recon"],
        ["truck", "o_support"], ["boat", "o_naval"]
    ];
    private _icon = _icons getOrDefault [_t getOrDefault ["menu", ""], "o_unknown"];
    private _errand = (_t getOrDefault ["errand", []]) param [0, ""];
    private _label = switch (true) do {
        case ((_t getOrDefault ["order", ""]) isEqualTo "capture"): { "attack" };
        case ((_t getOrDefault ["order", ""]) isEqualTo "intercept"): { "intercept" };
        case (_errand isEqualTo "rapport"): { "rapport" };
        case (_errand isEqualTo "reinforce"): { "reinforce" };
        case (_errand isEqualTo "fortify"): { "fortify" };
        case (_errand in ["build", "mine"]): { "build" };
        case ((_t getOrDefault ["returnZone", ""]) isNotEqualTo ""): { "redeploy" };
        case ("recon" in (_t getOrDefault ["flags", []])): { "recon" };
        default { "move" };
    };
    [_icon, format ["STR_DUWS_T_intel_contact_%1", _label]]
};

// How far the heading arrow stands off the unit icon. Under it the two overlap into one unreadable
// stamp at map zoom.
#define CONTACT_ARROW_OFFSET 120

// Plots one tasking and returns whether it plotted anything, the same contract fnc_zone_reveal and
// fnc_hardpoint_reveal keep, so fnc_intel_payout can tell a reveal from a no-op. Markers are global
// (created on the server, no *Local): a contact lands on every player's map, so the team is told.
//
// It does not announce, where the other reveal writers do: one payout plots a whole batch, and a line
// per contact would queue eight of them behind each other. The batch line is spoken at the payout.
DUWS_fnc_intel_contactReveal = {
    params ["_t"];
    private _id = _t get "id";
    if (_id in DUWS_intel_contactIds) exitWith { false };

    ([_t] call DUWS_fnc_intel_contactRead) params ["_icon", "_labelKey"];
    private _pos = _t get "pos";

    private _mk = format ["intel_contact_%1", _id];
    createMarker [_mk, _pos];
    _mk setMarkerShape "ICON";
    _mk setMarkerType _icon;
    _mk setMarkerColor "ColorOPFOR";
    _mk setMarkerSize [1, 1];
    _mk setMarkerText (localize _labelKey);

    // Heading off the leg the unit is walking now, the target only once the route is spent: a route
    // bends around terrain, so the final point is not where the unit is heading next.
    private _route = _t getOrDefault ["route", []];
    private _leg = _t getOrDefault ["leg", 0];
    private _to = if (_leg < count _route) then { _route select _leg } else { _t getOrDefault ["target", []] };
    if (count _to >= 2) then {
        private _dir = _pos getDir _to;
        private _am = format ["intel_contact_%1_dir", _id];
        createMarker [_am, _pos getPos [CONTACT_ARROW_OFFSET, _dir]];
        _am setMarkerShape "ICON";
        _am setMarkerType "mil_arrow_noShadow";
        _am setMarkerColor "ColorOPFOR";
        _am setMarkerSize [0.8, 0.8];
        _am setMarkerDir _dir;
    };

    DUWS_intel_contactIds pushBack _id;
    ["INFO", "INTEL", format ["contact plotted: tasking %1 (%2, %3) at %4",
        _id, _t getOrDefault ["menu", "?"], _labelKey, mapGridPosition _pos]] call fnc_log;

    // One thread per contact, each holding only an id: a handful stand at a time, and the alternative
    // is a sweep on a clock this system does not otherwise need. The tasking may die, arrive or be
    // re-ordered inside the window and the markers stay put -- last known position is what they say.
    [_id] spawn {
        params ["_id"];
        sleep DUWS_intel_contact_life;
        deleteMarker (format ["intel_contact_%1", _id]);
        deleteMarker (format ["intel_contact_%1_dir", _id]);
        DUWS_intel_contactIds = DUWS_intel_contactIds - [_id];
    };
    true
};
