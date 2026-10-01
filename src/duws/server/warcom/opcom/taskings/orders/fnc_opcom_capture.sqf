// Locality: server, [] call'd at load. The capture order: march on BLUFOR-held ground -- a zone, their HQ or a
// FOB -- report the crossing into it, and settle once it has changed hands.
if (!isServer) exitWith {};

// -> whether the target is still BLUFOR's: a zone by the control list. The HQ never changes hands, so it falls with
// its officer, whose death is already the HQ's lose condition. A FOB falls with its building.
DUWS_fnc_opcom_captureHolds = {
    params ["_key"];
    if (_key isEqualTo "HQ") exitWith { !isNil "hq_blu1" && {alive hq_blu1} };
    if ((_key select [0, 4]) isEqualTo "FOB_") exitWith {
        (Array_of_FOBS findIf { alive _x && {(_x getVariable ["DUWS_siteKey", ""]) isEqualTo _key} }) >= 0
    };
    [_key] call fnc_zone_bluforHeld
};

// -> the key of the BLUFOR-held holding a capture at _target takes, "" for none.
DUWS_fnc_opcom_captureKey = {
    params ["_target"];
    private _i = WARCOM_zones_controled_by_BLUFOR findIf {
        (_x distance2D _target) <= (([[_x] call fnc_zone_key] call fnc_site_at) getOrDefault ["radius", 0])
    };
    if (_i >= 0) exitWith { [WARCOM_zones_controled_by_BLUFOR select _i] call fnc_zone_key };
    private _zk = "";
    // The nearest base, since a FOB may stand inside the HQ's radius or another FOB's and each attack aims at its own
    // base's centre.
    private _best = -1;
    {
        private _site = [_x] call fnc_site_at;
        private _sp = _site getOrDefault ["pos", []];
        if (_sp isNotEqualTo []) then {
            private _d = _sp distance2D _target;
            if (_d <= (_site get "radius") && {_best < 0 || {_d < _best}}) then { _zk = _x; _best = _d };
        };
    } forEach ((["HQ"] + (Array_of_FOBS apply { _x getVariable ["DUWS_siteKey", ""] })) select { [_x] call DUWS_fnc_opcom_captureHolds });
    _zk
};

// -> true the tick an attacker enters its target zone's radius. A live one tracks it too, or a later stow re-reports.
DUWS_fnc_opcom_captureEnters = {
    params ["_t", "_pos"];
    private _site = [_t get "targetZone"] call fnc_site_at;
    private _in = (_pos distance2D (_site get "pos")) <= (_site get "radius");
    private _entered = _in && {!(_t getOrDefault ["inZone", false])};
    _t set ["inZone", _in];
    // Stamped on any tick inside that has none rather than only on entry, so a tasking already inside without a
    // stamp starts its hold instead of never finishing it.
    if (_in) then { if !("inZoneAt" in _t) then { _t set ["inZoneAt", time] } } else { _t deleteAt "inZoneAt" };
    _entered
};

// -> true if it garrisoned. A live attacker inside the objective guards until it stows, so it never vanishes in
// front of a player; one still on the road re-garrisons there.
//
// OPFOR has no pool at a base, so a base's attacker guards wherever it stands. A FOB's site is retired with it, so its
// absence reads as outside.
DUWS_fnc_opcom_captureEnd = {
    params ["_t", "_pos", "_grp"];
    private _zk = _t get "targetZone";
    private _site = [_zk] call fnc_site_at;
    _t set ["targetZone", ""];
    _t deleteAt "inZoneAt";
    if (count _site == 0 || {(_pos distance2D (_site get "pos")) > (_site get "radius")}) exitWith {
        _t set ["hold", 0];
        if (_zk isEqualTo "HQ" || {(_zk select [0, 4]) isEqualTo "FOB_"} || {!([_t, "return", _site get "pos", _zk] call fnc_opcom_task)}) then {
            [_t, "guard"] call fnc_opcom_task
        };
        false
    };
    private _home = (_zk select [0, 5]) isEqualTo "zone_";
    if (isNull _grp) exitWith {
        if (_home) then {
            [_t, _zk] call DUWS_fnc_opcom_garrisonInto;
        } else {
            _t set ["hold", 0];
            [_t, "guard"] call fnc_opcom_task;
        };
        true
    };
    _t set ["order", "guard"]; _t set ["target", _pos]; _t set ["route", []];
    _t set ["settleZone", ["", _zk] select _home];
    [_grp, "guard", _pos] call DUWS_fnc_opcom_applyOrder;
    ["INFO", "OPCOM", format ["capture: tasking %1 holds %2%3", _t get "id", _zk,
        ["", ", garrisoning when it stows"] select _home]] call fnc_log;
    false
};

