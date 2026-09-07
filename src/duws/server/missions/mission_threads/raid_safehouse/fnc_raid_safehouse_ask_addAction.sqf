// Locality: each client -- the thread remoteExecs it (JIP, keyed on the civilian) for every town local, so
// the scroll action exists on all machines. Shows only while a raid is live and this local is unasked;
// DUWS_safehouse_active is the broadcast gate, DUWS_safehouse_asked greys a spent local out for everyone.
params ["_civ"];
if (isNull _civ) exitWith {};

_civ addAction [
    localize "STR_DUWS_T_RAID_SAFEHOUSE_ASK_ACTION",
    { _this params ["_target", "_caller"]; [_target, _caller] remoteExec ["fnc_raid_safehouse_ask_request", 2] },
    nil,
    1.5,
    true,
    true,
    "",
    "!(_target getVariable ['DUWS_safehouse_asked', false]) && (missionNamespace getVariable ['DUWS_safehouse_active', false])",
    3
];
