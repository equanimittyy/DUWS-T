// Locality: client -- the Repair button's handler, spawned so the modal confirmation can block.
// Quotes the full-service cost client-side (a third of the recycle reward; DUWS_fnc_vehicleRecycleReward
// is broadcast) and confirms before committing. The server re-derives the same cost at commit, so the
// quote cannot drift.
if (!hasInterface) exitWith {};
private _sel = lbCurSel 2011;
if (_sel < 0) exitWith { hint localize "STR_DUWS_T_repair_no_vehicle"; };
private _nid = lbData [2011, _sel];
private _veh = objectFromNetId _nid;
if (isNull _veh) exitWith { hint localize "STR_DUWS_T_repair_no_vehicle"; };

private _name = getText (configFile >> "CfgVehicles" >> typeOf _veh >> "displayName");
private _cost = ceil (([_veh] call DUWS_fnc_vehicleRecycleReward) * 0.33);

private _ok = [
    format [localize "STR_DUWS_T_REPAIR_CONFIRM", _name, _cost],
    localize "STR_DUWS_T_repair_vehicle", true, true
] call BIS_fnc_guiMessage;
if (_ok) then { [player, _nid] remoteExec ["fnc_veh_repair_action", 2]; };
