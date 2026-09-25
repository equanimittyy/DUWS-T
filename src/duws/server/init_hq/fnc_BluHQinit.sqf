// Locality: server -- spawned from server/server_init.sqf:102, which spells it fnc_bluHQinit;
// SQF names are case-insensitive.
#include "..\..\shared\includes\action_style.hpp"

// The officer is invulnerable (allowDamage false) until OPFOR come within this of him -- wider than
// the 200 m the contact alert calls the base, so a marksman on a ridge stays a loss worth keeping,
// and drawn on no map. Enemy presence in the ring, not the source of a shot, is what makes him mortal;
// while mortal, a HandleDamage veto still drops identifiable friendly fire so it cannot end the
// campaign.
#define OFFICER_GUARD_RADIUS 500

if (isNil "PosOfBLUHQ") exitWith {};

private _hqObj = objNull;
private _supplyCrate = objNull;
private _mapBoard = objNull;
private _medTent = objNull;
private _guardBoxObj = objNull;
private _barGateObj = objNull;
private _repairDepot = objNull;
private _helipad = objNull;
private _allTowersList = [];

// Offsets from the HQ building, which stands at PosOfBLUHQ.
private _allObjectsData = ["duws_hq"] call fnc_composition_rows;

// The base's guns, in the same frame as the walls around them but kept in code rather than in the
// composition: guns are replaced on every redeploy (init_hq/fnc_redeployHQUnits.sqf replays these rows
// alone through fnc_placeHQUnits), and half of each row is placement data Eden cannot hold.
//
// Height is that data: these two sit above an anchor by a measured amount taken against its
// getPosWorld, because a building's own modelToWorld Z is unusable (init_hq/fnc_placeHQUnits.sqf). So the
// last two columns name the anchor class and the offset, resolved by whatever object of that class is
// nearest the row -- move the anchor and the gun's height follows it. Z is unused.
//
// Column 5 is the faction role holding the classname, or "" for a gun resolved by its class.
private _weaponData = [
    ["I_HMG_02_high_F", 21.22465, 17.25616, 0, 352.975, "",                  "Land_SandbagBarricade_01_hole_F", 1.21321],
    ["B_static_AA_F",   0.50074, -0.71388, 0, 165.875, "",                  "Land_Cargo_HQ_V1_F",              1.252556]
];

private _lightTypes = ["Land_PortableLight_double_F", "Land_LampShabby_F"];

private _invulnerableTypes = [
    "Land_PortableLight_double_F",
    "Land_MedicalTent_01_NATO_generic_inner_F",
    "B_supplyCrate_F",
    "Land_GuardTower_02_F",
    "Land_LampShabby_F",
    "Land_GuardBox_01_brown_F",
    "Land_BarGate_F",
    "Land_Tank_rust_F",
    "Land_ClothesLine_01_F",
    "Land_ShootingPos_Roof_01_F",
    "Land_RepairDepot_01_green_F",
    "RoadBarrier_F",
    "Land_ParkingMeter_01_F",
    "Land_Portable_generator_F",
    "Land_GarbageBarrel_02_F",
    "Land_Cargo_HQ_V1_F",
    "Land_FireExtinguisher_F",
    "TargetP_Zom_F",
    "WaterPump_01_forest_F",
    "Land_HelipadSquare_F",
    "Land_WoodenBox_02_F",
    "Land_WoodenCrate_01_stack_x5_F",
    "Land_WoodenCrate_01_F",
    "Land_WoodenCrate_01_stack_x3_F",
    "Land_Pallet_vertical_F",
    "Land_PalletTrolley_01_khaki_F",
    "Land_Pallet_F"
];

// Cleared before the props go down rather than at placement time: this is the first point the final
// HQ position is known, and the one path both random and manual placement pass through. 50 m is the
// composition's own reach -- its farthest wall stands 47 m from the HQ building every offset above is
// measured against.
[PosOfBLUHQ, 50] call fnc_clear_foliage;
[PosOfBLUHQ, 50] call fnc_clear_buildings;

