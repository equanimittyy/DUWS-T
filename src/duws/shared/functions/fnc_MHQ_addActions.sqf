// Locality: all machines -- some callers remoteExec to target 0, others to target 2, so it can run anywhere.
// The JIP-flagged callers share the id "duws_mhq_actions", so the queue holds one entry at the
// MHQ's current state rather than the whole deploy/undeploy history. Replacement is safe because
// each branch below opens with removeAllActions. "select" is not part of that: it carries no JIP
// flag and does something else.

#include "..\includes\action_style.hpp"

_addAction = _this select 0;

if (_addAction == "select") then {
	// create marker on MHQ
	_markerType = "b_motor_inf";
	waitUntil {!isNil "MHQ1"};
	if (MHQ1 isKindof "tank") then {_markerType = "b_armor"};

	[MHQ1, _markerType, "ColorYellow", 1, 1, localize "STR_DUWS_T_9ziy0qai"] remoteExec ["kndr_assignMarker", [0,-2] select isDedicated,false];

	// spawn loop to detect MHQ destroyed
	[] spawn fnc_MHQ_destroyed;

};

if (_addAction == "deploy") then {
	if ((vehiclevarname player) in Squad_Leaders) then {
		removeAllActions MHQ1;
		MHQ1 addaction [ACT_COMMIT("STR_DUWS_T_rqzxlvf4"),{[] remoteExec ["fnc_MHQ_deploy",2]},[],10,true,true,"","true"];
	};
};

if (_addAction == "undeploy") then {
	if ((vehiclevarname player) in Squad_Leaders) then {
		removeAllActions MHQ1;
		MHQ1 addaction [ACT_COMMIT("STR_DUWS_T_fjpyu3zb"),{[] remoteExec ["fnc_MHQ_undeploy",2]},[],10,true,true,"","true"];
	};
};

