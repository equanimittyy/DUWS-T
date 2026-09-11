// Locality: each client with a player (the thread remoteExecs it JIP, keyed on the house).
//
// Breach is shot-tracked off the furnish grid's door points, not a HitPart: a building door is often
// collision-only geometry that fires no HitPart, so a round into it registered nothing. A Fired event within
// REACH of a door point and aimed at it breaches -- reliable, and the grid's interior points let a shot pick
// the nearest door (an internal one, or one a big house sets far from its centre) rather than the house.
//
// The locked-door action exists because bis_disabled_Door_N suppresses the engine open action, so a locked
// house would give no feedback without it.
params ["_house"];
if (isNull _house || {!hasInterface}) exitWith {};
#define REACH 10       // TUNABLE, metres from the shooter to a door point
#define POINT_BLANK 1.5 // TUNABLE, at this range the aim check is waived -- the shooter is on the door
#define TOWARD 0.5     // TUNABLE, cos of the half-angle the shot must fall within to count as aimed at the door

// Guard a re-raid on a reused building from stacking a duplicate action.
if (!(_house getVariable ["DUWS_safehouse_lockAction", false])) then {
    _house setVariable ["DUWS_safehouse_lockAction", true];
    _house addAction [
        localize "STR_DUWS_T_RAID_SAFEHOUSE_OPEN",
        { hint (localize "STR_DUWS_T_RAID_SAFEHOUSE_LOCKED") },
        nil, 6, true, false, "",
        "(missionNamespace getVariable ['DUWS_safehouse_active', false]) && {!(_target getVariable ['DUWS_safehouse_breached', false])}",
        3
    ];
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
        {
            private _hs = _x;
            if (!isNull _hs && {!(_hs getVariable ["DUWS_safehouse_breached", false])}) then {
                {
                    private _to = _x vectorDiff _sp; _to set [2, 0];
                    private _d = vectorMagnitude _to;
                    if (_d <= REACH && {_d < POINT_BLANK || {(_v vectorDotProduct (vectorNormalized _to)) > TOWARD}}) exitWith {
                        [_hs, ""] remoteExec ["fnc_raid_safehouse_breach", 2];
                    };
                } forEach (_hs getVariable ["DUWS_safehouse_doorPts", []]);
            };
        } forEach (missionNamespace getVariable ["DUWS_safehouse_candidates", []]);
    }];
};
