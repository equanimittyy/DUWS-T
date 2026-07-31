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

	// The persistence ring, following the MHQ because it drives. Fixed name rather than one derived
	// from a position that changes, and only from the server: this branch is remoteExec'd to 2, and
	// the ring is a global marker one machine has to own.
	if (isServer) then { [MHQ1, "base_range_mhq"] call fnc_baseRangeMarker };

	// Nothing set this before, so an MHQ destroyed before it was ever deployed threw inside
	// fnc_MHQ_destroyed's own teardown test rather than tearing anything down.
	MHQ_deployed = false;
	publicVariable "MHQ_deployed";

	// Which designation this is. The watcher below outlives a release, so it is handed the number
	// it was spawned for and stands down when a later designation supersedes it -- otherwise
	// releasing and designating again leaves two watchers on one vehicle.
	MHQ_generation = (missionNamespace getVariable ["MHQ_generation", 0]) + 1;
	[MHQ_generation] spawn fnc_MHQ_destroyed;

};

// Release rides with the deploy entry rather than with undeploy, so it is reachable exactly while
// the vehicle is packed up and never while it is a working base. Undeploying is how the MHQ moves,
// which is the common action and has to stay cheap; releasing gives the vehicle back and frees the
// one-at-a-time slot, which is rare and worth a second click.
if (_addAction == "deploy") then {
	if ((vehiclevarname player) in Squad_Leaders) then {
		removeAllActions MHQ1;
		MHQ1 addaction [ACT_COMMIT("STR_DUWS_T_rqzxlvf4"),{[] remoteExec ["fnc_MHQ_deploy",2]},[],10,true,true,"","true"];
		MHQ1 addaction [ACT_COMMIT("STR_DUWS_T_MHQ_RELEASE"),{[] remoteExec ["fnc_MHQ_release",2]},[],10,true,true,"","true"];
	};
};

if (_addAction == "undeploy") then {
	if ((vehiclevarname player) in Squad_Leaders) then {
		removeAllActions MHQ1;
		MHQ1 addaction [ACT_COMMIT("STR_DUWS_T_fjpyu3zb"),{[] remoteExec ["fnc_MHQ_undeploy",2]},[],10,true,true,"","true"];
	};
};