DUWS_opcom_fobHoldSince = createHashMap;

// Once per tick after the task step, which sets each attacker's inZone. A FOB falls, live or virtual alike, once an
// attacker has stood inside for DUWS_captureHold with no BLUFOR in the ring; the hold restarts while any stand there.
// fnc_fob_destroyed withdraws the rest once the building is down. A running hold is broadcast on the building, so fast
// travel cannot put a player in the ring to restart it.
DUWS_fnc_opcom_fobOverrun = {
    {
        private _fob = _x;
        private _key = _fob getVariable ["DUWS_siteKey", ""];
        private _site = [_key] call fnc_site_at;
        private _held = alive _fob
            && {(DUWS_opcom_taskings findIf {
                (_x getOrDefault ["targetZone", ""]) isEqualTo _key && {_x getOrDefault ["inZone", false]}
                    && {!((_x get "status") in ["dead", "done"])}
                    // A virtual one with BLUFOR within K is still waiting to render.
                    && {(_x get "grp") isNotEqualTo "" || {(_x getOrDefault ["nearTicks", 0]) == 0}}
            }) >= 0}
            && {([_site get "pos", _site get "radius", west, true] call fnc_side_count_at) == 0};
        if (_held) then {
            private _since = DUWS_opcom_fobHoldSince getOrDefault [_key, time];
            DUWS_opcom_fobHoldSince set [_key, _since];
            if (time - _since >= DUWS_captureHold) then {
                _fob setDamage 1;
                _held = false;
                ["INFO", "OPCOM", format ["capture: FOB %1 overrun", Array_of_FOBname select _forEachIndex]] call fnc_log;
            };
        };
        if (!_held) then { DUWS_opcom_fobHoldSince deleteAt _key };
        if ((_fob getVariable ["DUWS_overrunHold", false]) isNotEqualTo _held) then { _fob setVariable ["DUWS_overrunHold", _held, true] };
    } forEach Array_of_FOBS;
};

DUWS_fnc_opcom_stepCapture = {
    params ["_t", "_ctx"];
    _ctx params ["_pos", "_grp", "_live"];
    private _zk = _t get "targetZone";
    if (!([_zk] call DUWS_fnc_opcom_captureHolds)) exitWith { [_t, _pos, _grp] call DUWS_fnc_opcom_captureEnd };
    private _entered = [_t, _pos] call DUWS_fnc_opcom_captureEnters;
    // A FOB falls to all its attackers at once (DUWS_fnc_opcom_fobOverrun).
    if ((_zk select [0, 4]) isEqualTo "FOB_") exitWith { false };
    // Below is the virtual attacker's stand-in for a fight that never renders; a live one takes the ground by winning it.
    if (_live) exitWith { false };
    if (_entered) then {
        private _ni = zone_namePOS_pairs findIf { ([_x select 1] call fnc_zone_key) isEqualTo _zk };
        if (_ni >= 0) then { [(zone_namePOS_pairs select _ni) select 0, []] call fnc_enemy_contact };
    };
    // A garrison is never beaten virtually: standing its men up is what renders this attacker to fight them
    // (fnc_site_poller wakes on a virtual one). The HQ has no undefended case either: it falls only with its officer.
    if (_zk isEqualTo "HQ" || {([_zk] call fnc_zone_tier) > 0}) exitWith { false };
    // No BLUFOR count: nearTicks 0 means none within K, so its stored force outnumbers nobody; while any are, it waits
    // to render. It still holds for DUWS_captureHold, the rule a live attacker meets through the trigger's timeout.
    if ((_t get "inZone") && {(_t getOrDefault ["nearTicks", 0]) == 0} && {(_t get "effForce") > 0}
        && {time - (_t get "inZoneAt") >= DUWS_captureHold}) then {
        private _zpos = ([_zk] call fnc_site_at) get "pos";
        private _trg = missionNamespace getVariable [format ["trigger_%1_%2", floor abs (_zpos select 0), floor abs (_zpos select 1)], objNull];
        if (!isNull _trg) then { call compile ((triggerStatements _trg) select 1) };
    };
    false
};
