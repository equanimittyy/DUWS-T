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

## Player-carried

Attached to `player`, so they die with the body; `src/onPlayerRespawn.sqf` re-adds each one.

| Entry | Source | Priority | Shown when |
| --- | --- | --- | --- |
| Toggle Earplugs | `src/duws/client/client_init.sqf:244`, `src/onPlayerRespawn.sqf:16` | 0 | `_this == player` |
| Debug | `src/duws/client/client_init.sqf:254`, `src/onPlayerRespawn.sqf:24` | 0 | `_this == player`, plus the `DUWS_Debug` parameter and `game_master` membership gating the add itself |
| Search for enemy positions (hold, 6 s) | `src/duws/client/misc/fnc_intel_search_action.sqf:26-45` | 6 | Hardcore mode, flag unspent, an east-side corpse under the cursor within 3 m |
| Disguise (hold, 1 s) | `src/duws/client/client_init.sqf:507-525`, `src/onPlayerRespawn.sqf:79-96` | 0 | Alive and on foot |
| Open Chute | `src/duws/client/misc/fnc_ghst_halo.sqf:138` | 1 | Added at HALO exit, removed at canopy altitude |

Open Chute is the only entry whose callback is a script path rather than inline code, and the
only intentional user of the `shortcut` slot (`"Eject"`).

## HQ

`fnc_BluHQinit` broadcasts each adder to every client once the base is built, keyed on the prop
it decorates. The command cluster all hangs off the HQ structure rather than being split across
the commander and the map board, because the commander is a killable unit.

| Entry | Prop | Source | Priority | Shown when |
| --- | --- | --- | --- | --- |
| REQUESTS MENU | HQ building | `src/duws/client/misc/fnc_addHQBuildingActions.sqf:15` | 100 | `_this == player` |
| Squad manager | HQ building | `…:18` | 95 | `_this == player`, added only for `Squad_Leaders` |
| Reset Squad Leader | HQ building | `…:19` | 0 | `_this == player`, added only for `Squad_Leaders` |
| FOB Manager | HQ building | `…:22` | 0 | `_this == player` |
| Show Mission Cooldowns | HQ building | `…:25` | 0 | `(vehiclevarname player) == 'player1'` |
| Black Market (6-row menu) | HQ terminal | `src/duws/client/misc/fnc_addTerminalBlackMarketActions.sqf:12` | 85 | `true` |
| Redeploy Base Units (2 CP) | HQ building | `src/duws/client/misc/fnc_addRedeployAction.sqf:4` | 6 | `true` |
| VA Arsenal | `bluHQ_object`, squad-leader units | `src/duws/client/init_hq/fnc_HQaddactions.sqf:10,22,24` | 90 | `_this == player`, gated on `support_armory_available` |
| HALO solo / HALO group / HALO group (AI only) | `bluHQ_object`, squad-leader units | `src/duws/client/init_hq/fnc_HQaddactions.sqf:14-40` | 0 | `alive player`, gated on `support_halo_available`; the two group variants need `Squad_Leaders` |
| REST/HEAL (3hrs) | Satellite phone | `src/duws/client/misc/fnc_addHQSatelliteActions.sqf:19` | 0 | `_this == player`, added only for `game_master` |
| AI Heal/Re-Arm | Medical tent | `src/duws/server/init_hq/fnc_BluHQinit.sqf:660` | 0 | Within 12 m |
| Quick Kits (menu) | Supply crate | `src/duws/client/misc/fnc_addQuickChangeActions.sqf:19` | 80 | Within 3 m |

The arsenal and HALO entries have a second add path in
`src/duws/client/dialog/fnc_request_support.sqf:40-42,126-136`, which re-runs the same block when
a support is unlocked mid-campaign rather than at base build.

### HQ map board

