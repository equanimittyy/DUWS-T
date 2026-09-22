// Locality: server, [] call'd at load. A commit order's Cost: the AP to rebuy the unit staked plus the defense it
// leaves behind (opcom_plan.md §Cost). Read from the pick's unscheduled pass, so nothing here may suspend.
if (!isServer) exitWith {};

// Priced on the whole stake, never the expected losses: those would score a 3:1 attack twelve times above an even one,
// and a commander that attacks only at crushing odds is no fight for the players.
DUWS_fnc_opcom_abandonAt = {
    params ["_worth", "_fri", "_ene", "_unitBlock"];
    if (_fri <= 0) exitWith { 0 };
    _worth * (((_ene + 1) / _fri) min 1) * ((_unitBlock / _fri) min 1)
};

DUWS_fnc_opcom_commitCost = {
    params ["_t"];
    private _ef = _t get "effForce";
    private _rebuy = _ef * OPCOM_AP_PER_FORCE;
    if ((_t get "order") isNotEqualTo "garrison" || {"noncombat" in (_t get "flags")}) exitWith { _rebuy };
    private _home = _t get "homeZone";
    private _worth = [_home] call DUWS_fnc_opcom_siteWorth;
    if (_worth <= 0) exitWith { _rebuy };
    ([([_home] call fnc_site_at) getOrDefault ["pos", _t get "pos"]] call DUWS_fnc_opcom_blockForce) params ["_fri", "_ene"];
    _rebuy + ([_worth, _fri, _ene, _ef * (call DUWS_fnc_opcom_blockGain)] call DUWS_fnc_opcom_abandonAt)
};
