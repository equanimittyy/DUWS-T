# Action Menu Inventory

Every scroll-wheel entry DUWS itself creates, grouped by the system that owns it. Vendored
modules under `src/modules/` add their own and are listed separately at the end.

Three mechanisms produce entries, and they are not interchangeable:

| Mechanism | Produces | Used for |
| --- | --- | --- |
| `addAction` | An instant scroll entry | Almost everything |
| `BIS_fnc_holdActionAdd` | A hold-to-complete entry with an on-screen icon and progress ring | Searching bodies and containers, the disguise panel, `fnc_actionRotary` props |
| `fnc_open_action_menu` | A dialog listbox opened *by* one scroll entry | Collapsing a cluster of related entries into a single scroll row |

`src/duws/client/dialog/fnc_open_action_menu.sqf` is the escape hatch from scroll-menu sprawl:
Black Market, Vehicle Recycling, Vehicle Customization, Killhouse Controls, Quick Kits and the
debug menu each occupy one scroll row and expand into a list. Rows in that listbox are *not*
action-menu entries and are excluded from the tables below; the row count is noted instead.

`addAction`'s array is positional — `[title, script, arguments, priority, showWindow, hideOnUse,
shortcut, condition, radius, unconscious, selection, memoryPoint]`. Slot 7 is a keybind name,
slot 8 is the condition. A seven-element array therefore has no condition at all.

## Title formatting

Titles are structured text, so `<t>` attributes apply. Only one is in use:

| Attribute | Status across every DUWS action title |
| --- | --- |
| `color` | The only attribute used. Most entries carry one; the exceptions cluster by category, listed below |
| `size` | Never used on any action title. The single `size='2'` in `stringtable.xml` is the AO-select map prompt, not an action |

Colour reaches a title from one of two places, and the `Colour` column in every table below
records which:

- **`str`** — baked into the stringtable value, e.g. `STR_DUWS_T_2rc0nvug` is literally
  `<t color='#00FF00'>Toggle Earplugs </t>`. Every localisation inherits the markup, and the
  string cannot be reused uncoloured.
- **`call`** — wrapped where the action is added, via `format ["<t color='#…'>%1</t>", localize …]`
  or `"<t color='#…'>" + localize …`. The stringtable value stays plain text.

Two further regularities are worth keeping when the format is rewritten:

**No hold action carries colour.** All eight are plain text and identify themselves by icon
instead, passed twice (idle and progress):

| Icon | Used by |
| --- | --- |
| `holdAction_search_ca.paa` | Player intel search, corpse search, intel container, `fnc_actionRotary` `"search"` |
| `holdAction_hack_ca.paa` | Disguise panel |
| `holdAction_connect_ca.paa` | `fnc_actionRotary` `"connect"` |
| `holdAction_talk_ca.paa` | `fnc_actionRotary` `"talk"` — the one icon not from `\a3\ui_f\data\IGUI\Cfg\holdactions\` |

**Menu rows use a different colour system entirely.** `fnc_open_action_menu` takes `[r,g,b,a]`
floats per row and strips `<t>` markup from row labels, because a listbox renders markup
literally. A scroll-entry colour and a row colour therefore cannot share a definition:

| Menu | Row colours |
| --- | --- |
| Black Market | `[0,1,0,1]` on all three purchases |
| Intel & Recruitment | `[1,0.667,0,1]` on all three rows |
| Killhouse Controls | `[0,1,0,1]` spawn targets, `[1,0,0,1]` spawn enemies, `[1,1,0,1]` cleanup, `[0,1,1,1]` kits and arsenal, `[1,0.533,0,1]` exit |
| Vehicle Recycling | None — both rows default |
| Vehicle Customization | None — all four rows default |

## Player-carried

Attached to `player`, so they die with the body; `src/onPlayerRespawn.sqf` re-adds each one.

| Entry | Source | Colour | Priority | Shown when |
| --- | --- | --- | --- | --- |
| Toggle Earplugs | `src/duws/client/client_init.sqf:244`, `src/onPlayerRespawn.sqf:16` | `#00FF00` str | 0 | `_this == player` |
| Debug | `src/duws/client/client_init.sqf:254`, `src/onPlayerRespawn.sqf:24` | `#ff8000` call | 0 | `_this == player`, plus the `DUWS_Debug` parameter and `game_master` membership gating the add itself |
| Search for enemy positions (hold, 6 s) | `src/duws/client/misc/fnc_intel_search_action.sqf:26-45` | — search icon | 6 | Hardcore mode, flag unspent, an east-side corpse under the cursor within 3 m |
| Disguise (hold, 1 s) | `src/duws/client/client_init.sqf:507-525`, `src/onPlayerRespawn.sqf:79-96` | — hack icon | 0 | Alive and on foot |
| Open Chute | `src/duws/client/misc/fnc_ghst_halo.sqf:138` | `#ff0000` str | 1 | Added at HALO exit, removed at canopy altitude |

