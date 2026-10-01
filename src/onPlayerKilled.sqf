
// Actions outlive their owner. Left on the body, each one still shows to the respawned player
// (the conditions test the viewer, not the body) and is polled for the rest of the campaign.
// onPlayerRespawn adds fresh ones to the new body.
removeAllActions player;

DUWS_deathLoadout = getUnitLoadout player;
player setVariable["Saved_Face", face player];
player setVariable["Saved_Speaker", speaker player];
