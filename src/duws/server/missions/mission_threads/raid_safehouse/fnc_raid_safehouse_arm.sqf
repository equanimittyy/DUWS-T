// Locality: each client with a player (the raid thread remoteExecs it, JIP).
//
// Breach is shot-tracked off per-door points, not a HitPart: a building door is often collision-only geometry
// that fires no HitPart, so a round into it never registered. Each point carries its door source, so the shot
// unlocks only the door it hit, not the house's first locked one.
//
// No breach action of our own: bis_disabled_Door_N leaves the engine's "Open door" in place -- it wiggles the
// locked leaf rather than suppressing the action -- so a second addAction would only double it. The shoot-to-
// breach instruction comes from a proximity hint instead, fired once per house per player on approach.
params ["_house"];
if (isNull _house || {!hasInterface}) exitWith {};
#define REACH 3        // TUNABLE, metres from the shooter to a door point
#define POINT_BLANK 1.5 // TUNABLE, at this range the aim check is waived -- the shooter is on the door
#define TOWARD 0.5     // TUNABLE, cos of the half-angle the shot must fall within to count as aimed at the door
#define HINT_RANGE 30  // TUNABLE, metres -- a player this close to a still-locked candidate gets the breach hint

// Teach the breach on approach. One hint per house per player, the first time they close within HINT_RANGE of a
// still-locked candidate; reads the server-broadcast candidate list, so one loop covers every house.
if (isNil "DUWS_safehouse_proxHint") then {
    DUWS_safehouse_proxHint = true;
    [] spawn {
        private _hinted = [];
        while { missionNamespace getVariable ["DUWS_safehouse_active", false] } do {
            {
                if (!isNull _x
                    && {!(_x in _hinted)}
                    && {!(_x getVariable ["DUWS_safehouse_breached", false])}
                    && {player distance _x < HINT_RANGE}) then {
                    _hinted pushBack _x;
                    hint (localize "STR_DUWS_T_RAID_SAFEHOUSE_LOCKED");
                };
            } forEach (missionNamespace getVariable ["DUWS_safehouse_candidates", []]);
            sleep 2;   // TUNABLE
        };
    };
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
        // Nearest, not first: two adjacent doors in reach otherwise unlock whichever the list yields, not the aimed one.
        private _best = [1e10, objNull, ""];
        {
            private _hs = _x;
            // No breached-gate: every door is unlocked by its own shot, before and after entry; the breach fires the
            // raid outcome only on the first, so interior doors keep unlocking once the house is cracked.
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
