// Locality: client -- opened from the Rest/Heal action on a FOB or medical tent. Weather set here
// is a one-shot nudge: the dynamic-weather daemon (server/dialog/fnc_weather.sqf) re-rolls overcast
// and fog on its next tick, so a pick holds only until then.
if (!hasInterface) exitWith {};

params ["_restSite"];

// Gated here, not on the action, so a non-GM still sees the row and is told who to ask.
if (!((vehiclevarname player) in game_master)) exitWith {
    hint format [localize "STR_DUWS_T_RESTHEAL_HOSTONLY", call fnc_gm_occupant];
};

// Global: the onSliderPosChanged config strings call it arg-less. Labels need the display (stashed
// by the dialog's onLoad); sliderPosition reads the top dialog by idc.
fnc_rest_labels = {
    private _disp = uiNamespace getVariable ["DUWS_rest_disp", displayNull];
    if (isNull _disp) exitWith {};

    private _h = sliderPosition 8703;
    private _d = date;
    private _t = ((_d select 3) * 60 + (_d select 4) + round (_h * 60)) mod 1440;
    private _mm = _t mod 60;
    private _clock = format ["%1:%2", floor (_t / 60), [str _mm, "0" + str _mm] select (_mm < 10)];
    (_disp displayCtrl 8702) ctrlSetText format [localize "STR_DUWS_T_rest_dur", _h toFixed 1, _clock];

    (_disp displayCtrl 8711) ctrlSetText format [localize "STR_DUWS_T_rest_overcast", (sliderPosition 8712) toFixed 2];
    (_disp displayCtrl 8713) ctrlSetText format [localize "STR_DUWS_T_rest_rain", (sliderPosition 8714) toFixed 2];
};

// Rain renders only over overcast >= 0.5 (engine floor). The re-set retriggers this handler, but
// the clamped value fails the condition, so it settles in one bounce rather than looping.
fnc_rest_couple = {
    params ["_ctrl"];
    private _o = sliderPosition 8712;
    private _r = sliderPosition 8714;
    if (_r > 0 && _o < 0.5) then {
        if (ctrlIDC _ctrl == 8714) then { sliderSetPosition [8712, 0.5]; }
        else { sliderSetPosition [8714, 0]; };
    };
    call fnc_rest_labels;
};

if (!createDialog "rest_dialog") exitWith {};
waitUntil { dialog };

sliderSetRange [8703, 3, 24];
sliderSetPosition [8703, 3];

// Default to the current sky, so leaving the weather sliders put is a no-op rather than a jump.
sliderSetRange [8712, 0, 1];
sliderSetPosition [8712, overcast];
sliderSetRange [8714, 0, 1];
sliderSetPosition [8714, rain];

lbClear 8716;
lbAdd [8716, localize "STR_DUWS_T_rest_fog_off"];
lbAdd [8716, localize "STR_DUWS_T_rest_fog_on"];
lbSetCurSel [8716, [0, 1] select (fog > 0.05)];

call fnc_rest_labels;

waitUntil { !dialog };

if !(missionNamespace getVariable ["DUWS_rest_confirmed", false]) exitWith {};
DUWS_rest_confirmed = false;

[player, _restSite, DUWS_rest_hours, DUWS_rest_overcast, DUWS_rest_rain, DUWS_rest_fog]
    remoteExec ["fnc_restHealServer", 2];
