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

  // Split the draw by difficulty: most offers seat near the frontline (easy, base pay); the rest push
  // deep into enemy ground (hard, a difficulty-scaled bonus). Hard is capped at 2 and easy takes the
  // remainder, so a short pool degrades to fewer hard rather than a negative easy count.
  private _hardCount = 2 min _missionDraw;
  private _easyCount = _missionDraw - _hardCount;
  private _hardOffers = [];   // [name, depth-from-friendly] per hard offer -> multiplier after the loop

  // Anchors for the hard-offer depth calc below: friendly-held ground is HQ, FOBs, and captured
  // zones. The placement weighting that used to live here -- frontline seam, deep-enemy score, the
  // OPFOR-zone band search, the finder handshake -- now lives in server/missions/fnc_mission_findSite,
  // called per offer below, so the debug force tool sites through the same logic instead of a copy.
  private _bluHeld = if (isNil "WARCOM_zones_controled_by_BLUFOR") then {[]} else {WARCOM_zones_controled_by_BLUFOR};
  private _friendlyAnchors = +_bluHeld;
  if (!(PosOfBLUHQ isEqualTo [])) then { _friendlyAnchors pushBack PosOfBLUHQ };
  if (!(isNil "Array_of_FOBpos")) then { { _friendlyAnchors pushBack _x } forEach Array_of_FOBpos };

  while {_counter < _missionDraw} do {

	// Proportional to the draw, not a fixed 0.1 a step: that constant was sized for the old
	// full-pool loop and would now stall the bar at 0.6.
	progressLoadingScreen (_counter / _missionDraw);

	_currentMission = _missionShuffle select _counter;
	private _threadName = (_missionDefs select _currentMission) select 0;

	// This offer's difficulty: the last _hardCount of the draw push deep, the rest seat on the front.
	private _hard = _counter >= _easyCount;
	// "More Urban" seats offers in named locations; drop it once its 20s failsafe has fired.
	private _allowUrban = (moreUrban == 1) && !failsafe_not_found2;

	// Same siting the debug force tool uses. _kibot_pos_array_missionPos is the keep-apart list, seeded
	// with a sentinel at the top of this thread; a [] result means the finder found no fit -> drop it.
	private _foundSafePos = [_threadName, _hard, getPos player, _kibot_pos_array_missionPos, _allowUrban] call fnc_mission_findSite;

	if (_foundSafePos isEqualTo []) then {
		["INFO", "MISSION", format ["site: type %1 found no fit, dropping offer", _currentMission]] call fnc_log;
		_counter = _counter + 1;
	} else {
		_kibot_pos_array_missionPos pushBack _foundSafePos;

		// Clears against the draw, not the pool: the loop stops at _missionDraw, so comparing with the
		// full pool size leaves the failsafe armed and aborts every request.
		if (_counter == _missionDraw-1) then {failsafe_not_found = false;};

		// The row supplies the description, the icon and the launcher; the search supplies the position
		// and the name, which go into the shared slot array the launcher reads back.
		(_missionDefs select _currentMission) params ["", "_nameKey", "_desc", "_icon", "", "_launcher", "_mcp", "_map", "_mrep", "_mdl", "", "_obj", ["_note", ""]];
		private _name = [0] call fnc_random_name;
		DUWS_missionSlots set [_currentMission, [_foundSafepos, _name]];

		// The stats block mirrors the journal's (fnc_missionTaskCreate) but prints a time band, not a
		// deadline clock: pre-pick, the deadline has not been rolled. Name, type and note come from the
		// same single source, mission_types.hpp, so editing a row moves the map figure and the paid
		// figure together. REP prints only where the type grants it.
		private _descFull = localize _desc;
		if (_note != "") then { _descFull = _descFull + "<br />" + format [localize "STR_DUWS_T_mission_note_line", localize _note] };
		_descFull = _descFull + "<br />" + localize "STR_DUWS_T_mission_divider";
		_descFull = _descFull + format [localize "STR_DUWS_T_mission_name_line", localize _nameKey];
		_descFull = _descFull + format [localize "STR_DUWS_T_mission_type_line", (toUpper (_obj select [0,1])) + (_obj select [1])];
		_descFull = _descFull + format [localize "STR_DUWS_T_mission_cpap", _mcp, _map];
		if (_mrep > 0) then { _descFull = _descFull + format [localize "STR_DUWS_T_mission_rep", _mrep] };
		_mdl params ["_dlMinH", "_dlMaxH"];
		_descFull = _descFull + (if (_dlMinH >= _dlMaxH)
			then { format [localize "STR_DUWS_T_mission_time_fixed", _dlMinH] }
			else { format [localize "STR_DUWS_T_mission_time_range", _dlMinH, _dlMaxH] });

		// Record hard offers with their depth from friendly-held ground; the loop's tail turns depth
		// into the 1.5x-2x multiplier. Same anchor set the frontier search measures against.
		if (_hard) then {
			private _depth = if (_friendlyAnchors isEqualTo []) then {
				_foundSafepos distance PosOfBLUHQ
			} else {
				selectMin (_friendlyAnchors apply {_foundSafepos distance2D _x})
			};
			_hardOffers pushBack [_name, _depth];
		};

		array_of_missions pushBack [
			_foundSafepos,
			_launcher,
			_name,
			_descFull,
			"",
			_icon,
			1,
			[]
		];

		_counter = _counter + 1;
	};
  };

  // Hard offers pay a difficulty-scaled bonus: their multiplier spans 1.5x (shallowest of the hard
  // set) to 2x (deepest), linear in depth from friendly-held ground. Easy offers get no entry and pay
  // flat. fnc_mission_reward reads DUWS_rewardBoost back on the server as [name, multiplier] pairs.
  // Overwritten each request -- safe because a request is gated shut while a mission is live
  // (Mission_available).
  private _hardDepths = _hardOffers apply {_x select 1};
  private _dmin = if (_hardDepths isEqualTo []) then {0} else {selectMin _hardDepths};
  private _dmax = if (_hardDepths isEqualTo []) then {0} else {selectMax _hardDepths};
  private _span = (_dmax - _dmin) max 1;   // guard a single hard offer (or a depth tie) against /0
  DUWS_rewardBoost = _hardOffers apply {
      _x params ["_nm", "_dp"];
      [_nm, 1.5 + 0.5 * ((_dp - _dmin) / _span)]
  };
  publicVariable "DUWS_rewardBoost";

  // Surface the bonus on the map so the incentive is visible: append a red structured-text tag, with
  // the offer's own multiplier, to each hard offer's description. The description control renders
  // structured text -- the per-type briefings already carry <br /> and their base CP/AP figures.
  {
      _x params ["_bn", "_bm"];
      private _ri = array_of_missions findIf {(_x select 2) isEqualTo _bn};
      if (_ri >= 0) then {
          private _tag = format ["<br /><t color='#ff0000'>%1</t>",
              format [localize "STR_DUWS_T_reward_boost_tag", (round (_bm * 10)) / 10]];
          private _row = array_of_missions select _ri;
          _row set [3, (_row select 3) + _tag];
      };
  } forEach DUWS_rewardBoost;

  // Civs-off CP lift: with no town-rep economy (civilians off, or the RAVAGE/WBK modes) mission CP is
  // paid x1.5 to substitute the absent town-CP faucet (server/missions/fnc_mission_reward.sqf). The gate
  // there is civ_town_rep being empty, which is server-only; CIV_PRESENCE is the broadcast setting that
  // decides it, so the client reproduces the same condition to surface the lift on every offer.
  if ((isNil "CIV_PRESENCE") || {CIV_PRESENCE in ["NONE", "RAVAGE", "WBK"]}) then {
      private _civTag = format ["<br /><t color='#ff0000'>%1</t>", localize "STR_DUWS_T_reward_civsoff_tag"];
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

