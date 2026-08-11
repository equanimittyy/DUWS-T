// Locality: client -- invoked from a dialog action.


///// DUWS_T  RERUN THE OPFOR FACTION FILE FOR JIP SIDE MISSION GEN
if (hasInterface && isMultiplayer)	then {
	[] call fnc_OPFOR_FactionFile_X;
	sleep 1;
};

if (isnil ("Mission_available")) then {Mission_available = true;publicVariable "Mission_available"};
if (!Mission_available) exitWith {
_speaker = localize "STR_DUWS_T_OVERLORD";
_speakeracteam = localize "STR_DUWS_T_actionteam";
_message = ([localize "STR_DUWS_T_missioncooldown"] call fnc_cs);
_message1 = localize "STR_DUWS_T_missioncooldown2";
// Answers the player who opened the menu, so it stays on their machine: this function is spawned
// by the request-menu action and already runs there. It was addressed to player1, which in co-op
// showed one player the refusal for another player's click.
hint localize "STR_DUWS_T_b68ftbvf";
[_speakeracteam, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 4;
[_speaker, _message1] remoteExec ["fnc_duws_dialogue", 0];
};

if (!((vehiclevarname player) in game_master)) exitWith {hint ([localize "STR_DUWS_T_eck4xh9m"] call fnc_cs)};

// init the array of missions
array_of_missions = [];

failsafe_not_found = true;
failsafe_not_found2 = false;
[] spawn {  // Spawn the secondary failsafe
	uiSleep 20;
	failsafe_not_found2 = true;
};

_handle = [] spawn {  // Spawn the MAIN SEARCH

  _counter = 0;
  [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_missionlook"] remoteExec ["fnc_duws_dialogue", 0];
  _kibot_pos_array_missionPos = [[-99999,-99999,-99999]];

  // Included inside the block, not above it: a spawned block captures no locals.
  private _missionDefs = [
  #include "..\..\shared\includes\mission_types.hpp"
  ];
  // Positions and names the launcher blocks read back, one slot per type. A global because the
  // blocks run later, from the map, and capture nothing.
  DUWS_missionSlots = [];
  { DUWS_missionSlots pushBack [] } forEach _missionDefs;

  _missionCount = [];
  { _missionCount pushBack _forEachIndex } forEach _missionDefs;
  _missionShuffle = _missionCount call BIS_fnc_arrayShuffle;
  // Seven drawn from the shuffled seventeen, not all of them. Every candidate costs a
  // BIS_fnc_findSafePos search before it can be offered, so the full pool spent that search
  // ten extra times to build a list no one reads to the bottom of.
  _missionDraw = 7 min (count _missionCount);

  // Frontier weighting for the anchor search. Anchors are drawn toward OPFOR ground nearest
  // friendly-held territory -- the HQ, FOBs and captured zones -- so a request rarely lands
  // behind the enemy's full depth on the far side of the map. As zones fall the friendly set
  // grows and the reachable band advances with the front. Reuses the ownership store the AoI
  // field reads; the friendly-AoI exclusion itself is applied server-side in fnc_missionTargetPos.
  private _frontierBias = 2;      // inverse-distance exponent: higher hugs the front harder
  private _frontierBand = 2000;   // metres past an OPFOR zone edge the countryside search spans

  private _bluHeld = if (isNil "WARCOM_zones_controled_by_BLUFOR") then {[]} else {WARCOM_zones_controled_by_BLUFOR};
  private _friendlyAnchors = +_bluHeld;
  if (!(PosOfBLUHQ isEqualTo [])) then { _friendlyAnchors pushBack PosOfBLUHQ };
  if (!(isNil "Array_of_FOBpos")) then { { _friendlyAnchors pushBack _x } forEach Array_of_FOBpos };

  // OPFOR-held zones as [[pos,radius], pos] pairs, precomputed once: ownership is fixed for
  // the few seconds this picker runs. A zone is OPFOR unless its centre sits in the BLUFOR-held
  // list -- the same control test the capture triggers and the AoI field use.
  private _opforZoneCands = [];
  {
      _x params ["", "_zp", "_zs"];
      if ((_bluHeld findIf {(_x distance2D _zp) < 1}) < 0) then {
          _opforZoneCands pushBack [[_zp, _zs], _zp];
      };
  } forEach zone_meta_array;

  // [_cands, _anchors, _bias] -> one item. _cands are [item, pos] pairs; weight is
  // 1 / dist(pos, nearest anchor)^_bias, so ground near the front is favoured but the deep
  // rear is thinned, not banned -- the spread stays. No anchors (campaign hour zero) -> flat random.
  private _fnFrontierPick = {
      params ["_cands", "_anchors", "_bias"];
      private _items = _cands apply {_x select 0};
      if (_anchors isEqualTo []) exitWith { selectRandom _items };
      private _weights = _cands apply {
          private _cpos = _x select 1;
          private _d = (selectMin (_anchors apply {_cpos distance2D _x})) max 1;
          1 / (_d ^ _bias)
      };
      _items selectRandomWeighted _weights
  };

  while {_counter < _missionDraw} do {

	// Proportional to the draw, not a fixed 0.1 a step: that constant was sized for the old
	// full-pool loop and would now stall the bar at 0.6.
	_progress = _counter / _missionDraw;
	progressLoadingScreen _progress;

	// DUWS_T "More Urban": near a building, clear of zone centres.

	_Posfound = false;
	_ZnLocation = [];
	_foundSafePos = [];

	while {!_Posfound} do {
		
		if (moreUrban == 1 && failsafe_not_found2 == false) then {
			// MORE URBAN -- named location, frontier-weighted toward the front
			_ZnAnchor = position ([MissionLocations apply {[_x, position _x]}, _friendlyAnchors, _frontierBias] call _fnFrontierPick);
			_ZnLocation = [_ZnAnchor, 100, 400,10,0,0.3,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;
			_Building = nearestBuilding _ZnLocation;
			_foundSafePos = [(getpos _Building select 0),(getpos _Building select 1)];
		}else{
			// LESS URBAN -- OPFOR countryside band, frontier-weighted. Falls back to the old
			// HQ ring only when every zone is already BLUFOR-held (win state).
			if (_opforZoneCands isEqualTo []) then {
				_foundSafePos = [PosOfBLUHQ, 0, (zones_max_dist_from_hq*1.5),5,0,0.3,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;
			} else {
				([_opforZoneCands, _friendlyAnchors, _frontierBias] call _fnFrontierPick) params ["_pzp", "_pzs"];
				_foundSafePos = [_pzp, _pzs, _pzs + _frontierBand,5,0,0.3,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;
			};
		};

		_Posfound = true;

		// Clear of every zone, by the zone's own radius rather than the campaign ceiling. The 400 m
		// on top is roughly what a mission's objective drifts from the anchor offered here
		// (fnc_missionTargetPos), so an anchor accepted a metre outside a zone does not hand that
		// thread fifty rejections and an abort. The drifted position is tested again there, which is
		// the test that actually decides; this one only keeps the offer off a zone.
		if ([_foundSafePos, 400] call fnc_pos_claimed) then {_Posfound = false};

	};
 
	// CREATE AN ARRAY OF POSSIBLE POSITIONS
    _found_dist_away = true;
    _kibot_distances_array = [];
    // for each element of the array of safe positions, 
    for [{_t=1}, {_t <= count _kibot_pos_array_missionPos}, {_t=_t+1}] do 
    {                                         
        // get the index of the element
        _kibot_pos_array_missionPos_index = _t-1;
        // create an array of all missionPos distances to current _foundSafePos.
        _kibot_distances_array = _kibot_distances_array +[(_kibot_pos_array_missionPos select _kibot_pos_array_missionPos_index) distance (_foundSafePos)]; 
    };
    // for each element of the array of distances we just generated...
    for [{_t=1}, {_t<=count _kibot_distances_array}, {_t=_t+1}] do
    {                                           
        // get the index of the tested element
        _kibot_distances_array_index = _t-1;
        // select an element with index so we can check it
        _check = (_kibot_distances_array select _kibot_distances_array_index);
        // check the distances contained in the distances array 1 by 1. If a distance is inferior to defined values, dump it.
        if (_check < 250) then {
            // If any mission is <250m away, tell it to this variable;
            _found_dist_away = false;   
        };
    };

    if (_foundsafePos distance player > 1500
        && _found_dist_away
        && _foundsafePos distance hq_blu1 < (zones_max_dist_from_hq*1.5)) then {

        // A VALID POS HAS BEEN FOUND add the position to the array of missionPos
        _kibot_pos_array_missionPos = _kibot_pos_array_missionPos + [_foundSafePos];
		
		// Clears against the draw, not the pool: the loop stops at _missionDraw, so comparing
		// with the full pool size leaves the failsafe armed and aborts every request.
		if (_counter == _missionDraw-1) then {failsafe_not_found = false;};
		_currentMission = _missionShuffle select _counter;

		// Add each mission type to stratmap array. The row supplies the description, the icon and
		// the launcher; the search supplies the position and the name, which go into the shared
		// slot array the launcher reads back.
		(_missionDefs select _currentMission) params ["", "", "_desc", "_icon", "", "_launcher"];
		private _name = [0] call fnc_random_name;
		DUWS_missionSlots set [_currentMission, [_foundSafepos, _name]];

		array_of_missions pushBack [
			_foundSafepos,
			_launcher,
			_name,
			localize _desc,
			"",
			_icon,
			1,
			[]
		];

        _counter = _counter + 1;
	};
  };

  // The two deepest offers pay more: rank the built offers by how far their position sits from
  // friendly-held ground (the same anchors the frontier search used) and flag the two farthest by
  // name. fnc_mission_reward reads DUWS_rewardBoost back on the server and scales their payout, so
  // pushing deep into enemy territory is worth the risk. Overwritten each request -- safe because a
  // request is gated shut while a mission is live (Mission_available).
  private _depths = array_of_missions apply {
      private _mp = _x select 0;
      private _d = if (_friendlyAnchors isEqualTo []) then {
          _mp distance PosOfBLUHQ
      } else {
          selectMin (_friendlyAnchors apply {_mp distance2D _x})
      };
      [_d, _x select 2]
  };
  _depths sort false;
  DUWS_rewardBoost = (_depths select [0, 2]) apply {_x select 1};
  publicVariable "DUWS_rewardBoost";

  // Surface the bonus on the map so the incentive is visible: append a red structured-text tag to
  // each flagged offer's description. The description control renders structured text -- the
  // per-type briefings already carry <br /> and their base CP/AP figures.
  private _boostTag = format ["<br /><br /><t color='#ff0000'>%1</t>", localize "STR_DUWS_T_reward_boost_tag"];
  {
      private _bn = _x;
      private _ri = array_of_missions findIf {(_x select 2) isEqualTo _bn};
      if (_ri >= 0) then {
          private _row = array_of_missions select _ri;
          _row set [3, (_row select 3) + _boostTag];
      };
  } forEach DUWS_rewardBoost;

  // Civs-off CP lift: with no town-rep economy (civilians off, or the RAVAGE/WBK modes) mission CP is
  // paid x1.5 to substitute the absent town-CP faucet (server/missions/fnc_mission_reward.sqf). The gate
  // there is civ_town_rep being empty, which is server-only; CIV_PRESENCE is the broadcast setting that
  // decides it, so the client reproduces the same condition to surface the lift on every offer.
  if ((isNil "CIV_PRESENCE") || {CIV_PRESENCE in ["NONE", "RAVAGE", "WBK"]}) then {
      private _civTag = format ["<br /><br /><t color='#ff0000'>%1</t>", localize "STR_DUWS_T_reward_civsoff_tag"];
      { _x set [3, (_x select 3) + _civTag] } forEach array_of_missions;
  };

  missionSearchDone = 1;
};

_maxTime = diag_tickTime + 60; // max 60s of loadingscreen before failsafe aborts
startLoadingScreen [localize "STR_DUWS_T_dmfmwmfp"];
waitUntil { uiSleep .01; !isNil "missionSearchDone" || diag_tickTime > _maxTime };
missionSearchDone = nil;
endLoadingScreen;
terminate _handle;

if (failsafe_not_found == true) exitWith {hint localize "STR_DUWS_T_crtzxs0j"};

hint localize "STR_DUWS_T_mission_selector_title";

// NOW OPEN THE MAP
_isNight = false;
if ((20 < daytime) OR (daytime < 5)) then {_isNight=true};

// https://community.bistudio.com/wiki/BIS_fnc_StrategicMapOpen
// 0: DISPLAY - parent display. When empty, mission display is used.
// 1: ARRAY - default view position in format [x,y,y] or [x,y]
// 2: ARRAY - list of missions in format:
// 3: ARRAY - list of ORBAT groups in format:
// 4: ARRAY - list of markers revealed in strategic map (will be hidden when map is closed)
// 5: ARRAY - list of custom images in format:
// 6: NUMBER - value in range <0-1> defining weather on strategic map (i.e. density of clouds)
// 7: BOOL - true for night version of strategic map (darker with blue tone)

[(findDisplay 46), getpos player, array_of_missions, [], [], [], 1, _isNight] call BIS_fnc_strategicMapOpen;

