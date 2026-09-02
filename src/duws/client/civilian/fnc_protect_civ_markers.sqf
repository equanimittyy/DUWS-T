// Locality: client -- inherited from client/client_init.sqf.
// 3D icons over the informant and crate while a player is in range, fed by DUWS_float_informant /
// DUWS_pc_crate (broadcast; nil at teardown). Draw3D so `onEachFrame {}` elsewhere cannot clear it.
if (!hasInterface) exitWith {};

DUWS_pcMarker_range = 50;

// [source global name, icon, colour, label, metres above the subject]
DUWS_pcMarker_rows = [
    ["DUWS_float_informant", "\a3\ui_f\data\gui\cfg\hints\Commanding_ca.paa", [0.2, 0.6, 1, 0.6], localize "STR_DUWS_T_pc_icon_informant", 2.2],
    ["DUWS_pc_crate",     "\a3\Ui_f\data\GUI\Cfg\CommunicationMenu\supplydrop_ca.paa",  [0.2, 1, 0.2, 0.6],   localize "STR_DUWS_T_pc_icon_crate",     1.6],
    ["DUWS_float_pilot",  "\A3\ui_f\data\IGUI\Cfg\Actions\heal_ca.paa",     [0.2, 0.6, 1, 0.6],   localize "STR_DUWS_T_pc_icon_pilot",     2.2]
];

addMissionEventHandler ["Draw3D", {
    {
        _x params ["_srcVar", "_icon", "_colour", "_label", "_height"];
        private _obj = missionNamespace getVariable [_srcVar, objNull];
        if (!isNull _obj && { player distance _obj <= DUWS_pcMarker_range }) then {
            drawIcon3D [_icon, _colour, _obj modelToWorldVisual [0, 0, _height], 1, 1, 0, _label, 1, 0.025, "TahomaB"];
        };
    } forEach DUWS_pcMarker_rows;
}];
