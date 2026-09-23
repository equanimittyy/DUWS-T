// Locality: server, [] call'd at load. The capture order: march on a BLUFOR-held zone, report the crossing into
// it, and settle once it has flipped.
if (!isServer) exitWith {};

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

// -> true if it garrisoned. A live attacker inside the zone guards until it stows, so it never vanishes in front of a
// player; one still on the road re-garrisons there.
DUWS_fnc_opcom_captureEnd = {
    params ["_t", "_pos", "_grp"];
    private _zk = _t get "targetZone";
    private _site = [_zk] call fnc_site_at;
    _t set ["targetZone", ""];
    _t deleteAt "inZoneAt";
    if ((_pos distance2D (_site get "pos")) > (_site get "radius")) exitWith {
        _t set ["hold", 0];
        if !([_t, "move", _site get "pos", _zk] call fnc_opcom_task) then { [_t, "guard"] call fnc_opcom_task };
        false
    };
    if (isNull _grp) exitWith { [_t, _zk] call DUWS_fnc_opcom_garrisonInto; true };
    _t set ["order", "guard"]; _t set ["target", _pos]; _t set ["route", []]; _t set ["settleZone", _zk];
    [_grp, "guard", _pos] call DUWS_fnc_opcom_applyOrder;
    ["INFO", "OPCOM", format ["capture: tasking %1 holds %2, garrisoning when it stows", _t get "id", _zk]] call fnc_log;
    false
};

DUWS_fnc_opcom_stepCapture = {
    params ["_t", "_ctx"];
    _ctx params ["_pos", "_grp", "_live"];
    private _zk = _t get "targetZone";
    if (!([_zk] call fnc_zone_bluforHeld)) exitWith { [_t, _pos, _grp] call DUWS_fnc_opcom_captureEnd };
    private _entered = [_t, _pos] call DUWS_fnc_opcom_captureEnters;
    // Below is the virtual attacker's stand-in for a fight that never renders; a live one takes the zone by winning it.
    if (_live) exitWith { false };
    if (_entered) then {
        private _ni = zone_namePOS_pairs findIf { ([_x select 1] call fnc_zone_key) isEqualTo _zk };
        if (_ni >= 0) then { [(zone_namePOS_pairs select _ni) select 0, []] call fnc_enemy_contact };
    };
    // A garrisoned zone is never taken virtually: standing its men up is what renders this attacker to fight
    // them (fnc_site_poller wakes on a virtual one). Below is the undefended case alone.
    if (([_zk] call fnc_zone_tier) > 0) exitWith { false };
    // No BLUFOR count: any within K would have rendered the attacker, so its stored force outnumbers nobody. It still
    // holds for DUWS_captureHold, the rule a live attacker meets through the trigger's timeout.
    if ((_t get "inZone") && {(_t get "effForce") > 0} && {time - (_t get "inZoneAt") >= DUWS_captureHold}) then {
        private _zpos = ([_zk] call fnc_site_at) get "pos";
        private _trg = missionNamespace getVariable [format ["trigger_%1_%2", floor abs (_zpos select 0), floor abs (_zpos select 1)], objNull];
        if (!isNull _trg) then { call compile ((triggerStatements _trg) select 1) };
    };
    false
};
