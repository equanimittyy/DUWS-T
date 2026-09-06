// Locality: client -- the vehicle-appearance (skin + user animations) dialog, opened by the depot
// menu on the vehicle the player selected. Hoisted out of the old repair scroll action so it takes
// an explicit target vehicle rather than resolving one from a trigger; the dialog's internals are
// otherwise unchanged.
if (!hasInterface) exitWith {};
params ["_veh"];
if (isNull _veh) exitWith { hint localize "STR_DUWS_T_vehicle_garage_no_vehicle"; };

disableSerialization;
private _display = createDialog ["RscDisplayEmpty", false];
private _listbox = _display ctrlCreate ["RscListBox", 1500];
_listbox ctrlSetPosition [0.3, 0.22, 0.4, 0.4];
_listbox ctrlCommit 0;

// skin list: static, no refresh needed
private _textures = ("true" configClasses (configFile >> "CfgVehicles" >> typeOf _veh >> "TextureSources")) apply {configName _x};
{ _listbox lbAdd format ["Texture: %1", _x]; } forEach _textures;

private _animations = ("true" configClasses (configFile >> "CfgVehicles" >> typeOf _veh >> "AnimationSources")) select {
    getText (_x >> "source") == "user"
} apply {configName _x};

private _fnc_refreshAnimList = {
    lbClear _listbox;
    { _listbox lbAdd format ["Texture: %1", _x]; } forEach _textures;
    {
        private _state = _veh animationSourcePhase _x;
        private _label = if (_state > 0) then { format ["%1 (ON)", _x] } else { format ["%1 (OFF)", _x] };
        _listbox lbAdd _label;
    } forEach _animations;
    lbSetCurSel [1500, 0];
};

call _fnc_refreshAnimList;

_display setVariable ["garage_veh", _veh];
_display setVariable ["garage_animList", _animations];
_display setVariable ["garage_textureList", _textures];

// Apply button: refresh the list without closing
private _applyBtn = _display ctrlCreate ["RscButton", 1600];
_applyBtn ctrlSetText "Apply";
_applyBtn ctrlSetPosition [0.35, 0.67, 0.1, 0.05];
_applyBtn ctrlCommit 0;
_applyBtn ctrlAddEventHandler ["ButtonClick", {
    private _parent = ctrlParent (_this select 0);
    private _veh = _parent getVariable ["garage_veh", objNull];
    if (isNull _veh) exitWith {};
    private _idx = lbCurSel 1500;
    private _text = lbText [1500, _idx];
    if (_text find "Texture:" != -1) then {
        private _texName = (_text splitString ": ") select 1;
        [_veh, _texName] call BIS_fnc_initVehicle;
    } else {
        private _animName = (_text splitString " (") select 0;
        private _state = _veh animationSourcePhase _animName;
        _veh animateSource [_animName, if (_state > 0) then {0} else {1}, true];
    };
    private _animations = _parent getVariable ["garage_animList", []];
    private _textures = _parent getVariable ["garage_textureList", []];
    private _listbox = _parent displayCtrl 1500;
    lbClear _listbox;
    { _listbox lbAdd format ["Texture: %1", _x]; } forEach _textures;
    {
        private _state = _veh animationSourcePhase _x;
        private _label = if (_state > 0) then { format ["%1 (ON)", _x] } else { format ["%1 (OFF)", _x] };
        _listbox lbAdd _label;
    } forEach _animations;
    lbSetCurSel [1500, 0];
}];

private _closeBtn = _display ctrlCreate ["RscButton", 1601];
_closeBtn ctrlSetText "Close";
_closeBtn ctrlSetPosition [0.55, 0.67, 0.1, 0.05];
_closeBtn ctrlCommit 0;
_closeBtn ctrlAddEventHandler ["ButtonClick", { closeDialog 0; }];
