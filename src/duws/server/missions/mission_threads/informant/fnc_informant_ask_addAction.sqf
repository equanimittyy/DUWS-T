// Locality: runs on each client -- the thread remoteExecs it (JIP, keyed on the civilian) for every
// crowd local, so the scroll action exists on all machines. Server-added actions show only to the
// host, hence the broadcast.
//
// The action shows only while a hunt is live and this civilian has not been asked. DUWS_informant_active
// is the broadcast flag (the informant object itself is server-only); DUWS_informant_asked is set with a
// broadcast so a spent civilian greys out for everyone.
params ["_civ"];
if (isNull _civ) exitWith {};

_civ addAction [
    localize "STR_DUWS_T_INTEL_INFORMANT_ASK_ACTION",
    { _this params ["_target", "_caller"]; [_target, _caller] remoteExec ["fnc_informant_ask_request", 2] },
    nil,
    1.5,
    true,
    true,
    "",
    "!(_target getVariable ['DUWS_informant_asked', false]) && (missionNamespace getVariable ['DUWS_informant_active', false])",
    3
];
