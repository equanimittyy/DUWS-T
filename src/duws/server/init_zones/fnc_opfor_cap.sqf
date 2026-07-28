// Locality: server; the trigger bodies below run on the machine that triggers them, not here.
// fnc_opfor_cap.sqf
_place   =   _this select 0; 
_points =   _this select 1;
_markername = _this select 2;
_markername2 = _this select 3;
_triggerPos = _this select 4;
_flagPos = _triggerPos;
_radius = _this select 5;
// Carried, not spent: losing a zone pays no CP, so the bounty passes straight to whoever
// takes it back. Only a capture decays it.
_bounty = _this select 6;

// Server-only, same reason as fnc_captured: shared-pool credits plus
// read-modify-write of networked globals, on a trigger of unproven locality.
if (!isServer) exitWith {};

if (_triggerPos in WARCOM_zones_controled_by_OPFOR) exitWith {};

// Hands the zone back to OPFOR: both side lists and both counters move together,
// and the lost zone becomes the primary assault target.
["OPF", _triggerPos] call fnc_zone_control_set;

["us_lostcontrol",[_place,""]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_lostcontrol"] remoteExec ["fnc_duws_dialogue", 0];

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
	publicVariable "hardcore_visibleZone_found";
};


// MODIFY ARMY POWER - the same swing a capture pays, in the other direction. No consolation
// share for BLUFOR here: losing ground is meant to cost, where OPFOR losing one is what
// mobilises it.
_apswing = round(_points * zone_ap_swing);
["OPF", _apswing, "zone_lost"] remoteExec ["fnc_ap_adjust", 2];
["BLU", -_apswing, "zone_lost"] remoteExec ["fnc_ap_adjust", 2];

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
    _trg setTriggerStatements["this", format["[""%1"",%2,""%3"",""%4"",%5,%6,%7] spawn fnc_blufor_cap",_place,_points,_markername,_markername2,_triggerPos,_radius,_bounty], ""];
};