// Locality: client -- the addAction script of the Collect entry beside each Arsenal entry. Intel goes along
// because only clients define DUWS_intelItems.
params ["_box", "_caller"];
[_box, _caller, DUWS_intelItems] remoteExecCall ["fnc_captured_pool_collect", 2];
