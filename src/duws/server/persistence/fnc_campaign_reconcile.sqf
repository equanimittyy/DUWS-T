// Locality: server. What live state cost that a restore does not bring back, as [CP, BLUFOR AP, OPFOR AP], for the
// snapshot's pools only: this runs at every write, so a refund through fnc_cp_adjust would pay for the same live
// squad again at each interval. An OPCOM tasking restores as data and an operative as paid on its roster, so neither
// needs one; a vehicle gets none, since parking it at a base or storing it in the garage is how it survives a restart.
if (!isServer) exitWith {};

DUWS_fnc_campaignReconcile = {
    private _prices = createHashMapFromArray ((["UNIT"] call fnc_faction_rqst_list) apply { [_x select 0, _x select 2] });
    private _cp = 0;
    {
        if (side _x isEqualTo west && {((units _x) findIf { isPlayer _x }) >= 0 || {isPlayer (hcLeader _x)}}) then {
            {
                if (alive _x && {!isPlayer _x} && {!(_x getVariable ["DUWS_operative", false])}) then { _cp = _cp + (_prices getOrDefault [typeOf _x, 0]) * (1 - damage _x) };
            } forEach units _x;
        };
    } forEach allGroups;
    private _opf = 0;
    { _opf = _opf + (_x param [4, 0]) } forEach DUWS_opcom_buildsPending;
    [round _cp, 0, _opf]
};
