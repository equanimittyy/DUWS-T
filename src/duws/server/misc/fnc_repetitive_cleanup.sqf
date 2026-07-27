// Locality: server -- inherited from server/server_init.sqf.
/*
    NAME: misc\repetitive_cleanup.sqf
    VERSION: 1.9

    DESCRIPTION:
    Can delete everything that is not really needed
    dead bodies, dropped items, smokes, chemlights, explosives, empty groups
    Nothing is deleted within KEEP_RADIUS of a player, whatever its age.

    USAGE:
    in server's init
    [
        60, // seconds to delete dead bodies (0 means don't delete)
        5*60, // seconds to delete dead vehicles (0 means don't delete)
        3*60, // seconds to delete immobile vehicles (0 means don't delete)
        2*60, // seconds to delete dropped weapons (0 means don't delete)
        10*60, // seconds to deleted planted explosives (0 means don't delete)
        0 // seconds to delete dropped smokes/chemlights (0 means don't delete)
    ] execVM 'misc\repetitive_cleanup.sqf';

    will delete dead bodies after 60 seconds (1 minute)
    will delete dead vehicles after 5*60 seconds (5 minutes)
    will delete immobile vehicles after 3*60 seconds (3 minutes)
    will delete weapons after 2*60 seconds (2 minutes)
    will delete planted explosives after 10*60 seconds (10 minutes)
    will not delete any smokes/chemlights since its disabled (set to 0)

    If you want something to withstand the clean up, paste this into it's init:
    this setVariable["persistent",true];
*/

if (!isServer) exitWith {}; // isn't server         

#define PUSH(A,B) A set [count (A),B];
#define REM(A,B) A=A-[B];

private ["_ttdBodies","_ttdVehiclesDead","_ttdVehiclesImmobile","_ttdWeapons","_ttdPlanted","_ttdSmokes","_addToCleanup","_objectsToCleanup","_timesWhenToCleanup","_removeFromCleanup","_census","_pass","_ttdDroppedGear"];

// Nothing inside this of a player is deleted, however old it is. A wreck or a body blinking
// out on screen reads as a bug, and the whole point of a lifetime is that it expires out of
// sight. Every category funnels through one deletion point, so this is enforced in one place.
#define KEEP_RADIUS 300

// Passes between census log lines. The census is the one part of this that cannot be checked
// offline -- allMissionObjects is documented around mission- and script-created objects, and a
// dropped rifle's holder is created by the engine. A zero here with combat behind you means the
// census does not see them and discovery has to go back to searching from unit positions.
#define LOG_EVERY 30

_ttdBodies=[_this,0,0,[0]] call BIS_fnc_param;
_ttdVehiclesDead=[_this,1,0,[0]] call BIS_fnc_param;
_ttdVehiclesImmobile=[_this,2,0,[0]] call BIS_fnc_param;
_ttdWeapons=[_this,3,0,[0]] call BIS_fnc_param;
_ttdPlanted=[_this,4,0,[0]] call BIS_fnc_param;
_ttdSmokes=[_this,5,0,[0]] call BIS_fnc_param;
_ttdDroppedGear=[_this,6,0,[0]] call BIS_fnc_param;

if({_x>0}count _this==0) exitWith {}; // all times are 0, we do not want to run this script at all

_objectsToCleanup=[];
_timesWhenToCleanup=[];

_addToCleanup = {
    _object = _this select 0;
    if(!(_object getVariable["persistent",false])) then {
        _newTime = (_this select 1)+time;
        _index = _objectsToCleanup find _object;
        if(_index == -1) then {
            PUSH(_objectsToCleanup,_object)
            PUSH(_timesWhenToCleanup,_newTime)
        } else {
            _currentTime = _timesWhenToCleanup select _index;
            if(_currentTime>_newTime) then {
                _timesWhenToCleanup set[_index, _newTime];
            };
        };
    };
};

_removeFromCleanup = {
    _object = _this select 0;
    _index = _objectsToCleanup find _object;
    if(_index != -1) then {
        _objectsToCleanup set[_index, 0];
        _timesWhenToCleanup set[_index, 0];
    };
};

_pass = 0;

