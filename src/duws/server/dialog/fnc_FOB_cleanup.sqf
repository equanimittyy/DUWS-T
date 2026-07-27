// Locality: server -- callers remoteExec to target 2.
params ["_fob","_fob_pos","_fob_name"];

_markername = format["fob%1%2",round (_fob_pos select 0),round (_fob_pos select 1)]; // Define marker name
deleteMarker _markername;
FOB_removed = true;

["INFO", "SUPPORT", format ["FOB '%1' removed by player at %2", _fob_name, _fob_pos]] call fnc_log;

["info",[format[localize "STR_DUWS_T_mrmg6qui",_fob_name],localize "STR_DUWS_T_f28nbzbw"]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];

// Delete the FOB triggers
private "_trg";
call compile format["_trg = trigfob%1%2",round (_fob_pos select 0),round (_fob_pos select 1)];
deleteVehicle _trg;
private "_trg2";
call compile format["_trg2 = trigfob2%1%2",round (_fob_pos select 0),round (_fob_pos select 1)];
deleteVehicle _trg2;

// Remove FOB from Array_of_FOBS
[_fob_pos] call fnc_fob_deregister;

// CLEANUP OBJECTS AFTER 5 min (保留平民)
[_fob_pos, _fob_name] spawn {  
    _zonePos = _this select 0;
    _fob_name = _this select 1;
    _radius = 15;
    sleep 300;  // 5 min
    _zoneObj = nearestObjects [_zonePos, [], _radius];
    {
        // 只删除非平民的物体（单位或载具）
        if (side _x != CIVILIAN) then {
            deleteVehicle _x;
        };
    } foreach _zoneObj;
    
    // Make a Task Force with the leftover units
    _nearestUnits = nearestObjects [_zonePos,["Man"],200];
    _group = createGroup west;
    {
        if ((side _x) == WEST) then {[_x] joinSilent _group};
    } forEach _nearestUnits;
    if (count (units _group) > 0) then {
        _group deleteGroupWhenEmpty true;
        _TFname = format["FOB_%1", _fob_name];
        [_group] spawn fnc_WARCOM_wp_blu_assault;
        [_group,_TFname] spawn fnc_WARCOM_gps_marker;
        waitUntil {sleep 5;(count WARCOM_zones_controled_by_OPFOR) > 0};
    };
};