Open Chute is the only entry whose callback is a script path rather than inline code, and the
only intentional user of the `shortcut` slot (`"Eject"`). Debug is the only title that is not a
`localize` call, so its colour is a literal in two files.

## HQ

`fnc_BluHQinit` broadcasts each adder to every client once the base is built, keyed on the prop
it decorates. The command cluster all hangs off the HQ structure rather than being split across
the commander and the map board, because the commander is a killable unit.

| Entry | Prop | Source | Colour | Priority | Shown when |
| --- | --- | --- | --- | --- | --- |
| REQUESTS MENU | HQ building | `src/duws/client/misc/fnc_addHQBuildingActions.sqf:15` | `#15ff00` str | 100 | `_this == player` |
| Squad manager | HQ building | `…:18` | `#ffb700` str | 95 | `_this == player`, added only for `Squad_Leaders` |
| Reset Squad Leader | HQ building | `…:19` | `#ffb700` str | 0 | `_this == player`, added only for `Squad_Leaders` |
| FOB Manager | HQ building | `…:22` | `#15ff00` str | 0 | `_this == player` |
| Show Mission Cooldowns | HQ building | `…:25` | `#15ff00` str | 0 | `(vehiclevarname player) == 'player1'` |
| Black Market (3-row menu) | HQ terminal | `src/duws/client/misc/fnc_addTerminalBlackMarketActions.sqf:12` | `#00ff00` call | 85 | `true` |
| Intel & Recruitment (3-row menu) | HQ terminal | `…:32` | `#00ff00` call | 84 | `true` |
| Redeploy Base Units (2 CP) | HQ building | `src/duws/client/misc/fnc_addRedeployAction.sqf:4` | `#ff1111` str | 6 | `true` |
| VA Arsenal | `bluHQ_object`, squad-leader units | `src/duws/client/init_hq/fnc_HQaddactions.sqf:10,22,24` | `#00FF00` str | 90 | `_this == player`, gated on `support_armory_available` |
| HALO solo / HALO group / HALO group (AI only) | `bluHQ_object`, squad-leader units | `src/duws/client/init_hq/fnc_HQaddactions.sqf:14-40` | `#00ffff` str | 0 | `alive player`, gated on `support_halo_available`; the two group variants need `Squad_Leaders` |
| REST/HEAL (3hrs) | Satellite phone | `src/duws/client/misc/fnc_addHQSatelliteActions.sqf:19` | `#00b7ff` str | 0 | `_this == player`, added only for `game_master` |
| AI Heal/Re-Arm | Medical tent | `src/duws/server/init_hq/fnc_BluHQinit.sqf:660` | `#ff1011` str | 0 | Within 12 m |
| Quick Kits (menu) | Supply crate | `src/duws/client/misc/fnc_addQuickChangeActions.sqf:19` | `#00ff00` call | 80 | Within 3 m |

The arsenal and HALO entries have a second add path in
`src/duws/client/dialog/fnc_request_support.sqf:40-42,126-136`, which re-runs the same block when
a support is unlocked mid-campaign rather than at base build.

### HQ map board

| Entry | Source | Colour | Priority | Shown when |
| --- | --- | --- | --- | --- |
| Teleport to Killhouse (A) | `src/duws/client/init_hq/fnc_addBoardKillhouseActions.sqf:13` | `#00AAFF` call | 65 | `true` |
| Teleport to Killhouse (B) | `…:23` | `#00AAFF` call | 65 | `true` |
| View Map | `…:34` | — | 5 | `_this == player`; opens the civilian map readout |
| Fast travel around base | `…:43` | `#00ffff` str | 6 | `_this == player`; claims the map-click channel, arrival capped at 200 m from `PosOfBLUHQ` |

The two teleports are the only entries that build their markup by `+` concatenation rather than
`format`.

## FOB

