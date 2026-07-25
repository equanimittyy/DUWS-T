// fnc_opfor_cap.sqf
_place   =   _this select 0; 
_points =   _this select 1;
_markername = _this select 2;
_markername2 = _this select 3;
_triggerPos = _this select 4;
_flagPos = _triggerPos;
_radius = _this select 5;

if (_triggerPos in WARCOM_zones_controled_by_OPFOR) exitWith {};

amount_zones_captured = amount_zones_captured - 1;
publicVariable "amount_zones_captured";

["us_lostcontrol",[_place,""]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_lostcontrol"] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];

// REMOVE A ZONE FROM BLUFOR CONTROL
_index = 0;
{
	if ((_x select 0 == _triggerPos select 0) && (_x select 1 == _triggerPos select 1)) exitWith {
		WARCOM_zones_controled_by_BLUFOR deleteAt _index;
	}; 
	_index = _index + 1;
} forEach WARCOM_zones_controled_by_BLUFOR;
publicVariable "WARCOM_zones_controled_by_BLUFOR";

// SORT THE ZONES BY DIST TO BLUHQ
WARCOM_zones_controled_by_OPFOR = [WARCOM_zones_controled_by_OPFOR,[WARCOM_blu_hq_pos],{_input0 distance _x},"ASCEND"] call BIS_fnc_sortBy;
// SET THE ZONE AS PRIMARY
WARCOM_zones_controled_by_OPFOR insert [0, [_triggerPos]];
publicVariable "WARCOM_zones_controled_by_OPFOR";

// Pause TFs if no opfor zones are visible
if (hardcore_mode_enable) then {
	hardcore_visibleZone_found = false;
	{
		_curr_zone = _x;
		{
			// check zone_name_pairs for any opfor zones that are still red
			if (str (_x select 1) == str (_curr_zone) && (_x select 2 == true)) then {
				hardcore_visibleZone_found = true;
			};
		} forEach zone_namePOS_pairs;
	} forEach WARCOM_zones_controled_by_OPFOR;
};

// MODIFY NUMBER OF CONTROLLED ZONES
zoneundercontrolblu = zoneundercontrolblu - 1;
publicVariable "zoneundercontrolblu";

// MODIFY ARMY POWER - OPF gains full points, BLU loses full points
["OPF", _points] remoteExec ["fnc_ap_adjust", 2];
["BLU", -_points] remoteExec ["fnc_ap_adjust", 2];

// MODIFY MARKER ICON
str(_markername) setMarkerColor "ColorRed";
// MODIFY MARKER ELLIPSE
str(_markername2) setMarkerColor "ColorRed";

// ========== 修复：使用统一的变量名获取旗杆并变色 ==========
if (VERSION_X == "MODERN" || simple_zones_enable) then {
    private _flagVarName = format["flag_%1_%2", floor abs (_flagPos select 0), floor abs (_flagPos select 1)];
    private _flg = missionNamespace getVariable [_flagVarName, objNull];
    if (!isNull _flg) then {
        _flg setFlagTexture "\A3\Data_F\Flags\flag_red_CO.paa";
    };
};

// ========== 修复：使用统一的变量名获取触发器 ==========
private _trgVarName = format["trigger_%1_%2", floor abs (_triggerPos select 0), floor abs (_triggerPos select 1)];
private _trg = missionNamespace getVariable [_trgVarName, objNull];
if (!isNull _trg) then {
    _trg setTriggerActivation["WEST SEIZED","PRESENT",true];
    _trg setTriggerStatements["this", format["[""%1"",%2,""%3"",""%4"",%5,%6] spawn fnc_blufor_cap",_place,_points,_markername,_markername2,_triggerPos,_radius], ""];
};