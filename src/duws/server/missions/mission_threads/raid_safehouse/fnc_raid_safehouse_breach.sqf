// Locality: server -- fnc_raid_safehouse_arm (a shot) and the thread's entry watcher (a raider inside)
// route here. It owns what a breach means: unlock the door and, the first time the house is cracked, wake
// the cache guards (real) or bill the raid on an innocent home (decoy).
//
// A breach only unlocks the door; the player then opens it with the engine action. A scripted animateDoor
// broadcast to every machine swung unreliably, so the leaf is left to the engine, which the unlock re-enables.
//
// _door: a door_<n>_rot source to unlock, "ALL" for an entry breach (unlock the lot), or "" when the shot
// hit no resolvable door (unlock the next still-locked one). Unlocking is idempotent -- a re-hit on an
// unlocked door does nothing and does not re-fire the outcome, which lands once.
if (!isServer) exitWith {};
params ["_house", ["_door", ""]];
if (isNull _house) exitWith {};
if (!(missionNamespace getVariable ["DUWS_safehouse_active", false])) exitWith {};

private _doors    = [_house] call fnc_house_doors;
private _unlocked = _house getVariable ["DUWS_safehouse_unlockedDoors", []];
private _locked   = _doors select { !(_x in _unlocked) };

// The door(s) this call unlocks. A specific still-locked door unlocks alone; "ALL" or an unresolved hit
// unlocks the next locked door (entry unlocks the lot) -- never a second door on one shot, so each stays a
// separate breach.
private _toUnlock = switch (true) do {
    case (_door == "ALL"): { _locked };
    case (_door != "" && {_door in _locked}): { [_door] };
    case (_door == ""): { [_locked param [0, ""]] - [""] };
    default { [] };
};

{
    _house setVariable [format ["bis_disabled_Door_%1", parseNumber (_x select [5])], 0, true];   // lift the lock; the engine open action returns
    _unlocked pushBackUnique _x;
} forEach _toUnlock;
if !(_toUnlock isEqualTo []) then {
    _house setVariable ["DUWS_safehouse_unlockedDoors", _unlocked, true];
};

// Outcome once, on the first crack -- a door unlocked, or an entry breach with the doors already unlocked.
if (_house getVariable ["DUWS_safehouse_breached", false]) exitWith {};
if (_toUnlock isEqualTo [] && {_door != "ALL"}) exitWith {};
_house setVariable ["DUWS_safehouse_breached", true, true];

// Occupants are PATH-frozen at spawn; release the breached house's so it reacts only once cracked.
{ _x enableAI "PATH" } forEach (_house getVariable ["DUWS_safehouse_occupants", []]);

{ [localize "STR_DUWS_T_RAID_SAFEHOUSE_BREACHED"] remoteExec ["hint", _x] } forEach (allPlayers select { _x distance _house < 50 });

if (_house getVariable ["DUWS_safehouse_real", false]) then {
    // Guards do not turn the instant the door goes: a 0-12 s fuse lets the cell read as reacting to the
    // raid rather than tripping a switch. They wake to EAST, elite, carrying OPFOR-armory automatics.
    private _guards = missionNamespace getVariable ["DUWS_safehouse_guards", []];
    [_guards] spawn {
        params ["_guards"];
        sleep (random 12);   // TUNABLE
        private _live = _guards select { alive _x };
        if (_live isEqualTo []) exitWith {};
        private _grp = [_live, "EAST", "opfor", ["vest", "pistol", ["submachinegun", "assault_rifle", "NONE"]], [true, 1]] call fnc_civ_arm;
        if (isNull _grp) exitWith {};
        // Reveal the raiders so the cell engages on turn, not when it happens to spot them. It keeps holding
        // the house: each guard's fnc_holdBuildingPost loop (started at spawn) survives the flip, so with
        // COMBAT set by fnc_civ_arm they fight from the building's positions rather than charging the street.
        { _grp reveal [_x, 4] } forEach (allUnits select { alive _x && {_x isKindOf "CAManBase"} && {side group _x == west} });
    };
} else {
    // Wrong house: kicking in an innocent home costs town standing, once per house. The occupants hold
    // where they were rather than bolting -- a room of locals who stand their ground reads the same as the
    // cache's hidden guards, so the raiders cannot tell a decoy until they commit. Killing them still bills
    // through the normal civ handler: the raid's own cost.
    private _ti = _house getVariable ["DUWS_safehouse_townIndex", -1];
    if (_ti >= 0) then { [_ti, -1, "raid_safehouse_wrong_house"] call fnc_town_rep_adjust };   // TUNABLE
};
