# Game modes: design notes and migration

Three campaign modes — DUWS, Guerilla, Apocalypse — picked from a row at the top of the faction
screen (`client/dialog/fnc_HQ_faction_dialog.sqf`), before HQ placement and before either
parameter screen. Paths below are relative to `src/`.

The row sits on the first screen of setup on purpose: a mode is allowed to narrow the screens that
follow it (which factions are offered, which parameter rows apply), and nothing that runs before it
can be narrowed at all. Moving the choice later would cost that.

Two of the three modes already exist as settings, buried among unrelated options. Apocalypse is the
civilian-type combo's `RAVAGE` and `WBK` rows; Guerilla is the environment screen's insurgent
toggle. Promoting them makes each one a thing the player chooses first rather than a flavour they
find at the bottom of a list, and gives the third mode — the plain campaign — a name.

## What ships now

`duws_gamemode` holds the token (`"duws"`, `"guerilla"`, `"apocalypse"`), set by the combo's
`LBSelChanged` handler, published alongside `BLUFOR_Faction_X` / `OPFOR_Faction_X` when the screen
closes, defaulted in `server/server_var_init.sqf` so no machine reads nil, and logged in the setup
snapshot in `client/dialog/fnc_callsign_confirm.sqf`.

What it decides so far is who the enemy can be (§Apocalypse below) and which civilian rows the
environment screen offers. What it does not yet decide is how the campaign plays: Guerilla is still
inert, and an Apocalypse campaign is still a DUWS campaign whose crowd happens to be zombies. Until
that lands, the row promises more than it delivers, which is reason enough not to ship it as it
stands.

## Guerilla

