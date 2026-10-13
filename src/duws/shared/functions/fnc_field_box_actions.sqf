// Locality: all machines; remoteExec'd to target 0 with the box as the JIP id, so late joiners get
// the same entries and the queue entry dies with the crate. The addAction bodies run on the machine
// that triggers them, not here.
//
// Shared by the two field crates that are loadout stations rather than loot: the supply drop
// (client/supports/fnc_ammobox.sqf) and the Mobile HQ box (server/dialog/fnc_MHQ_deploy.sqf). Both
// carry no cargo. Three entries here -- the Virtual Arsenal, its Dump loot and a squad heal/rearm -- plus
// the Quick Kits menu, which each caller attaches through fnc_addQuickChangeActions. The Arsenal pair is
// gated on the armory support: its condition reads the broadcast flag every frame, so the entries are
// absent until the team owns the armory and appear the moment it does, even if that unlock lands after
// the crate.
#include "..\includes\action_style.hpp"

params ["_box"];

_box addAction [ACT_EQUIP("STR_DUWS_T_160jkc3a"), fnc_duws_Arsenal, [], 80, false, false, "",
    "_this distance _target < 8 && {missionNamespace getVariable ['support_armory_available', false]}"];
_box addAction [ACT_EQUIP("STR_DUWS_T_ARSENAL_COLLECT"), fnc_arsenal_collect, [], 79, false, false, "",
    "_this distance _target < 8 && {missionNamespace getVariable ['support_armory_available', false]}"];
_box addAction [ACT_AID("STR_DUWS_T_xfgokhbc"), fnc_AI_rearm, [], 60, false, false, "", "_this distance _target < 8"];
