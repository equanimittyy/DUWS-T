// Locality: server. The direct-sighting sweep, one perception pass, built on the engine's own last-seen.
// Each live OPFOR observer reports which BLUFOR groups it is sensing RIGHT NOW (nearTargets, gated on a
// fresh position time); every freshly-seen group has its leader position, observed men-count and the tick
// stamped. A group nobody senses this tick is left untouched -- its stamp holds at last-seen and decay
// carries its confidence down, so belief never follows an unobserved or teleporting target, and force is
// the men-count at the last real sighting, held between sightings (not re-derived per tick).
//
// This replaced a knowsAbout-derivative gate: `east knowsAbout` is side-wide and lingers high while *any*
// observer merely REMEMBERS a target, so it cannot tell a watched mover from a remembered ghost and kept
// re-stamping the live position of unobserved targets (docs/info/architecture/arma_engine_gotchas.md).
// nearTargets carries a per-target position time, which does separate the two.
//
// Grouping observation by group netId is the one omnipotence OPCOM is granted -- a real observer would not
// know exact squad membership -- and it keeps the store one row per force, merged per cell by the grid.
// Leader-only approximation on both ends (an observer's knowledge read off its group leader; a target's
// position off its leader), accepted for the common squad case. Zone-flip and AoI sensors write belief
// through their own hooks, not here.
if (!isServer) exitWith {};

// nearTargets element indices (BIKI order). The one-shot probe below logs a raw entry to the RPT, so a
// shape mismatch shows up on the first playtest rather than silently misgating.
private _NT_OBJECT  = 4;   // the sensed target object (objNull when only its type is known)
private _NT_POSTIME = 5;   // mission time (s) the observer last fixed the target's position

// Which BLUFOR groups a live OPFOR observer is sensing this tick, keyed by group netId. nearTargets also
// carries remembered (stale) targets, so a position time within the last tick is what marks "seen now".
private _freshSeen = createHashMap;
{
    private _obs = leader _x;
    if (alive _obs) then {
        private _known = _obs nearTargets OPCOM_SENSE_RANGE;
        if (isNil "DUWS_opcom_ntProbed" && {_known isNotEqualTo []}) then {
            DUWS_opcom_ntProbed = true;
            ["DEBUG", "OPCOM", format ["nearTargets sample = %1", _known select 0]] call fnc_log;
        };
        {
            private _tgt = _x select _NT_OBJECT;
            if (!isNull _tgt && {side (group _tgt) == west}) then {
                if ((time - (_x select _NT_POSTIME)) <= OPCOM_TICK_PERIOD) then {
                    _freshSeen set [netId (group _tgt), true];
                };
            };
        } forEach _known;
    };
} forEach (allGroups select {side _x == east});

{
    private _grp = _x;
    private _ldr = leader _grp;
    if (!isNull _ldr && {alive _ldr} && {_freshSeen getOrDefault [netId _grp, false]}) then {
        private _pos = getPosATL _ldr;
        _pos set [2, 0];
        private _players = {isPlayer _x} count units _grp;
        private _str = ((count units _grp) - _players) + OPCOM_PLAYER_WORTH * _players;

        private _key = netId _grp;
        private _i = DUWS_opcom_belief_key findIf {_x isEqualTo _key};
        if (_i < 0) then {
            DUWS_opcom_belief_key  pushBack _key;
            DUWS_opcom_belief_pos  pushBack _pos;
            DUWS_opcom_belief_time pushBack DUWS_opcom_tick;
            DUWS_opcom_belief_str  pushBack _str;
        } else {
            DUWS_opcom_belief_pos  set [_i, _pos];
            DUWS_opcom_belief_time set [_i, DUWS_opcom_tick];
            DUWS_opcom_belief_str  set [_i, _str];
        };
    };
} forEach (allGroups select {side _x == west});

DUWS_opcom_dbg_fresh = count keys _freshSeen;