{
    _x params ["_class","_origX","_origY","_origZ","_dir","_isWeapon"];
    if (_isWeapon) then { continue; };
    
    private _newX = (PosOfBLUHQ select 0) + _origX;
    private _newY = (PosOfBLUHQ select 1) + _origY;
    private _obj = createVehicle [_class, [_newX, _newY, 0], [], 0, "CAN_COLLIDE"];
    [_obj, "HQ"] call fnc_duws_keep;
    _obj setPosATL [_newX, _newY, 0];
    _obj setDir _dir;
    
    // Global, not the local form: enableSimulation only affects the machine it runs on, so a
    // server-side call leaves every client still simulating props the server has frozen. They then
    // settle, drift and fall differently on each machine, which is how the base ends up looking
    // different to a joining player than it does to the host.
    if (_class in _lightTypes || _class == "B_supplyCrate_F") then {
        _obj enableSimulationGlobal true;
    } else {
        _obj enableSimulationGlobal false;
    };

    if (_class == "CamoNet_BLUFOR_open_F" || (toLower _class) find "land_camo" == 0) then {
        _obj allowDamage false;
    };

    if (_class in _invulnerableTypes) then {
        _obj allowDamage false;
    };
    
    if (_class == "Land_Cargo_HQ_V1_F") then { _hqObj = _obj; };
    if (_class == "B_supplyCrate_F") then { _supplyCrate = _obj; };
    if (_class == "MapBoard_altis_F") then { _mapBoard = _obj; };
    if (_class == "Land_MedicalTent_01_NATO_generic_inner_F") then { _medTent = _obj; };
    if (_class == "Land_GuardTower_02_F") then { _allTowersList pushBack _obj; };
    if (_class == "Land_GuardBox_01_brown_F") then { _guardBoxObj = _obj; };
    if (_class == "Land_BarGate_F") then { _barGateObj = _obj; };
    if (_class == "Land_RepairDepot_01_green_F") then { _repairDepot = _obj; };
    if (_class == "Land_HelipadSquare_F") then { _helipad = _obj; };
} forEach _allObjectsData;

bluHQ_object = _hqObj;
publicVariable "bluHQ_object";

// Every anchor fnc_placeHQUnits reads lives in these keys. They are written before the placement
// call rather than beside each spawn so the rebuild -- which has nothing but the namespace to work
// from -- places its units off exactly the data this build used.

// The guns, resolved out of their rows into the world positions the rebuild works from. Anchors
// travel as a class and a position rather than as an object reference: an anchor destroyed between
// build and rebuild would leave a null behind, where the class is re-found against whatever is
// standing there now.
// Resolved here rather than by fnc_static_place: these rows' product is data, not objects. The
// rebuild runs it again against whatever is standing on the anchors now, so the class is decided
// once per build and carried, and an unroled row is decided by its class through the same table
// every zone prefab uses.
missionNamespace setVariable ["HQ_redeploy_weaponData", _weaponData apply {
    _x params ["_class", "_origX", "_origY", "", "_dir", "_role", "_anchorClass", "_hOffset"];
    [
        [_class, "blufor", _role] call fnc_static_resolve,
        [(PosOfBLUHQ select 0) + _origX, (PosOfBLUHQ select 1) + _origY],
        _dir, _anchorClass, _hOffset
    ]
}, true];

// Unit-type pool. Broadcast because client_init reads it to caption the guards, and because a FOB's own
// patrol draws from it too (init_hq/fnc_guardsFOB.sqf) -- the HQ_ prefix is where it is set, not
// who may read it.
private _baseGuardTypes = [blufor_SOLDIER_X, blufor_LAT_SOLDIER_X, blufor_GL_SOLDIER_X, blufor_TL_SOLDIER_X, blufor_SL_SOLDIER_X, blufor_AR_SOLDIER_X, blufor_MARK_SOLDIER_X];
missionNamespace setVariable ["HQ_redeploy_guardTypes", _baseGuardTypes, true];

missionNamespace setVariable ["HQ_redeploy_towers", _allTowersList, true];

// Door pair: model XY, height offset, facing offset from the HQ building heading, anim.
// The facing is relative to the building, not absolute: re-saving the composition in Eden can turn the
// whole frame, and an absolute facing stays behind and ends up turning the pair inward.
missionNamespace setVariable ["HQ_redeploy_hqGuardsData", [
    [[-5.49573, -0.923828], -4.10893, -90, "STAND"],
    [[-4.84598, -3.90649], -4.03631, -90, "STAND_IA"]
], true];
missionNamespace setVariable ["HQ_redeploy_medGuardsData", [
    [[1.49021, -5.54492], -1.37312, "STAND_IA"],
    [[3.18945, -5.54492], -1.37312, "STAND"]
], true];

