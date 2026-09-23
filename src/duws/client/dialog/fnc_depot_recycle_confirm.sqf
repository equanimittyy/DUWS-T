// Locality: client -- the Recycle button's handler, spawned so the modal confirmation can block.
// Quotes the selected vehicle's reward client-side (DUWS_fnc_vehicleRecycleReward is broadcast) and
// confirms before committing; the server re-derives the reward at commit, so the quote cannot drift.
if (!hasInterface) exitWith {};
private _sel = lbCurSel 2011;
if (_sel < 0) exitWith { hint localize "STR_DUWS_T_9607znvh"; };
private _nid = lbData [2011, _sel];
private _veh = objectFromNetId _nid;
if (isNull _veh) exitWith { hint localize "STR_DUWS_T_DEPOT_VEHICLE_GONE"; };

private _name = getText (configFile >> "CfgVehicles" >> typeOf _veh >> "displayName");
private _reward = [_veh] call DUWS_fnc_vehicleRecycleReward;

private _ok = [
    format [localize "STR_DUWS_T_GARAGE_RECYCLE_CONFIRM", _name, _reward],
    localize "STR_DUWS_T_recycleaction", true, true
] call BIS_fnc_guiMessage;
if (_ok) then { [player, _nid] remoteExec ["fnc_veh_recycle_action", 2]; };
