if (!isServer) exitWith {};
_group = _this select 0;
_TFname = _this select 1;


// get the current primary zone
_primary_waypoint = [];
if (hardcore_mode_enable) then {
	{
		_curr_zone = _x;
		{
			// only use zones that are revealed
			if (str (_x select 1) == str (_curr_zone) && (_x select 2 == true)) then {
				_primary_waypoint insert [0, [(_x select 1)]];
			};
		} forEach zone_namePOS_pairs;
	} forEach WARCOM_zones_controled_by_OPFOR;
} else {
	_primary_waypoint insert [0, [(WARCOM_zones_controled_by_OPFOR select 0)]];
};

{
	if (str (_x select 1) == str (_primary_waypoint select 0)) then {
		[localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_tf_primary_target", _x select 0]] remoteExec ["fnc_duws_dialogue", 0];
	};
} foreach zone_namePOS_pairs;

// create marker on leader 
_leader = leader _group;
_markerType = "b_inf";
if ((vehicle _leader) isKindof "tank") then {_markerType = "b_armor"};
if ((vehicle _leader) isKindof "car") then {_markerType = "b_motor_inf"};

_markername = format["WARCOM%1",WARCOM_marker_num]; // Define marker name
_markerstr = createMarker [str(_markername), getpos _leader];
_markerstr setMarkerShape "ICON";
str(_markername) setMarkerType _markerType;
str(_markername) setMarkerSize [.6,.6];
str(_markername) setMarkerColor "ColorBlue";
str(_markername) setMarkerText format[" TF %1",_TFname];
WARCOM_marker_num = WARCOM_marker_num + 1;

// set the current primary waypoint for comparison later
_old_primary = (WARCOM_zones_controled_by_OPFOR select 0);

// loop for gps marker and check for new primary zone
while {true} do {
	_units_alive = {alive _x }count units _group;
	_leader = leader _group; 
	// IF ALL DEAD OR 1 ALIVE IN VEHICLE, EXIT.
	if (_units_alive <= 0 || (_units_alive == 1 && (vehicle _leader) != _leader && isTouchingGround (vehicle _leader))) exitWith {  
		private _standby = missionNamespace getVariable ["blu_taskforces_standby", []];
		if (_group in _standby) then {
			_standby = _standby - [_group];
			missionNamespace setVariable ["blu_taskforces_standby", _standby, true];
		};
		if (_units_alive == 1) then {deleteVehicle (leader _group)};
		str(_markername) setMarkerColor "ColorRed";
		str(_markername) setMarkerType "waypoint";
        [localize "STR_DUWS_T_OVERLORD", format[localize "STR_DUWS_T_y6pvcegu", _TFname]] remoteExec ["fnc_duws_dialogue", 0];
		sleep 600;
		deleteMarker str(_markername);
	};
		
	// set the new gps marker position
	str(_markername) setMarkerPos getpos _leader; 
		
	// Written, not inserted. Only index 0 is ever read, and the insert this replaces appended
	// there every four seconds -- roughly 900 entries an hour per task force, each tick shifting
	// everything already in the array, so the per-tick cost climbed with the session.
	_primary_waypoint set [0, (WARCOM_zones_controled_by_OPFOR select 0)];

	// check to see if primary opfor zone was changed by player
	// or WP reset was sent from AI master control
	if (BLUFOR_primary_chg == true) then {

		// Standby groups keep their parked waypoints; only launched groups follow the primary zone.
		private _standby = missionNamespace getVariable ["blu_taskforces_standby", []];
		if !(_group in _standby) then {
			[_group] spawn fnc_WARCOM_wp_blu_assault;
			// nudge the vehicle
			_vehicle = vehicle _leader;
			_nudge = 0.01;
			if (vehicle _leader != _leader) then {
				_vehPos = getPos _vehicle;
				_vehicle setPosATL [(_vehPos select 0),(_vehPos select 1)+_nudge,0];
			};
			// if primary has changed and not just "waypoint reset", send radio message
			if (str _old_primary != str (_primary_waypoint select 0)) then {
				{
					if (str (_x select 1) == str (_primary_waypoint select 0)) then {
						_speaker = localize "STR_DUWS_T_OVERLORD";
						_message = format[localize "STR_DUWS_T_3azcote7",_x select 0,_TFname];
						[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
					};
				} foreach zone_namePOS_pairs;
			};
		};
		_old_primary = (WARCOM_zones_controled_by_OPFOR select 0);
		// wait for change to finish 
		waitUntil {sleep 0.1;BLUFOR_primary_chg == false};
	};
		
	sleep 4;
};