// Locality: client -- inherited from client/client_init.sqf.
// Floating labels over the three base facilities a player has to find before they can use them.
// Each sits in a composition of look-alike props, and a scroll action announces itself only once
// the player is already standing on the right one.
//
// Draw3D, not the stacked onEachFrame that fnc_draw_HQicon uses: that file clears the whole stack
// with a bare `onEachFrame {}` every time the player leaves the base, which would take these with
// it. Draw3D is a separate mission event and cannot be clobbered.
if (!hasInterface) exitWith {};

HQ_facility_draw_range = 30;    // signposts inside the base, not a way to find the base

// [netId key, icon, label, metres above the model origin, unlock flag ("" draws unconditionally)]
// Read from a global rather than a local: a Draw3D block sees no locals from where it was written.
HQ_facility_icons = [
    ["HQ_mapBoard_netId",    "\a3\ui_f\data\gui\cfg\hints\Firemode_ca.paa",  localize "STR_DUWS_T_FACILITY_KILLHOUSE", 2.5, ""],
    ["HQ_medTent_netId",     "\A3\ui_f\data\IGUI\Cfg\Actions\heal_ca.paa",   localize "STR_DUWS_T_FACILITY_RESTTENT",  4,   ""],
    ["HQ_repairDepot_netId", "\A3\ui_f\data\IGUI\Cfg\Actions\repair_ca.paa", localize "STR_DUWS_T_FACILITY_VEHMOD",    3,   "support_veh_repair_available"]
];

addMissionEventHandler ["Draw3D", {
    if (isNil "PosOfBLUHQ" || {player distance PosOfBLUHQ > HQ_facility_draw_range}) exitWith {};

    {
        _x params ["_netIdVar", "_icon", "_label", "_height", "_flagVar"];
        // A station nobody has bought carries no actions, so an icon over it points at an inert
        // prop. The depot is scenery from the moment the base is built, unlocked or not.
        private _bought = _flagVar == "" || {missionNamespace getVariable [_flagVar, false]};
        private _obj = objectFromNetId (missionNamespace getVariable [_netIdVar, ""]);
        if (_bought && {!isNull _obj}) then {
            drawIcon3D [
                _icon, [0.2,1,0.2,0.5], _obj modelToWorldVisual [0, 0, _height],
                1, 1, 0, _label, 1, 0.025, "TahomaB"
            ];
        };
    } forEach HQ_facility_icons;
}];