`src/duws/shared/functions/fnc_FOBactions.sqf` mirrors the HQ command cluster onto each FOB, and
reuses its stringtable keys, so every colour here matches its HQ twin. It ends by blocking on
`!alive blu_officer_object` and then calling `removeAllActions _fob`, so losing the officer strips
every entry the FOB carries, including ones added by other files. That teardown is intended: the
officer is the command element, and losing him is meant to cost the player the command menus.

| Entry | Source | Colour | Priority | Shown when |
| --- | --- | --- | --- | --- |
| REQUESTS MENU | `src/duws/shared/functions/fnc_FOBactions.sqf:8` | `#15ff00` str | 100 | `_this == player`, added only for `Squad_Leaders` |
| Squad manager | `…:9` | `#ffb700` str | 95 | `_this == player`, added only for `Squad_Leaders` |
| FOB Manager | `…:12` | `#15ff00` str | 0 | `_this == player` |
| VA Arsenal | `…:15` | `#00FF00` str | 90 | `_this == player`, gated on `support_armory_available` |
| HALO solo / group / group (AI only) | `…:19,21,22` | `#00ffff` str | 0 | `_this == player`, gated on `support_halo_available` |
| REST/HEAL (3hrs) | `…:28` | `#00b7ff` str | 0 | `_this == player`, added only for `game_master`; 600 s cooldown enforced in the callback |
| AI Heal/Re-Arm | `…:63` | `#ff1011` str | 0 | Within 12 m |
| Show Mission Cooldowns | `…:65` | `#15ff00` str | 0 | `(vehiclevarname player) == 'player1'` |
| Replace FOB Defences (5 CP) | `src/duws/server/init_hq/fnc_fortifyFOB.sqf:221` | `#ff1111` str | 0 | `_this == player` and a `Squad_Leaders` member |
| Replace Guards (15 CP) | `src/duws/server/init_hq/fnc_guardsFOB.sqf:109` | `#ff1111` str | 0 | `_this == player` and a `Squad_Leaders` member |

## Mobile HQ

`src/duws/shared/functions/fnc_MHQ_addActions.sqf` calls `removeAllActions MHQ1` before each add,
so deploy and undeploy swap rather than accumulate.

| Entry | Prop | Source | Colour | Priority | Shown when |
| --- | --- | --- | --- | --- | --- |
| DEPLOY Mobile HQ | `MHQ1` | `src/duws/shared/functions/fnc_MHQ_addActions.sqf:21` | `#99ff00` str | none | Added only for `Squad_Leaders` |
| UN-DEPLOY Mobile HQ | `MHQ1` | `…:28` | `#99ff00` str | none | Added only for `Squad_Leaders` |
| VA Arsenal | `MHQ_ammobox` | `src/duws/server/dialog/fnc_MHQ_deploy.sqf:47` | `#00FF00` str | 0 | Within 8 m |
| AI Heal/Re-Arm | `MHQ_ammobox` | `…:48` | `#ff1011` str | 0 | Within 8 m |

The two deploy entries pass a two-element array, so every slot from `arguments` onward takes its
engine default — they are the only DUWS entries with no explicit priority.

## Killhouse

| Entry | Prop | Source | Colour | Priority | Shown when |
| --- | --- | --- | --- | --- | --- |
| Killhouse Controls (5–6 row menu) | Multi-screen computer | `src/duws/server/misc/fnc_createKillhouse.sqf:1248` | `#00FF00` call | 6 | `true` |

Rows are assembled on the clicking machine each time the terminal is used, not baked when the
killhouse is built, so the arsenal row can appear after a mid-campaign purchase. Entry to the
killhouse is via the two map-board teleports listed under HQ; exit is a row inside this menu.

## Support and logistics

| Entry | Prop | Source | Colour | Priority | Shown when |
| --- | --- | --- | --- | --- | --- |
| VA Arsenal | Airdropped ammobox | `src/duws/client/supports/fnc_ammobox.sqf:106` | `#00FF00` str | 0 | Within 8 m |
| AI Heal/Re-Arm | Airdropped ammobox | `…:107` | `#ff1011` str | 0 | Within 8 m |
| Vehicle Recycling (2-row menu) | Depot | `src/duws/client/supports/fnc_client_addRecycleActions.sqf:12` | — | 70 | Within 8 m |
| Vehicle Customization (4-row menu) | Depot | `src/duws/client/supports/fnc_client_addRepairActions.sqf:319` | — | 75 | Within 8 m |
| Give waypoints to the pilot | Taxi helicopter | `src/duws/client/supports/taxi/fnc_helotaxi.sqf:54` | `#00ff00` call | 0 | `vehicle _this == _target` |
| Give an LZ to the pilot | Taxi helicopter | `…:157` | `#00ff00` call | 0 | `vehicle _this == _target` |
| Tell the driver where to go | Taxi boat | `src/duws/client/supports/taxi/fnc_boatTaxi.sqf:37` | `#00b7ff` call | 0 | `vehicle _this == _target` |
| Give a location to the driver | Taxi boat | `…:75` | `#00b7ff` call | 0 | `vehicle _this == _target` |
| Give waypoints to the pilot | `player` | `src/duws/client/supports/fnc_helolift.sqf:210` | `#00ff00` call | 0 | `true`; added for the lift request and removed on takeoff |

