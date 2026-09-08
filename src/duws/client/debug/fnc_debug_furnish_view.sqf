// Locality: client -- an fnc_debug_furnish_menu row handler, runs on whoever opened the menu. Toggles the
// furnishing grid overlay for one building: a 3D dot per floor cell, coloured by state (open/near/blocked)
// or by room id. The grid is server-built and static (cached on the building), so this fires one gather,
// not a refresh loop. A Draw3D handler is the drawer -- the cells are sub-metre interior points a map
// marker cannot show. Re-checked against game_master because the function is broadcast. English-only debug.
if (!hasInterface) exitWith {};
if (!((vehiclevarname player) in game_master)) exitWith {};
params [["_target", objNull], ["_mode", "state"]];

// One handler, torn down by id; a bare removeMissionEventHandler by index would race a second overlay.
private _teardown = {
    private _id = missionNamespace getVariable ["DUWS_dbgFurnishEH", -1];
    if (_id >= 0) then { removeMissionEventHandler ["Draw3D", _id] };
    DUWS_dbgFurnishEH = -1;
    DUWS_dbgFurnishCells = [];
};

// A second call with the same mode clears; a different mode re-requests without a clear in between.
if ((missionNamespace getVariable ["DUWS_dbgFurnishOn", false])
    && {(missionNamespace getVariable ["DUWS_dbgFurnishMode", ""]) == _mode}) exitWith {
    DUWS_dbgFurnishOn = false;
    call _teardown;
    hint "Furnish grid: overlay cleared.";
};

if (isNull _target) exitWith {
    hint "Furnish grid (debug)\n\nNothing was under the cursor when Debug opened.\nLook at a building first, then open Debug.";
};

call _teardown;
DUWS_dbgFurnishOn = true;
DUWS_dbgFurnishMode = _mode;
DUWS_dbgFurnishCells = [];

// A Draw3D block sees no locals from where it was added, so the mode is read from the global set above
// and the room palette is inlined here rather than captured.
DUWS_dbgFurnishEH = addMissionEventHandler ["Draw3D", {
    private _mode = missionNamespace getVariable ["DUWS_dbgFurnishMode", "state"];
    private _palette = [[0.4,0.7,1,0.9],[1,0.5,0.3,0.9],[0.5,1,0.4,0.9],[1,1,0.3,0.9],[0.8,0.4,1,0.9],[0.3,1,0.9,0.9],[1,0.6,0.8,0.9],[0.7,0.7,0.7,0.9]];
    {
        _x params ["_pos", "_state", "_room"];
        if (player distance _pos <= 40) then {
            private _col = if (_mode == "room") then {
                if (_room < 0) then { [0.5,0.5,0.5,0.6] } else { _palette select (_room mod (count _palette)) }
            } else {
                switch (_state) do {
                    case "open":    { [0.3,1,0.3,0.9] };
                    case "near":    { [1,0.85,0.2,0.9] };
                    default         { [1,0.3,0.3,0.9] };
                };
            };
            private _txt = if (_mode == "room" && {_room >= 0}) then { str _room } else { "" };
            drawIcon3D ["\a3\ui_f\data\map\markers\military\dot_ca.paa", _col, _pos, 0.5, 0.5, 0, _txt, 1, 0.03, "TahomaB"];
        };
    } forEach (missionNamespace getVariable ["DUWS_dbgFurnishCells", []]);
}];

[_target, player, _mode] remoteExec ["fnc_furnish_grid_gather", 2];
hint format ["Furnish grid: gathering %1 overlay.\n\nGreen open, yellow near-wall, red blocked (state);\ncoloured by room id (rooms). Stand inside to see it.", _mode];
