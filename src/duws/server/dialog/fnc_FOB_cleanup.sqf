// Locality: server -- callers remoteExec to target 2.
params ["_fob_pos","_fob_name"];

_markername = format["fob%1%2",round (_fob_pos select 0),round (_fob_pos select 1)];
deleteMarker _markername;
// The persistence ring goes with it, or the map keeps promising a vehicle is safe at a FOB that no
// longer exists. Same name fnc_baseRangeMarker derives from the position.
deleteMarker (format ["base_range_%1_%2", round (_fob_pos select 0), round (_fob_pos select 1)]);
FOB_removed = true;

["INFO", "SUPPORT", format ["FOB '%1' removed by player at %2", _fob_name, _fob_pos]] call fnc_log;

["info",[format[localize "STR_DUWS_T_mrmg6qui",_fob_name],localize "STR_DUWS_T_f28nbzbw"]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];

// Delete the FOB's enemy-proximity trigger. It is the only one a FOB carries -- the arrival
// notification trigger that used to sit beside it is gone. Defaulted to objNull so a FOB whose
// trigger was never filed deletes nothing instead of throwing on a nil.
private _trg2 = missionNamespace getVariable [
    format["trigfob2%1%2",round (_fob_pos select 0),round (_fob_pos select 1)],
    objNull
];
deleteVehicle _trg2;

// Remove FOB from Array_of_FOBS
[_fob_pos] call fnc_fob_deregister;

[_fob_pos, _fob_name] spawn {
    _zonePos = _this select 0;
    _radius = 15;
    sleep 300;  // 5 min
    _zoneObj = nearestObjects [_zonePos, [], _radius];
    {
        if (side _x != CIVILIAN) then {
            deleteVehicle _x;
        };
    } foreach _zoneObj;
};