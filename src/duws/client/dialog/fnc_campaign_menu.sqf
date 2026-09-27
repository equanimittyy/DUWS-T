// Locality: client -- inherited from client/dialog/fnc_callsign_back.sqf.
  // Same flag and the same reason as the environment screen: preselecting a combo raises the
  // event a player's click raises, and only the player's counts as leaving the preset.
  duws_preset_applying = true;

  createDialog "startup_dialog2";
  waitUntil {dialog};

  // Marks a combo's default entry with a localised "(Default)" suffix at runtime, not
  // in the stringtable, so shared Yes/No and skill labels stay unchanged elsewhere.
  private _setDefault = {
      params ["_idc", "_i"];
      lbSetCurSel [_idc, _i];
      lbSetText [_idc, _i, (lbText [_idc, _i]) + " " + (localize "STR_DUWS_T_default_suffix")];
  };

  // Each row carries its own value as lbData, so the readback (fnc_process_campaign_menu) reads the
  // value straight off the selected row -- the label is free to be formatted or localised without a
  // parallel index-to-value switch. Compound settings pack a comma list (skill "min,max", the AT combo
  // "heli,armour"). Returns the row index for the rows a default or preset needs to preselect.
  private _addOpt = {
      params ["_idc", "_label", "_data"];
      private _row = lbAdd [_idc, _label];
      lbSetData [_idc, _row, _data];
      _row
  };

  [2100, "2000m", "2000"] call _addOpt;
  [2100, "1750m", "1750"] call _addOpt;
  [2100, "1500m", "1500"] call _addOpt;
  [2100, "1250m", "1250"] call _addOpt;
  private _hcMaxRadius = [2100, "1000m", "1000"] call _addOpt;
  [2100, "750m", "750"] call _addOpt;
  private _defMaxRadius = [2100, localize "STR_DUWS_T_zoneradiusmax500", "500"] call _addOpt;
  [2100, _defMaxRadius] call _setDefault;

  [2101, "1750m", "1750"] call _addOpt;
  [2101, "1500m", "1500"] call _addOpt;
  [2101, "1250m", "1250"] call _addOpt;
  [2101, "1000m", "1000"] call _addOpt;
  [2101, "750m", "750"] call _addOpt;
  [2101, "500m", "500"] call _addOpt;
  private _defMinRadius = [2101, localize "STR_DUWS_T_zoneradiusmin350", "350"] call _addOpt;
  [2101, _defMinRadius] call _setDefault;

  [2102, localize "STR_DUWS_T_jooz8g8q4", "40"] call _addOpt;
  [2102, localize "STR_DUWS_T_jooz8g8q3", "30"] call _addOpt;
  [2102, localize "STR_DUWS_T_jooz8g8q2", "20"] call _addOpt;
  [2102, localize "STR_DUWS_T_jooz8g8q", "15"] call _addOpt;
  [2102, localize "STR_DUWS_T_8gqzfdui", "10"] call _addOpt;
  [2102, "9", "9"] call _addOpt;
  [2102, "8", "8"] call _addOpt;
  [2102, "7", "7"] call _addOpt;
  private _hcZones = [2102, "6", "6"] call _addOpt;
  [2102, "5", "5"] call _addOpt;
  private _defZones = [2102, localize "STR_DUWS_T_zonecount4", "4"] call _addOpt;
  [2102, "3", "3"] call _addOpt;
  [2102, "2", "2"] call _addOpt;
  [2102, "1", "1"] call _addOpt;
  [2102, _defZones] call _setDefault;

  [2103, localize "STR_DUWS_T_blqblz86", "3000"] call _addOpt;
  [2103, "4 km", "4000"] call _addOpt;
  [2103, "5 km", "5000"] call _addOpt;
  [2103, "10 km", "10000"] call _addOpt;
  private _defDistHq = [2103, localize "STR_DUWS_T_hqdistmax15km", "15000"] call _addOpt;
  [2103, "20 km", "20000"] call _addOpt;
  [2103, _defDistHq] call _setDefault;

  [2104, "0", "0"] call _addOpt;
  [2104, "10", "10"] call _addOpt;
  [2104, "20", "20"] call _addOpt;
  [2104, "30", "30"] call _addOpt;
  private _defCp = [2104, "50", "50"] call _addOpt;
  [2104, "75", "75"] call _addOpt;
  [2104, "100", "100"] call _addOpt;
  [2104, "150", "150"] call _addOpt;
  [2104, "300", "300"] call _addOpt;
  [2104, "400", "400"] call _addOpt;
  [2104, "600", "600"] call _addOpt;
  [2104, _defCp] call _setDefault;

  // Reward Multiplier (scales both CP and AP mission payouts)
  [2106, "0.5x", "0.5"] call _addOpt;
  private _defReward = [2106, "1x", "1"] call _addOpt;
  [2106, "1.5x", "1.5"] call _addOpt;
  [2106, "2x", "2"] call _addOpt;
  [2106, "2.5x", "2.5"] call _addOpt;
  [2106, "3x", "3"] call _addOpt;
  [2106, "5x", "5"] call _addOpt;
  [2106, _defReward] call _setDefault;

  [2107, "0", "0"] call _addOpt;
  [2107, "1", "1"] call _addOpt;
  private _defDeath = [2107, "2", "2"] call _addOpt;
  [2107, "3", "3"] call _addOpt;
  [2107, "4", "4"] call _addOpt;
  [2107, "5", "5"] call _addOpt;
  [2107, "8", "8"] call _addOpt;
  [2107, "10", "10"] call _addOpt;
  [2107, _defDeath] call _setDefault;

  // BLUFOR starting tier (1-5) -- the campaign begins with BLUFOR's capability ladder already at this
  // tier (fnc_WARCOM_init seeds earned + tier, and opens the wallet at the same value). Tier 1 is
  // infantry from scratch; tier 5 opens with jets. The label shows the earned-AP floor of the tier (the
  // rung it seeds) and the capability it reaches named in brackets; the infantry floor shows the raw AP
  // alone, since starting with nothing unlocked needs no name. The data is both the earned floor and
  // the starting wallet.
  private _defBluAp = [2108, "0", "0"] call _addOpt;
  [2108, format ["60 (%1)", localize "STR_DUWS_T_tiername2"], "60"] call _addOpt;
  [2108, format ["150 (%1)", localize "STR_DUWS_T_tiername3"], "150"] call _addOpt;
  [2108, format ["350 (%1)", localize "STR_DUWS_T_tiername4"], "350"] call _addOpt;
  [2108, format ["600 (%1)", localize "STR_DUWS_T_tiername5"], "600"] call _addOpt;
  [2108, _defBluAp] call _setDefault;

  // OPFOR starting tier -- same ladder.
  [2109, "0", "0"] call _addOpt;
  private _defOpAp = [2109, format ["60 (%1)", localize "STR_DUWS_T_tiername2"], "60"] call _addOpt;
  [2109, format ["150 (%1)", localize "STR_DUWS_T_tiername3"], "150"] call _addOpt;
  [2109, format ["350 (%1)", localize "STR_DUWS_T_tiername4"], "350"] call _addOpt;
  [2109, format ["600 (%1)", localize "STR_DUWS_T_tiername5"], "600"] call _addOpt;
  [2109, _defOpAp] call _setDefault;

  [2110, localize "STR_DUWS_T_7ovwb13n", "0.85,1.0"] call _addOpt;
  [2110, localize "STR_DUWS_T_i9ql9ndj", "0.75,0.85"] call _addOpt;
  private _defBluSkill = [2110, localize "STR_DUWS_T_7szkelef", "0.55,0.75"] call _addOpt;
  [2110, localize "STR_DUWS_T_njgzfxj4", "0.35,0.55"] call _addOpt;
  [2110, localize "STR_DUWS_T_hjz2qz8j", "0.25,0.35"] call _addOpt;
  [2110, _defBluSkill] call _setDefault;

  [2111, localize "STR_DUWS_T_7ovwb13n", "0.85,1.0"] call _addOpt;
  [2111, localize "STR_DUWS_T_i9ql9ndj", "0.75,0.85"] call _addOpt;
  [2111, localize "STR_DUWS_T_7szkelef", "0.55,0.75"] call _addOpt;
  private _defOpSkill = [2111, localize "STR_DUWS_T_njgzfxj4", "0.35,0.55"] call _addOpt;
  [2111, localize "STR_DUWS_T_hjz2qz8j", "0.25,0.35"] call _addOpt;
  [2111, _defOpSkill] call _setDefault;

  // AT combo packs both toggles as "attackHeli,heavyArmour".
  private _defAt = [2112, localize "STR_DUWS_T_dge86ern", "1,1"] call _addOpt;
  [2112, localize "STR_DUWS_T_z4j9n0qo", "1,0"] call _addOpt;
  [2112, localize "STR_DUWS_T_reguyhhi", "0,1"] call _addOpt;
  [2112, localize "STR_DUWS_T_ps661jx6", "0,0"] call _addOpt;
  [2112, _defAt] call _setDefault;


  private _defEnemyMult = [2113, "1x", "1"] call _addOpt;
  [2113, "2x", "2"] call _addOpt;
  [2113, "3x", "3"] call _addOpt;
  [2113, _defEnemyMult] call _setDefault;

  // GARRISON DENSITY -- the share of a zone's mobile garrison that stands up at once; the rest wait as
  // reserve. Value labels carry the percentage; the data carries the fraction.
  [2114, "25%", "0.25"] call _addOpt;
  private _defGarrison = [2114, "50%", "0.5"] call _addOpt;
  [2114, "75%", "0.75"] call _addOpt;
  [2114, "100%", "1"] call _addOpt;
  [2114, _defGarrison] call _setDefault;

