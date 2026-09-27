# Intel and hardcore mode

Hardcore hides every enemy zone, and every civilian town bar the handful around the HQ, at campaign start
and makes finding them the game. Intel is the mechanism that unhides them. It is not hardcore-only — what
differs between the modes is the pool, not the machinery.

## What intel is for

**Intel reveals positions the player does not know exist.** Unrevealed zones, hidden hardpoints, enemy
locations somewhere on the general map — strategic discovery, and the answer to "where is the war". It is
not a live feed about ground already found.

That line is load-bearing, because it is what rules mechanics out. Two shipped features were deleted
against it rather than reworked: develop-informant, which drew a 700 m disc over a town and marked every
enemy inside it for one to three hours, and the informant spawner, which handed intel out on a 30-minute
timer the player could not influence. Both functioned. Both were a tactical readout of ground the player
was already standing on, sold as intel. Something that marks known enemies locally does not compete with
the sources below, because it is not answering the same question — but it does not belong in an intel
channel either.

## What is hidden depends on when it came into existence

Not on the difficulty setting. Campaign generation puts its output on the map in normal mode; anything
OPFOR build during play stays hidden in both.

| | Normal | Hardcore |
|---|---|---|
| Zones | visible from the start | hidden |
| Civilian towns | visible from the start | hidden, bar the HQ anchor's opening three |
| Zone hardpoints | visible from the start | hidden with their parent |
| Normal hardpoints, generated at start | visible from the start | hidden |
| Normal hardpoints, built in play | **hidden** | **hidden** |
| Enemy elements on missions | **hidden** | **hidden** |
| OPCOM units under orders | **hidden** | **hidden** |

So normal mode has a live intel channel answering "what has changed", and hardcore has that plus
everything generation produced, answering "where is the war". Normal mode's channel is the two kinds
OPFOR produce during play — a hardpoint it builds, and a unit it puts under orders — so outside
hardcore the pool holds only what the enemy is doing right now.

**The mode changes what is hidden and nothing else.** Every mechanic runs the same in both — same flag
rates, same action, same payout table, same substitute when intel comes up dry. Only how often each branch
is reached differs, because that follows from what generation put on the map. The search used to be gated
on `hardcore_mode_enable` to sidestep the empty pool, which cost normal mode a whole faucet to avoid a case
one branch handles.

## One writer per reveal flag, one function for payout

Two contracts hold the system together, and both exist so that adding a source cannot quietly change what
intel is worth.

**One writer per flag.** `fnc_zone_reveal` owns the revealed flag in `zone_namePOS_pairs`, whose entries
are `[name, pos, revealed]`; `fnc_civ_town_reveal` owns `civ_visible`, one boolean per entry of
`civ_locations`. Both repaint the markers from the flag rather than beside it, so no caller can leave the
map and the array disagreeing, and both return whether they changed anything so a caller can tell
"revealed something" from "that was already on the map".

The writers also make the announcement, so every source reports a reveal the same way. It goes to every
player, because the position lands on every player's map. Contacts are the exception: a payout plots a
batch of them at once, so their line is spoken by the payout rather than by the writer.