| Entry | Source | Priority | Shown when |
| --- | --- | --- | --- |
| Teleport to Killhouse (A) | `src/duws/client/init_hq/fnc_addBoardKillhouseActions.sqf:13` | 65 | `true` |
| Teleport to Killhouse (B) | `…:23` | 65 | `true` |
| View Map | `…:34` | 5 | `_this == player`; opens the civilian map readout |
| Fast travel around base | `…:43` | 6 | `_this == player`; claims the map-click channel, arrival capped at 200 m from `PosOfBLUHQ` |

## FOB

`src/duws/shared/functions/fnc_FOBactions.sqf` mirrors the HQ command cluster onto each FOB. It
ends by blocking on `!alive blu_officer_object` and then calling `removeAllActions _fob`, so
losing the officer strips every entry the FOB carries, including ones added by other files.
That teardown is intended: the officer is the command element, and losing him is meant to cost
the player the command menus.

| Entry | Source | Priority | Shown when |
| --- | --- | --- | --- |
| REQUESTS MENU | `src/duws/shared/functions/fnc_FOBactions.sqf:8` | 100 | `_this == player`, added only for `Squad_Leaders` |
| Squad manager | `…:9` | 95 | `_this == player`, added only for `Squad_Leaders` |
| FOB Manager | `…:12` | 0 | `_this == player` |
| VA Arsenal | `…:15` | 90 | `_this == player`, gated on `support_armory_available` |
| HALO solo / group / group (AI only) | `…:19,21,22` | 0 | `_this == player`, gated on `support_halo_available` |
| REST/HEAL (3hrs) | `…:28` | 0 | `_this == player`, added only for `game_master`; 600 s cooldown enforced in the callback |
| AI Heal/Re-Arm | `…:63` | 0 | Within 12 m |
| Show Mission Cooldowns | `…:65` | 0 | `(vehiclevarname player) == 'player1'` |
| Replace FOB Defences (5 CP) | `src/duws/server/init_hq/fnc_fortifyFOB.sqf:221` | 0 | `_this == player` and a `Squad_Leaders` member |
| Replace Guards (15 CP) | `src/duws/server/init_hq/fnc_guardsFOB.sqf:109` | 0 | `_this == player` and a `Squad_Leaders` member |

## Mobile HQ

`src/duws/shared/functions/fnc_MHQ_addActions.sqf` calls `removeAllActions MHQ1` before each add,
so deploy and undeploy swap rather than accumulate.

| Entry | Prop | Source | Priority | Shown when |
| --- | --- | --- | --- | --- |
| DEPLOY Mobile HQ | `MHQ1` | `src/duws/shared/functions/fnc_MHQ_addActions.sqf:21` | none | Added only for `Squad_Leaders` |
| UN-DEPLOY Mobile HQ | `MHQ1` | `…:28` | none | Added only for `Squad_Leaders` |
| VA Arsenal | `MHQ_ammobox` | `src/duws/server/dialog/fnc_MHQ_deploy.sqf:47` | 0 | Within 8 m |
| AI Heal/Re-Arm | `MHQ_ammobox` | `…:48` | 0 | Within 8 m |

The two deploy entries pass a two-element array, so every slot from `arguments` onward takes its
engine default — they are the only DUWS entries with no explicit priority.

## Killhouse

| Entry | Prop | Source | Priority | Shown when |
| --- | --- | --- | --- | --- |
| Killhouse Controls (5–6 row menu) | Multi-screen computer | `src/duws/server/misc/fnc_createKillhouse.sqf:1248` | 6 | `true` |

Rows are assembled on the clicking machine each time the terminal is used, not baked when the
killhouse is built, so the arsenal row can appear after a mid-campaign purchase. Entry to the
killhouse is via the two map-board teleports listed under HQ; exit is a row inside this menu.

## Support and logistics

