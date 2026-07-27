// Locality: the asking player's machine -- the server remoteExecs the outcome here.
/*
    fnc_civ_askEnemy_reveal.sqf
    参数: [_outcome, _pos]
    呈现打听敌情的结果。标记只对付钱的玩家可见。
*/
params ["_outcome", ["_pos", []]];

if (!hasInterface) exitWith {};

switch (_outcome) do {
    case "found": {
        // Local throughout: the tip belongs to whoever paid for it, not the whole squad. The
        // global createMarker this replaces put a name on every machine that only ever got
        // styled on one of them, so a second asker could collide with the first one's name.
        private _markerName = format ["enemy_group_%1", diag_tickTime];
        createMarkerLocal [_markerName, _pos];
        _markerName setMarkerShapeLocal "ICON";
        _markerName setMarkerTypeLocal "o_unknown";
        _markerName setMarkerColorLocal "ColorRed";
        _markerName setMarkerTextLocal (localize "STR_DUWS_T_ENEMY_GROUP");
        _markerName setMarkerSizeLocal [0.8, 0.8];
        [_markerName] spawn { sleep 60; deleteMarkerLocal (_this select 0); };

        [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_askopforlocyes"] call fnc_duws_dialogue;
        hint (localize "STR_DUWS_T_ASK_SUCCESS");
    };
    case "none": {
        hint (localize "STR_DUWS_T_NO_ENEMY_GROUPS");
        [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_askopforlocno2"] call fnc_duws_dialogue;
        sleep 4;
        [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_askopforlocno3"] call fnc_duws_dialogue;
    };
    case "fail": {
        hint (localize "STR_DUWS_T_ASK_FAIL");
        [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_askopforlocno"] call fnc_duws_dialogue;
    };
    case "refuse": {
        hint (localize "STR_DUWS_T_ASK_REFUSE");
        [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_stfu"] call fnc_duws_dialogue;
    };
};
