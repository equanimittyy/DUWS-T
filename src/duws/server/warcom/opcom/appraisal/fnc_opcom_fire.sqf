// Locality: server, [] call'd at load. The Arty action: what is worth shelling, with what pattern, and the rest the
// gun takes after (opcom_plan.md §Indirect-fire hardpoints). The mission itself is fnc_opcom_fires, which fires what
// it is handed. AP is the ammunition -- the guns rest empty and are loaded per mission -- so the wallet is the only
// limit on how often they speak.
if (!isServer) exitWith {};

// Tick each emplacement is loaded again, keyed by hardpoint.
DUWS_opcom_gunReady = createHashMap;

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
        if (_guns > 0 && {DUWS_opcom_tick >= (DUWS_opcom_gunReady getOrDefault [_key, 0])}) then {
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
    _target params ["_key", "_type", "_pt", "_rounds", "_shape", "_spread"];
    if !([_pt] call DUWS_fnc_opcom_fireClear) exitWith { false };
    private _eta = [_key, _pt] call DUWS_fnc_opcom_fireETA;
    if (([_key, _pt, _rounds, _shape] call DUWS_fnc_opcom_fireMission) <= 0) exitWith { false };
    (OPCOM_ARTY_COOLDOWN getOrDefault [_type, [300, 480]]) params ["_lo", "_hi"];
    DUWS_opcom_gunReady set [_key, DUWS_opcom_tick + _lo + floor random (_hi - _lo + 1)];
    // One mission per emplacement per tick, so the tick and the key name the marker uniquely.
    [_pt, _spread, _eta, format ["opcom_arty_%1_%2", _key, DUWS_opcom_tick]] spawn DUWS_fnc_opcom_fireWarn;
    true
};
