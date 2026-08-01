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

// What OPFOR put back on ground they had to retake is a scratch force, not the garrison the zone
// was generated with. Floored rather than merely reduced, so every retake costs them the same and
// a zone traded back and forth does not converge on full strength.
// No hold beside it, unlike a town's: EAST SEIZED cannot fire while any BLUFOR stand in the radius,
// so a retake already cannot happen under the player's feet, and the garrison arrives on the
// ordinary streaming rule once they are clear.
[[_triggerPos] call fnc_zone_key, 0.3] call fnc_zone_strength_set;

["us_lostcontrol",[_place,""]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_lostcontrol"] remoteExec ["fnc_duws_dialogue", 0];

// Pause TFs if no opfor zones are visible
call fnc_hardcore_visible_recalc;


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
    // Re-armed for BLUFOR to take it back, on the same terms as the opening capture: the garrison
    // beaten and the objective clear, not the whole radius swept (fnc_zone_capture_ready). The
    // position and radius the condition reads were put on this trigger when the zone was built and
    // ride it through every ownership change, so only the activation and statement move here.
    _trg setTriggerActivation["WEST","PRESENT",true];
    _trg setTriggerStatements["this && {[thisTrigger] call fnc_zone_capture_ready}", format["[""%1"",%2,""%3"",""%4"",%5,%6,%7] spawn fnc_blufor_cap",_place,_points,_markername,_markername2,_triggerPos,_radius,_bounty], ""];
};