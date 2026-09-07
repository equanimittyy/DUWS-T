// Locality: all machines -- some callers remoteExec to target 0, others to target 2, so it can run anywhere.
// The JIP-flagged action callers share the id "duws_mhq_actions": the queue holds one entry at the MHQ's
// current state, not the deploy/undeploy history, and each branch reopens with removeAllActions. The map
// icon is JIP-flagged separately as "duws_mhq_marker" (here and in MHQ_deploy/undeploy) for the same reason;
// both ids are dropped when the MHQ ends (release or destruction). "select" is not JIP-invoked -- it also runs one-time setup.

#include "..\includes\action_style.hpp"

_addAction = _this select 0;

if (_addAction == "select") then {
	_markerType = "b_motor_inf";
	waitUntil {!isNil "MHQ1"};
	if (MHQ1 isKindof "tank") then {_markerType = "b_armor"};

	[MHQ1, _markerType, "ColorYellow", 1, 1, localize "STR_DUWS_T_9ziy0qai"] remoteExec ["kndr_assignMarker", [0,-2] select isDedicated,"duws_mhq_marker"];

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
		// Deploying plants a forward respawn, so it is refused within 2 km of enemy ground. Checked at
		// the click on the deploying machine -- fnc_pos_near_enemy reads broadcast globals, so it answers
		// the same here as on the server -- and the deploy action stays, to retry once the vehicle moves.
		MHQ1 addaction [ACT_COMMIT("STR_DUWS_T_rqzxlvf4"),{
			if ([getPos MHQ1] call fnc_pos_near_enemy) exitWith { hint localize "STR_DUWS_T_too_close_enemy" };
			[] remoteExec ["fnc_MHQ_deploy",2]
		},[],10,true,true,"","true"];
		MHQ1 addaction [ACT_COMMIT("STR_DUWS_T_MHQ_RELEASE"),{[] remoteExec ["fnc_MHQ_release",2]},[],10,true,true,"","true"];
	};
};

if (_addAction == "undeploy") then {
	if ((vehiclevarname player) in Squad_Leaders) then {
		removeAllActions MHQ1;
		MHQ1 addaction [ACT_COMMIT("STR_DUWS_T_fjpyu3zb"),{[] remoteExec ["fnc_MHQ_undeploy",2]},[],10,true,true,"","true"];
	};
};

