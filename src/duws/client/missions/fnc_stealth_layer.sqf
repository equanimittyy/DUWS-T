// Locality: runs on each client (the mission thread remoteExecs it to 0, JIP-keyed). setUnitTrait takes a
// LOCAL argument, so the coef must be written on the machine the unit lives on -- a server-side write
// against a remote player silently does nothing.
//
// AI group mates take their leader's value implicitly: they are local to the machine leading them, so the
// local player's score is what reaches the members that machine owns.
//
// Globals, not locals: the Fired handler sees no locals from where it was written. DUWS_stealth_active is
// the server-owned teardown switch, flipped and broadcast by the thread.
params ["_centre", "_radius"];
if (!hasInterface) exitWith {};

// A late joiner whose JIP copy arrives after the mission already ended: nothing to install.
if (!(missionNamespace getVariable ["DUWS_stealth_active", false])) exitWith {};

DUWS_stealth_centre  = _centre;
DUWS_stealth_radius  = _radius;
DUWS_stealth_firedAt = -1e9;
if (isNil "DUWS_stealth_firedUnit") then { DUWS_stealth_firedUnit = objNull };
if (isNil "DUWS_stealth_firedEH")   then { DUWS_stealth_firedEH = -1 };
// Seeded from the debug param, then left alone so a console toggle outlives the next mission.
if (isNil "DUWS_dbgStealthCoef") then {
    DUWS_dbgStealthCoef = (["DUWS_Debug", 0] call BIS_fnc_getParamValue) == 1;
};

[] spawn {
    // A trait persists until overwritten, so a missed restore rides the unit for the rest of the campaign.
    private _release = {
        params ["_u"];
        if (isNull _u) exitWith {};
        private _base = _u getVariable ["DUWS_stealth_base", -1];
        if (_base < 0) exitWith {};
        _u setUnitTrait ["camouflageCoef", _base];
        _u setVariable ["DUWS_stealth_base", nil];
        _u setVariable ["DUWS_stealth_applied", nil];
    };

    private _touched = [];
    private _nextHint = 0;

    while { missionNamespace getVariable ["DUWS_stealth_active", false] } do {
        // A respawn hands out a new unit, so the handler is re-armed against it. Removed by index, never
        // with removeAllEventHandlers, which would strip other systems' Fired handlers from the player.
        if (alive player && { DUWS_stealth_firedUnit != player }) then {
            if (!isNull DUWS_stealth_firedUnit) then {
                DUWS_stealth_firedUnit removeEventHandler ["Fired", DUWS_stealth_firedEH];
            };
            DUWS_stealth_firedUnit = player;
            DUWS_stealth_firedEH = player addEventHandler ["Fired", { DUWS_stealth_firedAt = time }];
        };

        private _coef = [stance player, speed player, time - DUWS_stealth_firedAt] call fnc_stealth_coef;

        // hintSilent, not hint, because this repeats and hint clicks every time.
        if ((missionNamespace getVariable ["DUWS_dbgStealthCoef", false]) && { time > _nextHint }) then {
            _nextHint = time + 1;
            private _inRing = (player distance2D DUWS_stealth_centre) <= DUWS_stealth_radius;
            private _ago = time - DUWS_stealth_firedAt;
            // Score and live trait both: they part company whenever the unit does not qualify for a write.
            hintSilent parseText format [
                "<t size='1.4'>Stealth %1   live %2</t><br/>%3 | %4 km/h | fired %5<br/><t color='%6'>%7</t>",
                _coef toFixed 2,
                (player getUnitTrait "camouflageCoef") toFixed 2,
                toLower (stance player),
                (abs (speed player)) toFixed 1,
                if (_ago > 5) then { "--" } else { (_ago toFixed 1) + "s" },
                ["#ff8080", "#80ff80"] select _inRing,
                ["outside circle, not applied", "inside circle"] select _inRing
            ];
        };

        {
            private _u = _x;
            // A mounted unit is skipped: the trait would land on the vehicle's effective commander.
            if (!alive _u
                || { !isNull objectParent _u }
                || { (_u distance2D DUWS_stealth_centre) > DUWS_stealth_radius }) then {
                [_u] call _release;
            } else {
                if ((_u getVariable ["DUWS_stealth_base", -1]) < 0) then {
                    _u setVariable ["DUWS_stealth_base", _u getUnitTrait "camouflageCoef"];
                    _touched pushBackUnique _u;
                };
                // setUnitTrait carries a global effect, so an unchanged rewrite is pure network traffic.
                if (abs ((_u getVariable ["DUWS_stealth_applied", -1]) - _coef) > 0.01) then {
                    _u setUnitTrait ["camouflageCoef", _coef];
                    _u setVariable ["DUWS_stealth_applied", _coef];
                };
            };
        } forEach ([player] + ((units group player) select { local _x && { !isPlayer _x } }));

        sleep 0.5;
    };

    { [_x] call _release } forEach _touched;
    if (!isNull DUWS_stealth_firedUnit) then {
        DUWS_stealth_firedUnit removeEventHandler ["Fired", DUWS_stealth_firedEH];
        DUWS_stealth_firedUnit = objNull;
        DUWS_stealth_firedEH = -1;
    };
};
