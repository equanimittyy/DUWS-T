# Intel and hardcore mode

Hardcore hides every enemy zone, and every civilian town bar the handful around the HQ, at
campaign start and makes finding them the game. Intel is the mechanism that unhides them. It is
not hardcore-only — what differs between the modes is the pool, not the machinery.

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
| Civilian towns | visible from the start | hidden, bar the HQ anchor's opening three |
| Zone hardpoints | visible from the start | hidden with their parent |
| Normal hardpoints, generated at start | visible from the start | hidden |
| Normal hardpoints, built in play | **hidden** | **hidden** |
| Enemy elements on missions | **hidden** | **hidden** |

So normal mode has a live intel channel answering "what has changed", and hardcore has that plus
everything generation produced, answering "where is the war".

Both of normal mode's payouts are unbuilt today, which is why the body search is gated to
hardcore: building against a pool that is empty in that mode would be building against nothing.

## One writer per reveal flag, one function for payout

Two contracts hold the system together, and both exist so that adding a source cannot quietly
change what intel is worth.

**One writer per flag.** `fnc_zone_reveal` owns the revealed flag in `zone_namePOS_pairs`, whose
entries are `[name, pos, revealed]`; `fnc_civ_town_reveal` owns `civ_visible`, one boolean per
entry of `civ_locations`. Both repaint the markers from the flag rather than beside it, so no
caller can leave the map and the array disagreeing, and both return whether they changed anything
so a caller can tell "revealed something" from "that was already on the map".

Two functions rather than one switched writer, because the two arrays are keyed differently — a
zone by position compared through `str`, since that array carries no index; a town by index — and
their markers follow unrelated naming conventions. The town writer sets its alphas directly
instead of delegating to `fnc_civ_townRender`, which returns early for RAVAGE and WBK: those
campaigns register no town reputation, and their towns still have to be revealable. In the other
direction `fnc_civ_townRender` reads `civ_visible` before it touches the ellipse, so a reputation
change cannot repaint a hidden town back onto the map.

**`fnc_intel_payout` is the single point where intel becomes something.** Every faucet calls it:
the body search, all six side-mission sites, and the civilian menu when it lands. It picks a
*kind* at random from those holding something right now, then lets that kind pick its own member,
and reports that it had nothing left rather than silently awarding nothing.

| Kind | Picks | State |
|---|---|---|
| An unrevealed enemy zone | at random | built |
| An unrevealed civilian town | nearest to where the intel was earned | built; contributes nothing outside hardcore, where no town is hidden |
| An unrevealed normal hardpoint | — | waiting on [`../hardpoint_system_plan.md`](../hardpoint_system_plan.md) |
| An unrevealed enemy patrol | — | waiting on [`../opfor_commander_plan.md`](../opfor_commander_plan.md) |

**Kinds are separate buckets rather than one merged pool, because they are picked on different
rules.** A zone is a target the campaign points the player at, so which one comes next is a
strategic question and random is right — ranked by distance it would march them outward in a
spiral. A town is somewhere the player goes to *do* something, trade or recruit or ask a local,
so one on the far side of the map is worth no more to them than nothing happening, and nearest
wins. One merged pool would force a single rule on both. The consequence to know when tuning: in
hardcore both buckets usually hold stock, so roughly half of all intel goes to towns.

Every bucket draws from the unrevealed set rather than from everything and filtering after the
draw. Drawing from every zone and then testing whether it happened to be hidden — the shape this
replaced — makes the real odds decay as a campaign progresses, because late on most winning rolls
land on ground already found.

**A dry bucket drops out of the draw, not out of the feature.** `_kinds` is rebuilt from what has
stock on every call, so the last zone being found silently turns the coin flip into towns-only and
nothing latches. When every bucket is empty the payout speaks *"Nothing we don't already know"*
itself rather than returning quietly: four of the six side-mission sites hand their result to a
`remoteExec` and never see the return value, so a line spoken at each faucet is a line four of
them cannot say. It goes to the earner where there is one, and from Overlord to everyone where
there is not, because a mission completing is everyone's news.

