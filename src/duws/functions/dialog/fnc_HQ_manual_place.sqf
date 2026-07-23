diag_log format ["Placement BLUFOR Faction: %1", BLUFOR_Faction_X];
diag_log format ["Placement OPFOR Faction: %1", OPFOR_Faction_X];

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
hint localize "STR_DUWS_T_ahq99ew0";
OnMapSingleClick "ClickedPos = _pos; clicked = true;";

while {true} do {
    if (clicked) then {
        // ========== 第一步：删除点击位置周围 45 米内的所有物体（无筛选）==========
        private _clearRadius = 45;
        private _allObjects = nearestObjects [ClickedPos, [], _clearRadius];
        private _deletedCount = 0;
        private _hiddenCount = 0;
        
        {
            // 排除玩家、总部建筑等关键对象（可选，防止误删）
            if (!isPlayer _x && !(_x isKindOf "Man") && !(_x isKindOf "Land_HelipadEmpty_F") && !(_x isKindOf "FlagPole_F")) then {
                // 尝试删除
                deleteVehicle _x;
                _deletedCount = _deletedCount + 1;
                // 如果删除后对象仍然存在（某些静态物体），强制隐藏
                if (!isNull _x) then {
                    _x hideObjectGlobal true;
                    _hiddenCount = _hiddenCount + 1;
                };
            };
        } forEach _allObjects;
        
        // 广播删除+隐藏提示
        if (_deletedCount > 0 || _hiddenCount > 0) then {
            private _msg = format ["[HQ Placement] Removed %1 objects (deleted: %2, hidden: %3) within %4m of clicked location.", 
                _deletedCount + _hiddenCount, _deletedCount, _hiddenCount, _clearRadius];
            _msg remoteExec ["hint", 0];
        };
        
        // 等待引擎更新（重要）
        sleep 1;
        // ================================================================

        // ========== 第二步：在已清空的区域寻找安全位置 ==========
        _foundPickupPos = [ClickedPos, 0, 10, 5, 0, 0.5, 0, [], [[0,0],[0,0]]] call BIS_fnc_findSafePos;
        _nearRoad = [_foundPickupPos, 3] call BIS_fnc_nearestRoad;
        // ========================================================

        if ((!isNull _nearRoad) || (0 == _foundPickupPos select 0 && 0 == _foundPickupPos select 1)) then {  
            clicked = false;
            hint localize "STR_DUWS_T_2pcapkjo";
        } else {  
            clicked = false;
            onMapSingleClick "";
            hint localize "STR_DUWS_T_ml7p89yd";
            PosOfBLUHQ = _foundPickupPos;
            publicVariable "PosOfBLUHQ";

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