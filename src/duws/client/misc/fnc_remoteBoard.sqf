// Locality: runs on the target client -- the server remoteExecs it to the boarding player
// (server/misc/fnc_intro_heli.sqf). Registered from client_init so the client is holding it before the
// intro heli flies; server_init waits on that (it is not retried).
params ["_heliNetId", "_seatType", "_player"];
if (_player != player) exitWith {};
private _heli = objectFromNetId _heliNetId;
if (isNull _heli) exitWith { ["ERROR", "INTRO", "Remote board: helicopter not found."] call fnc_log; };
switch (_seatType) do {
    case "cargo": {
        player assignAsCargo _heli;
        player moveInCargo _heli;
    };
    case "gunner": {
        player assignAsGunner _heli;
        player moveInGunner _heli;
    };
    case "commander": {
        player assignAsCommander _heli;
        player moveInCommander _heli;
    };
};
["INFO", "INTRO", format ["Client %1 boarded helicopter as %2", name player, _seatType]] call fnc_log;
