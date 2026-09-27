# Campaign save format

The store mechanism and payload shape, adopted from Antistasi Community
(`A3A/addons/core/functions/Save/`, 20 files). *What* DUWS_T puts in a save is
[`campaign_persistence_plan.md`](../../plans/campaign_persistence_plan.md#the-snapshot); this is the container
it goes in.

It is reused rather than designed because it has survived several format migrations in production
on dedicated servers, and the shapes below are the ones that came out the other side. Where this
document diverges from Antistasi it says so and why — most of the divergences are simplifications
available to a mission with no saves in the wild yet.

## Attribution

Antistasi Community is MIT-licensed (`Copyright (c) 2019 Barbolani & The Official Antistasi
Community`). MIT carries a single obligation: any distribution that includes a substantial portion
of their code must ship the copyright and permission notice alongside it. MIT is GPL-compatible and
has no share-alike, so it adds nothing beyond carrying that notice (in `src/THIRD_PARTY_NOTICES.md`).

Techniques borrowed without their code -- the arsenal count overlay in
[`fnc_arsenal_counts.sqf`](../../../src/duws/client/arsenal/fnc_arsenal_counts.sqf) -- copy nothing
copyrightable and need only the courtesy credit already carried in its comment. The save container
under `src/duws/server/persistence/` is the same case: it is written from the shapes this document
describes and copies none of the `Save/` functions, so this document is its credit. A later port of
their code would carry the Antistasi MIT notice into `src/THIRD_PARTY_NOTICES.md`, which ships with
the packed mission.

## Two layers: an index and a payload

| Layer | Key | Contents | Read by |
|---|---|---|---|
| Index | `DUWST_saves` | One row per campaign: `[campaignID, worldName, headerJSON]` | The load screen, every write |
| Payload | `DUWST_save_<campaignID>` | The whole snapshot as one JSON string | Restore only |

The split exists so the load screen can label every save — world, day, zones held, CP, age —
without deserialising any payload. The header is a small JSON object carried *inside* the index
row, holding exactly the fields the screen renders plus the fields validation needs
(§[Refusing a save](#refusing-a-save)).

**One payload key per campaign, not per world.** A campaign ID is a random 5-digit string with
collision retry against the index (`fn_uniqueID.sqf`). Keying by world caps the player at one
campaign per map for no saving in code — the load screen has to iterate the index either way.

**`DUWST_save_<campaignID>_prev` holds the previous payload.** Writes are not atomic, and a
restart during one costs a campaign rather than an interval if there is nothing to fall back to.
This is a deliberate addition: Antistasi overwrites in place (`fn_finalizeSave.sqf:34`) and has no
fallback at all. The payload is tens of kilobytes, so doubling it is not a consideration.

## The namespace is resolved at runtime, not hardcoded

`missionProfileNamespace` is the default store — per-mission, server-side, and it lands in a
`DUWS_T.vars.Arma3Profile` outside the PBO once `description.ext` sets `missionGroup = "DUWS_T"`.

**It is not reliable everywhere.** Antistasi exposes the choice between it and `profileNamespace`
as a player-facing checkbox that defaults *off* on Linux servers, with the reason stated on the
control: *"Warning: This may not work correctly on Linux servers due to an Arma bug."*
(`A3A/addons/gui/Stringtable.xml:4920`; default at `fn_setupLoadgameTab.sqf:48`, detected with
`(productVersion # 6) isEqualTo "Linux"`).

So the namespace is read from **one function and flushed through one function**, and nothing else
in the mission names either command:

```sqf
DUWS_fnc_saveNamespace = { missionProfileNamespace };   // or profileNamespace
DUWS_fnc_saveFlush = { saveMissionProfileNamespace };   // or saveProfileNamespace
```

Antistasi retrofitted this and pays for it: the same
`[profileNamespace, missionProfileNamespace] select (_serverID isEqualType false)` expression is
re-derived in `fn_setStatVariable.sqf:12-21`, `fn_returnSavedStat.sqf:11-24`,
`fn_finalizeSave.sqf:37-46` and `fn_deleteSave.sqf:7-20`. Two functions written up front make a
Linux fallback a one-line change instead of a sweep.

`profileNamespace` remains the fallback rather than the default because it is shared by every
mission on the box, so a player clearing one mission's state risks another's.

## The payload is a hashmap serialised with `toJSON`

The save is built as a `createHashMap`, keyed by name, and written as a single `toJSON` string.
Restore does `fromJSON` once and reads keys back off the resulting hashmap.

**Names, not positions, because a format changes.** Adding a field to a positional array shifts
every index after it and silently misreads every older save; adding a key to a hashmap does
nothing to the keys already there. A reader that finds a key missing gets `nil` and can default.

**This sets a game-version floor of Arma 3 2.18**, which introduced `toJSON` / `fromJSON`.

### What JSON will and will not carry

| Rule | Consequence |
|---|---|
| Keys must be strings | A hashmap keyed by number is stringified on write and parsed back on read |
| Values: number, string, boolean, array, hashmap | Everything else is encoded to one of these first |
| No sides | Encode as an integer through a lookup both ways |
| No objects, groups, triggers, Locations, `netId`s | A `netId` is a string and survives the round trip, then resolves to nothing — silent failure, which is worse than a type error |

Antistasi hit both encoding cases: garage categories are numeric keys, stringified on save and
`call compile`d on load (`fn_saveLoop.sqf` HR_Garage block → `fn_loadStat.sqf:103-115`); sides go
through `createHashMapFromArray [[teamPlayer,0], [Occupants,1], [Invaders,2]]` and back at
`fn_loadStat.sqf:27`.

**Durations, never absolute stamps.** `diag_tickTime` and `time` count from process start, so a
stamp saved in one session sits in the future in the next and wedges whatever it gates. Store what
is left: `["nextTick", nextTick - time]` on the way out, `nextTick = time + _value` on the way in
(`fn_saveLoop.sqf`, `fn_loadStat.sqf:55`).

## One writer and one reader

No subsystem touches the namespace. `DUWS_fnc_campaignSnapshot` reads mission state into one hashmap,
which is serialised once at the end of the save. A restore keeps the deserialised payload in
`DUWS_restore`, and each restore hook reads its keys from there with `getOrDefault`, so a key that an
older or damaged snapshot lacks falls back to the builder's own value. The namespace is touched by the
write path, the scan, a delete and the one read of a chosen payload.

This is where DUWS_T drops the most Antistasi machinery. Their equivalents
(`fn_setStatVariable.sqf`, `fn_returnSavedStat.sqf`) each carry three backends — the in-flight
hashmap, a per-variable `missionProfileNamespace` key, and a per-variable `profileNamespace` key
with a `_serverID + _campaignID + "Antistasi" + _map` suffix — plus a fallback that retries under
the old Spanish variable names from the original DUWS-era codebase. All of that is back-compat for
saves that already exist. A mission with none does not inherit it.

## Write path

One function assembles and commits, on the model of `fn_finalizeSave.sqf`:

1. Build the header from the payload's own fields — format version, world, write stamp and its
   minute count, campaign day, zones held and total, CP, the faction picks, the ending, and the
   list of keys the payload holds — and `toJSON` it.
2. Rotate the current payload key to `_prev`.
3. Write the payload string, insert or replace the index row for this campaign ID, flush.

**Insert or replace, keyed by campaign ID** (`fn_finalizeSave.sqf:42-44`): a save that appends
unconditionally grows the index by one row per write.

**There is no single-variable writeback.** Antistasi's `fn_writebackSaveVar.sqf` loads a payload,
sets one key and re-commits, for the campaign-end flag. DUWS_T writes a whole snapshot marked ended
instead, from the campaign-end check just before the mission ends, since everything else in it is
current at that moment too.

**The write stamp orders saves as a minute count.** `systemTimeUTC` becomes minutes since
2020-01-01 (`DUWS_fnc_saveStamp`): SQF numbers are single floats, which hold whole minutes exactly
for decades from that epoch, where seconds since 1970 do not.

## Read path

The scan reads the index, checks each header against this session, and publishes the rows for the
load screen as `DUWS_saveList`: `[id, header pairs, refusal key]` per campaign, newest first, with the
header as pairs so the broadcast stays plain arrays. Nothing deserialises a payload until a campaign
is chosen. On choice the server parses and checks the payload before it accepts the answer
(`DUWS_fnc_saveChoose`), so a payload that fails leaves the load screen open. The restore then parses
it again into `DUWS_restore` and replays the builders against it.

**`DUWS_saveStatus` tells an empty store from one that did not read back.** Every commit also writes
the index's row count to `profileNamespace`, a second store. An empty index beside a count above zero
reads as `unreadable`, and the load screen warns before New Game writes to the same store.

**Publish an empty result rather than nothing when there is no valid save.** The load screen waits
on that variable, and a variable that is never set is indistinguishable from a server still
working.

## Refusing a save

Validation is against the *current* session, not just the payload's self-consistency. Antistasi
checks map, an `ended` flag, and that every faction, addon vehicle set and DLC the save names is
present in this session's loaded mods before a save is even offered (`fn_setupMonitor.sqf:34-42`).

For DUWS_T the mod-set check maps onto faction auto-detection: the save stores the detected
faction *identity*, not resolved classnames, and a save whose faction is no longer detectable is
labelled as such on the load screen rather than loaded into a campaign of missing classnames.

## Version and migration

The format version is an integer, not a string, so it can be compared: Antistasi parses `"3.11.4"`
into `31104` at load (`fn_loadStat.sqf:47-52`) and branches on it —
`if (A3A_saveVersion < 31000) exitWith {}`.

**Refusing a mismatched save is the opening behaviour, and it is a decision with a known cost.**
Five of Antistasi's twenty save files are converters (`fn_convert310Vehicles`,
`fn_convertSavedGarrisons`, `fn_convertSavedStatics`, `fn_convertVehiclesToInternal`, plus the
version branches in `fn_loadStat`). They carry that because refusing a save on a Workshop update
means every player loses their campaign on update day. A named-key payload makes the cheap half of
migration — a field added or dropped — free; only a field whose *meaning* changes needs a
converter.

**The world can drift under a save even at the same version**, because the map or the mission's
own generation can change. Antistasi drops garrisons whose markers no longer exist
(`fn_loadServer.sqf:90-94`), rebuilds any that are missing (`:106-111`), and falls back to an
approximate value when the city count no longer matches (`fn_loadStat.sqf:163-171`). The shape to
copy is per-entry reconciliation against the live world, not an all-or-nothing match.

## Per-player data

DUWS_T stores nothing per player ([`campaign_persistence_plan.md`](../../plans/campaign_persistence_plan.md#the-team)).
This section is what a per-player store would need: one hashmap inside the payload, keyed by player
UID, holding one hashmap per player. Player objects do not survive a session; UIDs do.

Three guards that are not obvious until they bite:

- **A `canSave` flag per player, false until that player's load completes.** Without it a player
  who disconnects mid-initialisation overwrites their own save with an empty one
  (`fn_savePlayer.sqf:29-32`).
- **Saving a dead or unconscious player strips their loadout and docks their money**
  (`fn_savePlayer.sqf:44-50`). Otherwise saving while downed preserves the gear the player was
  about to lose.
- **Save on disconnect, then delete the unit** (`fn_onPlayerDisconnect.sqf:40`) — a body left
  standing with a loadout that has already been banked is a duplication route.

## Export and import

Both are nearly free once the payload is a single JSON string, which is a large part of why the
string exists at all.

- **Export** is the stored payload, handed to the requesting client — `fn_exportSave.sqf` is nine
  lines. It must be sent to the client that asked, not written where the code happens to run: on a
  dedicated server an export that lands on the server box is unreachable.
- **Import** is `fromJSON`, then commit under a freshly generated campaign ID
  (`fn_importSave.sqf`, 21 lines). A new ID rather than the payload's own, so an import can never
  overwrite a campaign already on the box.

An imported payload is validated exactly as the server's own is. It has been outside the mission's
control, so it is an input.
