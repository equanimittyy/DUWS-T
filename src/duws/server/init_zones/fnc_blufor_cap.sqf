// Locality: server; the trigger bodies below run on the machine that triggers them, not here.
// fnc_blufor_cap.sqf
_place   =   _this select 0; 
_points =   _this select 1;
_markername = _this select 2;
_markername2 = _this select 3;
_triggerPos = _this select 4;
_flagPos = _triggerPos;
_radius = _this select 5;
// Retired bounty slot (always 0 now); read only to keep the 7-arg signature. A recapture pays
// BLUFOR nothing -- the zone's reward was earned at its first liberation. _points is the worth.
_bounty = _this select 6;

// Server-only, same reason as fnc_captured: shared-pool credits plus
// read-modify-write of networked globals, on a trigger of unproven locality.
if (!isServer) exitWith {};

if (_triggerPos in WARCOM_zones_controled_by_BLUFOR) exitWith {};

// Hands the zone to BLUFOR: both side lists and both counters move together.
["BLU", _triggerPos] call fnc_zone_control_set;

["us_takencontrol",[_place,""]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated,false];
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_takencontrol"] remoteExec ["fnc_duws_dialogue", 0];

// Pause TFs if no opfor zones are visible
call fnc_hardcore_visible_recalc;

// BLUFOR gains no AP for a recapture -- the liberation bonus was a once-ever reward, so a zone
// flipped back and forth yields nothing fresh. OPFOR still takes its consolation on every loss,
// a share of the worth: the anti-steamroll floor does not care how often the zone has flipped.
_opfreward = round(_points * zone_ap_consolation);
if (_opfreward > 0) then {
    ["OPF", _opfreward, "zone_lost_consolation"] remoteExec ["fnc_ap_adjust", 2];
};

// ADD Skill to operatives
[] spawn fnc_operative_mission_complete; 

// MODIFY MARKER ICON
// Blue for the same reason as the first capture: green is Independent, not friendly.
str(_markername) setMarkerColor "ColorBlue";
// MODIFY MARKER ELLIPSE
str(_markername2) setMarkerColor "ColorBlue";

// No CP on a recapture: passive CP now comes from towns, and a zone's one-time reward was paid
// at its first liberation. A zone traded back and forth is therefore not a CP faucet.

if (VERSION_X == "MODERN" || simple_zones_enable) then {
    private _flagVarName = format["flag_%1_%2", floor abs (_flagPos select 0), floor abs (_flagPos select 1)];
    private _flg = missionNamespace getVariable [_flagVarName, objNull];
    if (!isNull _flg) then {
        _flg setFlagTexture "\A3\Data_F\Flags\flag_blue_CO.paa";
    };
};

private _trgVarName = format["trigger_%1_%2", floor abs (_triggerPos select 0), floor abs (_triggerPos select 1)];
private _trg = missionNamespace getVariable [_trgVarName, objNull];
if (!isNull _trg) then {
    _trg setTriggerActivation["EAST SEIZED","PRESENT",true];
    // 7th arg is the retired bounty slot, passed 0.
    _trg setTriggerStatements["this", format["[""%1"",%2,""%3"",""%4"",%5,%6,%7] spawn fnc_opfor_cap",_place,_points,_markername,_markername2,_triggerPos,_radius,0], ""];
};