Only hardpoints can refill a dry pool — they are the one kind OPFOR build during play
([§What is hidden](#what-is-hidden-depends-on-when-it-came-into-existence)). Zones and towns are
generated once, so once found they are found for the campaign, and today that means the pool goes
dry permanently.

The town bucket needs somewhere to measure from, so every faucet passes an origin in. The body
search and the four hold-action sites have a player to ask; the two rescue missions pay out from
a server thread that has none, so they pass the mission site, the ground the rescue was fought
over. A faucet that passes nothing falls back to the HQ. With neither, the bucket sits out the
draw rather than picking at random — one feature quietly running on two different rules is worse
than it paying a zone instead.

`hardcore_visibleZone_found` gates every task-force launch (`fnc_request_squad`,
`fnc_WARCOM_blu_assault`, `fnc_WARCOM_opf_air`). It is derived from reveal state plus OPFOR
ownership and recomputed whole by `fnc_hardcore_visible_recalc`, never nudged: capture moves it
one way and reveal the other, and a delta from either side drifts as soon as they interleave.
Towns are deliberately outside it — it asks whether the player can see an enemy zone to send a
task force at, and a town is not capturable.

## Three sources, three prices

Proximity, the body search and the civilian menu all stay, and they are not redundant: proximity
costs the walk in, the body search costs a firefight, and the menu costs coins and a town's
patience. Three prices for one commodity is the point — a hardcore player out of one currency
still has a route.

| Source | Capped |
|---|---|
| Body search | yes — one attempt per player per economy tick, 20 % |
| Side-mission intel | no, and no roll either: completing the mission is the gate |
| Walking into a zone or town | not applicable; it reveals the ground the player is standing on and rolls nothing |
| Civilian interaction menu | no — limited instead by per-civilian consumption |

**Civilians are the intended primary source and the body search is a trickle.** That is what
makes 20 % a deliberate figure rather than a generous one. Anyone tuning this should raise the
civilian side before touching the body search, or the two stop being different mechanisms and
hardcore turns back into a kill count.

The sources draw from one finite pool, so they compete rather than stack, and the hidden-map
phase ends when the last hidden position is found however that happened. That is the intended arc — but it
means adding a fourth source shortens hardcore rather than enriching it.

Side missions are uncapped *and* unrolled. The old design put a campaign-wide throttle in front
of them, so a mission completed during another source's cooldown paid nothing and said nothing
about why; worse, the roll ran at mission *setup*, deciding whether the intel object existed
before the player had done anything. Four of the six plant a hold action on a specific object
rather than paying on completion, because reaching that object is the mission.

## The throttle is per player, and the attempt is what it spends

One search per player per 30-minute economy tick at 20 %. `econ_tick`
(`server/misc/fnc_zonesundercontrol.sqf`) is the clock, shared with the civilian heal cap and
with the civilian menu's intel row so nothing new is timed.

**Two budgets on one clock, not one budget.** Asking a local carries its own per-player cap
(`DUWS_civ_intel_asked`), cleared by the same tick in the same sweep. They are separate because a
corpse and a living local are different things to find: one flag would mean a body search on the
way into a town silently closed the conversation the player walked there to have. A player who
does both gets two chances per window.

Per player rather than campaign-wide is what makes it work in co-op. The throttle it replaces
was a single global, so the first player to find intel switched it off for everyone and a
four-player squad searched at the same rate as a lone operator. Here a squad genuinely searches
four times as fast.

The attempt is spent on the *attempt*, on the server. A client cannot be trusted to report
having already searched, and a 20 % roll a client makes is a 20 % roll a client can retry. A
failed search pays nothing but a line: what it costs is the thirty minutes before the next one,
and paying out on failure would make that wait the only thing separating a hit from a miss.

**The record and the readout are two different things, because a player does not survive their own
death.** `playerIntelSearchTick` (`server/server_var_init.sqf`) is the record: a server-only map
from player UID to the `econ_tick` the attempt was spent in, and the only thing `fnc_intel_search`
consults before refusing. `DUWS_intel_searched` on the player object, broadcast and cleared on
every player by the tick, is a copy of that record for the search action's condition to read — a
condition string is evaluated on the client several times a second, and broadcasting one boolean
per player is cheaper than broadcasting the clock for clients to subtract. `DUWS_civ_intel_asked`
beside it needs no record because nothing charges it across a death.

The split is what a respawn forces. A respawned player is a new object carrying no flag, so while
the object was the only record, dying refunded the attempt — a cheaper way to buy a search than
waiting out the window. The UID entry outlives the body; `fnc_intel_search_restore` copies it onto
whatever body the player is in now, asked for by `fnc_intel_search_action` at every add, which
covers a client's first boot as well as each respawn. A client that declines to ask gains nothing:
the server refuses on the record either way.

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

**One action per player only holds while dead bodies give theirs up.** An `addAction` is not removed
by its owner dying and the engine goes on evaluating the conditions of actions on any object near a
player, so a corpse left carrying this one polls a seven-clause condition for the rest of the
campaign — one more per death, forever, which is the per-corpse cost the outward-looking shape
exists to avoid. `onPlayerKilled.sqf` strips it from the body using the id stashed at add time. The
spent clause reads `player` rather than the object the action hangs on for the same reason: on a
body from an earlier death those are different units, and testing the corpse's flag would let a
player search past their own spent attempt.

The existing corpse hold action (`fnc_corpse_search_action.sqf`) is untouched. It reveals the
current *mission* target and is a different mechanic that happens to live on the same bodies, so
a mission target's corpse can carry both. That overlap is intended: one is the reward for the
mission, the other is the trickle any body offers.

## Persistence

A hardcore campaign's entire progress is which zones and towns it has revealed, and none of it
survives a restore today. The shape it needs — revealed state as an outcome applied after
build-out, the same as zone ownership — is specified in
[`../campaign_persistence_plan.md`](../campaign_persistence_plan.md#snapshot), which is unbuilt.
