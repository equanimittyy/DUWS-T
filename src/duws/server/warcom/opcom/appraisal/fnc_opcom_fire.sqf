// Locality: server, [] call'd at load. The Arty actions: what is worth shelling and with what pattern
// (opcom_plan.md §Indirect-fire hardpoints). The mission itself is fnc_opcom_fires, which fires what it is handed. AP
// is the ammunition -- the guns rest empty and are loaded per mission -- so the wallet is the only limit on how often
// they speak.
if (!isServer) exitWith {};

// Never aimed at the player HQ, and never onto OPFOR's own zone, which is full of its garrison. Re-read immediately
// before the guns fire: the point is latched at order time, so nothing may walk into the circle behind it.
DUWS_fnc_opcom_fireClear = {
    params ["_pos"];
    if (!isNil "PosOfBLUHQ" && {PosOfBLUHQ isNotEqualTo []} && {(_pos distance2D PosOfBLUHQ) < OPCOM_ARTY_HQ_CLEAR}) exitWith { false };
    (zone_meta_array findIf {
        ((_pos distance2D (_x select 1)) <= (_x select 2)) && {!([[_x select 1] call fnc_zone_key] call fnc_zone_bluforHeld)}
    }) < 0
};

// [[pos, believed force, P(win)], ...]: a sighting fresh enough to still be there. Belief only -- OPFOR shells
// what it has seen, never ground it merely owns eyes near, so a gun is as blind as the commander's sensors are.
// A sighting's odds are its freshness, because a fading one has probably moved.
DUWS_fnc_opcom_fireTargetsSeen = {
    private _out = [];
    {
        if ([_x] call DUWS_fnc_opcom_beliefIsSighting) then {
            private _age = DUWS_opcom_tick - (DUWS_opcom_belief_time select _forEachIndex);
            private _pos = DUWS_opcom_belief_pos select _forEachIndex;
            if (_age <= OPCOM_BELIEF_FRESH && {[_pos] call DUWS_fnc_opcom_fireClear}) then {
                _out pushBack [_pos, DUWS_opcom_belief_str select _forEachIndex,
                    1 - ((_age / OPCOM_BELIEF_EXPIRE) min 1)];
            };
        };
    } forEach DUWS_opcom_belief_key;
    _out
};

DUWS_fnc_opcom_batteryFiring = {
    params ["_key"];
    (([_key] call DUWS_fnc_opcom_batteryPieces) findIf { (_x getVariable ["DUWS_opcomFireEH", -1]) >= 0 }) >= 0
};

// A firing battery sits out, since the first mission's end would strip a second's Fired handler and empty its gun, and
// so does one a creep holds for an offensive still to launch.
DUWS_fnc_opcom_batteryBusy = {
    params ["_key"];
    [_key] call DUWS_fnc_opcom_batteryFiring
        || {(DUWS_opcom_intents findIf { (_x get "action") isEqualTo "arty_creeping" && {(_x get "target") isEqualTo _key} }) >= 0}
};

DUWS_fnc_opcom_fireTargets = {
    if (isNil "DUWS_opcom_grid_w") exitWith { [] };
    private _seen = call DUWS_fnc_opcom_fireTargetsSeen;
    if (_seen isEqualTo []) exitWith { [] };
    private _total = 0;
    { _total = _total + (_x select 1) } forEach _seen;
    private _out = [];
    {
        _x params ["_key", "_gpos", "_type"];
        private _guns = count ([_key] call DUWS_fnc_opcom_batteryPieces);
        if (_guns > 0 && {!([_key] call DUWS_fnc_opcom_batteryBusy)}) then {
            private _range = [OPCOM_MORTAR_REACH, OPCOM_ARTY_REACH] select (_type isEqualTo "ARTY");
            private _lethal = OPCOM_ARTY_LETHAL getOrDefault [_type, 20];
            private _perRound = OPCOM_AP_PER_ROUND getOrDefault [_type, 2];
            (OPCOM_ARTY_ROUNDS getOrDefault [_type, [4, 8]]) params ["_lo", "_hi"];
            private _rounds = _lo + floor random (_hi - _lo + 1);
            private _fired = _rounds * _guns;
            private _cover = [_lethal, _fired] call DUWS_fnc_opcom_artyReach;
            {
                _x params ["_pos", "", "_pw"];
                private _d = _gpos distance2D _pos;
                if (_d <= _range) then {
                    private _spread = [OPCOM_ARTY_SPREAD getOrDefault [_type, 50], _d] call DUWS_fnc_opcom_artySpread;
                    _out pushBack [[_key, _type, +_pos, _rounds, ["saturate", _spread], _spread], _fired * _perRound,
                        format ["Shell %1 from %2", mapGridPosition _pos, DUWS_hardpointName getOrDefault [_type, _type]],
                        [_pos, _cover, _spread, _seen, _total] call DUWS_fnc_opcom_artyValue, _pw];
                };
            } forEach _seen;
        };
    } forEach ([] call DUWS_fnc_opcom_batteries);
    _out
};

// The telegraph: an Allseer call and a marker on the ground about OPCOM_ARTY_WARN seconds out, so a barrage is
// something players can walk out of rather than a death from nowhere.
DUWS_fnc_opcom_fireWarn = {
    params ["_pt", "_spread", "_eta", "_name"];
    sleep ((_eta - OPCOM_ARTY_WARN) max 0);
    private _mk = createMarker [_name, _pt];
    _mk setMarkerShape "ELLIPSE";
    _mk setMarkerBrush "DiagGrid";
    _mk setMarkerColor "ColorRed";
    _mk setMarkerSize [_spread, _spread];
    [localize "STR_DUWS_T_ALLSEER", format [localize "STR_DUWS_T_OPCOM_ARTY_INBOUND", [_pt] call DUWS_fnc_hardpointNearestPlace]]
        remoteExec ["fnc_duws_dialogue", 0];
    sleep OPCOM_ARTY_MARK;
    deleteMarker _mk;
};

