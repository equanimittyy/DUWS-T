// Locality: client -- inherited from client/client_init.sqf.
// Every standing 3D icon the mission draws over a fixed thing: the HQ itself, and the base
// facilities a player has to find before they can use one. One handler over one table, because
// these were two drawers whose range, colour, opacity, text size and font were copies of each
// other -- and a copy is a thing you have to remember to edit twice.
//
// Not a stacked onEachFrame: taking one down needs a bare `onEachFrame {}`, which clears every
// stacked handler in the mission rather than its own, so any other system that wants one has to
// work around it.
//
// The killhouse contact markers stay out of this table (client/killhouse/fnc_killhouse_markers.sqf).
// Their alpha is a per-frame function of range and their subjects are a list that changes as the
// run goes on, where everything here is a prop that stands still.
if (!hasInterface) exitWith {};

DUWS_icon3d_range  = 30;                // metres, player to the icon's own subject
DUWS_icon3d_colour = [0.2, 1, 0.2, 0.5];

// [source, icon, label, metres above the subject, unlock flag ("" draws unconditionally)]
//
// A source is the NAME of a global, not the value: a string holding a netId resolves to that
// object and the icon rides it, an array is read as a position. Naming the global rather than
// holding the thing is what lets this table be built before the HQ is, and a row whose global is
// still unset simply does not draw. Global rather than local because a Draw3D block sees no
// locals from where it was written.
DUWS_icon3d_rows = [
    ["PosOfBLUHQ",           "\a3\ui_f\data\gui\cfg\hints\Commanding_ca.paa", localize "STR_DUWS_T_FACILITY_HQ",        2.5, ""],
    ["HQ_mapBoard_netId",    "\a3\ui_f\data\gui\cfg\hints\Firemode_ca.paa",   localize "STR_DUWS_T_FACILITY_KILLHOUSE", 2.5, ""],
    ["HQ_medTent_netId",     "\A3\ui_f\data\IGUI\Cfg\Actions\heal_ca.paa",    localize "STR_DUWS_T_FACILITY_RESTTENT",  4,   ""],
    ["HQ_repairDepot_netId", "\A3\ui_f\data\IGUI\Cfg\Actions\repair_ca.paa",  localize "STR_DUWS_T_FACILITY_VEHMOD",    3,   "support_veh_repair_available"]
];

addMissionEventHandler ["Draw3D", {
    {
        _x params ["_srcVar", "_icon", "_label", "_height", "_flagVar"];
        // A station nobody has bought carries no actions, so an icon over it points at an inert
        // prop. The depot is scenery from the moment the base is built, unlocked or not.
        if (_flagVar == "" || {missionNamespace getVariable [_flagVar, false]}) then {
            // Defaulted to a number rather than nil: nil in an array is its own kind of trouble,
            // and a scalar falls through to the same "no subject yet" answer.
            private _src = missionNamespace getVariable [_srcVar, 0];
            private _pos = switch (typeName _src) do {
                case "STRING": {
                    private _obj = objectFromNetId _src;
                    if (isNull _obj) then { [] } else { _obj modelToWorldVisual [0, 0, _height] }
                };
                case "ARRAY": { [_src select 0, _src select 1, _height] };
                default { [] };
            };
            if (count _pos > 0 && {player distance _pos <= DUWS_icon3d_range}) then {
                drawIcon3D [_icon, DUWS_icon3d_colour, _pos, 1, 1, 0, _label, 1, 0.025, "TahomaB"];
            };
        };
    } forEach DUWS_icon3d_rows;
}];
