// Locality: server -- creates the unit; the action it broadcasts runs on clients.
/*
    Puts one registered vendor back on its spot. Params: [_townIndex, _slot]. Returns the unit, or
    objNull.
*/
if (!isServer) exitWith { objNull };
params ["_townIndex", "_slot"];

private _recs = [_townIndex] call fnc_vendor_recs;
if (_slot < 0 || _slot >= count _recs) exitWith { objNull };
(_recs select _slot) params ["_type", "_pos", "_dir", "_cooldown"];
if (_cooldown > 0) exitWith { objNull };

private _civArray = missionNamespace getVariable ["civ_array", []];
if (_civArray isEqualTo []) exitWith { objNull };

private _unit = [_townIndex, _pos, selectRandom _civArray, false, true] call fnc_civ_spawnUnit;
if (isNull _unit) exitWith { objNull };

_unit setDir _dir;
// Stands where it was put for the rest of its life. The fixed building is what the marker points at,
// and a shopkeeper who strolled off would leave the player at an empty pin.
_unit disableAI "PATH";
_unit setVariable ["DUWS_vendor_slot", _slot];
// Broadcast: the catalogue runs on the player's machine and has to know which shop it is standing in
// front of, and which town's reputation gates it.
_unit setVariable ["DUWS_vendor_type", _type, true];
_unit setVariable ["DUWS_vendor_town", _townIndex, true];

([[_townIndex] call fnc_town_site_key, "vendors"] call fnc_site_roster) pushBack _unit;

// A second Killed handler beside the reputation one fnc_civ_spawnUnit hangs: shooting a shopkeeper
// still costs the town, and also shuts the shop for as long as the cooldown says.
_unit addEventHandler ["Killed", {
    params ["_dead"];
    [_dead getVariable ["DUWS_vendor_town", -1], _dead getVariable ["DUWS_vendor_slot", -1]]
        call fnc_vendor_killed;
}];

_unit