DUWS_fnc_opcom_fireRun = {
    params ["_target"];
    _target params ["_key", "", "_pt", "_rounds", "_shape", "_spread"];
    if !([_pt] call DUWS_fnc_opcom_fireClear) exitWith { false };
    private _eta = [_key, _pt] call DUWS_fnc_opcom_fireETA;
    if (([_key, _pt, _rounds, _shape] call DUWS_fnc_opcom_fireMission) <= 0) exitWith { false };
    // One mission per emplacement per tick, so the tick and the key name the marker uniquely.
    [_pt, _spread, _eta, format ["opcom_arty_%1_%2", _key, DUWS_opcom_tick]] spawn DUWS_fnc_opcom_fireWarn;
    true
};

// A creep walks its rounds forward through an offensive's objective ahead of the wave, so it buys that wave's survival
// rather than kills: worth a share of the force the offensive stakes, and scored without odds, since its objective
// stands still where a sighting drifts. One creep per offensive.
DUWS_fnc_opcom_creepTargets = {
    private _crept = (DUWS_opcom_intents select { (_x get "action") isEqualTo "arty_creeping" }) apply { _x get "parent" };
    private _out = [];
    {
        private _intent = _x;
        private _roles = _intent get "roles";
        if ((_intent get "action") isEqualTo "attack" && {(_intent get "state") in ["buildup", "execution"]}
            && {!((_intent get "id") in _crept)} && {_roles isNotEqualTo []}) then {
            private _pos = _intent get "pos";
            // The wave closes from its first role's rally, or from where that unit stands when it staged in place.
            private _from = (_roles select 0) get "rally";
            if (_from isEqualTo []) then {
                private _t = [_intent, _roles select 0] call DUWS_fnc_opcom_roleUnit;
                _from = if (isNil "_t") then { _pos } else { _t get "pos" };
            };
            private _dir = _from getDir _pos;
            private _start = _pos getPos [OPCOM_ARTY_CREEP_LENGTH / 2, _dir + 180];
            _start = [_start select 0, _start select 1, 0];
            private _shape = ["creep", OPCOM_ARTY_CREEP_WIDTH, OPCOM_ARTY_CREEP_LENGTH, _dir];
            private _v = ([_intent] call DUWS_fnc_opcom_boundForce) * OPCOM_AP_PER_FORCE * OPCOM_ARTY_CREEP_SHARE;
            {
                _x params ["_key", "_gpos", "_type"];
                private _guns = count ([_key] call DUWS_fnc_opcom_batteryPieces);
                if (_guns > 0 && {!([_key] call DUWS_fnc_opcom_batteryBusy)}
                    && {(_gpos distance2D _pos) <= ([OPCOM_MORTAR_REACH, OPCOM_ARTY_REACH] select (_type isEqualTo "ARTY"))}
                    && {[_start] call DUWS_fnc_opcom_fireClear}) then {
                    ([_shape, _guns] call DUWS_fnc_opcom_creepGrid) params ["_rows", "_perRow"];
                    _out pushBack [[_key, _intent get "id", _start, _shape],
                        _rows * _perRow * _guns * (OPCOM_AP_PER_ROUND getOrDefault [_type, 2]),
                        format ["Creep %1 ahead of the attack on %2", DUWS_hardpointName getOrDefault [_type, _type], _intent get "label"],
                        _v];
                };
            } forEach ([] call DUWS_fnc_opcom_batteries);
        };
    } forEach DUWS_opcom_intents;
    _out
};

// The creep holds its battery until its offensive launches; the runner fires it then (DUWS_fnc_opcom_creepStep).
DUWS_fnc_opcom_creepRun = {
    params ["_target"];
    _target params ["_key", "_pid", "_start", "_shape"];
    private _i = DUWS_opcom_intents findIf { (_x get "id") isEqualTo _pid };
    if (_i < 0 || {!(((DUWS_opcom_intents select _i) get "state") in ["buildup", "execution"])}) exitWith { false };
    private _intent = ["arty_creeping", _key, [], [], "buildup", _start, (DUWS_opcom_intents select _i) get "label"]
        call DUWS_fnc_opcom_intentOpen;
    _intent set ["parent", _pid];
    _intent set ["shape", _shape];
    true
};

// The only chain edge (opcom_plan.md §Chained fires): the creep fires once its offensive launches and its guns are
// free. An offensive that ends first takes the creep with it, the AP spent at commit as a lost truck's is.
DUWS_fnc_opcom_creepStep = {
    params ["_intent"];
    private _i = DUWS_opcom_intents findIf { (_x get "id") isEqualTo (_intent get "parent") };
    private _state = if (_i < 0) then { "done" } else { (DUWS_opcom_intents select _i) get "state" };
    if (_state isEqualTo "done") exitWith { [_intent, "dropped: its offensive ended before it launched"] call DUWS_fnc_opcom_intentClose };
    if (_state isNotEqualTo "execution" || {[_intent get "target"] call DUWS_fnc_opcom_batteryFiring}) exitWith {};
    private _shape = _intent get "shape";
    private _ok = [[_intent get "target", "", _intent get "pos", 0, _shape, (_shape select 2) max ((_shape select 1) / 2)]]
        call DUWS_fnc_opcom_fireRun;
    [_intent, ["dropped: no gun could fire", "fired"] select _ok] call DUWS_fnc_opcom_intentClose;
};