if (!isNull _medTent) then { missionNamespace setVariable ["HQ_medTent_netId", netId _medTent, true]; };
if (!isNull _guardBoxObj) then { missionNamespace setVariable ["HQ_guardBox_netId", netId _guardBoxObj, true]; };

private _patrolSpawnXY = _hqObj modelToWorld [1.27142, -21.9805, 0];
missionNamespace setVariable ["HQ_redeploy_patrolSpawnPos", [
    _patrolSpawnXY select 0,
    _patrolSpawnXY select 1,
    (getPosWorld _hqObj select 2) + (-3.87396)
], true];

call fnc_placeHQUnits;

private _xyWorld = _hqObj modelToWorld [0.0896273, -0.0180664, 0];
private _worldPos = [
    _xyWorld select 0,
    _xyWorld select 1,
    (getPosWorld _hqObj select 2) + (-3.27229)
];
private _offGrp = [_worldPos, WEST, [blufor_OFFICER_X], [], [], [0.4,0.6]] call BIS_fnc_spawnGroup;
private _officer = (units _offGrp) select 0;
_officer allowDamage false;  // the proximity monitor below flips this true only while OPFOR hold the ring
// Global: the local form freezes the officer on the server alone, so every client keeps
// simulating a unit hard-placed at an absolute Z and renders it falling.
_officer enableSimulationGlobal false;
_officer setPosWorld _worldPos;
_officer setDir ((getDir _hqObj) - 90);  // outward, relative to the building so a re-saved frame carries it
_officer setBehaviour "CARELESS";
_officer setCombatMode "BLUE";
_officer disableAI "TARGET"; _officer disableAI "AUTOTARGET";
_officer disableAI "FSM"; _officer disableAI "MOVE";
_officer setVariable ["asr_ai_exclude", true];
_officer setVariable ["NOAI", 1, false];
_officer setVariable ["Vcm_Disable", true];
_officer setVariable ["lambs_danger_disableAI", true];
removeBackpackGlobal _officer;
// An "Acts_" ambient animation holds through death: the corpse keeps the standing pose and never
// ragdolls, so hits read as having no effect and the officer looks invulnerable. The tower guards
// escape this because BIS_fnc_ambientAnimCombat breaks its own animation; a raw switchMove has
// nothing that does. Clearing the move lets the death animation play.
_officer addEventHandler ["Killed", {
    params ["_unit"];
    [_unit, ""] remoteExec ["switchMove", 0];
    // The queued pose goes with it. Left in the queue, a player joining after the officer dies is
    // handed the standing animation for a corpse -- the state clearing the move exists to prevent,
    // arriving by the other route.
    remoteExec ["", format ["hq_pose_%1", netId _unit]];
}];
// Loss condition: friendly fire must never end the campaign. The proximity gate below (allowDamage)
// blocks all damage while OPFOR are outside OFFICER_GUARD_RADIUS, so this only fires once they breach
// it -- there it drops any hit an identifiable WEST shooter dealt (_instigator the player behind an
// explosive or vehicle, _source a direct hit). Unattributed blasts still land, as the ring intends.
_officer addEventHandler ["HandleDamage", {
    params ["_unit", "", "_damage", "_source", "", "", "_instigator"];
    private _by = [_source, _instigator] select (!isNull _instigator);
    if (!isNull _by && {side _by == WEST}) exitWith { 0 };
    _damage
}];
hq_blu1 = _officer; publicVariable "hq_blu1";
[_officer] spawn {
    // Polled, not hung off the Killed handler above: that runs wherever the officer is local, and
    // campaign_lost_ending is deliberately not broadcast, so a client-side firing would leave the
    // server without the ending it names. The same poll gates his mortality via allowDamage -- the
    // reliable primitive that stops bullets, blasts and setDamage alike while the ring is clear,
    // which a per-hit HandleDamage veto could not. Killable only while OPFOR hold the ring.
    while { alive hq_blu1 } do {
        hq_blu1 allowDamage (([getPos hq_blu1, OFFICER_GUARD_RADIUS, EAST] call fnc_side_count_at) > 0);
        sleep 1;
    };
    if (DUWS_officerLost) exitWith {};
    ["alert", [localize "STR_DUWS_T_OFFICER_KILLED_TITLE", localize "STR_DUWS_T_OFFICER_KILLED"]]
        remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];
    // Lose conditions Full (0) or Officer Death Only (1).
    if !(DUWS_paramLoseConditions in [0, 1]) exitWith {
        ["INFO", "WARCOM", "Commanding officer killed: lose condition disabled"] call fnc_log;
    };

    campaign_lost = true;
    campaign_lost_body = "STR_DUWS_T_CAMPAIGN_LOST_OFFICER_MSG";
    // Names the outro card as well as the notification: both endings are worded, and the debriefing
    // class is read on the server only, so it needs no broadcast.
    campaign_lost_ending = "officerkilled";
    publicVariable "campaign_lost";
    publicVariable "campaign_lost_body";
    ["INFO", "WARCOM", "Commanding officer killed: campaign lost"] call fnc_log;
};
[_officer] spawn {
    params ["_u"];
    sleep 0.5;
    if (isNull _u || {!alive _u}) exitWith {};
    _u enableSimulationGlobal true;
    // switchMove is local, so posing from the server dressed the officer on the host and nowhere
    // else. Applied after simulation is back -- a frozen unit does not take the animation -- and
    // keyed so a joiner is posed too rather than meeting a man standing to attention.
    [_u, "acts_StandingSpeakingUnarmed"] remoteExec ["switchMove", 0, format ["hq_pose_%1", netId _u]];
};

