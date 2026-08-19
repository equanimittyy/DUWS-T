// Locality: server -- side-mission timeout branches call it, all server-side.
//
// Overlord's spoken "out of time" call when a side mission's deadline passes. Centralised so every
// thread's timeout branch says it the same way. Threads that keep their own timeout branch for extra
// teardown still route the notice here.
if (!isServer) exitWith {};

[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_mission_deadline_fail"] remoteExec ["fnc_duws_dialogue", 0];
