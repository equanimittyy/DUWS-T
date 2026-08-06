// Locality: server; the trigger bodies below run on the machine that triggers them, not here.
_place   =   _this select 0; 
_points =   _this select 1;
_markername = _this select 2;
_markername2 = _this select 3;
_triggerPos = _this select 4;
_radius = _this select 5;
// The CP this capture pays. Separate from _points, the zone's permanent worth: the bounty
// decays as the zone changes hands, the worth never does.
_bounty = _this select 6;

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
call fnc_hardcore_visible_recalc;

// ADD COMMAND POINTS  1000m zone of worth 100 opens at a bounty of 50
// Skipped once the bounty has decayed to nothing, or a zone flipped enough times announces
// a payday of zero.
if (_bounty > 0) then {
    [_bounty, "zone_first_capture"] remoteExec ["fnc_cp_adjust", 2];
};

// MODIFY ARMY POWER - measured against the worth, not the bounty, so a zone swings the same
// momentum however often it has changed hands. OPF gains a consolation share of the swing.
_apswing = round(_points * zone_ap_swing);
_opfreward = round(_apswing * zone_ap_consolation);
["OPF", _opfreward, "zone_first_capture"] remoteExec ["fnc_ap_adjust", 2];
["BLU", _apswing, "zone_first_capture"] remoteExec ["fnc_ap_adjust", 2];

if (VERSION_X == "MODERN" || simple_zones_enable) then {
    private _flagVarName = format["flag_%1_%2", floor abs (_triggerPos select 0), floor abs (_triggerPos select 1)];
    private _flg = missionNamespace getVariable [_flagVarName, objNull];
    if (!isNull _flg) then {
        _flg setFlagTexture "\A3\Data_F\Flags\flag_blue_CO.paa";
    };
};

// MODIFY MARKER ICON
// Blue, not green: green is the engine's Independent colour, which this mission sets hostile to
// west, so a zone the player owns was reading as a third party's. Pairs with the ColorRed an
// OPFOR-held zone carries.
str(_markername) setMarkerColor "ColorBlue";
// MODIFY MARKER ELLIPSE
str(_markername2) setMarkerColor "ColorBlue";

sleep 2;

private _trgVarName = format["trigger_%1_%2", floor abs (_triggerPos select 0), floor abs (_triggerPos select 1)];
private _trg = missionNamespace getVariable [_trgVarName, objNull];
if (!isNull _trg) then {
    _trg setTriggerActivation ["EAST SEIZED", "PRESENT", true];
    // The bounty handed on is what the *next* capture pays, so the decay is applied here
    // rather than on arrival: whoever takes this zone back finds it already devalued.
    _trg setTriggerStatements ["this", format["[""%1"",%2,""%3"",""%4"",%5,%6,%7] spawn fnc_opfor_cap", _place, _points, _markername, _markername2, _triggerPos, _radius, round(_bounty * zone_cp_recapture)], ""];
};

if (_bounty > 0) then {
    ["cpadded",[_bounty,""]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
};
