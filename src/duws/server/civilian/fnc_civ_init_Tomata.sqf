// Locality: server; the trigger bodies below run on the machine that triggers them, not here.
// Invoked from fnc_init_OPFOR_WARCOM once zone build-out finishes: the towns come from
// fnc_civ_selectTowns, which ranks map towns against the HQ and the enemy zones, so this
// cannot run before zone placement.
if (!isServer) exitWith {};

if (!isNil "civ_init_done") exitWith { ["WARN", "CIV", "Already initialized, skipping."] call fnc_log; };
civ_init_done = true;
["INFO", "CIV", "Initializing civilian system (persistent population with map icons)"] call fnc_log;

// The parameter is the parting map banner: "" clears it, anything else stays up until the
// map closes. The caller publishes mission_init_complete once this returns, so an abort here
// still releases the campaign start.
private _fnc_finish = {
    params [["_prompt", ""]];
    DUWS_civPrompt = _prompt;
    [_prompt] remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];
    ["INFO", "CIV", "Civilian system initialized."] call fnc_log;
};

// Runs before any abort below: PMC/partisan hiring uses civ_array as a body pool
// even when no town is ever registered.
["INFO", "CIV", format ["CIV_PRESENCE = %1", CIV_PRESENCE]] call fnc_log;
[] call fnc_civ_setup_array;
["INFO", "CIV", format ["civ_array loaded, count: %1", count civ_array]] call fnc_log;

// Banner first: the caller cleared the map before handing over, and selection cannot ping its
// own progress until it has enumerated the map's towns.
[localize "STR_DUWS_T_civ_gen_placing"] remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];
([] call ([fnc_civ_selectTowns, DUWS_fnc_restoreTownQueue] select DUWS_campaignLoaded)) params [["_queue", []], ["_spare", []]];

// The base composition spans about 30 m; the rest is margin for its guards, patrols and
// spawn points. Enemy zones are deliberately not gated -- a contested town is the point --
// but a civilian area sitting over the player's own base is not.
private _HQ_RADIUS = 100;
private _hq = missionNamespace getVariable ["PosOfBLUHQ", []];
private _hqPos = if (count _hq >= 2) then { [_hq select 0, _hq select 1, 0] } else { [] };

private _kept = [];
private _radii = [];
private _pops = [];
private _vis = [];
private _bldgs = [];
private _done = 0;

// A queue, not a forEach: an HQ overlap can only be judged once the radius is known here, and
// rejecting a town pushes its replacement back on for the same treatment.
while { count _queue > 0 } do {
    // The building list rides along from selection: it is the heaviest engine call in this pass,
    // and running it again per town entry would repeat it for the whole campaign.
    (_queue deleteAt 0) params ["_loc", "_buildingCount", ["_hqQuota", false], ["_usable", []], ["_savedRadius", 0]];
    private _pos = getPos _loc;
    private _locationName = if (text _loc != "") then { text _loc } else { format ["Unnamed%1", _done] };
    _done = _done + 1;

    [format [localize "STR_DUWS_T_civ_gen_progress", _done, _done + count _queue]]
        remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];

    // A restored town keeps its final radius, so the overlap cull below finds nothing left to trim.
    private _radius = if (_savedRadius > 0) then { _savedRadius } else { (_buildingCount * 10) min 500 max 100 };
    private _hqDist = if (count _hqPos > 0) then { _pos distance2D _hqPos } else { -1 };

    // Areas, not centres: a civilian disc that merely reaches the HQ's still spawns civilians
    // inside the base. The radius formula lives here, not in selection, so the test cannot run
    // before this point -- drop the town and take the next stand-in selection handed over.
    if (_hqDist >= 0 && { _hqDist < _radius + _HQ_RADIUS }) then {
        ["INFO", "CIV", format ["Skipping %1: area (r=%2) overlaps the BLUFOR HQ at %3m", _locationName, _radius, round _hqDist]] call fnc_log;
        if (count _spare > 0) then { _queue pushBack (_spare deleteAt 0) };
    } else {
        // A size figure, not a head count: never decremented, and it is what caps the crowd a town
        // can hold. Counted over a fixed 350 m disc in selection, so it doubles as the town's
        // building density -- which is what makes a clustered spawn feel busier in a bigger town.
        _kept pushBack _loc;
        _radii pushBack _radius;
        _pops pushBack _buildingCount;
        // Trimmed to the town's own area: selection's fixed 350 m disc (comparable ranking across towns)
        // reaches well past a small town's real edge. The reverse -- a radius above 350 -- needs 35+
        // buildings, and a town that dense already packs its cluster far inside 350 m anyway.
        _bldgs pushBack (_usable select { _x distance2D _pos <= _radius });
        // Hardcore hides towns the same way it hides zones, minus the ones the HQ anchor claimed:
        // a player who cannot see a single settlement has nowhere to start looking. A town that
        // was rejected above does not hand its flag to the stand-in that replaces it -- the
        // stand-in is a different place, and the point is what sits around the HQ.
        _vis pushBack (!hardcore_mode_enable || _hqQuota);

        ["INFO", "CIV", format ["Location %1: buildings=%2, radius=%3", _locationName, _buildingCount, _radius]] call fnc_log;
    };
};

