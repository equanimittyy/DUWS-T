// Locality: server; the trigger bodies below run on the machine that triggers them, not here.
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

// What OPFOR put back on ground they had to retake is a scratch force, not the garrison the zone was
// generated with. The loss ledger is seeded to 0.3 survival -- a thin single garrison with no reserve
// depth, since the seed spends the pool copies before it thins the garrison -- so every retake costs
// them the same and a zone traded back and forth does not converge on full strength.
// No hold beside it, unlike a town's: the ground changes hands back and forth under a live fight, and the
// garrison arrives on the ordinary streaming rule.
private _retakenKey = [_triggerPos] call fnc_zone_key;
[_retakenKey, 0.3] call DUWS_fnc_garrisonSeed;

// Mobilising: OPFOR own the ground and their men are not on it yet. Set here and cleared by
// fnc_zone_spawn when the garrison's peak publishes, so it describes exactly the window between the
// flip and the first man standing.
// The readout needs it because the tier alone would lie -- it would report a garrison as though it
// were there. It cannot be inferred from the absence of a peak, because a zone that has merely
// streamed out has no peak either and that one is quiet rather than mobilising.
missionNamespace setVariable [format ["DUWS_zoneMobilising_%1", _retakenKey], true];

["us_lostcontrol",[_place,""]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
[localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_lostcontrol", _place]] remoteExec ["fnc_duws_dialogue", 0];


// The same AP swing a capture pays, reversed: no consolation share for BLUFOR, since losing ground is
// meant to cost while OPFOR losing a zone is what mobilises it.
_apswing = round(_points * zone_ap_swing);
["OPF", _apswing, "zone_lost"] remoteExec ["fnc_ap_adjust", 2];
["BLU", -_apswing, "zone_lost"] remoteExec ["fnc_ap_adjust", 2];

str(_markername) setMarkerColor "ColorRed";
str(_markername2) setMarkerColor "ColorRed";
str(_markername + "port") setMarkerColor "ColorRed";

if (VERSION_X == "MODERN" || simple_zones_enable) then {
    private _flagVarName = format["flag_%1_%2", floor abs (_flagPos select 0), floor abs (_flagPos select 1)];
    private _flg = missionNamespace getVariable [_flagVarName, objNull];
    if (!isNull _flg) then {
        _flg setFlagTexture "\A3\Data_F\Flags\flag_red_CO.paa";
        // Zone lost to OPFOR: close the carry gate so the flagpole can no longer be moved.
        [_flg, false] call fnc_zone_flag_logistics;
    };
};

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