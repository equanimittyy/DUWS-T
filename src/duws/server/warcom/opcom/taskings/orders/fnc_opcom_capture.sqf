// Locality: server, [] call'd at load. The capture order: march on BLUFOR-held ground -- a zone, a town they
// have garrisoned, or their HQ -- report the crossing into it, and settle once it has changed hands.
if (!isServer) exitWith {};

// The target's town index, or -1 for a zone or the HQ. A town changes hands only by having its garrison cleared,
// where a zone flips on presence, and four steps below turn on that difference.
DUWS_fnc_opcom_captureTown = {
    params ["_key"];
    if ((_key select [0, 5]) isEqualTo "town_") exitWith { parseNumber (_key select [5]) };
    -1
};

// -> whether the target is still BLUFOR's: a zone by the control list, a town by the band its tier belongs to. The
// HQ never changes hands, so it falls with its officer, whose death is already the HQ's lose condition.
DUWS_fnc_opcom_captureHolds = {
    params ["_key"];
    if (_key isEqualTo "HQ") exitWith { !isNil "hq_blu1" && {alive hq_blu1} };
    private _i = [_key] call DUWS_fnc_opcom_captureTown;
    if (_i >= 0) exitWith { ([_i] call fnc_town_garrison_ownerAt) isEqualTo "BLU" };
    [_key] call fnc_zone_bluforHeld
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
// holds the ground rather than joining a reserve pool that no longer exists. OPFOR has no pool at the HQ either, so
// an HQ attacker guards wherever it stands.
DUWS_fnc_opcom_captureEnd = {
    params ["_t", "_pos", "_grp"];
    private _zk = _t get "targetZone";
    private _site = [_zk] call fnc_site_at;
    _t set ["targetZone", ""];
    _t deleteAt "inZoneAt";
    if ((_pos distance2D (_site get "pos")) > (_site get "radius")) exitWith {
        _t set ["hold", 0];
        if (_zk isEqualTo "HQ" || {!([_t, "return", _site get "pos", _zk] call fnc_opcom_task)}) then { [_t, "guard"] call fnc_opcom_task };
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
