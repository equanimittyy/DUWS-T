// Locality: server -- the win, clear and capture tests that ask whether a man is still in the fight.
// A medical mod (ACE, KAT) drops an AI unconscious instead of dead. He looks dead to the player, so a test that reads
// alive alone waits on a body for good. He can wake again; a test that has already passed stands.
alive _this && {lifeState _this != "INCAPACITATED"}
