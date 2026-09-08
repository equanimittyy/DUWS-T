// Locality: server -- createVehicle runs on the server. remoteExec'd to 2 by fnc_debug_furnish_calibrate.
// Spawns one furniture class at heading 0 -- its model +Y then points due north -- a few metres in front
// of the requester, so the dev reads the compass bearing the model's real front points at and records
// that number as the class's frontYaw. Replaces any previous calibration object; "" just clears it.
// Server-only, not broadcast.
if (!isServer) exitWith {};
params ["_class", "_who"];

private _prev = missionNamespace getVariable ["DUWS_furnishCalObj", objNull];
if (!isNull _prev) then { deleteVehicle _prev };
if (_class == "" || {isNull _who}) exitWith { DUWS_furnishCalObj = objNull };

private _obj = createVehicle [_class, _who modelToWorld [0, 3, 0], [], 0, "CAN_COLLIDE"];
_obj setDir 0;
_obj setVectorUp [0, 0, 1];
_obj allowDamage false;
DUWS_furnishCalObj = _obj;

[format ["Calibrating %1.\n\nIt sits at heading 0 (model +Y due north).\nRead the compass bearing its FRONT points at --\nthat number is frontYaw. Record it in\nfurniture_catalog.hpp.", _class]] remoteExec ["hint", _who];
