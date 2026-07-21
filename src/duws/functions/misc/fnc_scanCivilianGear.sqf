// functions\misc\fnc_scanCivilianGear.sqf
if (!isServer) exitWith {};

diag_log "[CIVGEAR] Starting civilian gear scan...";

// 等待平民数组可用
waitUntil { !isNil "civ_array" && {count civ_array > 0} };

private _civArray = civ_array;
private _safePos = [worldSize/2, worldSize/2, 0];

private _civUniforms = [];
private _civVests = [];
private _civHeadgear = [];
private _civBackpacks = [];

// 原始白名单背包（始终可用，且添加到军火库）
private _baseBackpacks = [
    "B_Messenger_Gray_F", "B_Messenger_Black_F", "B_Messenger_Olive_F",
    "B_LegStrapBag_black_F", "B_LegStrapBag_coyote_F", "B_LegStrapBag_olive_F",
    "B_CivilianBackpack_01_Everyday_Black_F", "B_CivilianBackpack_01_Everyday_Vrana_F",
    "B_CivilianBackpack_01_Everyday_Astra_F", "B_CivilianBackpack_01_Everyday_IDAP_F",
    "B_CivilianBackpack_01_Sport_Red_F", "B_CivilianBackpack_01_Sport_Green_F",
    "B_CivilianBackpack_01_Sport_Blue_F"
];

// 预先将原始白名单背包加入军火库
{
    if (_x != "" && {isClass (configFile >> "CfgVehicles" >> _x)}) then {
        [missionNamespace, _x, true, false] call BIS_fnc_addVirtualBackpackCargo;
        _civBackpacks pushBackUnique _x;
    };
} forEach _baseBackpacks;

// 扫描所有平民单位
{
    private _unitClass = _x;
    private _tempGroup = createGroup civilian;
    private _tempUnit = _tempGroup createUnit [_unitClass, _safePos, [], 0, "NONE"];
    if (!isNull _tempUnit) then {
        sleep 0.05;
        
        // 衣服
        private _uniform = uniform _tempUnit;
        if (_uniform != "" && {!(_uniform in _civUniforms)}) then {
            _civUniforms pushBack _uniform;
            [missionNamespace, _uniform, true, false] call BIS_fnc_addVirtualItemCargo;
        };
        
        // 背心
        private _vest = vest _tempUnit;
        if (_vest != "" && {!(_vest in _civVests)}) then {
            _civVests pushBack _vest;
            [missionNamespace, _vest, true, false] call BIS_fnc_addVirtualItemCargo;
        };
        
        // 头盔
        private _headgear = headgear _tempUnit;
        if (_headgear != "" && {!(_headgear in _civHeadgear)}) then {
            _civHeadgear pushBack _headgear;
            [missionNamespace, _headgear, true, false] call BIS_fnc_addVirtualItemCargo;
        };
        
        // 背包
        private _backpack = backpack _tempUnit;
        if (_backpack != "" && {!(_backpack in _civBackpacks)}) then {
            _civBackpacks pushBack _backpack;
            [missionNamespace, _backpack, true, false] call BIS_fnc_addVirtualBackpackCargo;
        };
        
        deleteVehicle _tempUnit;
    };
    deleteGroup _tempGroup;
} forEach _civArray;

// 最终背包列表去重（_civBackpacks 已包含原始白名单和扫描到的背包）
_civBackpacks = _civBackpacks arrayIntersect _civBackpacks;

// 公开缓存变量
DUWS_civUniforms = _civUniforms;
DUWS_civVests = _civVests;
DUWS_civHeadgear = _civHeadgear;
DUWS_civBackpacks = _civBackpacks;

publicVariable "DUWS_civUniforms";
publicVariable "DUWS_civVests";
publicVariable "DUWS_civHeadgear";
publicVariable "DUWS_civBackpacks";

diag_log format ["[CIVGEAR] Cached %1 uniforms, %2 vests, %3 headgear, %4 backpacks", 
    count _civUniforms, count _civVests, count _civHeadgear, count _civBackpacks];