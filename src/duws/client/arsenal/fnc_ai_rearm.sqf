// Locality: client -- passed as an addAction function value in server/dialog/fnc_MHQ_deploy.sqf,
// client/supports/fnc_ammobox.sqf and shared/functions/fnc_FOBactions.sqf, so it runs on whoever rearms.
// The unit rearm itself is remoteExec'd to the server.
private _result = [localize "STR_DUWS_T_ij1nh3gu", localize "STR_DUWS_T_d7eqef75", true, true] call BIS_fnc_guiMessage;
if (_result) then {
	{
		if !(isplayer _x) then {
			_x setDamage 0;
			[_x] remoteExec ["fnc_rearmUnit", 2];
		};
	} forEach units group player;
	
	player setDamage 0;
	hint localize "STR_DUWS_T_3y5r8lzq";
};