while{true} do {
    // Interruptible interval, not a flat sleep 10: a forced sweep asked for just after a pass
    // began waiting would otherwise sit out the whole interval, and a debug button that does
    // nothing for ten seconds reads as broken. Gated on time rather than a counted poll so the
    // interval still tracks setTimeMultiplier exactly as the sleep it replaces did. Polling one
    // boolean twice a second is free next to the census below.
    private _nextPass = time + 10;
    waitUntil { sleep 0.5; DUWS_cleanup_force || {time >= _nextPass} };
    _census = 0;

    // A census, not a search. nearObjects only answers "what is within X of here", so finding
    // this junk used to mean sweeping a 100 m radius from every unit in the mission -- four
    // sweeps each, every 10 s, with squadmates re-asking about the same ground. That was both
    // the largest sustained cost here and incomplete: litter from a firefight nobody survived
    // was never near a unit again, so it was never found and never deleted.
    if (_ttdWeapons>0) then {
        // Deduped across the three names: if allMissionObjects matches subclasses they overlap,
        // and the census below is only worth logging if it counts holders rather than queries.
        private _holders = [];
        {
            private _type = _x;
            { _holders pushBackUnique _x } forEach (allMissionObjects _type);
        } forEach ["WeaponHolder","GroundWeaponHolder","WeaponHolderSimulated"];
        _census = count _holders;
        { [_x, _ttdWeapons] call _addToCleanup; } forEach _holders;
    };

    if (_ttdPlanted>0) then {
        { [_x, _ttdPlanted] call _addToCleanup; } forEach (allMissionObjects "TimeBombCore");
    };

    if (_ttdSmokes>0) then {
        { [_x, _ttdSmokes] call _addToCleanup; } forEach (allMissionObjects "SmokeShell");
    };

    // Crates and parachutes are collected by class like everything else, and survive only by
    // being tagged. That is the same polarity as every other category here -- opt out, not opt
    // in -- so a drop added later is cleaned without anyone remembering to register it. It only
    // became safe once compositions were tagged: the HQ arsenal crate and a supply drop are both
    // B_supplyCrate_F, and three side missions use crate classes for their objectives.
    if (_ttdDroppedGear>0) then {
        { [_x, _ttdDroppedGear] call _addToCleanup; } forEach (allMissionObjects "ReammoBox_F");
        { [_x, _ttdDroppedGear] call _addToCleanup; } forEach (allMissionObjects "ParachuteBase");
    };

    // Explicit one-off lifetimes, chiefly from fnc_duws_release retiring a composition. Drained
    // rather than re-read, so each object is scheduled once with the lifetime it asked for.
    {
        _x params ["_obj", "_ttd"];
        [_obj, _ttd] call _addToCleanup;
    } forEach DUWS_disposables;
    DUWS_disposables = [];

    {
        if ((count units _x)==0) then {
            deleteGroup _x;
        };
    } forEach allGroups;

    if (_ttdBodies>0) then {
        {
            [_x, _ttdBodies] call _addToCleanup;
        } forEach allDeadMen;
    };

    if (_ttdVehiclesDead>0) then {
        {
            if(_x == vehicle _x) then { // make sure its vehicle
                [_x, _ttdVehiclesDead] call _addToCleanup;
            };
        } forEach (allDead - allDeadMen); // all dead without dead men == mostly dead vehicles
    };

    if (_ttdVehiclesImmobile>0) then {
        {
            // A static weapon satisfies !canMove merely by being one, so every unmanned turret
            // matches this clause. They survive by being tagged through fnc_duws_keep, not by a
            // class exemption here -- an exemption would also spare a turret whose composition
            // has been released, which is exactly the case that should be collected.
            if(!canMove _x && {alive _x}count crew _x==0) then {
                [_x, _ttdVehiclesImmobile] call _addToCleanup;
            } else {
                [_x] call _removeFromCleanup;
            };
        } forEach vehicles;
    };

    REM(_objectsToCleanup,0)
    REM(_timesWhenToCleanup,0)

    // Debug-menu request, cleared here rather than by the setter: the pass it woke is the only
    // place that knows it was served, and leaving it set would wake every pass from now on. It
    // brings this pass forward and nothing else -- lifetimes and KEEP_RADIUS still decide what
    // goes, so an early pass deletes exactly what the pass it pre-empted would have.
    private _force = DUWS_cleanup_force;
    DUWS_cleanup_force = false;
    private _tracked = count _objectsToCleanup;

    {
        if(isNull(_x)) then {
            _objectsToCleanup set[_forEachIndex, 0];
            _timesWhenToCleanup set[_forEachIndex, 0];
        } else {
            // Expired but in view stays on the list and is retried next pass, so it goes as
            // soon as the player moves off rather than never.
            private _obj = _x;
            if(_timesWhenToCleanup select _forEachIndex < time
                && {(allPlayers findIf {_x distance _obj < KEEP_RADIUS}) < 0}) then {
                deleteVehicle _obj;
                _objectsToCleanup set[_forEachIndex, 0];
                _timesWhenToCleanup set[_forEachIndex, 0];
            };
        };
    } forEach _objectsToCleanup;

    REM(_objectsToCleanup,0)
    REM(_timesWhenToCleanup,0)

    if (_force) then {
        ["INFO", "CLEANUP", format ["forced pass: %1 tracked, %2 still pending",
            _tracked, count _objectsToCleanup]] call fnc_log;
    };

    _pass = _pass + 1;
    if (_pass % LOG_EVERY == 0) then {
        ["INFO", "CLEANUP", format ["weapon-holder census %1, %2 pending deletion",
            _census, count _objectsToCleanup]] call fnc_log;
    };
};