// Locality: server. The direct-sighting sweep -- one perception pass on the engine's own last-seen. Each
// live OPFOR observer reports the BLUFOR it senses now (nearTargets, gated on a fresh position age); each
// freshly-seen group is stamped with the observer's remembered position (element 0, NOT the live position),
// its firepower (the force model, fnc_opcom_force) and the tick. A group nobody senses holds at last-seen
// and decays; force is the firepower at that sighting, held between sightings.
//
// Two engine traps shape this (see arma_engine_gotchas.md). `east knowsAbout` is side-wide and lingers high
// while anyone merely remembers a target, so it cannot tell a watched mover from a ghost -- hence the
// observer/nearTargets model, not a knowsAbout gate. And the live position drags belief to a teleport
// destination -- hence the remembered position, which the engine advances only on a real observation.
//
// Keying by group netId is the one omnipotence granted (an observer would not know exact squad membership).
// Zone-flip and AoI sensors write belief through their own hooks, not here.
if (!isServer) exitWith {};

// nearTargets element indices, confirmed by the probe: [pos, type, side, cost, object, age]. Element 5 is
// the AGE of the fix (seconds since last pinned, ~0 while sensing, growing after), NOT an absolute time.
// The two one-shot probes log a live and a stale sample so a shape/semantics drift shows in the RPT.
private _NT_POS    = 0;   // observer's remembered (last-known) position of the target
private _NT_OBJECT = 4;   // the sensed target object (objNull when only its type is known)
private _NT_POSAGE = 5;   // seconds since the observer last fixed the target's position (age)

// Freshest sighting this tick per BLUFOR group netId: [rememberedPos, men-count, age]. Age within a tick =
// seen now (vs still-remembered); lowest-age observer wins when several see the same group.
private _seen = createHashMap;
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
                private _age = _x select _NT_POSAGE;
                // Confirms element 5 grows for a remembered target; if it never fires, 5 is not age (pivot to nearTargetsCurrent).
                if (isNil "DUWS_opcom_ntStaleProbed" && {_age > OPCOM_TICK_PERIOD}) then {
                    DUWS_opcom_ntStaleProbed = true;
                    ["DEBUG", "OPCOM", format ["nearTargets stale sample age=%1 obj=%2", _age, _tgt]] call fnc_log;
                };
                if (_age <= OPCOM_TICK_PERIOD) then {
                    private _g = group _tgt;
                    private _k = netId _g;
                    if (_age < ((_seen getOrDefault [_k, [[], 0, 1e9]]) select 2)) then {
                        private _pos = +(_x select _NT_POS);
                        _pos set [2, 0];
                        private _gu = units _g;
                        private _players = {isPlayer _x} count _gu;
                        // Firepower, not headcount: each dismounted man 1, each crewed vehicle its class
                        // power (counted once), plus an additive premium per human aboard. Full power --
                        // belief is fogged by age decay, not by tracking a sighted hull's damage.
                        private _seenVeh = [];
                        private _fp = 0;
                        {
                            private _veh = vehicle _x;
                            if (_veh isEqualTo _x) then {
                                _fp = _fp + 1;
                            } else {
                                if !(_veh in _seenVeh) then {
                                    _seenVeh pushBack _veh;
                                    _fp = _fp + ([typeOf _veh] call DUWS_fnc_classPower);
                                };
                            };
                        } forEach _gu;
                        private _str = _fp + OPCOM_PLAYER_WORTH * _players;
                        _seen set [_k, [_pos, _str, _age]];
                    };
                };
            };
        } forEach _known;
    };
} forEach (allGroups select {side _x == east});

{
    private _key = _x;
    (_seen get _key) params ["_pos", "_str"];
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
} forEach (keys _seen);

DUWS_opcom_dbg_fresh = count keys _seen;
