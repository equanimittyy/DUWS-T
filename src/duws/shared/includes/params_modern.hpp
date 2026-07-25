class Params {

    class Revive {
       title = "$STR_DUWS_T_revivemode";
        values[] = {0,1,2};
        texts[] = {"$STR_DUWS_T_norevive","$STR_DUWS_T_ais", "$STR_DUWS_T_vanillarevive"};
        default = 0;
    };

    // Read by INIT.sqf into duws_log_level before either init script compiles fnc_log_init.
    // No default is repeated on the script side -- fnc_log_init owns it and only applies it
    // when the variable is still nil, so the two cannot drift apart.
    class DUWS_LogLevel {
        title = "RPT log level";
        values[] = {0,1,2,3,4};
        texts[] = {"Off","Errors only","Errors + warnings","Normal","Debug (verbose)"};
        default = 3;
    };

};
