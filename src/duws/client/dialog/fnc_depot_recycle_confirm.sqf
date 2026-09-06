// Locality: client -- the Recycle button's handler, spawned so the modal confirmation can block.
// Totals the empty pad vehicles' rewards client-side (DUWS_fnc_vehicleRecycleReward is broadcast, so
// this is the same figure the server will credit) and raises a Yes/No prompt before committing. The
// server recomputes the set at commit, so the pad changing between confirm and Yes cannot mis-credit.
if (!hasInterface) exitWith {};
private _trgNetId = uiNamespace getVariable ["DUWS_depotMenu_ctx", ""];
private _trg = objectFromNetId _trgNetId;
if (isNull _trg) exitWith {};

private _vehs = (vehicles inAreaArray _trg) select { count crew _x == 0 };
private _count = count _vehs;
if (_count == 0) exitWith { hint localize "STR_DUWS_T_recycleempty"; };

private _total = 0;
{ _total = _total + ([_x] call DUWS_fnc_vehicleRecycleReward); } forEach _vehs;

private _ok = [
    format [localize "STR_DUWS_T_GARAGE_RECYCLE_CONFIRM", _count, _total],
    localize "STR_DUWS_T_VEHICLE_RECYCLING", true, true
] call BIS_fnc_guiMessage;
if (_ok) then { [player, _trgNetId] remoteExec ["fnc_veh_recycle_action", 2]; };
