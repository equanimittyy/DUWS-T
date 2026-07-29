// Locality: server -- every caller is a zone builder or mission thread, all server-side.
// Despite the dialog/ folder it draws no UI.

// [{hint "LAPTOP HACKED."}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];

// Add Rotary Action to object

params ["_object", "_display", "_code"];

private _icon = "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa";

[
	_object,										// Object the action is attached to
	_display,										// Title of the action
	_icon,											// Idle icon shown on screen
	_icon,											// Progress icon shown on screen
	"_this distance _target < 3",					// Condition for the action to be shown
	"_caller distance _target < 3",					// Condition for the action to progress
	{},												// Code executed when action starts
	{},												// Code executed on every progress tick
	_code,											// Code executed on completion
	{},												// Code executed on interrupted
	[],												// Arguments passed to the scripts as _this select 3
	6,												// Action duration in seconds
	30,												// Priority
	true,											// Remove on completion
	true											// Show in unconscious state
] remoteExec ["BIS_fnc_holdActionAdd", [0,-2] select isDedicated, _object];