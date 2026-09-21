class Params {

    class Revive {
       title = "$STR_DUWS_T_revivemode";
        values[] = {0,1,2};
        texts[] = {"$STR_DUWS_T_norevive","$STR_DUWS_T_ais", "$STR_DUWS_T_vanillarevive"};
        default = 0;
    };

    // Stamina/fatigue for the player and the AI they field -- recruits, requested units and
    // paradrops read player_fatigue at spawn. On (default) keeps the engine's drain; Off disables it
    // for all of them. Read into player_fatigue in client_init and onPlayerRespawn.
    class DUWS_Fatigue {
        title = "Fatigue";
        values[] = {0,1};
        texts[] = {"Off","On"};
        default = 1;
    };

    // Snap the player back to first person whenever they pop to third. Camera is client-local,
    // so this is enforced per-client in client_init. Mode 2 leaves third person alone while
    // mounted, matching the engine's vehicles-only difficulty option.
    class DUWS_RestrictFirstPerson {
        title = "Restrict to 1P";
        values[] = {0,1,2};
        texts[] = {"Off","On (all views)","On (vehicle 3P allowed)"};
        default = 0;
    };

    // Hybrid keeps the player's own faction unlimited but count-tracks captured foreign gear against
    // the banked pool; Full restores the legacy everything-unlimited arsenal. Read on the machine that
    // opens the arsenal (client/arsenal/fnc_duws_Arsenal.sqf), so every opener reads the same value.
    class DUWS_ArsenalMode {
        title = "Arsenal";
        values[] = {0,1,2};
        texts[] = {"Hybrid (captured gear tracked)","Full (everything unlimited)","Limited (all gear tracked)"};
        default = 0;
    };

    // Off (default) leaves magazines unlimited in every mode: ammo is never pooled, and a captured
    // enemy weapon gets its ammo free on the shelf. On folds magazines into whatever the mode tracks
    // (Hybrid pools foreign ammo, Limited pools all of it) -- for scarcity scenarios like zombie mode.
    class DUWS_TrackAmmo {
        title = "Track Ammo";
        values[] = {0,1};
        texts[] = {"Off (ammo unlimited)","On (ammo tracked)"};
        default = 0;
    };

    // Gates the Rest/Heal weather box: Off replaces it with a notice and skips the weather change on
    // rest (read in fnc_rest_menu.sqf, enforced in fnc_rest_heal.sqf). Rest and time-skip still work.
    class DUWS_RestWeather {
        title = "Rest Weather Config";
        values[] = {0,1};
        texts[] = {"Off","On"};
        default = 1;
    };

    // Which endings fire: 0 both, 1 the officer's death only, 2 escalation only, 3 neither. Read
    // where each one fires -- fnc_BluHQinit.sqf, and fnc_escalation_report for the razed island.
    class DUWS_LoseConditions {
        title = "Campaign Lose Conditions";
        values[] = {0,1,2,3};
        texts[] = {"Full","Officer Death Only","Escalation Only","Off"};
        default = 0;
    };

    // How long litter survives before the map sweep deletes it -- one lifetime for bodies,
    // wrecks, abandoned vehicles, dropped weapons, smoke, crates and parachutes alike. The sweep
    // is always on: teardowns hand it their live leftovers, so there is no off. A longer lifetime
    // trades framerate for tidiness. Anything tagged persistent ignores this, so the HQ and
    // side-mission objectives are not affected by shortening it.
    class DUWS_CleanupLifetime {
        title = "Default Garbage Lifetime";
        values[] = {300,600,900,1200,1500,1800};
        texts[] = {"5 minutes","10 minutes","15 minutes","20 minutes","25 minutes","30 minutes"};
        default = 300;
    };

    // Toggles map group icons (setGroupIconsVisible). Friendly groups always show; enemy groups show
    // only where BLUFOR has intel (knowsAbout), so it tracks live detections rather than revealing the
    // whole map. Off by default. Icon visibility is per-machine display state, so each client applies it
    // in client_init (INIT and the server inits repeat it for the host); a dedicated server has no map.
    class DUWS_GroupIcons {
        title = "Map Group Icons";
        values[] = {0,1};
        texts[] = {"Off","On"};
        default = 0;
    };

    // Which native bandit factions dress bandits: a player who does not own a DLC gets its purchase
    // prompt from its content, so the host withholds what the session's players lack. Read once on
    // the server by fnc_bandit_looks.
    class DUWS_Bandits {
        title = "Bandits";
        values[] = {0,1,2,3};
        texts[] = {"Full","No DLC","No Apex DLC","No Contact DLC"};
        default = 0;
    };

    // Inert separator: a value-less row the engine renders but never reads, splitting the
    // gameplay options above from the developer options below.
    class DUWS_Divider_Dev {
        title = "--------- Developer ---------";
        values[] = {0};
        texts[] = {""};
        default = 0;
    };

    // Whether the developer menu exists at all, not who may open it: a parameter is mission
    // config, so every machine in a session reads the same value. client_init.sqf gates the
    // menu on game_master as well, or this would hand it to every client on the server.
    class DUWS_Debug {
        title = "Debug";
        values[] = {0,1};
        texts[] = {"Disabled","Enabled"};
        default = 0;
    };

    // Read by INIT.sqf into duws_log_level before either init script compiles fnc_log_init.
    // No default is repeated on the script side -- fnc_log_init owns it and only applies it
    // when the variable is still nil, so the two cannot drift apart.
    class DUWS_LogLevel {
        title = "Logging Level";
        values[] = {0,1,2,3,4};
        texts[] = {"Off","Errors only","Errors + warnings","Normal","Debug (verbose)"};
        default = 3;
    };

};