| Kind | Announcement |
|---|---|
| Zone | a *Zone Discovered* card, and an Overlord line naming the zone and the nearest settlement (`fnc_place_name`) |
| Town | a *Town Discovered* card naming the town |
| Hardpoint | an Allseer line on SUB-NET naming the type and the nearest zone or town ([`hardpoints.md`](hardpoints.md#reveal)) |
| Contact | an Allseer line, one for the whole batch, that names no place and no count |

`fnc_zone_reveal` and `fnc_hardpoint_reveal` also take a `_quiet` flag that hands the reporting to the
caller: the recon mission marks its target under its own confirm line rather than beneath a second
announcement.

Two functions rather than one switched writer, because the two arrays are keyed differently — a zone by
position compared through `str`, since that array carries no index; a town by index — and their markers
follow unrelated naming conventions. The town writer sets its alphas directly instead of delegating to
`fnc_civ_townRender`, which returns early for RAVAGE and WBK: those campaigns register no town reputation,
and their towns still have to be revealable. In the other direction `fnc_civ_townRender` reads
`civ_visible` before it touches the ellipse, so a reputation change cannot repaint a hidden town back onto
the map.

**`fnc_intel_payout` is the single point where intel becomes something.** Every faucet calls it: the body
search, all six side-mission sites, the civilian menu when it lands, and the Intelligence Center's clock.

**A payout has two halves and pays both.** The pool half reveals one hidden position; the contact half
plots a random share of the eligible OPCOM units where they are marching. They answer different questions — *where is
the war*, and *what is the enemy doing right now* — so making them compete for a single draw only ever
starved whichever mattered more that hour. Either half can come up empty; the payout reports having nothing
only when both do.

**A source can be scoped to its own ground.** `_radius` limits both halves to what lies within reach of
where the intel was earned. Zero is the whole map, and every faucet but the civilian menu passes zero. The
menu passes twice the town's area of influence, measured from the town rather than from the asking player:
a local knows the checkpoint down the road, not a zone on the far side of Altis. Twice the influence rather
than the influence itself, because the town's own ground is the part the player can already see. Unscoped
it was the cheapest source in the mission — one guaranteed reveal per player per economy tick, which beat
the Intelligence Center's second rung for free.

The pool half picks a *kind* at random from the buckets holding something, then lets that kind pick its
own member.

| Kind | Picks | State |
|---|---|---|
| An unrevealed enemy zone | at random | built |
| An unrevealed civilian town | nearest to where the intel was earned | built; contributes nothing outside hardcore, where no town is hidden |
| An unrevealed hardpoint | at random from the eligible set | built ([`hardpoints.md`](hardpoints.md#reveal)) |

**Kinds are separate buckets rather than one merged pool, because they are picked on different rules.** A
zone is a target the campaign points the player at, so which one comes next is a strategic question and
random is right — ranked by distance it would march them outward in a spiral. A town is somewhere the
player goes to *do* something, so one on the far side of the map is worth no more to them than nothing
happening, and nearest wins. One merged pool would force a single rule on both. The consequence to know
when tuning: in hardcore both buckets usually hold stock, so roughly half of the pool half goes to towns.

Every bucket draws from the unrevealed set rather than from everything and filtering after the draw.
Drawing from every zone and then testing whether it happened to be hidden — the shape this replaced —
makes the real odds decay as a campaign progresses, because late on most winning rolls land on ground
already found.

**A dry bucket drops out of the draw, not out of the feature.** `_kinds` is rebuilt from what has stock on
every call, so the last zone being found silently turns the coin flip into towns-only and nothing latches.
When both halves come up empty the payout speaks *"Nothing we don't already know"* itself rather than
returning quietly: four of the six side-mission sites hand their result to a `remoteExec` and never see the
return value, so a line spoken at each faucet is a line four of them cannot say. It is a searcher's report of
their own search, so it goes to the earner alone, and a faucet with no earner behind it stays quiet.

Hardpoints and contacts are what OPFOR keep producing during play
([§What is hidden](#what-is-hidden-depends-on-when-it-came-into-existence)). Zones and towns are generated
once, so once found they are found for the campaign, and a fully mapped campaign pays the pool half nothing
for the rest of its run — the contact half still has the enemy's movements to report.

The town bucket needs somewhere to measure from, so every faucet passes an origin in. The body search and
the four hold-action sites have a player to ask; the two rescue missions pay out from a server thread that
has none, so they pass the mission site, the ground the rescue was fought over. A faucet that passes nothing
falls back to the HQ. With neither, the bucket sits out the draw rather than picking at random — one feature
quietly running on two different rules is worse than it paying a zone instead.

## Four sources, four prices

Proximity, the body search, the civilian menu and the Intelligence Center are not redundant: proximity costs
the walk in, the body search costs a firefight, the menu costs coins, a town's patience and reaches only
that town's own district, and the center
costs CP and AP once and then pays on a clock. Four prices for one commodity is the point — a hardcore
player out of one currency still has a route.

| Source | Capped |
|---|---|
| Body search | by the flagged materiel on the ground, not by a clock — a third of any combat group, zone garrison and side-mission patrol alike |
| Side-mission objective | flagged with certainty; reaching the object is the gate |
| Walking into a zone or town | not applicable; it reveals the ground the player is standing on and rolls nothing |
| Civilian frisk | flagged with certainty; the arrest is the price, and its payout table carries the odds |
| Intelligence Center | by the odds its levels buy — one roll per OPCOM tick ([§The Intelligence Center](#the-intelligence-center)) |

**A third of a combat group is searchable, so a fight is a reliable route to intel rather than a lottery.**
A much lower rate read in play as a broken action: a player who cleared a position and found no prompt on
any body had no way to tell a cold roll from a feature that never worked. What keeps the search from
collapsing into a kill count is its payout table, where intel is one kind of four, not its flag rate — so
a combat group pays *something* most of the time and pays intel far less often than that.

The sources draw from one pool, so they compete rather than stack, and the hidden-map phase ends when the
last hidden position is found however that happened. A fourth source therefore shortens that phase rather
than enriching it, and the Intelligence Center is that fourth source knowingly: it is paid for, it is the
only source that pays while the player does nothing else, and a faster route through the hidden map is
exactly what the purchase buys. What keeps it from being only that is the contact bucket, which refills — a
center standing over a mapped campaign still has the enemy's movements to report.

Side missions are uncapped *and* unrolled. The old design put a campaign-wide throttle in front of them, so a
mission completed during another source's cooldown paid nothing and said nothing about why; worse, the roll
ran at mission *setup*, deciding whether the intel object existed before the player had done anything. Four
of the six plant a hold action on a specific object rather than paying on completion, because reaching that
object is the mission.

## The success roll is spent at spawn, so the price is the fight

An entity that can be searched is decided when it is created, not when it is searched
(`server/search/fnc_search_flag_group.sqf`). What the player can find is then a function of how much OPFOR the
campaign put on the ground, rather than of how often a key was pressed, and the price of a search is the
fight that produced the thing being searched.

**That is what let the clock go.** The body search used to carry a second price, one attempt per player per
30-minute economy tick, and with it a UID-keyed record, a broadcast copy on the player object and a restore
routine to reconcile the two across a respawn — a whole apparatus existing only to make a timer survive
dying. A flag lives on the body and dies with it, so none of it is needed. `DUWS_civ_intel_asked` still rides
`econ_tick`, because asking a *local* is capped against a finite population rather than against a clock.

Only the flagged share carries any state, rather than every corpse the campaign produces. Flags are broadcast,
because the action's condition is evaluated on the client that would draw it and an unflagged thing offers no
action at all.

**A zone rebuilding its garrison re-rolls, and that is allowed.** A player can leave, wait out the despawn,
return and search a fresh garrison — but the cycle is not a button press, it is walking out and defeating a
full garrison again. The pool is finite, so farming buys a faster route through the hidden-map phase and
nothing after it, and the cost scales with the reward because the garrison that must be beaten is the same
garrison whose size sets how many flags are in it.

## What a search pays is a weighted table per source

Stage two is a draw over `DUWS_searchSources` (`server/server_var_init.sqf`), each row naming a payout kind
and its weight. Weights rather than a cumulative `if` ladder: every band in a ladder depends on the one above
it, so adding a kind means re-deriving each constant below it.

Kinds are drawn **without replacement**. `fnc_intel_payout` is the only kind that can decline — it returns
false once every position is revealed — and when it does, that kind drops out and the remainder are re-drawn.
A dry pool therefore costs a search its best outcome rather than its voice, which is the failure this mission
already paid for once when a dry pool returned quietly.

**When intel is exhausted, the search pays a flat 2 CP in its place.** Reachable only where intel was the last
kind standing — an intel-only source such as a mission objective, which hardcore reaches once the map has been
found and normal mode reaches on every such search. Reaching the objective still pays, so a reveal pool going
dry costs the search its best outcome rather than its whole worth.

`fnc_search_claim` silences the payout's dry answer, so the flat consolation above answers a decline
without contradiction.

`nothing` is a row rather than the absence of one, and a weight of zero is how a source opts out of a kind.
The empty-handed line is per-source too, because a body that held nothing and a detainee who was carrying
nothing are different sentences.

**Every outcome except a reveal is spoken in the searcher's voice, to the searcher alone.** A frisk spoke in the team's
callsign until the two shapes were reconciled; the player did the searching either way, and one voice per
faucet was the thing this system was collapsed to remove. It is hinted as well as spoken: the dialogue queue
holds a line behind whatever traffic is already in it, and a result the player held an action for should not
arrive late or scroll past unread. The audience is the searcher rather than everyone because a body emptied
in co-op is not news the other three players asked for.

**What the team sees instead is an announcement, and only for the two kinds that move shared state.** A
revealed position lands on every player's map and a pool payout lands on every player's CP total, so the
team is told those happened even though the search that bought them is reported locally. A reveal is
announced by its writer ([§One writer per reveal flag](#one-writer-per-reveal-flag-one-function-for-payout)),
not by the search. Money, a document and an empty pocket move nothing anyone else can see and stay with the
searcher. This is the one split the system draws: *voice and hint are local, the announcement is global*,
and the notification prose is written
for a reader who did not do the searching — hence *"The pool gains 2 CP"* rather than *"you gained"*.

**Money and a document go straight into the searcher's inventory, or at their feet if the find does not
fit whole.** All or nothing, because a payout split between pack and ground needs one hint to name two
places. The grant runs on the searcher's machine (`client/misc/fnc_loot_grant.sqf`), because an inventory
add works only where the unit is local; the server decides only what was found. It is the arsenal's own
regrant underneath (`DUWS_fnc_money_regrant`, `initPlayerLocal.sqf`), which holds the all-or-nothing rule
for every path that hands a player money. The civilian side missions pay through the same function
([`economy.md`](economy.md#faucets)).

**Both rolls run on the server, and so does everything they read.** A roll a client makes is a roll a client
can retry. Server authority over the roll alone is not enough: the reveal payout was once handed a target
position sampled on the client, from a global only the server ever wrote, so it silently paid nothing on a
dedicated server while working perfectly on a listen host. The claim is taken before the payout resolves,
because the intel branch speaks across a sleep.

## One action on the player, not one per searchable thing

One hold action watching `cursorObject`, rather than an action attached to each thing that can be searched. A
per-corpse action needs a `remoteExec` with the JIP flag per death, so it costs one queue entry and one action
for every body the campaign produces rather than one of each per player.

The flag is what let the type test go with it. The condition no longer asks whether the thing under the cursor
is a body: it asks whether it carries a search source and has not already been claimed, which covers bodies
and the objects a mission places deliberately — a laptop, a piece of armour — through one condition. Those
objects had an action apiece before, each with `removeOnCompletion` set, and that removal is local: it hid the
entry from the searcher and left it standing for everyone else, so in co-op one objective paid once per player.

Living men are the one exclusion the flag cannot express, since a garrison is flagged when it spawns. That
clause is scoped to men rather than gating the whole action, because a laptop is never dead and an intact
vehicle is still worth opening. The condition's clause order is load-bearing and is documented where it lives
(`client/search/fnc_intel_search_action.sqf`); it matters at all because an action on the player is evaluated far
more often than one on a distant object — the player is never out of range of themselves.

**The action survives its owner's death, so it has to be stripped.** An `addAction` is not removed by its owner
dying and the engine goes on evaluating the conditions of actions on any object near a player, so a corpse left
carrying this one polls the whole condition for the rest of the campaign — one more per death, forever, which
is the per-object cost this shape exists to avoid. `onPlayerKilled.sqf` strips every action from the body.

## A contact is a snapshot

An OPCOM unit is a virtual record (`DUWS_opcom_taskings`), a hashMap that marches a route every OPCOM tick
and only becomes real men when a player comes near. A contact is what intel makes of one: one global marker
on the position that record held at the moment the intel landed, and nothing after that.

`server/search/fnc_intel_contact_init.sqf` draws it. The marker is a half-size arrow (`mil_arrow_noShadow`) on the
unit's position, rotated to its heading with `setMarkerDir` — the leg it is walking now, or the target once
the route is spent, because a route bends around terrain and its last point is not where the unit is headed
next. A streamed unit plots at its group leader and heads for the group's current waypoint instead, because
its record's leg stops advancing once the group walks its own waypoints.

**The arrow is the whole contact: where it was, and which way it was going.** A type icon and an order label
stood on it before, and both answer what the enemy *is doing* — a live readout of a unit the player has not
found, which is what [§What intel is for](#what-intel-is-for) rules out. A fix reports a sighting, so two of
the three facts were the wrong kind. A tasking with nowhere left to go therefore plots nothing rather than an
arrow pointing at random.

**The marker never moves, and that is the feature.** A tracker would cost one marker update per contact per
tick for the whole team. So the contact ages: the unit marches on, and what the player holds is a last known
position. The arrow starts fully opaque and fades out over `DUWS_intel_contact_life` (600 s), then the
marker is deleted. One thread per contact holds only the tasking id and the marker name. The fade goes in 20
steps rather than smoothly, because each `setMarkerAlpha` on a global marker is a network broadcast.

Every tasking whose order is not `guard` or `garrison` is eligible, virtual or streamed. A garrison is not
eligible: it is the content of a zone, and the zone reveal is what puts that on the map.

**A unit that is already plotted is plotted again.** The payout deletes its old marker and draws a fresh one
at the unit's current position, and the fade starts again. `DUWS_intel_contacts` maps each tasking id to the
marker that plots it now. Each plot takes a new marker name, so the thread of a replaced marker sees that it
no longer owns the unit and stops.

**One payout plots a random share of the eligible units, from 20% to all of them, rounded up.** The share
is drawn again for each payout, and the units in it are picked at random. The floor matters because an older
draw started at zero: two identical payouts could then be worth anything from nothing to the whole picture,
which read as an unreliable source rather than as a quiet sector. A unit that plots nothing does not use up a
place in the share. The batch is announced once rather than per contact: eight Allseer lines queued behind
each other would still be arriving minutes later.

**The half is gated on the player knowing where at least one OPFOR-held zone is.** A march plotted across
ground whose owner they have never found names nothing, and in hardcore that blank map is the opening the
first zone is there to end — intel that jumped straight to enemy movements would answer a question the
player has not yet earned the right to ask. The gate reads the revealed flag in `zone_namePOS_pairs`
against `WARCOM_zones_controled_by_OPFOR`, so a zone the player has taken does not hold it open.

## The Intelligence Center

Four permanent support levels, `intel1` to `intel4`, gated in order like the radio towers and the vehicle
garage, on the AP tier ladder at 2/3/4/5. Each level is bought once for the team and never refunds.

`fnc_support_perm_grant` recomputes `DUWS_intelLevel` from `DUWS_support_permanent` on every unlock, rather
than incrementing a counter — gated buying means the count equals the level, so it cannot drift, and a
restored record restores the level with it. That is the same shape `DUWS_bluforRadioLevel` uses.

**The OPCOM tick rolls it**, as a stage of `fnc_opcom_perception_run` after the task-force upkeep:
`DUWS_intel_roll_by_level` indexed by `DUWS_intelLevel` against `random 1`, every `OPCOM_TICK_PERIOD`. It rides that
loop rather than the economy tick because the contacts it plots are read off that loop's own tasking store,
so the intel is sampled on the clock that moved the units. Last in the tick for the same reason the task
forces are: a fault there costs OPCOM's own stages nothing, and the loop's per-tick `catch` names the stage.

The roll is per five seconds, so the table's figures are small and the mean wait is what to tune by — 60,
30, 16 and 10 minutes at levels I to IV. It is a table rather than one rate multiplied by the level,
because that curve bought 4x the find rate for 8x the cumulative price: every level after the first was
worse value than the one below it, and the top two were never worth buying. The table's rate climbs with
what the levels cost, so the ladder reads as an investment rather than a tax.

A winning roll calls `fnc_intel_payout` with no origin and no earner, which is to say it pays both halves
on the same terms every other source gets: one hidden position, and whatever OPCOM has moving. The center is a faucet, never a
channel of its own — giving it private payouts is how "one place decides what intel is worth" stops being
true.

It rolls silently on a dry pool. A support that rolls every five seconds for hours cannot answer
*"Nothing we don't already know"* each time; a player who searched a body asked the question and is owed
the answer.

## Persistence

A hardcore campaign's entire progress is which zones and towns it has revealed, so the campaign snapshot
stores the revealed zones by position and the revealed towns by index, and applies both after build-out, the
same as zone ownership ([`../campaign_persistence_plan.md`](../../plans/campaign_persistence_plan.md#the-team)).
A hardpoint's reveal rides its own registry row and comes back with it.