Today's `insurgent_mode_enable` is a support-economy restriction and nothing else: withheld
supports render grey rather than orange (`client/dialog/fnc_support_list_fill.sqf:23,56`), buying
one is refused outright, and the Mobile HQ is free (`client/supports/fnc_supports_init.sqf:138-146`,
mirrored in the list's free-price rendering at `fnc_support_list_fill.sqf:41`).

The mode is the wider package that setting only gestures at: fewer supports *and* a campaign the
player is not expected to win by attrition — heavier OPFOR multiplier and army power, a thinner
BLUFOR start, more ground to take. Those are campaign-screen values
(`client/dialog/fnc_process_campaign_menu.sqf`), which puts the mode in the same business as the
preset row (`client/dialog/fnc_startup_preset_apply.sqf`): both answer parameter screens on the
player's behalf.

Only one of them can own a combo's value, and the cheap way to keep it one is for the mode to
contribute a defaults set the way Classic does — the mode's values become what `_setDefault` marks
and what the preset row restores to, and touching any combo afterwards drops that row to Custom
exactly as it does now. No second writer, no ordering rule to maintain. What that costs is the
ability to say "Guerilla means at least this much OPFOR": a player can walk every value back and
keep the name. Whether the mode should instead clamp is the open decision below.

`insurgent_mode_enable` then stops being a setting and becomes `duws_gamemode == "guerilla"`,
derived at the two read sites above. Its environment row goes: `shared/includes/enviro_menu.hpp:290-309`,
`client/dialog/fnc_enviro_menu.sqf:141-147`, `client/dialog/fnc_process_enviro_menu.sqf:187-194`.

## Apocalypse

Two mod-backed implementations sit behind one row. Ravage supplies `zombie_bolter` / `zombie_runner`
/ `zombie_walker` (`shared/factions/CIV_FACTIONS.sqf:81-95`, which already probes for them and
falls back to plain civilians with a warning when the mod is absent); WBK supplies its own special
zombies, listed in `server/civilian/fnc_civ_handler_wbk.sqf:131-144`. Each has its own town handler and
neither shares the plain-civilian path.

**Which faction counts as zombies is decided by display name**, not by a per-mod class list:
`fnc_factionIsZombie` (`shared/factions/MODERN/fn_factionAutoDetect.sqf`) matches `zombie`,
`undead` or `infected` in a `CfgFactionClasses` display name. Two mods are supported by name and
neither's faction classes can be enumerated ahead of time, so a name test is the only rule that
holds for both — and for a third zombie mod nobody has installed yet. It is a heuristic, and the
cost of it being wrong is a faction in the wrong pool, not a broken campaign.

Both directions run off that one test. `fnc_getAllFactionsClean` takes `_wantZombies` and returns
either the ordinary factions or the zombie ones, never both, so:

- the AutoDetect picker gets zombies only in the apocalypse mode, and only for OPFOR — BLUFOR is
  always called with `false` (`client/dialog/fnc_startup_faction_resolve.sqf`), which is what keeps
  the player's own side pickable in the mode without letting anyone auto-select zombies for it;
- the random roll applies the same filter from `duws_gamemode`
  (`shared/factions/MODERN/AUTODETECT_RANDOM_opfor.sqf`), so a random OPFOR is never zombies in a
  campaign that is not about them, nor an army in one that is;
- the OPFOR dropdown itself drops to the two AutoDetect rows in the apocalypse mode
  (`duws_fill_opfor_combo` in `client/dialog/fnc_HQ_faction_dialog.sqf`), because a static faction
  file or a pasted one carries no such guarantee.

With neither mod loaded the pool is empty, so the mode row refuses the pick, names both supported
mods and falls back to DUWS. Failing closed is the whole point: an Apocalypse campaign with no
zombie source is a mission with no enemy, and the mission has to keep running mod-free.

What remains is that the zombies are still *civilians*. Picking a zombie OPFOR faction says who
holds the zones; the crowd in the towns is still `CIV_PRESENCE`, still spawned by the two mode
handlers, and still chosen from the environment screen (now filtered to those two rows). Migration
of that half is a rename of the gate, not of the behaviour. Twenty-five branches across seventeen
files test `CIV_PRESENCE` against `"RAVAGE"` / `"WBK"`; they become `duws_gamemode == "apocalypse"`
plus a backend token (`duws_zombie_backend`, `"ravage"` or `"wbk"`), leaving `CIV_PRESENCE` to mean
only what flavour of civilian a town holds. Grouped by what they actually gate:

| What it gates | Sites |
|---|---|
| Handler dispatch and town setup | `server/civilian/fnc_civ_init_Tomata.sqf:177,234,238,282` |
| Reputation and garrison suppression | `server/civilian/fnc_civ_rep_Tomata.sqf:12`, `fnc_civ_garrison.sqf:8`, `fnc_escalation.sqf:9` |
| Ravage-only spawn extras | `server/civilian/fnc_civ_spawnUnit.sqf:28,44`, `fnc_civ_recycle.sqf:125,141`, `server/server_init.sqf:270` |
| Task text and objectives | `server/misc/fnc_capture_zones_task.sqf:37,46` |
| Disguise and recruitment | `client/dialog/fnc_disguise_menu.sqf:32`, `server/civilian/fnc_disguiseAsCivilian.sqf:112,115`, `server/disguise/fnc_disguiseAsEnemy.sqf:16`, `fnc_recruit_civilian_server.sqf:96` |
| Cleanup and client atmosphere | `server/missions/fnc_mission_cleanup.sqf:95-96`, `server/server_init.sqf:434`, `client/client_init.sqf:294,361,364` |

The mode's own goal — a survivor base to build up and an escape to reach — is new content built on
the migrated backend, not part of the migration. The seam for it exists:
`fnc_capture_zones_task.sqf:37-49` already swaps the zone-capture task out for an apocalypse-mode task,
so the win condition is not wired to zone count the way the other two modes are.

## Constraints the wiring has to respect

`duws_gamemode` is read on both sides — civilian handlers and WARCOM on the server, support menus
and atmosphere on clients — so it must be broadcast before `chosen_settings` opens the gate in
`client/dialog/fnc_callsign_confirm.sqf`. It already is, published with the faction picks.

The environment screen's Back button re-enters the faction screen
(`client/dialog/fnc_startup_faction_flow.sqf`), so the row restores from `duws_gamemode` rather
than resetting — the same restore-on-back contract the other two screens keep. Any narrowing a mode
applies to a later screen has to survive that round trip, and changing the mode has to invalidate
what that screen restores from: `duws_enviro_sel` holds row *indices*, which mean nothing once the
mode rebuilds the list under them. The mode row drops it on a change, the way applying a preset
does.

Saves carry the settings this replaces: `CIV_PRESENCE` and `insurgent_mode_enable` are both in the
server-config group ([`campaign_persistence_plan.md`](campaign_persistence_plan.md)). `duws_gamemode`
joins that group, and a restore of a save written before the modes existed has to map the old pair
onto a mode rather than default to DUWS — an insurgent-mode save reloaded as a plain campaign hands
the player back supports the campaign was balanced without.

## Open decisions

- **Mode versus preset precedence.** Defaults-only (above) keeps one writer but lets a player keep
  the Guerilla name with DUWS numbers. A clamp fixes that and costs a second writer on both
  parameter screens.
- **Whether the display-name markers catch what both mods actually ship.** The rule is only as
  good as the names Ravage and WBK give their factions, and that can only be confirmed with each
  mod loaded. A miss in one direction leaks a zombie faction into an ordinary campaign; in the
  other it leaves the apocalypse mode with an empty pool and the fallback to DUWS.
- **Where the backend is chosen once the town crowd stops being `CIV_PRESENCE`.** Today the
  environment screen's two remaining civilian rows pick it. The alternatives are deriving it from
  the OPFOR faction the player picked, or auto-picking when only one mod is installed.
- **What Guerilla does to OPFOR force generation**, beyond the multiplier and army-power values the
  campaign screen already exposes — whether the mode also changes what OPFOR field, or only how
  much of it.
