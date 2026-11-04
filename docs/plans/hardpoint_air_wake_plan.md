# Hardpoint air wake: implementation plan

Give every standalone hardpoint an air ring, so that a player helicopter near an emplacement finds it
crewed. Today only `AA` has an air ring. The ground ring (`fnc_duws_bluforNear`) ignores everyone in an
aircraft, so a standalone MG nest or OP wakes only when the crew of a landed helicopter gets out.

Paths are relative to `src/duws/`.

## Behaviour

| Hardpoint | Air ring | Aircraft that count | Speed cap |
|---|---|---|---|
| Standalone `AA` | 5,000 m, no change | any aircraft with WEST crew, AI-flown included | none |
| Standalone `OP`, `MG`, `AT`, `GMG`, `ROADBLOCK`, `RADIO`, `MORTAR`, `ARTY` | 1,500 m, new | a player-crewed aircraft or any UAV | none |
| Standalone `MINEFIELD` | none, no change | — | — |
| Any zone hardpoint | the zone's 1,500 m ring, no change | a player-crewed aircraft or any UAV | under 250 km/h |

No standalone hardpoint has a speed cap, because fast flight must not hide an emplacement. With a cap, a
helicopter at full speed would cross the ring of an MG nest that could hit it while the gun is stowed,
and a player-flown jet could never find a revealed nest crewed.

The types other than `AA` matter less against aircraft, so they get a smaller ring than `AA` and count
only an aircraft with a player aboard, or a UAV. An AI-flown aircraft (High Command, an AI transport with
no player aboard) wakes nothing.

A zone hardpoint wakes with its zone, so it keeps the zone's speed cap. The cap protects the raise of a
full zone garrison, which costs much more than one emplacement.

For `MORTAR` and `ARTY`, the guns and their crews are already resident, so the air ring wakes only the
loose garrison.

`MINEFIELD` gets no air ring. It has no garrison, and its mines matter only to ground units.

The air distance is 3D, as it is for zones, so an aircraft more than 1,500 m above a hardpoint does not
wake it. A hardpoint wakes on the first site pass that sees the aircraft. After that, the 180 s grace and
the hold for an engaged defender apply as they do for a ground wake.

## Design

**An air filter for each occupant.** The occupant field `airFilter` names the aircraft that its air ring
counts:

| `airFilter` | Aircraft that count | Used by |
|---|---|---|
| `all` | any aircraft with WEST crew | `AA` |
| `player` | a player-crewed aircraft or any UAV | the other standalone hardpoints with an air ring |
| `committed` | as `player`, and under `DUWS_zoneAirCommitSpeed` | zones |

`DUWS_hardpointStreaming` gets a fifth column that holds the filter for each type. A zone sets
`committed`, which replaces its `airRingCommitted` flag.

**One filter test.** A new helper, `fnc_site_airPasses`, answers whether an aircraft passes a filter. The
poller builds one aircraft list for each filter with it on each pass, and `fnc_site_bluforOrAir` uses it
at registration. Today `fnc_site_bluforOrAir` counts every WEST aircraft. Without the shared test, an
AI-flown aircraft within 1,500 m at registration would crew the hardpoint, and the hardpoint would stow
again when its grace ends.

**Cost.** Each standalone hardpoint with nobody near it on the ground adds one `findIf` over the `player`
list on each pass. The list is empty unless a player flies or a UAV is up.

## Changes

| File | Change |
|---|---|
| `server/server_var_init.sqf:415-442` | Add the `airFilter` column and its comment line. Set `airRing` 1500 and `player` for `OP`, `MG`, `AT`, `GMG`, `ROADBLOCK`, `RADIO`, `MORTAR` and `ARTY`. `AA` stays at 5000 with `all`, and `MINEFIELD` stays at 0 with `all`. The `airRing` comment names only `AA` now, so it changes too |
| `server/server_var_init.sqf:444-448` | The zone air comment says that `AA` keeps its own air ring. It changes to say that standalone hardpoints keep their own rings in the table above |
| `server/misc/fnc_site_stream_init.sqf:227-236` | Add `fnc_site_airPasses`. Add an `_airFilter` parameter (default `all`) to `fnc_site_bluforOrAir`, which then counts only aircraft that pass the filter |
| `server/misc/fnc_site_stream_init.sqf:279-295` | Build `_westAir`, a new `_westAirPlayer` and `_westAirCommitted` with `fnc_site_airPasses`, and change the comment to name the three filters |
| `server/misc/fnc_site_stream_init.sqf:342` | Choose the list from the occupant's `airFilter`, not from `airRingCommitted` |
| `server/init_zones/fnc_createzone.sqf:168-172` | Set `airFilter` to `committed` in place of `airRingCommitted` true, and change the comment above it |
| `server/init_zones/fnc_hardpoint_stream.sqf:424-436` | Read the fifth column (fallback `[600, 180, false, 0, "all"]`) and set `airFilter` on the occupant |
| `server/init_zones/fnc_hardpoint_stream.sqf:511,521` | Pass the occupant's `airFilter` to `fnc_site_bluforOrAir` |

## Saved state

The change adds no saved state. The air ring and its filter are configuration, and
`fnc_hardpoint_register` reads them on each registration. A load registers each saved hardpoint again
(`server/persistence/fnc_campaign_restore.sqf:347,352`), so a loaded campaign takes the new rings with no
change to the save.

## Reference docs

In the same change as the code, `docs/info/gameplay/hardpoints.md` changes:

- The streaming section (`:225-235`) describes both air rings and their filters, and says that a zone
  hardpoint keeps its zone's speed cap.
- The `AA` note in the type table (`:39`) says that its air ring counts AI-flown aircraft too.
