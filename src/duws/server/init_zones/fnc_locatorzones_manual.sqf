// Locality: server; the map-click bodies below run on the machine that triggers them, not here (inherited from server/warcom/fnc_init_OPFOR_WARCOM.sqf).

// player1 on purpose, unlike the mission announcements: manual placement is one person clicking the
// map, and the map this opens is theirs. Everyone else gets the typeText card on the next line.
[{hint localize "STR_DUWS_T_5ve9v8c0"}] remoteExec ["BIS_fnc_Spawn", player1,false];
[[localize "STR_DUWS_T_shuo4nyn"]] remoteExec ["BIS_fnc_typeText", [0,-2] select isDedicated,false];

titleCut ["", "BLACK IN", 10];
man_fortified = true; publicVariable "man_fortified";
openMap [true, true];
mapAnimAdd [3, 1, PosOfBLUHQ];
mapAnimCommit;
_zones_array = [[-9999,-9999,-9999]];

for [{_i=1}, {_i<=zones_number}, {_i=_i+1}] do  // BEGIN "FOR" LOOP --
{
    player globalChat format[localize "STR_DUWS_T_6izloqi3",_i];
    // Banner, not hint/globalChat: this whole loop runs with the map forced open above, and
    // the engine draws both of those beneath it -- every instruction and every rejection
    // below was invisible, so a click that failed validation looked like no click at all.
    // Held in a variable because the outcome messages append to it.
    private _zonePrompt = format ["<t size='2' color='#00ffff'>%1 </t><br/>%2",
        format [localize "STR_DUWS_T_6izloqi3", _i], localize "STR_DUWS_T_5ve9v8c0"];
    [_zonePrompt] remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];
    _found = false;
    man_zone_radius = 0; publicVariable "man_zone_radius";
    man_points_zone = 0; publicVariable "man_points_zone"; 
    while {man_zone_radius<=zones_min_radius} do {
        _random_zones_max_radius = random zones_max_radius;
        man_zone_radius = round _random_zones_max_radius;   
        man_points_zone = round (man_zone_radius/10);
    };
	
    while {!_found} do {
        clicked = false;
        OnMapSingleClick "ClickedPos = _pos; clicked = true;";	
        _found_distance = false;
        man_missionPos = []; publicVariable "man_missionPos";
		_Posfound = false;

        if (clicked) then {

			while {!_Posfound} do {
				_posDeMeilleurTruc = [];
				_nearRoad = [];
				if (simple_zones_enable) then {  // allow for tighter spaces
					_posDeMeilleurTruc = [ClickedPos, 0, 10, 5, 0, 0.5, 0, [], [[0,0],[0,0]]] call BIS_fnc_findSafePos;
					_nearRoad = [_posDeMeilleurTruc,3] call BIS_fnc_nearestRoad;
				} else {
					_posDeMeilleurTruc = [ClickedPos, 0, 10, 5, 0, 0.5, 0, [], [[0,0],[0,0]]] call BIS_fnc_findSafePos;
					_nearRoad = [_posDeMeilleurTruc,20] call BIS_fnc_nearestRoad;
				};

				if (0 == _posDeMeilleurTruc select 0 && 0 == _posDeMeilleurTruc select 1) then {
					clicked = false;
					[format ["%1<br/><t color='#ff1111'>%2</t>", _zonePrompt, localize "STR_DUWS_T_blz9jyju"]] remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];
				} else {
if (isNull _nearRoad) then {
    if (_posDeMeilleurTruc distance2D [0,0,0] < 500) then {
        clicked = false;
        [format ["%1<br/><t color='#ff1111'>%2</t>", _zonePrompt, localize "STR_DUWS_T_zone_too_close_origin"]] remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];
        _Posfound = false;
        _found_distance = false;
    } else {
        onMapSingleClick "";
        [format ["%1<br/><t color='#66ff66'>%2</t>", _zonePrompt, localize "STR_DUWS_T_7o4m3o2t"]] remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];
        man_missionPos = _posDeMeilleurTruc;
        _Posfound = true;
        _found_distance = true;
    };
} else {
    clicked = false;
    [format ["%1<br/><t color='#ff1111'>%2</t>", _zonePrompt, localize "STR_DUWS_T_wwegpr4y"]] remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];
};
				};
			};
		};

        if (_found_distance) then {

			currzone = _i;
			publicVariable "currzone";  
			_next = amount_zones_created;
			
		    man_missionPos = [round(man_missionPos select 0),round(man_missionPos select 1)];
			_prefab=true;
			if (simple_zones_enable) then {_prefab = false};

			["",man_points_zone,man_zone_radius,man_missionPos,man_fortified,_prefab,currzone] remoteExec ["fnc_createZone", 2];
            _found = true;
            _zones_array = _zones_array + [man_missionPos]; 
			
			[{player globalChat format[localize "STR_DUWS_T_vai9q3po",currzone]}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
			sleep 1;
			[{player globalChat format[localize "STR_DUWS_T_1lfvd9iw",currzone]}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];

            waituntil {sleep 1;amount_zones_created > _next;};
        };
    };
};

[""] remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];

// No completion announcement here: every one of them fires from fnc_init_OPFOR_WARCOM once
// civilians are registered too. Announcing at this point told the player the campaign was
// ready while towns were still being placed.

// Drop the [-9999,-9999,-9999] seed pushed at init so only real zones remain.
_zones_array = [_zones_array, 0] call BIS_fnc_removeIndex;

serv_zones_array = [] + _zones_array;
publicVariable "serv_zones_array";

["INFO", "ZONES", format ["manual placement complete: %1 zones", count serv_zones_array]] call fnc_log;