Boat and helicopter taxi are the same feature in two colours: green for air, blue for sea, set at
the call site rather than by role. The lift entry is the one support action attached to the player
rather than the vehicle, and it reuses the helo-taxi title string and colour.

## Side missions

| Entry | Prop | Source | Colour | Priority | Shown when |
| --- | --- | --- | --- | --- | --- |
| Full Arsenal (one-time use) | Cache ammo boxes | `…/destroy_cache/fnc_destroy_cache_mission.sqf:101,136` | `#00ff00` call | 6 | Arsenal unspent |
| Full Arsenal (one-time use) | Supply truck | `…/steal_supply/fnc_steal_supply_mission.sqf:65` | `#00ff00` call | 6 | Arsenal unspent |
| Sabotage | Laptop | `…/sabotage_laptop/fnc_sabotage_laptop_mission.sqf:191` | — | 0 | `_this == player` |
| Search for Intel (hold, 6 s) | Laptop | `…/sabotage_laptop/fnc_sabotage_laptop_mission.sqf:196` via `src/duws/server/dialog/fnc_actionRotary.sqf` | — search icon | 6 | Within 3 m, hardcore mode only |
| Search Container (hold, 1 s) | Intel container | `…/intel_gathering/fnc_intel_gathering_mission.sqf:88-110` | — search icon | 0 | Within 3 m |
| Carry the pilot | Downed pilot | `…/rescue_pilot/fnc_rescue_pilot_mission.sqf:298` | `#FF0000` call | 1 | `radius` 5 m |
| Put the pilot down | Carrier | `…:241` | `#FF0000` call | 1 | `player == _target`, `radius` 5 m |
| Load the pilot into the vehicle | Carrier | `…:254` | `#FF0000` call | 1 | Carrying a live pilot with a vehicle within 5 m, `radius` 5 m |
| Take the pilot out | Vehicle | `…:357` | `#FF0000` call | 1 | `vehicle _this == _this`, `radius` 5 m |

The four rescue-pilot entries are the only DUWS actions that use the `radius` slot rather than a
distance test inside the condition string, and the only group with a consistent colour applied
across the whole feature.

## Intel

| Entry | Prop | Source | Colour | Priority | Shown when |
| --- | --- | --- | --- | --- | --- |
| Search the body (hold, 2 s) | Enemy corpse | `src/duws/client/misc/fnc_corpse_search_action.sqf:22-78` | — search icon | 1 | Within 3 m |

Added per corpse by `src/duws/server/misc/fnc_add_intel_on_death.sqf:6`. The player-carried
hardcore body search is a separate entry with its own payout path; see Player-carried above.

## Civilian interaction

Added per civilian. `fnc_civ_clientActions` bundles the first two into a single broadcast so the
unit can serve as the JIP id — a queued message keyed to a deleted object is dropped, where an
auto-generated id would outlive the civilian and leave one queue entry per unit forever.

| Entry | Source | Colour | Priority | Shown when |
| --- | --- | --- | --- | --- |
| Order to Stop | `src/duws/shared/functions/fnc_civ_stopCommand.sqf:25` | — | 6 | Within 6 m, inside a 15° facing cone, not panicking |
| Civilian Interaction (5-row dialog) | `src/duws/shared/functions/fnc_civ_menuAction.sqf:15` | — | 6 | Alive, called over, within 3 m, not surrendered, not spent |
| Search | `src/duws/shared/functions/fnc_civ_search_action.sqf:12` | `#ffaa00` call | 6 | Within 3 m and surrendered |
| Release | `src/duws/shared/functions/fnc_civ_release_action.sqf:12` | — | 6 | Within 3 m, surrendered, still on the civilian side |
| Offer evacuation | `src/duws/shared/functions/fnc_addRecruitAction.sqf:11` | — | 6 | `true` |