// Restore selections when the player returns to this screen via the Back button. With no snapshot
// to restore, a preset that owes this screen values applies them here, where its combos exist.
if (!isNil "duws_campaign_sel") then {
    // No longer a contiguous 2100-range: More Urban (2105) moved to the environment screen, so the
    // restore zips stored values against an explicit idc list that MUST stay in lockstep with the
    // snapshot in fnc_startup_next.sqf.
    private _idcs = [2100,2101,2102,2103,2104,2106,2107,2108,2109,2110,2111,2112,2113,2114];
    { lbSetCurSel [_idcs select _forEachIndex, _x]; } forEach duws_campaign_sel;
} else {
    if (duws_preset_base == "hardcore") then {
        lbSetCurSel [2100, _hcMaxRadius];
        lbSetCurSel [2102, _hcZones];
    };
};

// The preset row lives on the environment screen, which is answered before this one, so there is
// nothing to repaint here -- only the state to drop. The row shows Custom when the player steps
// back to it.
private _display = uiNamespace getVariable ["duws_startup_display", displayNull];
{
    (_display displayCtrl _x) ctrlAddEventHandler ["LBSelChanged", {
        if (duws_preset_applying) exitWith {};
        duws_preset = "custom";
    }];
} forEach [2100,2101,2102,2103,2104,2106,2107,2108,2109,2110,2111,2112,2113,2114];

duws_preset_applying = false;