private _locations = _kept;

// Warn on the map banner rather than by hint or notification: the map is still open at this
// point, and the engine draws both of those underneath it.
if (count _locations == 0) exitWith {
    ["ERROR", "CIV", "No civilian towns registered. Civilian population is disabled for this campaign."] call fnc_log;
    [format ["%1<br/>%2", localize "STR_DUWS_T_CIV_NO_TOWNS_TITLE", localize "STR_DUWS_T_CIV_NO_TOWNS"]] call _fnc_finish;
};

private _count = count _locations;
private _toDelete = [];
private _minRadius = 50;

for "_i" from 0 to (_count - 1) do {
    if (_i in _toDelete) then { continue };
    for "_j" from (_i + 1) to (_count - 1) do {
        if (_j in _toDelete) then { continue };
        private _pos1 = getPos (_locations select _i);
        private _pos2 = getPos (_locations select _j);
        private _dist = _pos1 distance _pos2;
        private _rad1 = _radii select _i;
        private _rad2 = _radii select _j;
        private _radSum = _rad1 + _rad2;
        if (_dist < _radSum * 1.05) then {
            if (_rad1 <= _rad2) then {
                private _newRad = _rad1;
                while { _newRad > _minRadius && { _dist < (_newRad + _rad2) * 1.05 } } do {
                    _newRad = _newRad - 5;
                };
                if (_dist < (_newRad + _rad2) * 1.05) then {
                    _toDelete pushBack _i;
                } else {
                    _radii set [_i, _newRad];
                };
            } else {
                private _newRad = _rad2;
                while { _newRad > _minRadius && { _dist < (_rad1 + _newRad) * 1.05 } } do {
                    _newRad = _newRad - 5;
                };
                if (_dist < (_rad1 + _newRad) * 1.05) then {
                    _toDelete pushBack _j;
                } else {
                    _radii set [_j, _newRad];
                };
            };
        };
    };
};

_toDelete = _toDelete arrayIntersect _toDelete;

// The losers are dropped from the registry only. These are the map's own Locations now, and
// deleteLocation would remove them from the engine for the rest of the mission -- side
// mission siting (fnc_mission_findSite) and the player's location readout both read them
// back out of nearestLocations.
private _newLocations = [];
private _newRadii = [];
private _newPops = [];
private _newVis = [];
private _newBldgs = [];
for "_i" from 0 to (_count - 1) do {
    if (!(_i in _toDelete)) then {
        _newLocations pushBack (_locations select _i);
        _newRadii pushBack (_radii select _i);
        _newPops pushBack (_pops select _i);
        _newVis pushBack (_vis select _i);
        _newBldgs pushBack (_bldgs select _i);
    };
};