This is the least formatted category: four of five entries are plain text, and Search is the only
entry anywhere on `#ffaa00`. Civilian Interaction opens `civ_dialog` rather than
`fnc_open_action_menu`, because its rows need per-row greying against coin count, town state and
range. Search stays a scroll entry rather than becoming a dialog row: the menu hides on
`isSurrendered`, so offering it there would mean closing, waiting out the surrender animation and
reopening.

The call-over reaches twice as far as everything it gates, which is the one deliberate range
mismatch here: halting a local is done at a distance, and the player then walks in to the 3 m the
menu and both arrest follow-ups work at. Search and Release are the two ways an arrest ends, and
Release tests side as well as `isSurrendered` — the reprisal roll moves a civilian who turns on the
player into a resistance group without clearing the flag.

## Vendored module entries

Not DUWS-authored, but they share the same scroll menu, the same priority space, and the same
`<t>` markup.

| Module | Entries | Source and formatting |
| --- | --- | --- |
| AIS | First Aid/Revive, Stabilize, Drag, Carry, Release, Unload Injured, Load Injured | `src/modules/AIS/System/fn_postinit.sqf`, added through `AIS_Core_fnc_addAction` at a fixed priority of 1.5. Titles are hardcoded English and restyled through `setUserActionText` with `#E9FDF7` text plus a per-action `<img>` icon — the only entries in the scroll menu that carry an inline image |
| R3F Logistics | Object move/rotate/align entries and the config-tool dump actions | `src/modules/R3F_LOG/objet_deplacable/deplacer.sqf:166-171`, priority 10 on release and 6 on the rest, coloured `#ee0000` and `#00eeff` |
| TAW View Distance | View-distance menu | `src/modules/taw_vd/fn_openMenu.sqf`, reached through the CfgFunctions include in `src/description.ext` |

## Where the format diverges

Each row is a real split in the current source, and each is a decision to make before the format
can be standardised.

| Axis | Variants in use |
| --- | --- |
| Colour application | Baked into the stringtable value (`str` in the tables above); wrapped at the call site with `format` (`call`); concatenated with `+` (the two killhouse teleports); or absent |
| Colour vocabulary | Green appears as `#00FF00`, `#00ff00`, `#15ff00` and `#99ff00`; red as `#ff1111`, `#ff1011`, `#FF0000` and `#ff0000`; blue as `#00b7ff`, `#00AAFF` and `#00ffff`; amber as `#ffb700`, `#ffaa00` and `#ff8000` — 14 distinct literals for what reads as four intents, with no consistent mapping from hue to meaning |
| Colour coverage | Whole categories are unstyled: every hold action, both depot menus, and three of the four civilian entries. Side missions style the rescue-pilot set and leave sabotage plain |
| Size | Unused on every action title, so there is no existing convention to preserve |
| Trailing whitespace | Twelve action-title values end in a space inside the `<t>` tag (`VA Arsenal `, `REQUESTS MENU `, `Squad manager `, `HALO solo `, and the rest) |
| Localisation | Every title is a `localize` call except Debug, a hardcoded English literal in `client_init.sqf:254` and `onPlayerRespawn.sqf:24` |
| Priority | 100, 95, 90, 85, 80, 75, 70, 65, 6, 5, 1, 0, and two entries with none. Values above 65 form a rough intent ordering; 6 and 0 are used interchangeably for everything else |
| `arguments` slot | `""`, `nil` and `[]` all appear for "no arguments" |
| Condition slot | `""` (always shown), `"true"`, `"_this == player"`, `"alive player"`, a distance literal at 3/8/12/15/40 m, or the `radius` slot instead |
| Attach path | Direct `addAction` behind `if (!hasInterface) exitWith {}`; `remoteExec ["addAction", 0]`; `remoteExec` of a named adder function with the JIP flag; and `BIS_fnc_MP` (deprecated) at four call sites |
| Duplicate guard | `getVariable ["…_done", false]`; `isNil {getVariable "…"}`; a `setVariable` with no read; or no guard at all |
| Removal | `removeAction` on a stored id; `removeAllActions`; `hideOnUse`; or a condition reading a spent flag |
| Slot arity | Two elements (MHQ deploy), seven (Open Chute), eight (most), nine (rescue pilot) |
