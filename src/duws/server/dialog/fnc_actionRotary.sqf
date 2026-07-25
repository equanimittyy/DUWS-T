// Locality: server -- every caller is a zone builder or mission thread, all server-side.
// Despite the dialog/ folder it draws no UI.

// [{hint "LAPTOP HACKED."}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];

// Add Rotary Action to object

params ["_object", "_display", "_iconType", "_code"];

_icon = "";

switch (_iconType) do {
	case "connect": {
		_icon = "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_connect_ca.paa";
	};
	case "search": {
		_icon = "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa"
	};
	case "talk": {
		_icon = "\a3\missions_f_oldman\data\img\holdactions\holdAction_talk_ca.paa"
	};
};

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
	6,												// Priority
	true,											// Remove on completion
	true											// Show in unconscious state
] remoteExec ["BIS_fnc_holdActionAdd", [0,-2] select isDedicated, _object];

// Set a marker if it's an informant
if (side _object == CIVILIAN) then {
     _speaker = localize "STR_DUWS_T_OVERLORD";
     _message = localize "STR_DUWS_T_v7djsfoq";
     [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
     [] remoteExec ["fnc_broadcastRadioChatter", 0];
	["info",[localize "STR_DUWS_T_rtv3i48t",localize "STR_DUWS_T_j94223ip"]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
	_markername = format["Informant%1",str (getpos _object)]; // Define marker name
	_markerstr = createMarker [str(_markername), getpos _object];
	_markerstr setMarkerShape "ICON";
	str(_markername) setMarkerType "mil_unknown_noShadow";
	str(_markername) setMarkerSize [1,1];
	str(_markername) setMarkerColor "ColorCIV";
	//str(_markername) setMarkerText format[" TF %1",_TFname];

	while {alive _object} do {
		str(_markername) setMarkerPos getpos _object; 
		// after 2 min, set the new marker position
		sleep 30;
	};

	deleteMarker str(_markername);
	
};