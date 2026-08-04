// Locality: client; the map-click bodies below run on the machine that triggers them, not here (invoked from a dialog action).
["INFO", "FACTION", format ["Placement BLUFOR Faction: %1", BLUFOR_Faction_X]] call fnc_log;
["INFO", "FACTION", format ["Placement OPFOR Faction: %1", OPFOR_Faction_X]] call fnc_log;

player_is_choosing_hqpos = true;
publicVariable "player_is_choosing_hqpos";
hq_manually_placed = true;
publicVariable "hq_manually_placed";

clicked = false;

forceMap true;
mapAnimAdd [3, 1, [5000,5000]];
mapAnimCommit;
sleep 3;
openMap [true, false];
// Banner, not hint: the engine draws the hint box beneath the open map, so the placement
// instruction was invisible for the whole click phase. Same treatment the AO step gets below.
private _hqPrompt = format ["<t size='2' color='#00ffff'>%1 </t><br/>%2",
    localize "STR_DUWS_T_SELECT_HQ", localize "STR_DUWS_T_ahq99ew0"];
[_hqPrompt] call fnc_map_prompt;
OnMapSingleClick "ClickedPos = _pos; clicked = true;";

while {true} do {
    if (clicked) then {
        // Handed to the server, which is the only machine whose hide is seen by everyone. The
        // final HQ position lands within 10 m of the click, so this circle is the click's own;
        // fnc_BluHQinit clears the base footprint again once that position is settled.
        [ClickedPos, 50] remoteExec ["fnc_clear_foliage", 2, false];
        sleep 1;

        _foundPickupPos = [ClickedPos, 0, 10, 5, 0, 0.5, 0, [], [[0,0],[0,0]]] call BIS_fnc_findSafePos;
        _nearRoad = [_foundPickupPos, 3] call BIS_fnc_nearestRoad;

        if ((!isNull _nearRoad) || (0 == _foundPickupPos select 0 && 0 == _foundPickupPos select 1)) then {  
            clicked = false;
            [format ["%1<br/><t color='#ff1111'>%2</t>", _hqPrompt, localize "STR_DUWS_T_2pcapkjo"]] call fnc_map_prompt;
        } else {  
            clicked = false;
            onMapSingleClick "";
            hint localize "STR_DUWS_T_ml7p89yd";
            PosOfBLUHQ = _foundPickupPos;
            publicVariable "PosOfBLUHQ";
            ["INFO", "BOOT", format ["HQ placed manually at %1", PosOfBLUHQ]] call fnc_log;

            // 创建临时 HQ 标记
            _markername = "foo";
            _markerstr = createMarker [str(_markername), PosOfBLUHQ];
            _markerstr setMarkerShape "ICON";
            str(_markername) setMarkerType "mil_flag";
            str(_markername) setMarkerColor "ColorBlue";

            sleep 2;

            forceMap false;
            [localize "STR_DUWS_T_k9kxtm85"] call fnc_map_prompt;
            OnMapSingleClick "ClickedPos2 = _pos; clicked = true;";
            waituntil {sleep 0.1; clicked or !(visiblemap)};
            if (clicked) then {
                AO_direction = ClickedPos2;
                publicVariable "AO_direction";
                _markername2 = "foo2";
                _markerstr2 = createMarker [str(_markername2), AO_direction];
                _markerstr2 setMarkerShape "ICON";
                str(_markername2) setMarkerType "mil_flag";
                str(_markername2) setMarkerColor "ColorRed";
                sleep 2;
                deletemarker str(_markername2);
            };  
            deletemarker str(_markername);
            hint "";
            [""] call fnc_map_prompt;
            openMap [false, false];
            titleCut ["", "BLACK FADED", 999];
            chosen_hq_placement = true;
            publicVariable "chosen_hq_placement";
        }
    };
    sleep 1;
    if (chosen_hq_placement) exitWith {sleep 3};
};