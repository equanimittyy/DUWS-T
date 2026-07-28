// Locality: server; the trigger bodies below run on the machine that triggers them, not here.
_place   =   _this select 0; 
_points =   _this select 1;
_markername = _this select 2;
_markername2 = _this select 3;
_triggerPos = _this select 4;
_flagPos = _triggerPos;
_radius = _this select 5;

// Server-only: this credits the shared CP/AP pools and read-modify-writes several
// networked globals, so a second machine running it would double-credit a capture.
// The zone trigger is created with createTrigger's makeGlobal defaulted to true and
// its evaluation locality is not proven, so assert it rather than rely on it.
if (!isServer) exitWith {};

if (_triggerPos in WARCOM_zones_controled_by_BLUFOR) exitWith {};

// Hands the zone to BLUFOR: both side lists and both counters move together.
["BLU", _triggerPos] call fnc_zone_control_set;

["us_takencontrol",[_place,""]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_takencontrol"] remoteExec ["fnc_duws_dialogue", 0];

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

// ADD COMMAND POINTS  1000m zone = 100 / 2 = 50 pts available
// Derived, never assigned back into _points: the zone's worth is handed to the next owner's
// trigger below and round-trips through fnc_opfor_cap to fnc_blufor_cap, so dividing it in
// place shrank the zone every time it changed hands until a contested one paid nothing.
_cpreward = round(_points/2);
[_cpreward, "zone_first_capture"] remoteExec ["fnc_cp_adjust", 2];

// MODIFY ARMY POWER - OPF gains 1/2 the points, BLU gains full points
_opfreward = round(_points/2);
["OPF", _opfreward, "zone_first_capture"] remoteExec ["fnc_ap_adjust", 2];
["BLU", _points, "zone_first_capture"] remoteExec ["fnc_ap_adjust", 2];

// 将战区旗杆改为蓝色
if (VERSION_X == "MODERN" || simple_zones_enable) then {
    private _flagVarName = format["flag_%1_%2", floor abs (_triggerPos select 0), floor abs (_triggerPos select 1)];
    private _flg = missionNamespace getVariable [_flagVarName, objNull];
    if (!isNull _flg) then {
        _flg setFlagTexture "\A3\Data_F\Flags\flag_blue_CO.paa";
    };
};

// MODIFY MARKER ICON
str(_markername) setMarkerColor "ColorGreen";
// MODIFY MARKER ELLIPSE
str(_markername2) setMarkerColor "ColorGreen";

sleep 2;

// 将触发器改为红方可占领
private _trgVarName = format["trigger_%1_%2", floor abs (_triggerPos select 0), floor abs (_triggerPos select 1)];
private _trg = missionNamespace getVariable [_trgVarName, objNull];
if (!isNull _trg) then {
    _trg setTriggerActivation ["EAST SEIZED", "PRESENT", true];
    _trg setTriggerStatements ["this", format["[""%1"",%2,""%3"",""%4"",%5,%6] spawn fnc_opfor_cap", _place, _points, _markername, _markername2, _triggerPos, _radius], ""];
};

["cpadded",[_cpreward,""]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
