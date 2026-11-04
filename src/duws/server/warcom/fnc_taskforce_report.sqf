// Locality: server.
params ["_group", "_key", "_place"];
private _tf = groupId _group;
[_tf, format [localize _key, _tf, _place], "SUB-NET"] remoteExec ["fnc_duws_dialogue", 0];
