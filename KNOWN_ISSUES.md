# Testables

Playtest checklist. Keep it short. Check a box only once verified in a real
session, not by reading code. Note SP (single-player) vs MP (client on a
dedicated/hosted server) where it matters — a thing can pass on the host and
still be broken for a joining client.

## HQ

- [ ] Side-mission board hands out missions and rewards pay out (SP + MP client)
- [ ] Purchasing (units, supports, FOB) charges correctly and refunds on the same terms (SP + MP client)

## Side missions

- [ ] Every side-mission thread playtested for dialogue and task UX — markers, hints, task states, clean end

  deny_armor, destroy_cache, destroy_hardpoint, destroy_patrol_camp,
  destroy_radar, destroy_tower, informant, protect_civ, recon, rescue_pilot,
  rescue_squad, sabotage_laptop, steal_builder, steal_supply, target_armor,
  target_hvt, target_recon, target_sniper, transport_idap

## Supports

- [ ] Every support fires and completes for a joining MP client, not just the host

  arty, CAS, attack heli, UAV scan, paradrop, vehicle drop, ammo box, helo
  lift, taxi, FOB deploy, recycle station, repair station

## Campaign loop

- [ ] Zone capture registers, marker flips, holds across save/load (SP)
- [ ] Economy: CP/AP income, capture bounty, and support/unit costs stay in balance

## AI opposition

- [ ] Garrison strength + reserves top-up and hardpoint stream behave as intended after a capture

## Multiplayer

- [ ] JIP: client joining mid-campaign sees correct zone state, economy, and owned supports
