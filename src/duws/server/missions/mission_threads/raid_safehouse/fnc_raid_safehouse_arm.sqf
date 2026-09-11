// Locality: each client with a player (the thread remoteExecs it JIP, keyed on the house).
//
// Breach is shot-tracked off per-door points, not a HitPart: a building door is often collision-only geometry
// that fires no HitPart, so a round into it never registered. Each point carries its door source, so the shot
// opens only the door it hit, not the house's first shut one.
//
// The locked-door action exists because bis_disabled_Door_N suppresses the engine open action, so a locked
// house would give no feedback without it.
params ["_house"];
if (isNull _house || {!hasInterface}) exitWith {};
#define REACH 10       // TUNABLE, metres from the shooter to a door point
#define POINT_BLANK 1.5 // TUNABLE, at this range the aim check is waived -- the shooter is on the door
#define TOWARD 0.5     // TUNABLE, cos of the half-angle the shot must fall within to count as aimed at the door

// Guard a re-raid on a reused building from stacking duplicate actions.
if (!(_house getVariable ["DUWS_safehouse_lockAction", false])) then {
    _house setVariable ["DUWS_safehouse_lockAction", true];
    // One locked-door action per door, anchored to that door's selection so it shows only when the player aims
    // at it -- a radius off the building origin never reached a perimeter door. Gated on that door still shut
    // (its source not yet in openedDoors), not the whole-house breach, so each door reads locked until its own
    // shot opens it. A door whose selection did not resolve carries no anchor and gets no action.
    {
        _x params ["", "_src", ["_sel", ""]];
        if (_sel != "") then {
            _house addAction [
                localize "STR_DUWS_T_RAID_SAFEHOUSE_OPEN",
                { hint (localize "STR_DUWS_T_RAID_SAFEHOUSE_LOCKED") },
                nil, 6, true, false, "",
                format ["(missionNamespace getVariable ['DUWS_safehouse_active', false]) && {!('%1' in (_target getVariable ['DUWS_safehouse_openedDoors', []]))}", _src],
                2.5, false, _sel
            ];
        };
    } forEach (_house getVariable ["DUWS_safehouse_doorPts", []]);
};

// One watcher for the whole raid, reading the server-broadcast candidate list.
if (isNil "DUWS_safehouse_firedEH") then {
    DUWS_safehouse_firedEH = player addEventHandler ["Fired", {
        params ["_shooter", "", "", "", "", "", "_proj"];
        if (!(missionNamespace getVariable ["DUWS_safehouse_active", false])) exitWith {};
        private _v = velocity _proj; _v set [2, 0];
        if (vectorMagnitude _v < 0.1) exitWith {};
        _v = vectorNormalized _v;
        private _sp = getPosASL _shooter;
        // Nearest, not first: two adjacent doors in reach otherwise open whichever the list yields, not the aimed one.
        private _best = [1e10, objNull, ""];
        {
            private _hs = _x;
            // No breached-gate: every door is shot open on its own, before and after entry; the breach fires the
            // raid outcome only on the first, so interior doors keep opening once the house is cracked.
            if (!isNull _hs) then {
                {
                    _x params ["_dp", "_src"];
                    private _to = _dp vectorDiff _sp; _to set [2, 0];
                    private _d = vectorMagnitude _to;
                    if (_d <= REACH && {_d < (_best select 0)} && {_d < POINT_BLANK || {(_v vectorDotProduct (vectorNormalized _to)) > TOWARD}}) then {
                        _best = [_d, _hs, _src];
                    };
                } forEach (_hs getVariable ["DUWS_safehouse_doorPts", []]);
            };
        } forEach (missionNamespace getVariable ["DUWS_safehouse_candidates", []]);
        if (!isNull (_best select 1)) then {
            [_best select 1, _best select 2] remoteExec ["fnc_raid_safehouse_breach", 2];
        };
    }];
};
