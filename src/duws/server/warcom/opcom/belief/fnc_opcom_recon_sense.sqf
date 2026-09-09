// Locality: server. The recon flag's own sensor, run each perception tick after fnc_opcom_sense. That sweep
// rides A3's fallible last-seen (nearTargets on live observers only), so a virtual tasking senses nothing and
// a live one can be blinded by stealth or line of sight. A recon-flagged tasking instead detects every BLUFOR
// group within K grid cells of it for certain -- no detection roll, live or virtual -- and stamps belief.
// That guaranteed reach is the whole worth of a recon element: it buys OPCOM reliable eyes on the ground it
// sits on, where the ordinary sweep might see nothing.
//
// Reach is Chebyshev cells, the same measure and w2c cells the streamer uses (fnc_opcom_task_step), by
// platform since the three recon rows differ only there (opcom_plan.md). Belief is the same store
// fnc_opcom_sense writes, keyed by BLUFOR group netId on the one sighting scale (DUWS_fnc_opcom_sightStr);
// running after that sweep, a recon fix is the authoritative overwrite for a group both sensors saw.
if (!isServer) exitWith {};
if (isNil "DUWS_opcom_grid_w") exitWith {};

private _w = DUWS_opcom_grid_w;

// Every live BLUFOR group's cell once for the tick: [group, cx, cy]. Group, not unit -- belief keys and
// stamps by group at its leader's cell, matching fnc_opcom_sense. allGroups (handles), never a scan over
// allUnits/nearEntities (info/performance.md).
private _wcells = [];
{
    private _ldr = leader _x;
    if (!isNull _ldr && {alive _ldr}) then {
        private _ci = [getPosASL _ldr] call DUWS_fnc_opcom_w2c;
        _wcells pushBack [_x, _ci mod _w, floor (_ci / _w)];
    };
} forEach (allGroups select { side _x == west });
if (_wcells isEqualTo []) exitWith {};

{
    if ("recon" in (_x getOrDefault ["flags", []])) then {
        // Live unit senses from where it stands; a virtual one from its stepped grid point.
        private _grp = _x get "grp";
        private _pos = if (_grp isNotEqualTo "") then {
            private _g = groupFromNetId _grp;
            if (isNull _g) then { _x get "pos" } else { getPosASL (leader _g) };
        } else {
            _x get "pos"
        };
        private _k = OPCOM_RECON_K getOrDefault [_x get "moveType", 1];
        private _rc = [_pos] call DUWS_fnc_opcom_w2c;
        private _rcx = _rc mod _w;
        private _rcy = floor (_rc / _w);

        {
            _x params ["_wg", "_gcx", "_gcy"];
            if (((abs (_rcx - _gcx)) max (abs (_rcy - _gcy))) <= _k) then {
                private _key = netId _wg;
                private _bp = getPosASL (leader _wg);
                _bp set [2, 0];
                private _str = [_wg] call DUWS_fnc_opcom_sightStr;
                private _i = DUWS_opcom_belief_key findIf { _x isEqualTo _key };
                if (_i < 0) then {
                    DUWS_opcom_belief_key  pushBack _key;
                    DUWS_opcom_belief_pos  pushBack _bp;
                    DUWS_opcom_belief_time pushBack DUWS_opcom_tick;
                    DUWS_opcom_belief_str  pushBack _str;
                } else {
                    DUWS_opcom_belief_pos  set [_i, _bp];
                    DUWS_opcom_belief_time set [_i, DUWS_opcom_tick];
                    DUWS_opcom_belief_str  set [_i, _str];
                };
            };
        } forEach _wcells;
    };
} forEach DUWS_opcom_taskings;