| Entry | Prop | Source | Priority | Shown when |
| --- | --- | --- | --- | --- |
| VA Arsenal | Airdropped ammobox | `src/duws/client/supports/fnc_ammobox.sqf:106` | 0 | Within 8 m |
| AI Heal/Re-Arm | Airdropped ammobox | `…:107` | 0 | Within 8 m |
| Vehicle Recycling (2-row menu) | Depot | `src/duws/client/supports/fnc_client_addRecycleActions.sqf:12` | 70 | Within 8 m |
| Vehicle Customization (4-row menu) | Depot | `src/duws/client/supports/fnc_client_addRepairActions.sqf:319` | 75 | Within 8 m |
| Give waypoints to the pilot | Taxi helicopter | `src/duws/client/supports/taxi/fnc_helotaxi.sqf:54` | 0 | `vehicle _this == _target` |
| Give an LZ to the pilot | Taxi helicopter | `…:157` | 0 | `vehicle _this == _target` |
| Tell the driver where to go | Taxi boat | `src/duws/client/supports/taxi/fnc_boatTaxi.sqf:37` | 0 | `vehicle _this == _target` |
| Give a location to the driver | Taxi boat | `…:75` | 0 | `vehicle _this == _target` |
| Give waypoints to the pilot | `player` | `src/duws/client/supports/fnc_helolift.sqf:210` | 0 | `true`; added for the lift request and removed on takeoff |

The lift entry is the one support action attached to the player rather than the vehicle, and it
reuses the helo-taxi title string.

## Side missions

| Entry | Prop | Source | Priority | Shown when |
| --- | --- | --- | --- | --- |
| Full Arsenal (one-time use) | Cache ammo boxes | `…/destroy_cache/fnc_destroy_cache_mission.sqf:101,136` | 6 | Arsenal unspent |
| Full Arsenal (one-time use) | Supply truck | `…/steal_supply/fnc_steal_supply_mission.sqf:65` | 6 | Arsenal unspent |
| Sabotage | Laptop | `…/sabotage_laptop/fnc_sabotage_laptop_mission.sqf:191` | 0 | `_this == player` |
| Search for Intel (hold, 6 s) | Laptop | `…/sabotage_laptop/fnc_sabotage_laptop_mission.sqf:196` via `src/duws/server/dialog/fnc_actionRotary.sqf` | 6 | Within 3 m, hardcore mode only |
| Search Container (hold, 1 s) | Intel container | `…/intel_gathering/fnc_intel_gathering_mission.sqf:88-110` | 0 | Within 3 m |
| Carry the pilot | Downed pilot | `…/rescue_pilot/fnc_rescue_pilot_mission.sqf:298` | 1 | `radius` 5 m |
| Put the pilot down | Carrier | `…:241` | 1 | `player == _target`, `radius` 5 m |
| Load the pilot into the vehicle | Carrier | `…:254` | 1 | Carrying a live pilot with a vehicle within 5 m, `radius` 5 m |
| Take the pilot out | Vehicle | `…:357` | 1 | `vehicle _this == _this`, `radius` 5 m |

The four rescue-pilot entries are the only DUWS actions that use the `radius` slot rather than a
distance test inside the condition string.

## Intel

| Entry | Prop | Source | Priority | Shown when |
| --- | --- | --- | --- | --- |
| Search the body (hold, 2 s) | Enemy corpse | `src/duws/client/misc/fnc_corpse_search_action.sqf:22-78` | 1 | Within 3 m |

Added per corpse by `src/duws/server/misc/fnc_add_intel_on_death.sqf:6`. The player-carried
hardcore body search is a separate entry with its own payout path; see Player-carried above.

## Civilian interaction

Added per civilian. `fnc_civ_clientActions` bundles the first two into a single broadcast so the
unit can serve as the JIP id — a queued message keyed to a deleted object is dropped, where an
auto-generated id would outlive the civilian and leave one queue entry per unit forever.

