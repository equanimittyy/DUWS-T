// Locality: server, [] call'd at load. The capture order: march on BLUFOR-held ground -- a zone, a town they
// have garrisoned, their HQ or a FOB -- report the crossing into it, and settle once it has changed hands.
if (!isServer) exitWith {};

// The target's town index, or -1 for a zone or a base. A town changes hands only by having its garrison cleared,
// where a zone flips on presence, and four steps below turn on that difference.
DUWS_fnc_opcom_captureTown = {
    params ["_key"];
    if ((_key select [0, 5]) isEqualTo "town_") exitWith { parseNumber (_key select [5]) };
    -1
};

// -> whether the target is still BLUFOR's: a zone by the control list, a town by the band its tier belongs to. The
// HQ never changes hands, so it falls with its officer, whose death is already the HQ's lose condition. A FOB falls
// with its building.
DUWS_fnc_opcom_captureHolds = {
    params ["_key"];
    if (_key isEqualTo "HQ") exitWith { !isNil "hq_blu1" && {alive hq_blu1} };
    if ((_key select [0, 4]) isEqualTo "FOB_") exitWith {
        (Array_of_FOBS findIf { alive _x && {(_x getVariable ["DUWS_siteKey", ""]) isEqualTo _key} }) >= 0
    };
    private _i = [_key] call DUWS_fnc_opcom_captureTown;
    if (_i >= 0) exitWith { ([_i] call fnc_town_garrison_ownerAt) isEqualTo "BLU" };
    [_key] call fnc_zone_bluforHeld
};

// -> the key of the BLUFOR-held holding a capture at _target takes, "" for none.
DUWS_fnc_opcom_captureKey = {
    params ["_target"];
    // Zones first, so ground that is both falls to the bigger prize: a town inside a zone the player also holds is
    // taken by taking the zone.
    private _i = WARCOM_zones_controled_by_BLUFOR findIf {
        (_x distance2D _target) <= (([[_x] call fnc_zone_key] call fnc_site_at) getOrDefault ["radius", 0])
    };
    if (_i >= 0) exitWith { [WARCOM_zones_controled_by_BLUFOR select _i] call fnc_zone_key };
    private _zk = "";
    // A town the player garrisoned is capture ground too. Only a garrisoned one: a town with no tier changes hands on
    // reputation, and there would be nothing for an attacker to beat.
    private _tiers = missionNamespace getVariable ["DUWS_townGarrisonTier", []];
    for "_n" from 0 to (count _tiers - 1) do {
        if (_zk isEqualTo "" && {(_tiers select _n) > 0}
            && {([_n] call fnc_town_garrison_ownerAt) isEqualTo "BLU"}) then {
            private _tk = [_n] call fnc_town_site_key;
            private _site = [_tk] call fnc_site_at;
            private _sp = _site getOrDefault ["pos", []];
            if (_sp isNotEqualTo [] && {(_sp distance2D _target) <= (_site getOrDefault ["radius", 0])}) then {
                _zk = _tk;
            };
        };
    };
    if (_zk isNotEqualTo "") exitWith { _zk };
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
// A cleared town keeps no garrison to home into -- its tier went with the clear -- so an attacker that took one
// holds the ground rather than joining a reserve pool that no longer exists. OPFOR has no pool at a base either, so
// a base's attacker guards wherever it stands. A FOB's site is retired with it, so its absence reads as outside.
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

DUWS_fnc_opcom_stepCapture = {
    params ["_t", "_ctx"];
    _ctx params ["_pos", "_grp", "_live"];
    private _zk = _t get "targetZone";
    if (!([_zk] call DUWS_fnc_opcom_captureHolds)) exitWith { [_t, _pos, _grp] call DUWS_fnc_opcom_captureEnd };
    private _entered = [_t, _pos] call DUWS_fnc_opcom_captureEnters;
    // A FOB falls, live or virtual alike, once its attacker has stood inside for DUWS_captureHold with no BLUFOR in the
    // ring. The hold restarts while any stand there, so a player who respawns at the FOB still holds it.
    // fnc_fob_destroyed withdraws the rest once the building is down.
    if ((_zk select [0, 4]) isEqualTo "FOB_") exitWith {
        if (_t get "inZone") then {
            private _site = [_zk] call fnc_site_at;
            if (([_site get "pos", _site get "radius", west, true] call fnc_side_count_at) > 0) exitWith { _t set ["inZoneAt", time] };
            if (time - (_t get "inZoneAt") >= DUWS_captureHold) then {
                { if ((_x getVariable ["DUWS_siteKey", ""]) isEqualTo _zk) then { _x setDamage 1 } } forEach Array_of_FOBS;
                ["INFO", "OPCOM", format ["capture: tasking %1 overran %2", _t get "id", _zk]] call fnc_log;
            };
        };
        false
    };
    // Below is the virtual attacker's stand-in for a fight that never renders; a live one takes the ground by winning it.
    if (_live) exitWith { false };
    private _town = [_zk] call DUWS_fnc_opcom_captureTown;
    if (_entered) then {
        private _name = "";
        if (_town >= 0) then {
            _name = [_town] call DUWS_fnc_opcom_townLabel;
        } else {
            private _ni = zone_namePOS_pairs findIf { ([_x select 1] call fnc_zone_key) isEqualTo _zk };
            if (_ni >= 0) then { _name = (zone_namePOS_pairs select _ni) select 0 };
        };
        if (_name isNotEqualTo "") then { [_name, []] call fnc_enemy_contact };
    };
    // A garrison is never beaten virtually: standing its men up is what renders this attacker to fight them
    // (fnc_site_poller wakes on a virtual one). A town has no undefended case to fall through to -- it changes
    // hands only by having its garrison cleared, and one without a garrison was never a target. Nor has the HQ,
    // which falls only with its officer.
    if (_town >= 0 || {_zk isEqualTo "HQ"} || {([_zk] call fnc_zone_tier) > 0}) exitWith { false };
    // No BLUFOR count: any within K would have rendered the attacker, so its stored force outnumbers nobody. It still
    // holds for DUWS_captureHold, the rule a live attacker meets through the trigger's timeout.
    if ((_t get "inZone") && {(_t get "effForce") > 0} && {time - (_t get "inZoneAt") >= DUWS_captureHold}) then {
        private _zpos = ([_zk] call fnc_site_at) get "pos";
        private _trg = missionNamespace getVariable [format ["trigger_%1_%2", floor abs (_zpos select 0), floor abs (_zpos select 1)], objNull];
        if (!isNull _trg) then { call compile ((triggerStatements _trg) select 1) };
    };
    false
};