_locations = _newLocations;
_radii = _newRadii;
_pops = _newPops;
missionNamespace setVariable ["civ_locations", _locations];
missionNamespace setVariable ["civ_radii", _radii];
// The same two numbers a client needs to keep a side mission off a town, and nothing else. Those
// two arrays stay server-side -- one holds Location objects and the other is half of a state
// machine -- but the side-mission picker runs on the client and has to be able to ask
// (client/missions/fnc_stratmap.sqf). Plain positions and radii, the shape zone_meta_array already
// broadcasts for the military half.
duws_town_circles = [];
{ duws_town_circles pushBack [getPos _x, _radii param [_forEachIndex, 0]] } forEach _locations;
publicVariable "duws_town_circles";
// Written before the marker loop below, because the renderer it calls reads this to decide
// whether its repaint is allowed to put a town back on the map.
missionNamespace setVariable ["civ_visible", _newVis];
["INFO", "CIV", format ["After overlap cleanup: %1 locations remaining.", count _locations]] call fnc_log;

// Per-town reputation and Army Power worth. Neither array is broadcast: nothing on a client
// reads them, and the markers they drive are painted with global-effect commands.
// Off entirely in RAVAGE and WBK -- a zombie apocalypse has no civil standing to lose, so the
// number would be a dial with nothing on the other end of it. Those towns keep the neutral band permanently.
if !(CIV_PRESENCE in ["RAVAGE", "WBK"]) then {
    private _n = count _locations;
    private _townRep = [];
    private _townAp = [];
    // Runs here rather than in selection because the overlap cull above has only just finalised
    // every radius, and the enemy-zone test is disc against disc.
    private _zoneMeta = missionNamespace getVariable ["zone_meta_array", []];
    {
        private _civPos = getPos _x;
        private _civRad = _radii select _forEachIndex;
        private _buildings = _pops select _forEachIndex;

        // Rank within the campaign's own kept set, not an absolute building count: Altis cities
        // and a small map's hamlets both have to span 1 to 5. Counting strictly smaller towns
        // means ties pay equally and the expression cannot reach 6 (the largest town has _n-1
        // smaller, so 5*(_n-1)/_n floors to at most 4). The figure is the town's worth per tick,
        // paid as CP to a BLUFOR-banded town and AP to an OPFOR-banded one.
        private _smaller = { _x < _buildings } count _pops;
        _townAp pushBack (1 + floor (5 * _smaller / _n));

        // A civilian area whose edge reaches into an enemy zone still puts civilians inside it,
        // so the town starts on the enemy's books rather than neutral.
        private _rep = 0;
        {
            _x params ["", "_zonePos", "_zoneRad"];
            if ((_civPos distance2D _zonePos) < _civRad + _zoneRad) exitWith { _rep = -20 };
        } forEach _zoneMeta;
        if (_rep < 0) then {
            ["INFO", "CIV", format ["Location %1 overlaps an enemy zone: starting at %2", _forEachIndex, _rep]] call fnc_log;
        };
        _townRep pushBack _rep;
    } forEach _locations;
    missionNamespace setVariable ["civ_town_rep", _townRep];
    missionNamespace setVariable ["civ_town_ap", _townAp];
    // Seed the placement keep-out list from the starting reputations: towns overlapping an enemy zone
    // begin at -20, so they are enemy ground before the first band crossing would ever fire the rebuild.
    [] call fnc_enemy_towns_refresh;
    ["INFO", "CIV", format ["Town reputation registered for %1 towns, AP worth %2", _n, _townAp]] call fnc_log;
};

