// Locality: server -- createMine and revealMine must run where the mines are made.
//
// One square per call; a larger field is several squares laid by the caller, stepped by DUWS_mineSquare.
//
// A field is planned as coordinates first and only then made into objects. OPCOM lays belts up to 1.5 km
// long, which is hundreds of mines if every square exists at once, so for those the plan is the
// field's real state: a square within reach of a player holds objects, every other square holds only the
// positions it will put back, and a mine the player took off the map leaves the plan rather than a list
// of handles. A short field (a civilian job) is laid whole and skips all of it.
//
// Vanilla mine classes only: the same footing as the Land_* props the compositions use, so nothing
// here forces a mod. east revealMine marks each mine as OPFOR-laid, which keeps OPFOR AI off its own
// field and leaves BLUFOR to detect and clear it.

#define MINE_CELL 10
// A mine may land this far from its cell's centre, out to the cell edge, which is enough to break up the grid.
// A spread past the edge let neighbouring cells overlap, and the clumps and gaps it made read as too random.
#define MINE_SPREAD 5
// Half a square's diagonal plus the spread past its edge: no mine is made under somebody standing there.
#define MINE_NO_POP 50

DUWS_mineSquare = 50;

// A streamed square's mines are made inside the first distance and deleted past the second. The in-ring
// must cover a vehicle crossing a whole site poll (SITE_TICK) at speed, or a driver reaches ground
// whose mines do not exist yet. The 100 m between the two is hysteresis: somebody holding station on that
// edge would otherwise re-lay and clear the same square every pass.
DUWS_mineStreamIn = 350;
DUWS_mineStreamOut = 450;

// [variant, classes, mines per cell]. A table beside its only reader,
// the way DUWS_staticRoles sits by its resolver, so the AT/AP sets are edited as data not code.
// A fractional count is rolled per cell, so AT's 0.36 averages 9 mines a square and AP's 0.44 averages 11.
// Thin, because a belt is deep rather than dense: what a vehicle meets is the mines down the whole depth it
// crosses, so depth buys the same bite for fewer mines standing at once.
DUWS_mineVariants = [
    ["AT", ["ATMine"], 0.36],
    ["AP", ["APERSMine"], 0.44]
];

// [_center, _dir, _variant] call fnc_hardpoint_minefield_plan -> [[[x,y], class], ...]
//   _dir     degrees     clockwise like setDir
//   _variant "AT" | "AP" resolved through DUWS_mineVariants; an unknown token falls to AT
fnc_hardpoint_minefield_plan = {
    params ["_center", "_dir", ["_variant", "AT"]];

    private _hit = DUWS_mineVariants findIf { (_x select 0) isEqualTo (toUpper _variant) };
    (if (_hit >= 0) then { DUWS_mineVariants select _hit } else { DUWS_mineVariants select 0 }) params ["", "_classes", "_perCell"];

    private _cx = _center select 0;
    private _cy = _center select 1;
    private _half = DUWS_mineSquare / 2;
    private _plan = [];
    for "_i" from 0 to (DUWS_mineSquare / MINE_CELL - 1) do {
        for "_j" from 0 to (DUWS_mineSquare / MINE_CELL - 1) do {
            for "_k" from 1 to (floor (_perCell + random 1)) do {
                private _off = [
                    (_i + 0.5) * MINE_CELL + ((random 2) - 1) * MINE_SPREAD - _half,
                    (_j + 0.5) * MINE_CELL + ((random 2) - 1) * MINE_SPREAD - _half,
                    _dir] call fnc_hardpoint_rotate;
                _plan pushBack [[_cx + (_off select 0), _cy + (_off select 1)], selectRandom _classes];
            };
        };
    };
    _plan
};

// [_plan, _key] call fnc_hardpoint_minefield_make -> [mines], one object per plan entry and in the same
// order, so a caller holding both can drop a spent mine's position with it.
fnc_hardpoint_minefield_make = {
    params ["_plan", ["_key", ""]];
    private _mines = [];
    {
        _x params ["_p", "_class"];
        private _mine = createMine [_class, [_p select 0, _p select 1, 0], [], 0];
        east revealMine _mine;
        if (_key != "") then { [_mine, _key] call fnc_duws_keep };
        _mines pushBack _mine;
    } forEach _plan;
    _mines
};

