# Intel and hardcore mode

Hardcore hides every enemy zone at campaign start and makes finding them the game. Intel is the
mechanism that unhides them. It is not hardcore-only — what differs between the modes is the
pool, not the machinery.

## What intel is for

**Intel reveals positions the player does not know exist.** Unrevealed zones, hidden hardpoints,
enemy locations somewhere on the general map — strategic discovery, and the answer to "where is
the war". It is not a live feed about ground already found.

That line is load-bearing, because it is what rules mechanics out. Two shipped features were
deleted against it rather than reworked: develop-informant, which drew a 700 m disc over a town
and marked every enemy inside it for one to three hours, and the informant spawner, which handed
intel out on a 30-minute timer the player could not influence. Both functioned. Both were a
tactical readout of ground the player was already standing on, sold as intel.

Something that marks known enemies locally does not compete with the sources below, because it
is not answering the same question — but it does not belong in an intel channel either.

## What is hidden depends on when it came into existence

Not on the difficulty setting. Campaign generation puts its output on the map in normal mode;
anything OPFOR build during play stays hidden in both.

| | Normal | Hardcore |
|---|---|---|
| Zones | visible from the start | hidden |
| Zone hardpoints | visible from the start | hidden with their parent |
| Normal hardpoints, generated at start | visible from the start | hidden |
| Normal hardpoints, built in play | **hidden** | **hidden** |
| Enemy elements on missions | **hidden** | **hidden** |

So normal mode has a live intel channel answering "what has changed", and hardcore has that plus
everything generation produced, answering "where is the war".

Both of normal mode's payouts are unbuilt today, which is why the body search is gated to
hardcore: building against a pool that is empty in that mode would be building against nothing.

## One writer for reveal, one function for payout

Two contracts hold the system together, and both exist so that adding a source cannot quietly
change what intel is worth.

**`fnc_zone_reveal` is the sole writer of the revealed flag** in `zone_namePOS_pairs`, whose
entries are `[name, pos, revealed]`. It repaints the markers from that flag rather than beside
it, so no caller can leave the map and the array disagreeing, and it returns whether it changed
anything so a caller can tell "revealed a zone" from "that was already on the map". Position is
the key, compared through `str`, because the array carries no index.

**`fnc_intel_payout` is the single point where intel becomes something.** Every faucet calls it:
the body search, all six side-mission sites, and the civilian menu when it lands. It draws at
random from the kinds that have something to give *right now* rather than from a fixed list, so
a kind with an empty pool never enters the draw and a fully-uncovered campaign reports that
instead of silently awarding nothing.

| Kind | State |
|---|---|
| An unrevealed enemy zone | built |
| An unrevealed normal hardpoint | waiting on [`../hardpoint_system_plan.md`](../hardpoint_system_plan.md) |
| An unrevealed enemy patrol | waiting on [`../opfor_commander_plan.md`](../opfor_commander_plan.md) |

The zone draw takes from the unrevealed set only. Drawing from every zone and then testing
whether it happened to be hidden — the shape this replaced — makes the real odds decay as a
campaign progresses, because late on most winning rolls land on ground already found.

`hardcore_visibleZone_found` gates every task-force launch (`fnc_request_squad`,
`fnc_WARCOM_blu_assault`, `fnc_WARCOM_opf_air`). It is derived from reveal state plus OPFOR
ownership and recomputed whole by `fnc_hardcore_visible_recalc`, never nudged: capture moves it
one way and reveal the other, and a delta from either side drifts as soon as they interleave.

## Three sources, three prices

Proximity, the body search and the civilian menu all stay, and they are not redundant: proximity
costs the walk in, the body search costs a firefight, and the menu costs coins and a town's
patience. Three prices for one commodity is the point — a hardcore player out of one currency
still has a route.

| Source | Capped |
|---|---|
| Body search | yes — one attempt per player per economy tick, 10 % |
| Side-mission intel | no, and no roll either: completing the mission is the gate |
| Walking into a zone | not applicable; it reveals the zone the player is standing in and rolls nothing |
| Civilian interaction menu | no — limited instead by per-civilian consumption |

**Civilians are the intended primary source and the body search is a trickle.** That is what
makes 10 % a deliberate figure rather than a stingy one. Anyone tuning this should raise the
civilian side before touching the body search, or the two stop being different mechanisms and
hardcore turns back into a kill count.

The sources draw from one finite pool, so they compete rather than stack, and the hidden-map
phase ends when the last zone is found however that happened. That is the intended arc — but it
means adding a fourth source shortens hardcore rather than enriching it.

Side missions are uncapped *and* unrolled. The old design put a campaign-wide throttle in front
of them, so a mission completed during another source's cooldown paid nothing and said nothing
about why; worse, the roll ran at mission *setup*, deciding whether the intel object existed
before the player had done anything. Four of the six plant a hold action on a specific object
rather than paying on completion, because reaching that object is the mission.

## The throttle is per player, and the attempt is what it spends

One search per player per 30-minute economy tick at 10 %. `econ_tick`
(`server/misc/fnc_zonesundercontrol.sqf`) is the clock, shared with the civilian heal cap so
nothing new is timed.

Per player rather than campaign-wide is what makes it work in co-op. The throttle it replaces
was a single global, so the first player to find intel switched it off for everyone and a
four-player squad searched at the same rate as a lone operator. Here a squad genuinely searches
four times as fast.

The attempt is spent on the *attempt*, on the server. A client cannot be trusted to report
having already searched, and a 10 % roll a client makes is a 10 % roll a client can retry. A
failed search pays nothing but a line: what it costs is the thirty minutes before the next one,
and paying out on failure would make that wait the only thing separating a hit from a miss.

`DUWS_intel_searched` lives on the player object, broadcast, and is cleared on every player by
the tick. It goes there rather than in a server-side table keyed by UID because the action's own
condition reads it, and a condition string is evaluated on the client several times a second.
Broadcasting one boolean per player is cheaper than broadcasting the clock for clients to
subtract.

## The body search looks outward, so it scales with players not corpses

One action on the player, watching `cursorObject`, rather than one action per corpse. The
per-corpse shape needs a `remoteExec` with the JIP flag per death and nothing ever removes those
entries, so the queue would grow with the campaign's kill count instead of its player count —
tolerable for the handful of mission patrols `fnc_add_intel_on_death` runs on today, unbounded
at the scale of every kill.

The condition's clause order is load-bearing and is documented where it lives
(`client/misc/fnc_intel_search_action.sqf`). The reason it matters at all is that an action on
the player is evaluated far more often than one on a distant object: the player is never out of
range of themselves.

The existing corpse hold action (`fnc_corpse_search_action.sqf`) is untouched. It reveals the
current *mission* target and is a different mechanic that happens to live on the same bodies, so
a mission target's corpse can carry both. That overlap is intended: one is the reward for the
mission, the other is the trickle any body offers.

## Persistence

A hardcore campaign's entire progress is which zones it has revealed, and none of it survives a
restore today. The shape it needs — revealed state as an outcome applied after build-out, the
same as zone ownership — is specified in
[`../campaign_persistence_plan.md`](../campaign_persistence_plan.md#snapshot), which is unbuilt.
