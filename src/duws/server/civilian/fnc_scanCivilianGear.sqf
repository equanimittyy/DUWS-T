if (!isServer) exitWith {};

["INFO", "CIV", "Starting civilian gear scan..."] call fnc_log;

waitUntil { !isNil "civ_array" && {count civ_array > 0} };

private _civArray = civ_array;
private _safePos = [worldSize/2, worldSize/2, 0];

private _civUniforms = [];
private _civVests = [];
private _civHeadgear = [];
private _civBackpacks = [];

private _baseBackpacks = [
    "B_Messenger_Gray_F", "B_Messenger_Black_F", "B_Messenger_Olive_F",
    "B_LegStrapBag_black_F", "B_LegStrapBag_coyote_F", "B_LegStrapBag_olive_F",
    "B_CivilianBackpack_01_Everyday_Black_F", "B_CivilianBackpack_01_Everyday_Vrana_F",
    "B_CivilianBackpack_01_Everyday_Astra_F", "B_CivilianBackpack_01_Everyday_IDAP_F",
    "B_CivilianBackpack_01_Sport_Red_F", "B_CivilianBackpack_01_Sport_Green_F",
    "B_CivilianBackpack_01_Sport_Blue_F"
];

{
    if (_x != "" && {isClass (configFile >> "CfgVehicles" >> _x)}) then {
        [missionNamespace, _x, true, false] call BIS_fnc_addVirtualBackpackCargo;
        _civBackpacks pushBackUnique _x;
    };
} forEach _baseBackpacks;

{
    private _unitClass = _x;
    private _tempGroup = createGroup civilian;
    private _tempUnit = _tempGroup createUnit [_unitClass, _safePos, [], 0, "NONE"];
    if (!isNull _tempUnit) then {
        sleep 0.05;
        
        private _uniform = uniform _tempUnit;
        if (_uniform != "" && {!(_uniform in _civUniforms)}) then {
            _civUniforms pushBack _uniform;
            [missionNamespace, _uniform, true, false] call BIS_fnc_addVirtualItemCargo;
        };
        
        private _vest = vest _tempUnit;
        if (_vest != "" && {!(_vest in _civVests)}) then {
            _civVests pushBack _vest;
            [missionNamespace, _vest, true, false] call BIS_fnc_addVirtualItemCargo;
        };
        
        private _headgear = headgear _tempUnit;
        if (_headgear != "" && {!(_headgear in _civHeadgear)}) then {
            _civHeadgear pushBack _headgear;
            [missionNamespace, _headgear, true, false] call BIS_fnc_addVirtualItemCargo;
        };
        
        private _backpack = backpack _tempUnit;
        if (_backpack != "" && {!(_backpack in _civBackpacks)}) then {
            _civBackpacks pushBack _backpack;
            [missionNamespace, _backpack, true, false] call BIS_fnc_addVirtualBackpackCargo;
        };
        
        deleteVehicle _tempUnit;
    };
    deleteGroup _tempGroup;
} forEach _civArray;

_civBackpacks = _civBackpacks arrayIntersect _civBackpacks;

DUWS_civUniforms = _civUniforms;
DUWS_civVests = _civVests;
DUWS_civHeadgear = _civHeadgear;
DUWS_civBackpacks = _civBackpacks;

publicVariable "DUWS_civUniforms";
publicVariable "DUWS_civVests";
publicVariable "DUWS_civHeadgear";
publicVariable "DUWS_civBackpacks";

["INFO", "CIV", format ["cached %1 uniforms, %2 vests, %3 headgear, %4 backpacks",
    count _civUniforms, count _civVests, count _civHeadgear, count _civBackpacks]] call fnc_log;

// Fold civilian disguise gear into the friendly set. This scan runs tens of seconds after
// fnc_create_ammo_lists snapshotted DUWS_friendlyArsenal, so these classes are absent from it --
// without this the count overlay reads them as an empty pool ([0]) in Hybrid and the disguise gear
// cannot be drawn. Only genuinely-new classes are seeded, so a boot-seeded count is never reset.
private _civAdded = _civUniforms + _civVests + _civHeadgear + _civBackpacks;
private _friendly = missionNamespace getVariable ["DUWS_friendlyArsenal", []];
private _newFriendly = _civAdded select { !(_x in _friendly) };
if (count _newFriendly > 0) then {
    DUWS_friendlyArsenal = _friendly + _newFriendly;
    publicVariable "DUWS_friendlyArsenal";
    // Limited has no unlimited floor: seed the new classes at the boot seed count so they start
    // stocked instead of at zero, matching fnc_create_ammo_lists.
    if (DUWS_arsenalLimited) then {
        { [_x, DUWS_limitedSeed] call fnc_captured_pool_setCount; } forEach _newFriendly;
        publicVariable "DUWS_capturedPool";
    };
};

// Log unconditionally (even when 0 new) so an RPT proves this fold ran: a stale build lacking it
// prints no such line, making "did the civ-gear fix load?" answerable from the log alone.
["INFO", "CIV", format ["friendly set: folded %1 new of %2 civilian classes (mode: %3)",
    count _newFriendly, count _civAdded, ["Hybrid", "Limited"] select DUWS_arsenalLimited]] call fnc_log;