// [_center, _dir, _variant, _key] call fnc_hardpoint_minefield -> [mines]
//   _key  site key  files each mine under the key for teardown and the clearance count;
//                   "" leaves them unmanaged
fnc_hardpoint_minefield = {
    params ["_center", "_dir", ["_variant", "AT"], ["_key", ""]];
    private _mines = [[_center, _dir, _variant] call fnc_hardpoint_minefield_plan, _key] call fnc_hardpoint_minefield_make;

    // Filed by key so the clearance check can read what is left: the field is spent when no armed mine
    // remains, and its own hazard list is the only count of that. Signs are not in it -- a warning
    // marker is not a hazard, and a field of only signs is a cleared field. Appended, so every square
    // laid under one key clears as one field.
    if (_key != "") then {
        private _var = format ["DUWS_hpMines_%1", _key];
        missionNamespace setVariable [_var, (missionNamespace getVariable [_var, []]) + _mines];
    };

    _mines
};

// [_centres, _dir, _key] call fnc_hardpoint_minefield_signs -- warning signs for a whole field, drawn
// from its squares. One per eight squares rather than one per square: a sign on every square of a long
// belt traces its whole run for the player, and costs more objects than a square's mines.
// Inner 80% of the square only, so a sign never marks the field's edge.
fnc_hardpoint_minefield_signs = {
    params ["_centres", "_dir", ["_key", ""]];
    if (_centres isEqualTo []) exitWith {};
    private _half = DUWS_mineSquare / 2;
    for "_i" from 1 to (2 max round ((count _centres) / 8)) do {
        private _c = selectRandom _centres;
        private _off = [((random 2) - 1) * _half * 0.8, ((random 2) - 1) * _half * 0.8, _dir] call fnc_hardpoint_rotate;
        private _sign = createVehicle ["Land_Sign_Mines_F",
            [(_c select 0) + (_off select 0), (_c select 1) + (_off select 1), 0], [], 0, "CAN_COLLIDE"];
        _sign setDir (random 360);
        if (_key != "") then { [_sign, _key] call fnc_duws_keep };
    };
};

// [_centres, _dir, _variant, _key] call fnc_hardpoint_minefield_stream -> mines planned. Registers the
// field for streaming instead of laying it: nothing is made until fnc_hardpoint_minefield_cycle runs.
// A square is [centre, plan, objects]; objects [] means the square is off the map.
fnc_hardpoint_minefield_stream = {
    params ["_centres", "_dir", "_variant", "_key"];
    private _squares = [];
    private _total = 0;
    {
        private _plan = [_x, _dir, _variant] call fnc_hardpoint_minefield_plan;
        if (_plan isEqualTo []) then { continue };
        _total = _total + count _plan;
        _squares pushBack [_x, _plan, []];
    } forEach _centres;
    // Nothing filed when nothing was planned: a key holding an empty square list reads as a field whose
    // every mine is gone, and the next clearance pass would clear a field that was never laid.
    if (_total > 0) then {
        missionNamespace setVariable [format ["DUWS_hpMineSquares_%1", _key], _squares];
        missionNamespace setVariable [format ["DUWS_hpMineLaid_%1", _key], _total];
    };
    _total
};

// [_cols, _rows] call fnc_hardpoint_minefield_ring -> the site radius a belt needs: half its long side
// plus the stream-out distance, so the poller is still looking at the field while a player stands on its
// far end. The type table's ring covers one emplacement, and a belt is kilometres of them.
fnc_hardpoint_minefield_ring = {
    params ["_cols", "_rows"];
    ceil (((_cols max _rows) * DUWS_mineSquare / 2) + DUWS_mineStreamOut)
};

// [_key] call fnc_hardpoint_minefield_left -> mines the field still holds, standing or not. The plan is
// the count, not the objects: a square off the map is still mined ground.
fnc_hardpoint_minefield_left = {
    params ["_key"];
    private _n = 0;
    { _n = _n + count (_x select 1) } forEach (missionNamespace getVariable [format ["DUWS_hpMineSquares_%1", _key], []]);
    _n
};

