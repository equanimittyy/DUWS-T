// Locality: server. The patrol sensor, run each perception tick after fnc_opcom_sense. Two separable things:
//
// Every combatant tasking stamps the staleness layer over its reach, recon or not (fnc_opcom_cover_stamp). The stamp
// is when OPCOM last looked at a cell, never how sure it is of what it saw, so a rifle squad resets it as a recon
// does -- what spreads the patrols and lets swept ground decay back in. A noncombat hull with no recon flag is not
// out watching ground, so it stamps nothing.
//
// Certainty stays with the recon flag. fnc_opcom_sense rides A3's fallible last-seen (nearTargets on live observers
// only), so a virtual tasking senses nothing and a live one can be blinded; a recon-flagged tasking instead detects
// every BLUFOR group in reach with no roll, live or virtual, and clears the rows its reach disproves
// (fnc_opcom_cover_clear). A combatant's empty look proves nothing, so it buys no clear, and selling certainty to
// every rifle squad would leave the recon rows nothing to buy.
//
// Reach is what the Value priced the sweep on (DUWS_fnc_opcom_patrolReach), Chebyshev cells as the streamer measures
// them (fnc_opcom_task_step). Belief keys by BLUFOR group netId on the one sighting scale (DUWS_fnc_opcom_sightStr);
// running after fnc_opcom_sense, a recon fix is the authoritative overwrite for a group both saw.
if (!isServer) exitWith {};
if (isNil "DUWS_opcom_grid_w") exitWith {};

private _w = DUWS_opcom_grid_w;

// Every visible BLUFOR group's cell once for the tick: [group, cx, cy, lead]. Group, not unit -- belief keys
// and stamps by group at its sight lead's cell, matching fnc_opcom_sense. allGroups (handles), never a scan
// over allUnits/nearEntities (info/performance.md).
private _wcells = [];
{
    private _ldr = [_x] call DUWS_fnc_opcom_sightLead;
    if (!isNull _ldr) then {
        private _ci = [getPosASL _ldr] call DUWS_fnc_opcom_w2c;
        _wcells pushBack [_x, _ci mod _w, floor (_ci / _w), _ldr];
    };
} forEach (allGroups select { side _x == west });

// No empty-_wcells early exit: a unit still stamps coverage with no BLUFOR in play (looked, found nothing).
{
    private _flags = _x getOrDefault ["flags", []];
    private _isRecon = "recon" in _flags;
    if (_isRecon || {!("noncombat" in _flags)}) then {
        // Live unit senses from where it stands; a virtual one from its stepped grid point.
        private _grp = _x get "grp";
        private _pos = if (_grp isNotEqualTo "") then {
            private _g = groupFromNetId _grp;
            if (isNull _g) then { _x get "pos" } else { getPosASL (leader _g) };
        } else {
            _x get "pos"
        };
        private _k = [_x] call DUWS_fnc_opcom_patrolReach;
        [_pos, _k] call fnc_opcom_cover_stamp;

        if (_isRecon) then {
            private _rc = [_pos] call DUWS_fnc_opcom_w2c;
            private _rcx = _rc mod _w;
            private _rcy = floor (_rc / _w);
            {
                _x params ["_wg", "_gcx", "_gcy", "_lead"];
                if (((abs (_rcx - _gcx)) max (abs (_rcy - _gcy))) <= _k) then {
                    private _key = netId _wg;
                    private _bp = getPosASL _lead;
                    _bp set [2, 0];
                    private _str = [_wg] call DUWS_fnc_opcom_sightStr;
                    [_key, _bp, _str] call fnc_opcom_belief_upsert;
                };
            } forEach _wcells;

            [_pos, _k] call fnc_opcom_cover_clear;
        };
    };
} forEach DUWS_opcom_taskings;
