// Locality: server -- the safehouse HitPart (fnc_raid_safehouse_arm) remoteExecs it to target 2. It owns
// what the shot means: unlock the doors, and either wake the cache guards (real) or bill the raid on an
// innocent home (decoy). Idempotent -- the first hit breaches, the rest no-op.
if (!isServer) exitWith {};
params ["_house", ["_shooter", objNull]];
if (isNull _house) exitWith {};
if (!(missionNamespace getVariable ["DUWS_safehouse_active", false])) exitWith {};
if (_house getVariable ["DUWS_safehouse_breached", false]) exitWith {};
_house setVariable ["DUWS_safehouse_breached", true, true];

// Lift the lock (bis_disabled_Door_N suppresses the engine's open action) and swing the leaves open on
// every machine -- animateDoor is local-effect, so it has to run everywhere the door is drawn.
for "_i" from 1 to 10 do { _house setVariable [format ["bis_disabled_Door_%1", _i], 0, true] };
[[_house], { params ["_h"]; for "_i" from 1 to 10 do { _h animateDoor [format ["Door_%1_rot", _i], 1] } }] remoteExec ["BIS_fnc_call", 0];

if (_house getVariable ["DUWS_safehouse_real", false]) then {
    // Guards do not turn the instant the door goes: a 0-12 s fuse lets the cell read as reacting to the
    // raid rather than tripping a switch. They wake to EAST, elite, carrying OPFOR-armory automatics.
    private _guards = missionNamespace getVariable ["DUWS_safehouse_guards", []];
    [_guards] spawn {
        params ["_guards"];
        sleep (random 12);   // TUNABLE
        private _live = _guards select { alive _x };
        if (_live isEqualTo []) exitWith {};
        private _grp = [_live, "opfor_auto", 1] call fnc_civ_flip_hostile;
        // Reveal the raiders so the cell engages on turn, not when it happens to spot them (mob pattern).
        if (!isNull _grp) then {
            { _grp reveal [_x, 4] } forEach (allUnits select { alive _x && {_x isKindOf "CAManBase"} && {side group _x == west} });
        };
    };
} else {
    // Wrong house: kicking in a home full of civilians costs town standing, once per house. Their deaths,
    // if the raiders open up, bill again through the normal civ handler -- this is the cost of the raid itself.
    private _ti = _house getVariable ["DUWS_safehouse_townIndex", -1];
    if (_ti >= 0) then { [_ti, -1, "raid_safehouse_wrong_house"] call fnc_town_rep_adjust };   // TUNABLE
    { if (alive _x) then { [_x, _shooter] call fnc_civ_panic } } forEach (_house getVariable ["DUWS_safehouse_occupants", []]);
};