// [_key, _here, _revealed] call fnc_hardpoint_minefield_cycle -> whether any mine stands (always, for a
// field laid whole) -- one site-poller pass over a streamed field. A square nobody is near never exists,
// so a belt costs its stream ring, not its length.
// _here false (nobody inside the site's ring) takes the whole field off the map without a player scan.
fnc_hardpoint_minefield_cycle = {
    params ["_key", "_here", ["_revealed", false]];
    private _squares = missionNamespace getVariable [format ["DUWS_hpMineSquares_%1", _key], []];
    if (_squares isEqualTo []) exitWith { true };

    private _players = [];
    if (_here) then { _players = ((call BIS_fnc_listPlayers) select { alive _x }) apply { getPosATL _x } };

    private _up = false;
    {
        _x params ["_c", "_plan", "_objs"];
        // Backwards, so deleting an entry cannot skip the next one. Plan and objects are index-aligned:
        // a mine that has gone off or been disarmed takes its position with it, and that ground stays clear.
        for "_i" from (count _objs) - 1 to 0 step -1 do {
            private _m = _objs select _i;
            if (isNull _m || {!mineActive _m}) then {
                _objs deleteAt _i;
                _plan deleteAt _i;
            };
        };

        // Walked rather than mapped through apply: a belt is up to 90 squares and this runs every pass,
        // so an allocation per square to find one number is the loop's whole cost.
        private _d = 1e9;
        { private _pd = _x distance2D _c; if (_pd < _d) then { _d = _pd } } forEach _players;
        if (_objs isEqualTo [] && {_plan isNotEqualTo []} && {_d < DUWS_mineStreamIn} && {_d > MINE_NO_POP}) then {
            private _made = [_plan, _key] call fnc_hardpoint_minefield_make;
            // Not JIP-queued: these objects live only while somebody is near, and a queue entry per square
            // per pass would outlive them. A client joining onto a standing square reveals on its next lay.
            if (_revealed) then { [_made] remoteExec ["fnc_hardpoint_minefield_reveal", 0] };
            _objs append _made;
        };
        if (_objs isNotEqualTo [] && {_d > DUWS_mineStreamOut}) then {
            { deleteVehicle _x } forEach _objs;
            _objs resize 0;
        };
        if (_objs isNotEqualTo []) then { _up = true };
    } forEach _squares;
    _up
};

// [_mines] remoteExec ["fnc_hardpoint_minefield_reveal", 0, jip] -- adds the mines to this machine's map icons.
// Not west revealMine: that also draws the engine's 3D mine icons, at a range only the difficulty's
// detected-mines option sets. Cost: BLUFOR AI no longer steers clear of a revealed field.
fnc_hardpoint_minefield_reveal = {
    params ["_mines"];
    if (!hasInterface) exitWith {};
    DUWS_revealedMines = ((missionNamespace getVariable ["DUWS_revealedMines", []]) select { !isNull _x }) + _mines;
};

// [] spawn fnc_hardpoint_minefield_map_icons -- client. Draws each revealed mine on the main map with the
// engine's own detected-mine icon.
fnc_hardpoint_minefield_map_icons = {
    if (!hasInterface) exitWith {};
    DUWS_mineIcon = getText (configFile >> "CfgInGameUI" >> "Cursor" >> "explosive");
    // Config colour entries can be profile-colour expression strings rather than numbers.
    DUWS_mineIconColour = (getArray (configFile >> "CfgInGameUI" >> "Cursor" >> "explosiveColor"))
        apply { if (_x isEqualType "") then { call compile _x } else { _x } };
    DUWS_mineIconColour set [3, 0.5];
    waitUntil { !isNull findDisplay 12 };
    (findDisplay 12 displayCtrl 51) ctrlAddEventHandler ["Draw", {
        params ["_map"];
        {
            if (!isNull _x && {mineActive _x}) then {
                _map drawIcon [DUWS_mineIcon, DUWS_mineIconColour, getPosATL _x, 12, 12, 0, ""];
            };
        } forEach (missionNamespace getVariable ["DUWS_revealedMines", []]);
    }];
};

// [_center, _dir, _cols, _rows] call fnc_hardpoint_minefield_grid -> [[x,y], ...] square centres of a
// block _cols wide and _rows deep about _center, rows stacked along _dir.
fnc_hardpoint_minefield_grid = {
    params ["_center", "_dir", "_cols", "_rows"];
    private _out = [];
    for "_c" from 0 to (_cols - 1) do {
        for "_r" from 0 to (_rows - 1) do {
            private _off = [(_c - (_cols - 1) / 2) * DUWS_mineSquare, (_r - (_rows - 1) / 2) * DUWS_mineSquare, _dir]
                call fnc_hardpoint_rotate;
            _out pushBack [(_center select 0) + (_off select 0), (_center select 1) + (_off select 1)];
        };
    };
    _out
};