private _barrierPosX = (PosOfBLUHQ select 0) - 32.3144;
private _barrierPosY = (PosOfBLUHQ select 1) + 9.9932;
private _barrier = nearestObject [[_barrierPosX, _barrierPosY, 0] apply { _x + 0 }, "RoadBarrier_F"];
if (!isNull _barrier) then {
    private _xyWorld = _barrier modelToWorld [2.41602, 0.460938, 0];
    private _worldPos = [
        _xyWorld select 0,
        _xyWorld select 1,
        (getPosWorld _barrier select 2) + (-0.490046)
    ];
    private _grp = [_worldPos, WEST, [blufor_HELI_PILOT_X], [], [], [0.4,0.6]] call BIS_fnc_spawnGroup;
    private _unit = (units _grp) select 0;
    private _dirToTent = [_worldPos, getPosWorld _medTent] call BIS_fnc_dirTo;
    _unit allowDamage true;
    _unit enableSimulationGlobal false;
    _unit setPosWorld _worldPos;
    _unit setUnitPos "UP";
    _unit disableAI "MOVE";
    _unit setDir _dirToTent;
    removeAllWeapons _unit;
    removeGoggles _unit;
    _unit unassignItem "NVGoggles";
    _unit removeItem "NVGoggles";
    _unit unassignItem "NVGoggles_OPFOR";
    _unit removeItem "NVGoggles_OPFOR";
    _unit unassignItem "NVGoggles_INDEP";
    _unit removeItem "NVGoggles_INDEP";
    // He keeps the helmet his own class spawns in rather than being dressed as ground crew: the
    // construction hard hat is DLC content, so a player who does not own it met the base wearing a
    // purchase prompt.
    [_unit] spawn {
        params ["_u"];
        sleep 0.5;
        if (isNull _u || {!alive _u}) exitWith {};
        _u enableSimulationGlobal true;
        // Broadcast and keyed, same as the officer: a local switchMove posed him for the host
        // alone, and it has to wait for simulation to come back before it takes.
        [_u, "Acts_PointingLeftUnarmed"] remoteExec ["switchMove", 0, format ["hq_pose_%1", netId _u]];
    };
    // Clears the pose on death; the Acts_ animation otherwise holds and the corpse stands.
    // The queued pose is dropped with it, or a joiner re-poses the corpse.
    _unit addEventHandler ["Killed", {
        params ["_u"];
        [_u, ""] remoteExec ["switchMove", 0];
        remoteExec ["", format ["hq_pose_%1", netId _u]];
    }];
};

if (!isNull _supplyCrate) then {
    clearMagazineCargoGlobal _supplyCrate;
    clearWeaponCargoGlobal _supplyCrate;
    clearItemCargoGlobal _supplyCrate;
    clearBackpackCargoGlobal _supplyCrate;
    _supplyCrate addMagazineCargoGlobal ["Money_roll", 20];
    // Suffixed JIP ids throughout this block: an object-keyed id is that object's netId, so a
    // second broadcast against the same object would silently evict the first. Each prop takes
    // one adder today, and the suffix is what keeps that true if one ever takes two.
    [_supplyCrate] remoteExec ["fnc_addQuickChangeActions", 0, format ["hq_quickchange_%1", netId _supplyCrate]];
};

