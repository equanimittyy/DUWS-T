// Locality: server; the trigger bodies below run on the machine that triggers them, not here.
_place   =   _this select 0; 
_points =   _this select 1;
_markername = _this select 2;
_markername2 = _this select 3;
_triggerPos = _this select 4;
_radius = _this select 5;
// Retired: the CP capture bounty is gone with the town->CP reroute. Still read so the 7-arg
// trigger signature is unchanged across the three cap handlers, but no longer paid -- the first
// capture pays a flat liberation bonus instead, and a recapture pays nothing.
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
[localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_takencontrol", _place]] remoteExec ["fnc_duws_dialogue", 0];

// First-ever capture pays a flat liberation bonus in both currencies, once per zone. The key is
// recorded in DUWS_zone_first_captured so a reload -- or this zone lost and later retaken through
// fnc_blufor_cap -- never pays it again: a zone's reward is earned exactly once, which is what
// makes the anti-farm invariant structural rather than arithmetic. A recapture (fnc_blufor_cap)
// pays BLUFOR nothing at all.
private _zoneKey = [_triggerPos] call fnc_zone_key;
private _firstEver = !(_zoneKey in DUWS_zone_first_captured);
if (_firstEver) then {
    DUWS_zone_first_captured pushBack _zoneKey;
    [zone_first_capture_cp, "zone_first_capture"] remoteExec ["fnc_cp_adjust", 2];
    // Liberating a zone is earned ground, so the bonus AP credits the tier counter (4th arg). Paid
    // once ever per zone (DUWS_zone_first_captured), so a recapture adds nothing to the ladder either.
    ["BLU", zone_first_capture_ap, "zone_first_capture", zone_first_capture_ap] remoteExec ["fnc_ap_adjust", 2];
};

// OPFOR is paid a consolation whenever it loses a zone -- a share of the worth, so losing a big
// zone funds a bigger counter-attack. This is the anti-steamroll floor: a fast advance arms the
// resistance. Wallet only, and paid every capture rather than only the first.
_opfreward = round(_points * zone_ap_consolation);
if (_opfreward > 0) then {
    ["OPF", _opfreward, "zone_lost_consolation"] remoteExec ["fnc_ap_adjust", 2];
};

if (VERSION_X == "MODERN" || simple_zones_enable) then {
    private _flagVarName = format["flag_%1_%2", floor abs (_triggerPos select 0), floor abs (_triggerPos select 1)];
    private _flg = missionNamespace getVariable [_flagVarName, objNull];
    if (!isNull _flg) then {
        _flg setFlagTexture "\A3\Data_F\Flags\flag_blue_CO.paa";
        // BLUFOR holds the zone now: open the carry gate on its flagpole.
        [_flg, true] call fnc_zone_flag_logistics;
    };
};

// Blue, not green: green is the engine's Independent colour, which this mission sets hostile to
// west, so a zone the player owns was reading as a third party's. Pairs with the ColorRed an
// OPFOR-held zone carries.
str(_markername) setMarkerColor "ColorBlue";
str(_markername2) setMarkerColor "ColorBlue";

sleep 2;

private _trgVarName = format["trigger_%1_%2", floor abs (_triggerPos select 0), floor abs (_triggerPos select 1)];
private _trg = missionNamespace getVariable [_trgVarName, objNull];
if (!isNull _trg) then {
    _trg setTriggerActivation ["EAST SEIZED", "PRESENT", true];
    // The 7th arg is the retired bounty slot, passed 0: no CP rides a recapture any more.
    _trg setTriggerStatements ["this", format["[""%1"",%2,""%3"",""%4"",%5,%6,%7] spawn fnc_opfor_cap", _place, _points, _markername, _markername2, _triggerPos, _radius, 0], ""];
};

if (_firstEver) then {
    ["cpadded",[zone_first_capture_cp,""]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
};
