// Locality: server, [] call'd at load. The Arty actions: what is worth shelling and with what pattern
// (opcom_plan.md §Indirect-fire hardpoints). The mission itself is fnc_opcom_fires, which fires what it is handed. AP
// is the ammunition -- the guns rest empty and are loaded per mission -- so the wallet and each gun's cooldown are all
// that limit how often they speak.
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
        || {(DUWS_opcom_attacks findIf { ((_x get "creep") param [0, ""]) isEqualTo _key }) >= 0}
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
        private _guns = count ([_key] call DUWS_fnc_opcom_batteryReady);
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
    params ["_key", "_pt", "_spread", "_eta", "_name"];
    sleep ((_eta - OPCOM_ARTY_WARN) max 0);
    private _mk = createMarker [_name, _pt];
    _mk setMarkerShape "ELLIPSE";
    _mk setMarkerBrush "DiagGrid";
    _mk setMarkerColor "ColorRed";
    _mk setMarkerSize [_spread, _spread];
    private _place = [_pt] call DUWS_fnc_hardpointNearestPlace;
    [localize "STR_DUWS_T_ALLSEER", format [localize "STR_DUWS_T_OPCOM_ARTY_INBOUND", _place]]
        remoteExec ["fnc_duws_dialogue", 0];
    ["critical", [localize "STR_DUWS_T_OPCOM_ARTY_INBOUND_TITLE", format [localize "STR_DUWS_T_OPCOM_ARTY_INBOUND_MSG", _place]]]
        remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated, false];
    // The battery stops firing as its last round leaves the tube, which lands a flight time later.
    waitUntil { sleep 1; !([_key] call DUWS_fnc_opcom_batteryFiring) };
    private _last = 0;
    { _last = _last max (_x getVariable ["DUWS_opcomShotAt", 0]) } forEach ([_key] call DUWS_fnc_opcom_batteryPieces);
    sleep ((_last + _eta - time) max 0);
    deleteMarker _mk;
};

DUWS_fnc_opcom_fireRun = {
    params ["_target"];
    _target params ["_key", "", "_pt", "_rounds", "_shape", "_spread"];
    if !([_pt] call DUWS_fnc_opcom_fireClear) exitWith { false };
    private _eta = [_key, _pt] call DUWS_fnc_opcom_fireETA;
    // Looked up by key: a creep hands no type.
    private _hp = DUWS_hardpoints findIf { (_x select 0) isEqualTo _key };
    private _price = if (_hp < 0) then { 0 } else { OPCOM_AP_PER_ROUND getOrDefault [(DUWS_hardpoints select _hp) select 2, 2] };
    if (([_key, _pt, _rounds, _shape, _price] call DUWS_fnc_opcom_fireMission) <= 0) exitWith { false };
    // One mission per emplacement per tick, so the tick and the key name the marker uniquely.
    [_key, _pt, _spread, _eta, format ["opcom_arty_%1_%2", _key, DUWS_opcom_tick]] spawn DUWS_fnc_opcom_fireWarn;
    true
};

// A creep walks its rounds forward through an offensive's objective ahead of the wave, so it buys that wave's survival
// rather than kills: worth a share of the force the offensive stakes, and scored without odds, since its objective
// stands still where a sighting drifts, which is why a QRF takes none. One creep per offensive.
DUWS_fnc_opcom_creepTargets = {
    private _out = [];
    {
        private _attack = _x;
        private _roles = _attack get "roles";
        if ((_attack get "creep") isEqualTo [] && {_roles isNotEqualTo []} && {(_attack get "kind") isNotEqualTo "qrf"}) then {
            private _pos = _attack get "pos";
            // The wave closes from its first role's rally, or from where that unit stands when it staged in place.
            private _from = (_roles select 0) get "rally";
            if (_from isEqualTo []) then {
                private _us = [_attack, _roles select 0] call DUWS_fnc_opcom_roleUnits;
                _from = if (_us isEqualTo []) then { _pos } else { (_us select 0) get "pos" };
            };
            private _dir = _from getDir _pos;
            private _start = _pos getPos [OPCOM_ARTY_CREEP_LENGTH / 2, _dir + 180];
            _start = [_start select 0, _start select 1, 0];
            private _shape = ["creep", OPCOM_ARTY_CREEP_WIDTH, OPCOM_ARTY_CREEP_LENGTH, _dir];
            private _v = ([_attack] call DUWS_fnc_opcom_boundForce) * OPCOM_AP_PER_FORCE * OPCOM_ARTY_CREEP_SHARE;
            {
                _x params ["_key", "_gpos", "_type"];
                private _guns = count ([_key] call DUWS_fnc_opcom_batteryReady);
                if (_guns > 0 && {!([_key] call DUWS_fnc_opcom_batteryBusy)}
                    && {(_gpos distance2D _pos) <= ([OPCOM_MORTAR_REACH, OPCOM_ARTY_REACH] select (_type isEqualTo "ARTY"))}
                    && {[_start] call DUWS_fnc_opcom_fireClear}) then {
                    ([_shape, _guns] call DUWS_fnc_opcom_creepGrid) params ["_rows", "_perRow"];
                    _out pushBack [[_key, _attack get "id", _start, _shape],
                        _rows * _perRow * _guns * (OPCOM_AP_PER_ROUND getOrDefault [_type, 2]),
                        format ["Creep %1 ahead of the %2 on %3", DUWS_hardpointName getOrDefault [_type, _type], _attack get "kind", _attack get "label"],
                        _v];
                };
            } forEach ([] call DUWS_fnc_opcom_batteries);
        };
    } forEach DUWS_opcom_attacks;
    _out
};

// The creep holds its battery until its offensive launches; the runner fires it then (DUWS_fnc_opcom_creepStep).
DUWS_fnc_opcom_creepRun = {
    params ["_target"];
    _target params ["_key", "_aid", "_start", "_shape"];
    private _i = DUWS_opcom_attacks findIf { (_x get "id") isEqualTo _aid };
    if (_i < 0 || {((DUWS_opcom_attacks select _i) get "creep") isNotEqualTo []}) exitWith { false };
    (DUWS_opcom_attacks select _i) set ["creep", [_key, _start, _shape]];
    true
};

// Called each tick of a launched attack (opcom_plan.md §Chained fires).
DUWS_fnc_opcom_creepStep = {
    params ["_attack"];
    (_attack get "creep") params ["_key", "_start", "_shape"];
    if ([_key] call DUWS_fnc_opcom_batteryFiring) exitWith {};
    private _ok = [[_key, "", _start, 0, _shape, (_shape select 2) max ((_shape select 1) / 2)]] call DUWS_fnc_opcom_fireRun;
    _attack set ["creep", []];
    ["INFO", "OPCOM", format ["attack %1 (%2 %3) creep %4", _attack get "id", _attack get "kind", _attack get "label",
        ["dropped: not every gun could fire", "fired"] select _ok]] call fnc_log;
};