| Entry | Source | Priority | Shown when |
| --- | --- | --- | --- |
| Order to Stop | `src/duws/shared/functions/fnc_civ_stopCommand.sqf:25` | 6 | Within 40 m |
| Civilian Interaction (5-row dialog) | `src/duws/shared/functions/fnc_civ_menuAction.sqf:15` | 6 | Alive, called over, within 15 m, not surrendered |
| Search | `src/duws/shared/functions/fnc_civ_search_action.sqf:12` | 6 | Within 3 m and surrendered |
| Offer evacuation | `src/duws/shared/functions/fnc_addRecruitAction.sqf:11` | 6 | `true` |

Civilian Interaction opens `civ_dialog` rather than `fnc_open_action_menu`, because its rows need
per-row greying against coin count, town state and range. Search stays a scroll entry rather than
becoming a dialog row: the menu hides on `isSurrendered`, so offering it there would mean closing,
waiting out the surrender animation and reopening.

## Vendored module entries

Not DUWS-authored, but they share the same scroll menu and the same priority space.

| Module | Entries | Source |
| --- | --- | --- |
| AIS | First Aid/Revive, Stabilize, Drag, Carry, Release, Unload Injured, Load Injured | `src/modules/AIS/System/fn_postinit.sqf`, added through `AIS_Core_fnc_addAction` at a fixed priority of 1.5. Titles are hardcoded English and restyled through `setUserActionText` with `#E9FDF7` text plus an icon |
| R3F Logistics | Object move/rotate/align entries and the config-tool dump actions | `src/modules/R3F_LOG/objet_deplacable/deplacer.sqf:166-171` |
| TAW View Distance | View-distance menu | `src/modules/taw_vd/fn_openMenu.sqf`, reached through the CfgFunctions include in `src/description.ext` |

## Where the format diverges

Each row is a real split in the current source, and each is a decision to make before the format
can be standardised.

| Axis | Variants in use |
| --- | --- |
| Colour application | Baked into the stringtable value (`STR_DUWS_T_2rc0nvug` = `<t color='#00FF00'>Toggle Earplugs </t>`); wrapped at the call site with `format ["<t color='#00ff00'>%1</t>", localize …]`; concatenated with `+` (`fnc_addBoardKillhouseActions.sqf:14`); or absent entirely (Change Appearance, View Map, Vehicle Recycling, Vehicle Customization, Sabotage, every hold action, and three of the four civilian entries) |
| Colour vocabulary | Green appears as `#00FF00`, `#00ff00`, `#15ff00` and `#99ff00`; red as `#ff1111`, `#ff1011`, `#FF0000` and `#ff0000`; blue as `#00b7ff`, `#00AAFF` and `#00ffff`; amber as `#ffb700`, `#ffaa00` and `#ff8000` — with no consistent mapping from hue to meaning |
| Trailing whitespace | Several stringtable values end in a space inside the `<t>` tag (`VA Arsenal `, `REQUESTS MENU `, `Squad manager `) |
| Localisation | Every title is a `localize` call except Debug, which is a hardcoded English literal in `client_init.sqf:254` and `onPlayerRespawn.sqf:24` |
| Priority | 100, 95, 90, 85, 80, 75, 70, 65, 6, 5, 1, 0, and two entries with none. Values above 65 form a rough intent ordering; 6 and 0 are used interchangeably for everything else |
| `arguments` slot | `""`, `nil` and `[]` all appear for "no arguments" |
| Condition slot | `""` (always shown), `"true"`, `"_this == player"`, `"alive player"`, a distance literal at 3/8/12/15/40 m, or the `radius` slot instead |
| Attach path | Direct `addAction` behind `if (!hasInterface) exitWith {}`; `remoteExec ["addAction", 0]`; `remoteExec` of a named adder function with the JIP flag; and `BIS_fnc_MP` (deprecated) at four call sites |
| Duplicate guard | `getVariable ["…_done", false]`; `isNil {getVariable "…"}`; a `setVariable` with no read; or no guard at all |
| Removal | `removeAction` on a stored id; `removeAllActions`; `hideOnUse`; or a condition reading a spent flag |
| Slot arity | Two elements (MHQ deploy), seven (Open Chute), eight (most), nine (rescue pilot) |
