# Arma 3 map marker icons

Reference for the stock `CfgMarkers` icon markers — the `markerType` values accepted
by `setMarkerType` / `setMarkerTypeLocal`. Sourced from the Bohemia Interactive
[CfgMarkers wiki table](https://community.bistudio.com/wiki/CfgMarkers). Use it to pick
an icon by look (from the numbered contact sheet) and copy its exact class.

The contact sheet [`arma3_marker_icons.png`](arma3_marker_icons.png) numbers every icon;
those numbers are the **No.** column below, in the same order, so a glance at the image
maps straight to a class name.

## Usage

```sqf
_m = createMarker ["objAlpha", getPos player];
_m setMarkerType "hd_objective";   // class from the table
_m setMarkerColor "ColorRED";      // marker colour is separate from the icon
_m setMarkerText "Strongpoint";
```

Colour is set independently (`setMarkerColor`); the icon class only fixes the shape.

## Reading the table

- **Scope** is the addon `scope` on the class. It only governs whether the type appears
  in the Eden Editor marker-type picker (`2` listed, `1`/`0` not) — every class works
  with `setMarkerType` from script regardless of scope.
- **Shadow** reproduces the wiki's own Shadow column (`Y` = checked). It does not track
  the `_noShadow` class suffix, so when you need a drop shadow gone, trust the suffix,
  not this column.
- **DLC** names the addon the icon ships in. A blank cell is base-game and always
  present; a DLC icon can be missing or fall back to default on a client without that
  DLC. Portability rule for this mission: prefer blank-DLC classes for anything a player
  must see. See the no-hard-mod-dependency principle in [`CLAUDE.md`](../../../CLAUDE.md).

| No. | Class | Name | Icon path | Shadow | Scope | DLC |
|----:|-------|------|-----------|:------:|:-----:|-----|
| 1 | `b_air` | Helicopter | `\A3\ui_f\data\map\markers\nato\b_air.paa` | Y | 1 |  |
| 2 | `b_antiair` | Anti-Air | `\A3\ui_f\data\map\markers\nato\b_antiair.paa` | Y | 1 |  |
| 3 | `b_armor` | Armor | `\A3\ui_f\data\map\markers\nato\b_armor.paa` | Y | 1 |  |
| 4 | `b_art` | Artillery | `\A3\ui_f\data\map\markers\nato\b_art.paa` | Y | 1 |  |
| 5 | `b_hq` | HQ | `\A3\ui_f\data\map\markers\nato\b_hq.paa` | Y | 1 |  |
| 6 | `b_inf` | Infantry | `\A3\ui_f\data\map\markers\nato\b_inf.paa` | Y | 1 |  |
| 7 | `b_installation` | Installation | `\A3\ui_f\data\map\markers\nato\b_installation.paa` | Y | 1 |  |
| 8 | `b_maint` | Maintenance | `\A3\ui_f\data\map\markers\nato\b_maint.paa` | Y | 1 |  |
| 9 | `b_mech_inf` | Mechanized | `\A3\ui_f\data\map\markers\nato\b_mech_inf.paa` | Y | 1 |  |
| 10 | `b_med` | Medical | `\A3\ui_f\data\map\markers\nato\b_med.paa` | Y | 1 |  |
| 11 | `b_mortar` | Mortar | `\A3\ui_f\data\map\markers\nato\b_mortar.paa` | Y | 1 |  |
| 12 | `b_motor_inf` | Motorized | `\A3\ui_f\data\map\markers\nato\b_motor_inf.paa` | Y | 1 |  |
| 13 | `b_naval` | Naval | `\A3\ui_f\data\map\markers\nato\b_naval.paa` | Y | 1 |  |
| 14 | `b_Ordnance` | Ordnance | `\a3\UI_F_Orange\Data\CfgMarkers\b_Ordnance_ca.paa` | Y | 1 | Laws of War |
| 15 | `b_plane` | Plane | `\A3\ui_f\data\map\markers\nato\b_plane.paa` | Y | 1 |  |
| 16 | `b_recon` | Recon | `\A3\ui_f\data\map\markers\nato\b_recon.paa` | Y | 1 |  |
| 17 | `b_service` | Service | `\A3\ui_f\data\map\markers\nato\b_service.paa` | Y | 1 |  |
| 18 | `b_support` | Support | `\A3\ui_f\data\map\markers\nato\b_support.paa` | Y | 1 |  |
| 19 | `b_uav` | UAV | `\A3\ui_f\data\map\markers\nato\b_uav.paa` | Y | 1 |  |
| 20 | `b_unknown` | Unknown | `\A3\ui_f\data\map\markers\nato\b_unknown.paa` | Y | 1 |  |
| 21 | `c_air` | Helicopter | `\A3\ui_f\data\map\markers\nato\c_air.paa` | Y | 1 |  |
| 22 | `c_car` | Car | `\A3\ui_f\data\map\markers\nato\c_car.paa` | Y | 1 |  |
| 23 | `c_plane` | Plane | `\A3\ui_f\data\map\markers\nato\c_plane.paa` | Y | 1 |  |
| 24 | `c_ship` | Ship | `\A3\ui_f\data\map\markers\nato\c_ship.paa` | Y | 1 |  |
| 25 | `c_unknown` | Unknown | `\A3\ui_f\data\map\markers\nato\c_unknown.paa` | Y | 1 |  |
| 26 | `Contact_arrow1` | arrow1 | `\a3\UI_F_Enoch\Data\CfgMarkers\arrow1_ca.paa` | Y | 0 | Contact |
| 27 | `Contact_arrow2` | arrow2 | `\a3\UI_F_Enoch\Data\CfgMarkers\arrow2_ca.paa` | Y | 0 | Contact |
| 28 | `Contact_arrow3` | arrow3 | `\a3\UI_F_Enoch\Data\CfgMarkers\arrow3_ca.paa` | Y | 0 | Contact |
| 29 | `Contact_arrowLeft` | arrowLeft | `\a3\UI_F_Enoch\Data\CfgMarkers\arrowLeft_ca.paa` | Y | 0 | Contact |
| 30 | `Contact_arrowRight` | arrowRight | `\a3\UI_F_Enoch\Data\CfgMarkers\arrowRight_ca.paa` | Y | 0 | Contact |
| 31 | `Contact_arrowSmall1` | arrowSmall1 | `\a3\UI_F_Enoch\Data\CfgMarkers\arrowSmall1_ca.paa` | Y | 0 | Contact |
| 32 | `Contact_arrowSmall2` | arrowSmall2 | `\a3\UI_F_Enoch\Data\CfgMarkers\arrowSmall2_ca.paa` | Y | 0 | Contact |
| 33 | `Contact_art1` | art1 | `\a3\UI_F_Enoch\Data\CfgMarkers\art1_ca.paa` | Y | 0 | Contact |
| 34 | `Contact_art2` | art2 | `\a3\UI_F_Enoch\Data\CfgMarkers\art2_ca.paa` | Y | 0 | Contact |
| 35 | `Contact_circle1` | circle1 | `\a3\UI_F_Enoch\Data\CfgMarkers\circle1_ca.paa` | Y | 0 | Contact |
| 36 | `Contact_circle2` | circle2 | `\a3\UI_F_Enoch\Data\CfgMarkers\circle2_ca.paa` | Y | 0 | Contact |
| 37 | `Contact_circle3` | circle3 | `\a3\UI_F_Enoch\Data\CfgMarkers\circle3_ca.paa` | Y | 0 | Contact |
| 38 | `Contact_circle4` | circle4 | `\a3\UI_F_Enoch\Data\CfgMarkers\circle4_ca.paa` | Y | 0 | Contact |
| 39 | `Contact_dashedLine1` | dashedLine1 | `\a3\UI_F_Enoch\Data\CfgMarkers\dashedLine1_ca.paa` | Y | 0 | Contact |
| 40 | `Contact_dashedLine2` | dashedLine2 | `\a3\UI_F_Enoch\Data\CfgMarkers\dashedLine2_ca.paa` | Y | 0 | Contact |
| 41 | `Contact_dashedLine3` | dashedLine3 | `\a3\UI_F_Enoch\Data\CfgMarkers\dashedLine3_ca.paa` | Y | 0 | Contact |
| 42 | `Contact_defenseLine` | defenseLine | `\a3\UI_F_Enoch\Data\CfgMarkers\defenseLine_ca.paa` | Y | 0 | Contact |
| 43 | `Contact_defenseLineOver` | defenseLineOver | `\a3\UI_F_Enoch\Data\CfgMarkers\defenseLineOver_ca.paa` | Y | 0 | Contact |
| 44 | `Contact_dot1` | dot1 | `\a3\UI_F_Enoch\Data\CfgMarkers\dot1_ca.paa` | Y | 0 | Contact |
| 45 | `Contact_dot2` | dot2 | `\a3\UI_F_Enoch\Data\CfgMarkers\dot2_ca.paa` | Y | 0 | Contact |
| 46 | `Contact_dot3` | dot3 | `\a3\UI_F_Enoch\Data\CfgMarkers\dot3_ca.paa` | Y | 0 | Contact |
| 47 | `Contact_dot4` | dot4 | `\a3\UI_F_Enoch\Data\CfgMarkers\dot4_ca.paa` | Y | 0 | Contact |
| 48 | `Contact_dot5` | dot5 | `\a3\UI_F_Enoch\Data\CfgMarkers\dot5_ca.paa` | Y | 0 | Contact |
| 49 | `Contact_pencilCircle1` | pencilCircle1 | `\a3\UI_F_Enoch\Data\CfgMarkers\pencilCircle1_ca.paa` | Y | 0 | Contact |
| 50 | `Contact_pencilCircle2` | pencilCircle2 | `\a3\UI_F_Enoch\Data\CfgMarkers\pencilCircle2_ca.paa` | Y | 0 | Contact |
| 51 | `Contact_pencilCircle3` | pencilCircle3 | `\a3\UI_F_Enoch\Data\CfgMarkers\pencilCircle3_ca.paa` | Y | 0 | Contact |
| 52 | `Contact_pencilDoodle1` | pencilDoodle1 | `\a3\UI_F_Enoch\Data\CfgMarkers\pencilDoodle1_ca.paa` | Y | 0 | Contact |
| 53 | `Contact_pencilDoodle2` | pencilDoodle2 | `\a3\UI_F_Enoch\Data\CfgMarkers\pencilDoodle2_ca.paa` | Y | 0 | Contact |
| 54 | `Contact_pencilDoodle3` | pencilDoodle3 | `\a3\UI_F_Enoch\Data\CfgMarkers\pencilDoodle3_ca.paa` | Y | 0 | Contact |
| 55 | `Contact_pencilDot1` | pencilDot1 | `\a3\UI_F_Enoch\Data\CfgMarkers\pencilDot1_ca.paa` | Y | 0 | Contact |
| 56 | `Contact_pencilDot2` | pencilDot2 | `\a3\UI_F_Enoch\Data\CfgMarkers\pencilDot2_ca.paa` | Y | 0 | Contact |
| 57 | `Contact_pencilDot3` | pencilDot3 | `\a3\UI_F_Enoch\Data\CfgMarkers\pencilDot3_ca.paa` | Y | 0 | Contact |
| 58 | `Contact_pencilTask1` | pencilTask1 | `\a3\UI_F_Enoch\Data\CfgMarkers\pencilTask1_ca.paa` | Y | 0 | Contact |
| 59 | `Contact_pencilTask2` | pencilTask2 | `\a3\UI_F_Enoch\Data\CfgMarkers\pencilTask2_ca.paa` | Y | 0 | Contact |
| 60 | `Contact_pencilTask3` | pencilTask3 | `\a3\UI_F_Enoch\Data\CfgMarkers\pencilTask3_ca.paa` | Y | 0 | Contact |
| 61 | `Empty` | Empty | `\A3\ui_f\data\map\markers\system\empty_ca.paa` | Y | 1 |  |
| 62 | `EmptyIcon` | Flag | `#(argb,8,8,3)color(0,0,0,0)` | - | 0 |  |
| 63 | `Flag` | Flag | `\A3\ui_f\data\map\markers\military\mission_CA.paa` | - | 0 |  |
| 64 | `flag_AAF` | Altis Armed Forces | `\A3\ui_f\data\map\markers\flags\AAF_ca.paa` | Y | 1 |  |
| 65 | `flag_Altis` | Altis | `\A3\ui_f\data\map\markers\flags\Altis_ca.paa` | Y | 1 |  |
| 66 | `flag_AltisColonial` | Altis (Colonial) | `\A3\ui_f\data\map\markers\flags\AltisColonial_ca.paa` | Y | 1 |  |
| 67 | `flag_Astra` | Astra | `\a3\UI_F_Enoch\Data\CfgMarkers\Astra_CA.paa` | Y | 1 | Contact |
| 68 | `flag_Belgium` | Belgium | `\A3\ui_f\data\map\markers\flags\Belgium_ca.paa` | Y | 1 |  |
| 69 | `flag_Canada` | Canada | `\A3\ui_f\data\map\markers\flags\Canada_ca.paa` | Y | 1 |  |
| 70 | `flag_Catalonia` | Catalonia | `\A3\ui_f\data\map\markers\flags\Catalonia_ca.paa` | Y | 0 |  |
| 71 | `flag_Croatia` | Croatia | `\A3\ui_f\data\map\markers\flags\Croatia_ca.paa` | Y | 1 |  |
| 72 | `flag_CSAT` | CSAT | `\A3\ui_f\data\map\markers\flags\CSAT_ca.paa` | Y | 1 |  |
| 73 | `flag_CTRG` | CTRG | `\A3\Ui_f\data\Map\Markers\Flags\ctrg_ca.paa` | Y | 1 | Apex |
| 74 | `flag_CzechRepublic` | Czech Republic | `\A3\ui_f\data\map\markers\flags\CzechRepublic_ca.paa` | Y | 1 |  |
| 75 | `flag_Denmark` | Denmark | `\A3\ui_f\data\map\markers\flags\Denmark_ca.paa` | Y | 1 |  |
| 76 | `flag_EAF` | Livonian Defense Force | `\a3\UI_F_Enoch\Data\CfgMarkers\LDF_CA.paa` | Y | 1 | Contact |
| 77 | `flag_Enoch` | Livonia | `\a3\UI_F_Enoch\Data\CfgMarkers\Livonia_CA.paa` | Y | 1 | Contact |
| 78 | `flag_EnochLooters` | Livonian Looters | `\a3\UI_F_Enoch\Data\CfgMarkers\LivoniaLooters_CA.paa` | Y | 1 | Contact |
| 79 | `flag_EU` | European Union | `\A3\ui_f\data\map\markers\flags\EU_ca.paa` | Y | 1 |  |
| 80 | `flag_FIA` | FIA | `\A3\ui_f\data\map\markers\flags\FIA_ca.paa` | Y | 1 |  |
| 81 | `flag_France` | France | `\A3\ui_f\data\map\markers\flags\France_ca.paa` | Y | 1 |  |
| 82 | `flag_Georgia` | Georgia | `\A3\ui_f\data\map\markers\flags\Georgia_ca.paa` | Y | 1 |  |
| 83 | `flag_Germany` | Germany | `\A3\ui_f\data\map\markers\flags\Germany_ca.paa` | Y | 1 |  |
| 84 | `flag_Greece` | Greece | `\A3\ui_f\data\map\markers\flags\Greece_ca.paa` | Y | 1 |  |
| 85 | `flag_Hungary` | Hungary | `\A3\ui_f\data\map\markers\flags\Hungary_ca.paa` | Y | 1 |  |
| 86 | `flag_Iceland` | Iceland | `\A3\ui_f\data\map\markers\flags\Iceland_ca.paa` | Y | 1 |  |
| 87 | `flag_IDAP` | International Development & Aid Project | `\A3\ui_f_orange\data\cfgmarkers\IDAP_ca.paa` | - | 1 | Laws of War |
| 88 | `flag_Italy` | Italy | `\A3\ui_f\data\map\markers\flags\Italy_ca.paa` | Y | 1 |  |
| 89 | `flag_Luxembourg` | Luxembourg | `\A3\ui_f\data\map\markers\flags\Luxembourg_ca.paa` | Y | 1 |  |
| 90 | `flag_NATO` | NATO | `\A3\ui_f\data\map\markers\flags\nato_ca.paa` | Y | 1 |  |
| 91 | `flag_Netherlands` | Netherlands | `\A3\ui_f\data\map\markers\flags\Netherlands_ca.paa` | Y | 1 |  |
| 92 | `flag_Norway` | Norway | `\A3\ui_f\data\map\markers\flags\Norway_ca.paa` | Y | 1 |  |
| 93 | `flag_Poland` | Poland | `\A3\ui_f\data\map\markers\flags\Poland_ca.paa` | Y | 1 |  |
| 94 | `flag_Portugal` | Portugal | `\A3\ui_f\data\map\markers\flags\Portugal_ca.paa` | Y | 1 |  |
| 95 | `flag_Russia` | Russia | `\a3\UI_F_Enoch\Data\CfgMarkers\Russia_CA.paa` | Y | 1 | Contact |
| 96 | `flag_Slovakia` | Slovakia | `\A3\ui_f\data\map\markers\flags\Slovakia_ca.paa` | Y | 1 |  |
| 97 | `flag_Slovenia` | Slovenia | `\A3\ui_f\data\map\markers\flags\Slovenia_ca.paa` | Y | 1 |  |
| 98 | `flag_Spain` | Spain | `\A3\ui_f\data\map\markers\flags\Spain_ca.paa` | Y | 1 |  |
| 99 | `flag_Spetsnaz` | Spetsnaz | `\a3\UI_F_Enoch\Data\CfgMarkers\Spetsnaz_CA.paa` | Y | 1 | Contact |
| 100 | `flag_Syndicat` | Syndikat | `\A3\Ui_f\data\Map\Markers\Flags\syndicat_ca.paa` | Y | 1 | Apex |
| 101 | `flag_Tanoa` | Tanoa | `\A3\Ui_f\data\Map\Markers\Flags\tanoa_ca.paa` | Y | 1 | Apex |
| 102 | `flag_TanoaGendarmerie` | Gendarmerie | `\A3\Ui_f\data\Map\Markers\Flags\tanoaGendarmerie_ca.paa` | Y | 1 | Apex |
| 103 | `flag_UK` | UK | `\A3\ui_f\data\map\markers\flags\UK_ca.paa` | Y | 1 |  |
| 104 | `flag_UN` | United Nations | `\A3\ui_f\data\map\markers\flags\UN_ca.paa` | Y | 1 |  |
| 105 | `flag_USA` | USA | `\A3\ui_f\data\map\markers\flags\USA_ca.paa` | Y | 1 |  |
| 106 | `flag_Viper` | Viper | `\A3\Ui_f\data\Map\Markers\Flags\viper_ca.paa` | Y | 1 | Apex |
| 107 | `GroundSupport_ARTY_EAST` | GroundSupport_ARTY_EAST | `\a3\Modules_F_Curator\Data\iconOrdnance_ca.paa` | Y | 0 | Helicopters |
| 108 | `GroundSupport_ARTY_RESISTANCE` | GroundSupport_ARTY_RESISTANCE | `\a3\Modules_F_Curator\Data\iconOrdnance_ca.paa` | Y | 0 | Helicopters |
| 109 | `GroundSupport_ARTY_WEST` | GroundSupport_ARTY_WEST | `\a3\Modules_F_Curator\Data\iconOrdnance_ca.paa` | Y | 0 | Helicopters |
| 110 | `GroundSupport_CAS_EAST` | GroundSupport_CAS_EAST | `\a3\Modules_F_Curator\Data\portraitCASGunMissile_ca.paa` | Y | 0 | Helicopters |
| 111 | `GroundSupport_CAS_RESISTANCE` | GroundSupport_CAS_RESISTANCE | `\a3\Modules_F_Curator\Data\portraitCASGunMissile_ca.paa` | Y | 0 | Helicopters |
| 112 | `GroundSupport_CAS_WEST` | GroundSupport_CAS_WEST | `\a3\Modules_F_Curator\Data\portraitCASGunMissile_ca.paa` | Y | 0 | Helicopters |
| 113 | `group_0` | Fire Team | `\A3\ui_f\data\map\markers\nato\group_0.paa` | Y | 1 |  |
| 114 | `group_1` | Squad | `\A3\ui_f\data\map\markers\nato\group_1.paa` | Y | 1 |  |
| 115 | `group_10` | Army | `\A3\ui_f\data\map\markers\nato\group_10.paa` | Y | 1 |  |
| 116 | `group_11` | Army Group | `\A3\ui_f\data\map\markers\nato\group_11.paa` | Y | 1 |  |
| 117 | `group_2` | Section | `\A3\ui_f\data\map\markers\nato\group_2.paa` | Y | 1 |  |
| 118 | `group_3` | Platoon | `\A3\ui_f\data\map\markers\nato\group_3.paa` | Y | 1 |  |
| 119 | `group_4` | Company | `\A3\ui_f\data\map\markers\nato\group_4.paa` | Y | 1 |  |
| 120 | `group_5` | Battalion | `\A3\ui_f\data\map\markers\nato\group_5.paa` | Y | 1 |  |
| 121 | `group_6` | Regiment | `\A3\ui_f\data\map\markers\nato\group_6.paa` | Y | 1 |  |
| 122 | `group_7` | Brigade | `\A3\ui_f\data\map\markers\nato\group_7.paa` | Y | 1 |  |
| 123 | `group_8` | Division | `\A3\ui_f\data\map\markers\nato\group_8.paa` | Y | 1 |  |
| 124 | `group_9` | Corps | `\A3\ui_f\data\map\markers\nato\group_9.paa` | Y | 1 |  |
| 125 | `hd_ambush` | Ambush | `\A3\ui_f\data\map\markers\handdrawn\ambush_CA.paa` | - | 2 |  |
| 126 | `hd_ambush_noShadow` | Ambush | `\A3\ui_f\data\map\markers\handdrawn\ambush_CA.paa` | Y | 0 |  |
| 127 | `hd_arrow` | Arrow | `\A3\ui_f\data\map\markers\handdrawn\arrow_CA.paa` | - | 2 |  |
| 128 | `hd_arrow_noShadow` | Arrow | `\A3\ui_f\data\map\markers\handdrawn\arrow_CA.paa` | Y | 0 |  |
| 129 | `hd_destroy` | Destroy | `\A3\ui_f\data\map\markers\handdrawn\destroy_CA.paa` | - | 2 |  |
| 130 | `hd_destroy_noShadow` | Destroy | `\A3\ui_f\data\map\markers\handdrawn\destroy_CA.paa` | Y | 0 |  |
| 131 | `hd_dot` | Dot | `\A3\ui_f\data\map\markers\handdrawn\dot_CA.paa` | - | 2 |  |
| 132 | `hd_dot_noShadow` | Dot | `\A3\ui_f\data\map\markers\handdrawn\dot_CA.paa` | Y | 0 |  |
| 133 | `hd_end` | End | `\A3\ui_f\data\map\markers\handdrawn\end_CA.paa` | - | 2 |  |
| 134 | `hd_end_noShadow` | End | `\A3\ui_f\data\map\markers\handdrawn\end_CA.paa` | Y | 0 |  |
| 135 | `hd_flag` | Flag | `\A3\ui_f\data\map\markers\handdrawn\flag_CA.paa` | - | 2 |  |
| 136 | `hd_flag_noShadow` | Flag | `\A3\ui_f\data\map\markers\handdrawn\flag_CA.paa` | Y | 0 |  |
| 137 | `hd_join` | Join | `\A3\ui_f\data\map\markers\handdrawn\join_CA.paa` | - | 2 |  |
| 138 | `hd_join_noShadow` | Join | `\A3\ui_f\data\map\markers\handdrawn\join_CA.paa` | Y | 0 |  |
| 139 | `hd_objective` | Objective | `\A3\ui_f\data\map\markers\handdrawn\objective_CA.paa` | - | 2 |  |
| 140 | `hd_objective_noShadow` | Objective | `\A3\ui_f\data\map\markers\handdrawn\objective_CA.paa` | Y | 0 |  |
| 141 | `hd_pickup` | Pick Up | `\A3\ui_f\data\map\markers\handdrawn\pickup_CA.paa` | - | 2 |  |
| 142 | `hd_pickup_noShadow` | Pick Up | `\A3\ui_f\data\map\markers\handdrawn\pickup_CA.paa` | Y | 0 |  |
| 143 | `hd_start` | Start | `\A3\ui_f\data\map\markers\handdrawn\start_CA.paa` | - | 2 |  |
| 144 | `hd_start_noShadow` | Start | `\A3\ui_f\data\map\markers\handdrawn\start_CA.paa` | Y | 0 |  |
| 145 | `hd_unknown` | Unknown | `\A3\ui_f\data\map\markers\handdrawn\unknown_CA.paa` | - | 2 |  |
| 146 | `hd_unknown_noShadow` | Unknown | `\A3\ui_f\data\map\markers\handdrawn\unknown_CA.paa` | Y | 0 |  |
| 147 | `hd_warning` | Warning | `\A3\ui_f\data\map\markers\handdrawn\warning_CA.paa` | - | 2 |  |
| 148 | `hd_warning_noShadow` | Warning | `\A3\ui_f\data\map\markers\handdrawn\warning_CA.paa` | Y | 0 |  |
| 149 | `KIA` | KIA | `\a3\Ui_F_Curator\Data\CfgMarkers\kia_ca.paa` | Y | 1 | Zeus |
| 150 | `loc_Ambush` | Ambush | `\A3\Ui_f\data\Map\Markers\Military\ambush_ca.paa` | - | 0 | Apex |
| 151 | `loc_Attack` | Attack | `\a3\ui_f\data\igui\cfg\simpletasks\types\attack_ca.paa` | - | 0 | Apex |
| 152 | `loc_boat` | Boat | `\a3\ui_f\data\igui\cfg\simpletasks\types\Boat_ca.paa` | - | 0 | Apex |
| 153 | `loc_Box` | Box | `\a3\ui_f\data\igui\cfg\simpletasks\types\box_ca.paa` | - | 0 | Apex |
| 154 | `loc_Bunker` | Bunker | `\A3\ui_f\data\map\mapcontrol\Bunker_CA.paa` | Y | 1 |  |
| 155 | `loc_Bush` | Bush | `\A3\ui_f\data\map\mapcontrol\Bush_CA.paa` | Y | 1 |  |
| 156 | `loc_BusStop` | Bus Stop | `\A3\ui_f\data\map\mapcontrol\BusStop_CA.paa` | Y | 1 |  |
| 157 | `loc_car` | Car | `\a3\ui_f\data\igui\cfg\simpletasks\types\car_ca.paa` | - | 0 | Apex |
| 158 | `loc_Chapel` | Chapel | `\A3\ui_f\data\map\mapcontrol\Chapel_CA.paa` | Y | 1 |  |
| 159 | `loc_Church` | Church | `\A3\ui_f\data\map\mapcontrol\Church_CA.paa` | Y | 1 |  |
| 160 | `loc_CivilDefense` | Civil Defense | `\A3\ui_f_orange\data\cfgmarkers\civildefense.paa` | Y | 1 | Laws of War |
| 161 | `loc_container` | container | `\a3\ui_f\data\igui\cfg\simpletasks\types\Container_ca.paa` | - | 0 | Apex |
| 162 | `loc_Cross` | Cross | `\A3\ui_f\data\map\mapcontrol\Cross_CA.paa` | Y | 1 |  |
| 163 | `loc_CulturalProperty` | Cultural Property | `\A3\ui_f_orange\data\cfgmarkers\culturalproperty_ca.paa` | Y | 1 | Laws of War |
| 164 | `loc_DangerousForces` | Dangerous Forces | `\A3\ui_f_orange\data\cfgmarkers\dangerousforces_ca.paa` | Y | 1 | Laws of War |
| 165 | `loc_defend` | Defend | `\a3\ui_f\data\igui\cfg\simpletasks\types\defend_ca.paa` | - | 0 | Apex |
| 166 | `loc_destroy` | Destroy | `\a3\ui_f\data\igui\cfg\simpletasks\types\destroy_ca.paa` | - | 0 | Apex |
| 167 | `loc_download` | Download | `\a3\ui_f\data\igui\cfg\simpletasks\types\Download_ca.paa` | - | 0 | Apex |
| 168 | `loc_Fortress` | Bunker | `\A3\ui_f\data\map\mapcontrol\Bunker_CA.paa` | Y | 0 |  |
| 169 | `loc_Fountain` | Fountain | `\A3\ui_f\data\map\mapcontrol\Fountain_CA.paa` | Y | 1 |  |
| 170 | `loc_Frame` | Frame | `\a3\Ui_f\data\GUI\Rsc\RscDisplayArsenal\icon_ca.paa` | Y | 0 | Apex |
| 171 | `loc_Fuelstation` | Fuel Station | `\A3\ui_f\data\map\mapcontrol\Fuelstation_CA.paa` | Y | 1 |  |
| 172 | `loc_heal` | Heal | `\a3\ui_f\data\igui\cfg\simpletasks\types\Heal_ca.paa` | - | 0 | Apex |
| 173 | `loc_heli` | Heli | `\a3\ui_f\data\igui\cfg\simpletasks\types\Heli_ca.paa` | - | 0 | Apex |
| 174 | `loc_help` | Help | `\a3\ui_f\data\igui\cfg\simpletasks\types\help_ca.paa` | - | 0 | Apex |
| 175 | `loc_Hospital` | Hospital | `\A3\ui_f\data\map\mapcontrol\Hospital_CA.paa` | Y | 1 |  |
| 176 | `loc_interact` | Interact | `\a3\ui_f\data\igui\cfg\simpletasks\types\interact_ca.paa` | - | 0 | Apex |
| 177 | `loc_LetterA` | LetterA | `\a3\ui_f\data\igui\cfg\simpletasks\letters\a_ca.paa` | - | 0 | Apex |
| 178 | `loc_LetterB` | LetterB | `\a3\ui_f\data\igui\cfg\simpletasks\letters\b_ca.paa` | - | 0 | Apex |
| 179 | `loc_LetterC` | LetterC | `\a3\ui_f\data\igui\cfg\simpletasks\letters\c_ca.paa` | - | 0 | Apex |
| 180 | `loc_LetterD` | LetterD | `\a3\ui_f\data\igui\cfg\simpletasks\letters\d_ca.paa` | - | 0 | Apex |
| 181 | `loc_LetterE` | LetterE | `\a3\ui_f\data\igui\cfg\simpletasks\letters\e_ca.paa` | - | 0 | Apex |
| 182 | `loc_LetterF` | LetterF | `\a3\ui_f\data\igui\cfg\simpletasks\letters\f_ca.paa` | - | 0 | Apex |
| 183 | `loc_LetterG` | LetterG | `\a3\ui_f\data\igui\cfg\simpletasks\letters\g_ca.paa` | - | 0 | Apex |
| 184 | `loc_LetterH` | LetterH | `\a3\ui_f\data\igui\cfg\simpletasks\letters\h_ca.paa` | - | 0 | Apex |
| 185 | `loc_LetterI` | LetterI | `\a3\ui_f\data\igui\cfg\simpletasks\letters\i_ca.paa` | - | 0 | Apex |
| 186 | `loc_LetterJ` | LetterJ | `\a3\ui_f\data\igui\cfg\simpletasks\letters\j_ca.paa` | - | 0 | Apex |
| 187 | `loc_LetterK` | LetterK | `\a3\ui_f\data\igui\cfg\simpletasks\letters\k_ca.paa` | - | 0 | Apex |
| 188 | `loc_LetterL` | LetterL | `\a3\ui_f\data\igui\cfg\simpletasks\letters\l_ca.paa` | - | 0 | Apex |
| 189 | `loc_LetterM` | LetterM | `\a3\ui_f\data\igui\cfg\simpletasks\letters\m_ca.paa` | - | 0 | Apex |
| 190 | `loc_LetterN` | LetterN | `\a3\ui_f\data\igui\cfg\simpletasks\letters\n_ca.paa` | - | 0 | Apex |
| 191 | `loc_LetterO` | LetterO | `\a3\ui_f\data\igui\cfg\simpletasks\letters\o_ca.paa` | - | 0 | Apex |
| 192 | `loc_LetterP` | LetterP | `\a3\ui_f\data\igui\cfg\simpletasks\letters\p_ca.paa` | - | 0 | Apex |
| 193 | `loc_LetterQ` | LetterQ | `\a3\ui_f\data\igui\cfg\simpletasks\letters\q_ca.paa` | - | 0 | Apex |
| 194 | `loc_LetterR` | LetterR | `\a3\ui_f\data\igui\cfg\simpletasks\letters\r_ca.paa` | - | 0 | Apex |
| 195 | `loc_LetterS` | LetterS | `\a3\ui_f\data\igui\cfg\simpletasks\letters\s_ca.paa` | - | 0 | Apex |
| 196 | `loc_LetterT` | LetterT | `\a3\ui_f\data\igui\cfg\simpletasks\letters\t_ca.paa` | - | 0 | Apex |
| 197 | `loc_LetterU` | LetterU | `\a3\ui_f\data\igui\cfg\simpletasks\letters\u_ca.paa` | - | 0 | Apex |
| 198 | `loc_LetterV` | LetterV | `\a3\ui_f\data\igui\cfg\simpletasks\letters\v_ca.paa` | - | 0 | Apex |
| 199 | `loc_LetterW` | LetterW | `\a3\ui_f\data\igui\cfg\simpletasks\letters\w_ca.paa` | - | 0 | Apex |
| 200 | `loc_LetterX` | LetterX | `\a3\ui_f\data\igui\cfg\simpletasks\letters\x_ca.paa` | - | 0 | Apex |
| 201 | `loc_LetterY` | LetterY | `\a3\ui_f\data\igui\cfg\simpletasks\letters\y_ca.paa` | - | 0 | Apex |
| 202 | `loc_LetterZ` | LetterZ | `\a3\ui_f\data\igui\cfg\simpletasks\letters\z_ca.paa` | - | 0 | Apex |
| 203 | `loc_Lighthouse` | Lighthouse | `\A3\ui_f\data\map\mapcontrol\Lighthouse_CA.paa` | Y | 1 |  |
| 204 | `loc_meet` | Meet | `\a3\ui_f\data\igui\cfg\simpletasks\types\meet_ca.paa` | - | 0 | Apex |
| 205 | `loc_mine` | Mine | `\a3\ui_f\data\igui\cfg\simpletasks\types\mine_ca.paa` | - | 0 | Apex |
| 206 | `loc_move` | Move | `\a3\ui_f\data\igui\cfg\simpletasks\types\move_ca.paa` | - | 0 | Apex |
| 207 | `loc_Pick` | Pick | `\a3\Ui_f\data\IGUI\Cfg\Actions\take_ca.paa` | - | 0 | Apex |
| 208 | `loc_plane` | Plane | `\a3\ui_f\data\igui\cfg\simpletasks\types\Plane_ca.paa` | - | 0 | Apex |
| 209 | `loc_Power` | Power Plant | `\A3\ui_f\data\map\mapcontrol\Power_CA.paa` | Y | 1 |  |
| 210 | `loc_PowerSolar` | Solar Power Plant | `\A3\ui_f\data\map\mapcontrol\PowerSolar_CA.paa` | Y | 1 |  |
| 211 | `loc_PowerWave` | Wave Power Plant | `\A3\ui_f\data\map\mapcontrol\PowerWave_CA.paa` | Y | 1 |  |
| 212 | `loc_PowerWind` | Wind Power Plant | `\A3\ui_f\data\map\mapcontrol\PowerWind_CA.paa` | Y | 1 |  |
| 213 | `loc_Quay` | Pier | `\A3\ui_f\data\map\mapcontrol\Quay_CA.paa` | Y | 1 |  |
| 214 | `loc_radio` | Radio | `\a3\ui_f\data\igui\cfg\simpletasks\types\Radio_ca.paa` | - | 0 | Apex |
| 215 | `loc_rearm` | Rearm | `\a3\ui_f\data\igui\cfg\simpletasks\types\rearm_ca.paa` | - | 0 | Apex |
| 216 | `loc_refuel` | Refuel | `\a3\ui_f\data\igui\cfg\simpletasks\types\refuel_ca.paa` | - | 0 | Apex |
| 217 | `loc_repair` | Repair | `\a3\ui_f\data\igui\cfg\simpletasks\types\repair_ca.paa` | - | 0 | Apex |
| 218 | `loc_Rifle` | Rifle | `\a3\ui_f\data\igui\cfg\simpletasks\types\rifle_ca.paa` | - | 0 | Apex |
| 219 | `loc_Rock` | Rock | `\A3\ui_f\data\map\mapcontrol\Rock_CA.paa` | Y | 1 |  |
| 220 | `loc_Ruin` | Ruin | `\A3\ui_f\data\map\mapcontrol\Ruin_CA.paa` | Y | 1 |  |
| 221 | `loc_SafetyZone` | Safety Zone | `\A3\ui_f_orange\data\cfgmarkers\safetyzone_ca.paa` | Y | 1 | Laws of War |
| 222 | `loc_save` | Save | `\a3\Ui_f\data\GUI\Rsc\RscDisplayArcadeMap\icon_saveas_ca.paa` | - | 0 | Apex |
| 223 | `loc_sdv` | SDV | `\a3\ui_f\data\gui\cfg\hints\SDV_ca.paa` | - | 0 | Apex |
| 224 | `loc_search` | Search | `\a3\ui_f\data\igui\cfg\simpletasks\types\search_ca.paa` | - | 0 | Apex |
| 225 | `loc_SmallTree` | Small Tree | `\A3\ui_f\data\map\mapcontrol\SmallTree_CA.paa` | Y | 1 |  |
| 226 | `loc_Stack` | Chimney Stack | `\A3\ui_f\data\map\mapcontrol\Stack_CA.paa` | Y | 1 |  |
| 227 | `loc_talk` | Talk | `\a3\ui_f\data\igui\cfg\simpletasks\types\Talk_ca.paa` | - | 0 | Apex |
| 228 | `loc_Tourism` | Hotel | `\A3\ui_f\data\map\mapcontrol\Tourism_CA.paa` | Y | 1 |  |
| 229 | `loc_Transmitter` | Radio Tower | `\A3\ui_f\data\map\mapcontrol\Transmitter_CA.paa` | Y | 1 |  |
| 230 | `loc_Tree` | Tree | `\A3\ui_f\data\map\mapcontrol\tree_CA.paa` | Y | 1 |  |
| 231 | `loc_Truck` | Truck | `\a3\ui_f\data\igui\cfg\simpletasks\types\truck_ca.paa` | - | 0 | Apex |
| 232 | `loc_use` | Use | `\a3\ui_f\data\igui\cfg\simpletasks\types\Use_ca.paa` | - | 0 | Apex |
| 233 | `loc_ViewTower` | View Tower | `\A3\ui_f\data\map\mapcontrol\ViewTower_CA.paa` | Y | 1 |  |
| 234 | `loc_WaterTower` | Water Tower | `\A3\ui_f\data\map\mapcontrol\WaterTower_CA.paa` | Y | 1 |  |
| 235 | `MemoryFragment` | Flag | `\A3\ui_f_orange\data\cfgmarkers\memoryFragment_ca.paa` | Y | 0 | Laws of War |
| 236 | `mil_ambush` | Ambush | `\A3\ui_f\data\map\markers\military\ambush_CA.paa` | - | 1 |  |
| 237 | `mil_ambush_noShadow` | Ambush | `\A3\ui_f\data\map\markers\military\ambush_CA.paa` | Y | 0 |  |
| 238 | `mil_arrow` | Arrow | `\A3\ui_f\data\map\markers\military\arrow_CA.paa` | - | 1 |  |
| 239 | `mil_arrow2` | Arrow (filled) | `\A3\ui_f\data\map\markers\military\arrow2_CA.paa` | - | 1 |  |
| 240 | `mil_arrow2_noShadow` | Arrow (filled) | `\A3\ui_f\data\map\markers\military\arrow2_CA.paa` | Y | 0 |  |
| 241 | `mil_arrow_noShadow` | Arrow | `\A3\ui_f\data\map\markers\military\arrow_CA.paa` | Y | 0 |  |
| 242 | `mil_box` | Square | `\A3\ui_f\data\map\markers\military\box_CA.paa` | - | 1 |  |
| 243 | `mil_box_noShadow` | Square | `\A3\ui_f\data\map\markers\military\box_CA.paa` | Y | 0 |  |
| 244 | `mil_circle` | Circle | `\A3\ui_f\data\map\markers\military\circle_CA.paa` | - | 1 |  |
| 245 | `mil_circle_noShadow` | Circle | `\A3\ui_f\data\map\markers\military\circle_CA.paa` | Y | 0 |  |
| 246 | `mil_destroy` | Destroy | `\A3\ui_f\data\map\markers\military\destroy_CA.paa` | - | 1 |  |
| 247 | `mil_destroy_noShadow` | Destroy | `\A3\ui_f\data\map\markers\military\destroy_CA.paa` | Y | 0 |  |
| 248 | `mil_dot` | Dot | `\A3\ui_f\data\map\markers\military\dot_CA.paa` | - | 1 |  |
| 249 | `mil_dot_noShadow` | Dot | `\A3\ui_f\data\map\markers\military\dot_CA.paa` | Y | 0 |  |
| 250 | `mil_end` | End | `\A3\ui_f\data\map\markers\military\end_CA.paa` | - | 1 |  |
| 251 | `mil_end_noShadow` | End | `\A3\ui_f\data\map\markers\military\end_CA.paa` | Y | 0 |  |
| 252 | `mil_flag` | Flag | `\A3\ui_f\data\map\markers\military\flag_CA.paa` | - | 1 |  |
| 253 | `mil_flag_noShadow` | Flag | `\A3\ui_f\data\map\markers\military\flag_CA.paa` | Y | 0 |  |
| 254 | `mil_join` | Join | `\A3\ui_f\data\map\markers\military\join_CA.paa` | - | 1 |  |
| 255 | `mil_join_noShadow` | Join | `\A3\ui_f\data\map\markers\military\join_CA.paa` | Y | 0 |  |
| 256 | `mil_marker` | Marker | `\A3\ui_f\data\map\markers\military\marker_CA.paa` | - | 1 |  |
| 257 | `mil_marker_noShadow` | Marker | `\A3\ui_f\data\map\markers\military\marker_CA.paa` | Y | 0 |  |
| 258 | `mil_objective` | Objective | `\A3\ui_f\data\map\markers\military\objective_CA.paa` | - | 1 |  |
| 259 | `mil_objective_noShadow` | Objective | `\A3\ui_f\data\map\markers\military\objective_CA.paa` | Y | 0 |  |
| 260 | `mil_pickup` | Pick Up | `\A3\ui_f\data\map\markers\military\pickup_CA.paa` | - | 1 |  |
| 261 | `mil_pickup_noShadow` | Pick Up | `\A3\ui_f\data\map\markers\military\pickup_CA.paa` | Y | 0 |  |
| 262 | `mil_start` | Start | `\A3\ui_f\data\map\markers\military\start_CA.paa` | - | 1 |  |
| 263 | `mil_start_noShadow` | Start | `\A3\ui_f\data\map\markers\military\start_CA.paa` | Y | 0 |  |
| 264 | `mil_triangle` | Triangle | `\A3\ui_f\data\map\markers\military\triangle_CA.paa` | - | 1 |  |
| 265 | `mil_triangle_noShadow` | Triangle | `\A3\ui_f\data\map\markers\military\triangle_CA.paa` | Y | 0 |  |
| 266 | `mil_unknown` | Unknown | `\A3\ui_f\data\map\markers\military\unknown_CA.paa` | - | 1 |  |
| 267 | `mil_unknown_noShadow` | Unknown | `\A3\ui_f\data\map\markers\military\unknown_CA.paa` | Y | 0 |  |
| 268 | `mil_warning` | Warning | `\A3\ui_f\data\map\markers\military\warning_CA.paa` | - | 1 |  |
| 269 | `mil_warning_noShadow` | Warning | `\A3\ui_f\data\map\markers\military\warning_CA.paa` | Y | 0 |  |
| 270 | `Minefield` | Minefield | `\a3\Ui_F_Curator\Data\CfgMarkers\minefield_ca.paa` | Y | 1 | Zeus |
| 271 | `MinefieldAP` | Minefield (AP) | `\a3\Ui_F_Curator\Data\CfgMarkers\minefieldAP_ca.paa` | Y | 1 | Zeus |
| 272 | `n_air` | Helicopter | `\A3\ui_f\data\map\markers\nato\n_air.paa` | Y | 1 |  |
| 273 | `n_antiair` | Anti-Air | `\A3\ui_f\data\map\markers\nato\n_antiair.paa` | Y | 1 |  |
| 274 | `n_armor` | Armor | `\A3\ui_f\data\map\markers\nato\n_armor.paa` | Y | 1 |  |
| 275 | `n_art` | Artillery | `\A3\ui_f\data\map\markers\nato\n_art.paa` | Y | 1 |  |
| 276 | `n_hq` | HQ | `\A3\ui_f\data\map\markers\nato\n_hq.paa` | Y | 1 |  |
| 277 | `n_inf` | Infantry | `\A3\ui_f\data\map\markers\nato\n_inf.paa` | Y | 1 |  |
| 278 | `n_installation` | Installation | `\A3\ui_f\data\map\markers\nato\n_installation.paa` | Y | 1 |  |
| 279 | `n_maint` | Maintenance | `\A3\ui_f\data\map\markers\nato\n_maint.paa` | Y | 1 |  |
| 280 | `n_mech_inf` | Mechanized | `\A3\ui_f\data\map\markers\nato\n_mech_inf.paa` | Y | 1 |  |
| 281 | `n_med` | Medical | `\A3\ui_f\data\map\markers\nato\n_med.paa` | Y | 1 |  |
| 282 | `n_mortar` | Mortar | `\A3\ui_f\data\map\markers\nato\n_mortar.paa` | Y | 1 |  |
| 283 | `n_motor_inf` | Motorized | `\A3\ui_f\data\map\markers\nato\n_motor_inf.paa` | Y | 1 |  |
| 284 | `n_naval` | Naval | `\A3\ui_f\data\map\markers\nato\n_naval.paa` | Y | 1 |  |
| 285 | `n_Ordnance` | Ordnance | `\a3\UI_F_Orange\Data\CfgMarkers\n_Ordnance_ca.paa` | Y | 1 | Laws of War |
| 286 | `n_plane` | Plane | `\A3\ui_f\data\map\markers\nato\n_plane.paa` | Y | 1 |  |
| 287 | `n_recon` | Recon | `\A3\ui_f\data\map\markers\nato\n_recon.paa` | Y | 1 |  |
| 288 | `n_service` | Service | `\A3\ui_f\data\map\markers\nato\n_service.paa` | Y | 1 |  |
| 289 | `n_support` | Support | `\A3\ui_f\data\map\markers\nato\n_support.paa` | Y | 1 |  |
| 290 | `n_uav` | UAV | `\A3\ui_f\data\map\markers\nato\n_uav.paa` | Y | 1 |  |
| 291 | `n_unknown` | Unknown | `\A3\ui_f\data\map\markers\nato\n_unknown.paa` | Y | 1 |  |
| 292 | `o_air` | Helicopter | `\A3\ui_f\data\map\markers\nato\o_air.paa` | Y | 1 |  |
| 293 | `o_antiair` | Anti-Air | `\A3\ui_f\data\map\markers\nato\o_antiair.paa` | Y | 1 |  |
| 294 | `o_armor` | Armor | `\A3\ui_f\data\map\markers\nato\o_armor.paa` | Y | 1 |  |
| 295 | `o_art` | Artillery | `\A3\ui_f\data\map\markers\nato\o_art.paa` | Y | 1 |  |
| 296 | `o_hq` | HQ | `\A3\ui_f\data\map\markers\nato\o_hq.paa` | Y | 1 |  |
| 297 | `o_inf` | Infantry | `\A3\ui_f\data\map\markers\nato\o_inf.paa` | Y | 1 |  |
| 298 | `o_installation` | Installation | `\A3\ui_f\data\map\markers\nato\o_installation.paa` | Y | 1 |  |
| 299 | `o_maint` | Maintenance | `\A3\ui_f\data\map\markers\nato\o_maint.paa` | Y | 1 |  |
| 300 | `o_mech_inf` | Mechanized | `\A3\ui_f\data\map\markers\nato\o_mech_inf.paa` | Y | 1 |  |
| 301 | `o_med` | Medical | `\A3\ui_f\data\map\markers\nato\o_med.paa` | Y | 1 |  |
| 302 | `o_mortar` | Mortar | `\A3\ui_f\data\map\markers\nato\o_mortar.paa` | Y | 1 |  |
| 303 | `o_motor_inf` | Motorized | `\A3\ui_f\data\map\markers\nato\o_motor_inf.paa` | Y | 1 |  |
| 304 | `o_naval` | Naval | `\A3\ui_f\data\map\markers\nato\o_naval.paa` | Y | 1 |  |
| 305 | `o_Ordnance` | Ordnance | `\a3\UI_F_Orange\Data\CfgMarkers\o_Ordnance_ca.paa` | Y | 1 | Laws of War |
| 306 | `o_plane` | Plane | `\A3\ui_f\data\map\markers\nato\o_plane.paa` | Y | 1 |  |
| 307 | `o_recon` | Recon | `\A3\ui_f\data\map\markers\nato\o_recon.paa` | Y | 1 |  |
| 308 | `o_service` | Service | `\A3\ui_f\data\map\markers\nato\o_service.paa` | Y | 1 |  |
| 309 | `o_support` | Support | `\A3\ui_f\data\map\markers\nato\o_support.paa` | Y | 1 |  |
| 310 | `o_uav` | UAV | `\A3\ui_f\data\map\markers\nato\o_uav.paa` | Y | 1 |  |
| 311 | `o_unknown` | Unknown | `\A3\ui_f\data\map\markers\nato\o_unknown.paa` | Y | 1 |  |
| 312 | `RedCrystal` | Red Crystal | `\A3\ui_f_orange\data\cfgmarkers\redcrystal_ca.paa` | - | 2 | Laws of War |
| 313 | `respawn_air` | Helicopter Respawn | `\A3\ui_f\data\map\markers\nato\respawn_air_ca.paa` | Y | 1 |  |
| 314 | `respawn_armor` | Armor Respawn | `\A3\ui_f\data\map\markers\nato\respawn_armor_ca.paa` | Y | 1 |  |
| 315 | `respawn_inf` | Infantry Respawn | `\A3\ui_f\data\map\markers\nato\respawn_inf_ca.paa` | Y | 1 |  |
| 316 | `respawn_motor` | Car Respawn | `\A3\ui_f\data\map\markers\nato\respawn_motor_ca.paa` | Y | 1 |  |
| 317 | `respawn_naval` | Naval Respawn | `\A3\ui_f\data\map\markers\nato\respawn_naval_ca.paa` | Y | 1 |  |
| 318 | `respawn_para` | Airborne Respawn | `\A3\ui_f\data\map\markers\nato\respawn_para_ca.paa` | Y | 1 |  |
| 319 | `respawn_plane` | Plane Respawn | `\A3\ui_f\data\map\markers\nato\respawn_plane_ca.paa` | Y | 1 |  |
| 320 | `respawn_unknown` | Respawn | `\A3\ui_f\data\map\markers\nato\respawn_unknown_ca.paa` | Y | 1 |  |
| 321 | `Select` | Select | `\A3\ui_f\data\igui\cfg\islandmap\iconplayer_ca.paa` | Y | 1 |  |
| 322 | `selector_selectable` | Selector - Selectable | `\A3\ui_f\data\map\groupicons\selector_selectable_ca.paa` | Y | 1 |  |
| 323 | `selector_selectedEnemy` | Selector - Selected Enemy | `\A3\ui_f\data\map\groupicons\selector_selectedEnemy_ca.paa` | Y | 1 |  |
| 324 | `selector_selectedFriendly` | Selector - Selected Friendly | `\A3\ui_f\data\map\groupicons\selector_selectedFriendly_ca.paa` | Y | 1 |  |
| 325 | `selector_selectedMission` | Selector - Selected Mission | `\A3\ui_f\data\map\groupicons\selector_selectedMission_ca.paa` | Y | 1 |  |
| 326 | `u_installation` | Installation | `\A3\ui_f\data\map\markers\nato\u_installation.paa` | Y | 1 |  |
| 327 | `waypoint` | Waypoint | `\A3\ui_f\data\map\groupicons\waypoint.paa` | Y | 1 |  |
| 328 | `White` | White | `\A3\ui_f_orange\data\cfgmarkers\white_ca.paa` | - | 2 | Laws of War |