{
    private _locIndex = _forEachIndex;
    private _pos = getPos _x;
    private _radius = _radii select _locIndex;
    private _initialPop = _pops select _locIndex;
    private _locationName = if (text _x != "") then { text _x } else { format ["Unnamed%1", _locIndex] };

    missionNamespace setVariable [format ["civ_pop_%1", _locIndex], _initialPop];
    // Trimmed again here, not just at registration: the overlap cull above can have shrunk this
    // town's radius after the first pass, and a building outside the final disc would pull the
    // crowd beyond the area the map draws around it.
    missionNamespace setVariable [format ["civ_buildings_%1", _locIndex],
        (_newBldgs select _locIndex) select { _x distance2D _pos <= _radius }];

    // RAVAGE and WBK keep the presence trigger and their two-mode handlers. The plain civilian
    // path polls instead, from the single thread started below the loop, so it needs no trigger
    // and no cleanup entry point.
    if (CIV_PRESENCE in ["RAVAGE", "WBK"]) then {
        private _trg = createTrigger ["EmptyDetector", _pos];
        _trg setTriggerArea [_radius, _radius, 0, false, 80];
        _trg setTriggerActivation ["ANYPLAYER", "PRESENT", true];
        private _handlerFunc = ["fnc_civ_handler_ravage", "fnc_civ_handler_wbk"] select (CIV_PRESENCE == "WBK");
        // The reveal rides the presence trigger the population already uses rather than a second
        // trigger of its own, so walking into a town uncovers it exactly as walking into a zone does.
        _trg setTriggerStatements [
        "this",
        format ["[%1, 'spawn'] spawn %2; [%1] call fnc_civ_town_reveal", _locIndex, _handlerFunc],
        format ["[%1, 'cleanup'] spawn %2", _locIndex, _handlerFunc]
        ];
    };

    // Alpha is the whole of hiding: a hidden town keeps its trigger and its population, exactly as a
    // hidden zone keeps its OPFOR. Only the map stays quiet.
    private _shown = _newVis select _locIndex;

    // Created neutral, then repainted below by the same renderer the reputation writer uses,
    // so a town cannot be created reading differently from how it repaints. The neutral pair
    // is what RAVAGE and WBK towns keep: the renderer returns early for them.
    ([0] call fnc_civ_townBand) params ["_areaColour", "_iconColour"];

    private _markerName = format ["civ_area_%1", _locIndex];
    private _marker = createMarker [_markerName, _pos];
    _marker setMarkerShape "ELLIPSE";
    _marker setMarkerBrush "SolidBorder";
    _marker setMarkerColor _areaColour;
    _marker setMarkerAlpha ([0, 0.3] select _shown);
    _marker setMarkerSize [_radius, _radius];

    private _iconPos = [(_pos select 0), (_pos select 1) - 80];
    private _iconName = format ["civ_icon_%1", _locIndex];
    private _icon = createMarker [_iconName, _iconPos];
    _icon setMarkerShape "ICON";
    _icon setMarkerType "loc_tourism";
    _icon setMarkerColor _iconColour;
    _icon setMarkerSize [1.2, 1.2];
    _icon setMarkerAlpha ([0, 1] select _shown);
    [_locIndex] call fnc_civ_townRender;

    ["INFO", "CIV", format ["Created markers for location %1 (%2) pop %3", _locIndex, _locationName, _initialPop]] call fnc_log;
} forEach _locations;

// Registered only once the loop above has published each town's radius, population and building
// list: registration reads all three. Called rather than spawned -- it files hooks and returns.
if !(CIV_PRESENCE in ["RAVAGE", "WBK"]) then { [] call fnc_civ_handler };

// After the crowd, because both register occupants on the same sites and the draft reads the
// per-town population and building survey the loop above published. Called rather than spawned --
// it files hooks and returns, and they have to exist before the poller reaches these towns.
[] call fnc_vendor_init;

// No start-up delay: this runs after zone build-out, not alongside a map-wide scan, so the
// spawns have nothing left to wait out.
missionNamespace setVariable ["civ_spawn_enabled_time", time, true];

call _fnc_finish;
