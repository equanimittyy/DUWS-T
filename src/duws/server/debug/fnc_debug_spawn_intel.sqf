// Locality: server -- createVehicle is global, so exactly one machine may run the spawn.
//
// Developer tool: spawns every intel-item class near the caller so a tester can settle by hand which
// have a physical ground body and which vanish when dropped. For each class it drops the raw item
// into a holder to pick up and drop-test, and -- where an `Item_<class>` ground class exists -- also
// places that body in a row to eyeball. The per-class report names which have that ground variant,
// which is the config answer behind the drop test.
if (!isServer) exitWith {};

params ["_caller"];
if (isNull _caller) exitWith {};

// Re-checked rather than trusted to the menu: reachable by remoteExec from any client, and it spawns
// objects that pay out nothing but litter the map.
if !((vehicleVarName _caller) in game_master) exitWith {};

private _classes = ["SmartPhone", "MobilePhone", "FlashDisk", "Files",
    "FilesSecret", "Wallet_ID", "FileTopSecret"];

private _base = getPosATL _caller;
private _drop = _caller getPos [2, getDir _caller];

// One holder for the raw items, so a class with no ground body can still be inventory-drop-tested.
private _holder = createVehicle ["GroundWeaponHolder", [0, 0, 0], [], 0, "CAN_COLLIDE"];
_holder setPosATL [_drop select 0, _drop select 1, _base select 2];

private _report = "Intel items spawned at your feet.\nTake each, drop it, watch what survives.\n\nclass : has Item_ ground body\n";
{
    private _ground = "Item_" + _x;
    private _hasBody = isClass (configFile >> "CfgVehicles" >> _ground);
    // The physical body itself, where the class has one -- laid out in a grid to eyeball.
    if (_hasBody) then {
        private _obj = createVehicle [_ground, [0, 0, 0], [], 0, "CAN_COLLIDE"];
        _obj setPosATL [
            (_base select 0) + 1 + (_forEachIndex mod 4) * 0.6,
            (_base select 1) + 1 + floor (_forEachIndex / 4) * 0.6,
            _base select 2
        ];
    };
    // Cargo takes the raw inventory class either way; magazine vs item decides which cargo slot.
    if (isClass (configFile >> "CfgMagazines" >> _x)) then {
        _holder addMagazineCargoGlobal [_x, 1];
    } else {
        _holder addItemCargoGlobal [_x, 1];
    };
    _report = _report + format ["%1 : %2\n", _x, _hasBody];
} forEach _classes;

_report remoteExec ["hint", _caller];