if (!isNull _medTent) then {
    // Broadcast to everyone rather than to interfaced machines alone, and keyed, because the
    // adder now decides per player which of its three entries apply -- a joiner has to run it for
    // themselves rather than inherit the host's answer.
    [_medTent] remoteExec ["fnc_medtent_actions", 0, format ["hq_medtent_%1", netId _medTent]];
};

if (!isNull _mapBoard) then {
    missionNamespace setVariable ["HQ_mapBoard_netId", netId _mapBoard, true];
    [_mapBoard] remoteExec ["fnc_addBoardKillhouseActions", 0, format ["hq_mapboard_%1", netId _mapBoard]];
};

if (!isNull _hqObj) then {
    [_hqObj] remoteExec ["fnc_addHQBuildingActions", 0, format ["hq_building_%1", netId _hqObj]];
};

// Gate auto-trigger: object passed by netId, since the trigger statement is a string
if (!isNull _barGateObj && {isNil {_barGateObj getVariable "gate_trigger_added"}}) then {
    _barGateObj setVariable ["gate_trigger_added", true, true];
    private _gateNetId = netId _barGateObj;
    _trgGate = createTrigger ["EmptyDetector", getPosWorld _barGateObj, false];
    _trgGate setTriggerArea [12, 12, 0, false, 12];
    _trgGate setTriggerActivation ["ANYPLAYER", "PRESENT", true];
    _trgGate setTriggerStatements [
        "this",
        format [
            "private _g = objectFromNetId '%1'; if (!isNull _g && {alive _g}) then { _g animate ['door_1_rot', 1]; [_g] spawn { params ['_gt']; sleep 15; if (!isNull _gt && {alive _gt}) then { _gt animate ['door_1_rot', 0]; }; }; };",
            _gateNetId
        ],
        ""
    ];
};

_markername = format["%1%2",round (PosOfBLUHQ select 0),round (PosOfBLUHQ select 1)];
blu_hq_markername = _markername; publicVariable "blu_hq_markername";
createMarker [str(_markername), PosOfBLUHQ];
str(_markername) setMarkerShape "ICON";
str(_markername) setMarkerType "mil_flag";
str(_markername) setMarkerColor "ColorBlue";
str(_markername) setMarkerText "Main Base";

// Server-local, matching the zone's contact trigger: a global trigger runs its statement on every
// machine, which would raise the alert and drop its markers once per player.
_trgWarning = createTrigger["EmptyDetector",PosOfBLUHQ,false];
_trgWarning setTriggerArea[200,200,0,false];
_trgWarning setTriggerActivation["EAST","PRESENT",true];
_trgWarning setTriggerStatements["this", "['Main Base', thisList] call fnc_enemy_contact;", ""];
_trgWarning setTriggerTimeout [10, 10, 10, true];

private _respawnXY = _medTent modelToWorld [-0.243752, -7.28516, 0];
private _respawnPos = [
    _respawnXY select 0,
    _respawnXY select 1,
    (getPosWorld _medTent select 2) + (-2.02112)
];
"respawn_west" setMarkerPos _respawnPos;

if (!isNull _repairDepot) then { missionNamespace setVariable ["HQ_repairDepot_netId", netId _repairDepot, true]; };
if (!isNull _helipad) then { missionNamespace setVariable ["HQ_helipad_netId", netId _helipad, true]; };

// Hold the interaction-critical HQ fixtures out of Zeus, so a game master cannot delete the base's
// building, heal tent, map board or vehicle depot (fnc_asset_guard).
{ if (!isNull _x) then { [_x] call fnc_guard_register } } forEach [_hqObj, _medTent, _mapBoard, _repairDepot];

HQ_pos_found_generated = true; publicVariable "HQ_pos_found_generated";
["INFO", "BOOT", format ["BLUFOR HQ built at %1", PosOfBLUHQ]] call fnc_log;
// Drawn through the shared function so the HQ, every FOB and the MHQ all advertise the one radius
// the cleanup sweep honours -- a separate hardcoded figure drifts from it (200 m against a sweep
// that spares 250).
[PosOfBLUHQ] call fnc_baseRangeMarker;