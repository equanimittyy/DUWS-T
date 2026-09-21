// Locality: server.
/*
    Shuts one vendor's shop for the respawn cooldown and greys its marker. Params: [_townIndex, _slot].
*/
if (!isServer) exitWith {};

// Long enough that losing a shopkeeper is a real cost, short enough that it is not a campaign-length
// one. While it runs the town simply lacks that vendor and its service.
#define VENDOR_RESPAWN 300

params ["_townIndex", "_slot"];
private _recs = [_townIndex] call fnc_vendor_recs;
if (_slot < 0 || _slot >= count _recs) exitWith {};

(_recs select _slot) set [3, VENDOR_RESPAWN];
[_townIndex, _slot] call fnc_vendor_markerPaint;
