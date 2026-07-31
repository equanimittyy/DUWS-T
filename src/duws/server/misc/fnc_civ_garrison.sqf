// Locality: server -- spawned per town from server/misc/fnc_civ_init_Tomata.sqf.
if (!isServer) exitWith {};

params ["_townIndex"];

// RAVAGE and WBK register no town reputation, so no town ever enters the OPFOR band and this
// thread would spin for the campaign doing nothing.
if (CIV_PRESENCE == "RAVAGE" || CIV_PRESENCE == "WBK") exitWith {};

private _locations = missionNamespace getVariable ["civ_locations", []];
if (_townIndex >= count _locations) exitWith {};

private _centre = getPos (_locations select _townIndex);
private _radius = (missionNamespace getVariable ["civ_radii", []]) param [_townIndex, 300];

// Units only. A town gets no fortification ring and no prefab: the static emplacements are what
// make a zone an objective, and a town must not compete with one for the player's attention.
private _fnc_spawnTier = {
    params ["_tier"];
    [_centre, _radius] spawn fnc_createoppatrol2;
    sleep 5;
    [_centre, _radius] spawn fnc_createopteam2;
    if (_tier >= 2) then {
        sleep 5;
        [_centre, _radius] spawn fnc_createopteam2;
        sleep 5;
        [OPFOR_Faction_X, "car", _centre, _radius] spawn fnc_random_veh;
    };
    if (_tier >= 3) then {
        sleep 5;
        [OPFOR_Faction_X, "armored", _centre, _radius] spawn fnc_random_veh;
    };
};

// SEIZED is the engine's own "this side present, the opposing side absent" test, which is what
// lets this work at all: the three spawners are fire-and-forget and register nothing, so there
// is no group handle to watch die. The interruptable timeout restarts if OPFOR walk back in, so
// the town has to be held clear rather than sprinted through.
// Whether CIVILIAN-side units block SEIZED is unconfirmed; if they do, this needs a plain
// condition trigger counting hostile units in thisList instead.
private _fnc_makeClearTrigger = {
    private _trg = createTrigger ["EmptyDetector", _centre, false];
    _trg setTriggerArea [_radius, _radius, 0, false];
    _trg setTriggerActivation ["WEST SEIZED", "PRESENT", true];
    _trg setTriggerTimeout [30, 40, 50, true];
    _trg setTriggerStatements ["this", "", ""];
    _trg
};

// OPFOR standing inside the trigger's own area, which is what makes the town clearable. SEIZED is
// satisfied by an empty town as readily as by a fought-out one, so nothing else can tell the two
// apart.
private _fnc_opforPresent = {
    ({side _x == EAST} count (_centre nearEntities [["CAManBase"], _radius])) > 0
};

private _garrisoned = false;
private _trg = objNull;

while {true} do {
    sleep 30;

    private _rep = [_townIndex] call fnc_civ_repAt;

    if (!_garrisoned) then {
        if (_rep <= -10) then {
            // Presence is decided the way zones decide it: a five-second re-test after first
            // contact, so grazing the perimeter does not commit a garrison for someone already
            // leaving. Waiting for arrival at all is what keeps the map free of standing units.
            if ([_centre, _radius + 400] call fnc_duws_bluforNear) then {
                sleep 5;
                if ([_centre, _radius + 400] call fnc_duws_bluforNear) then {
                    private _tier = 1;
                    if (_rep <= -15) then { _tier = 2 };
                    if (_rep <= -20) then { _tier = 3 };
                    [_tier] spawn _fnc_spawnTier;
                    // Armed only once the garrison is standing in it. The three spawners are
                    // scheduled and each resolves a safe position before it places anything, so
                    // for the first half-minute the town holds the player and nobody else -- and
                    // that is precisely what WEST SEIZED reports as cleared. A trigger armed
                    // beside the spawn therefore hands the town its whole reputation debt back
                    // for a garrison nobody fought, which reads in play as reputation climbing
                    // out of the negative band on its own from standing in the town.
                    private _deadline = diag_tickTime + 60;
                    waitUntil { sleep 2; (call _fnc_opforPresent) || {diag_tickTime > _deadline} };
                    if (call _fnc_opforPresent) then {
                        _trg = call _fnc_makeClearTrigger;
                        _garrisoned = true;
                        ["INFO", "CIV", format ["Garrison tier %1 spawned at town %2 (rep %3)", _tier, _townIndex, _rep]] call fnc_log;
                    } else {
                        // Left un-garrisoned rather than credited: the band is still the
                        // condition, so the next pass tries again.
                        ["WARN", "CIV", format ["Garrison tier %1 at town %2 placed no OPFOR within %3 m in 60 s; not armed", _tier, _townIndex, _radius]] call fnc_log;
                    };
                };
            };
        };
    } else {
        // Out of the band by aid or heals rather than by a fight: the band is the condition, so
        // the garrison has no business being there. How those units leave is the retreat
        // behaviour, not a deletion sweep -- until it lands they are left to the map cleanup.
        if (_rep > -10) then {
            deleteVehicle _trg;
            _garrisoned = false;
            ["INFO", "CIV", format ["Town %1 left the OPFOR band at rep %2; garrison released", _townIndex, _rep]] call fnc_log;
        } else {
            if (!isNull _trg && {triggerActivated _trg}) then {
                deleteVehicle _trg;
                _garrisoned = false;
                // Clearing the garrison discharges the whole debt at once. That is deliberate:
                // the alternative is a town the player can permanently ruin with no route back,
                // which is what passive recovery used to prevent. The garrison is the price.
                [_townIndex, -_rep, "garrison_cleared"] call fnc_town_rep_adjust;
                ["INFO", "CIV", format ["Town %1 cleared; reputation reset from %2", _townIndex, _rep]] call fnc_log;
            };
        };
    };
};
