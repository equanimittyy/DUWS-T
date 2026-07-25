// Locality: server or client -- called from both. It only formats and shows chat, so either
// is safe.
// fnc_sideChat_filter.sqf
// Use this to decide how to transmit chat messages
// Modified to accept a sender parameter for multiplayer compatibility.

params [
    ["_message", ""],
    ["_sender", objNull]
];

if (isNull _sender) then {
    _sender = player; // 默认使用当前玩家
};

// Check if sender has a radio
if ("ItemRadio" in assignedItems _sender) then {
    [[West,"OVERLORD"], _message] remoteExec ["sideChat", 0];
    // 播放无线电杂音（新函数，带互斥）
    [] remoteExec ["fnc_broadcastRadioChatter", 0];
} else {
    [hq_blu1, _message] remoteExec ["globalChat", 0];
};