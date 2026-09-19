/*
    Debug menu row colours, one meaning each, so a row shows what choosing it does before it is chosen.
    A page row also ends " >", a map-pick row "(click map)" and a toggle "[on]" or "[off]".
*/
#define DBG_PAGE    [1, 1, 1, 1]
#define DBG_ACTION  [1, 0.667, 0, 1]
#define DBG_MAP     [0, 1, 1, 1]
#define DBG_ON      [0.082, 1, 0, 1]
#define DBG_OFF     [0.6, 0.6, 0.6, 1]
#define DBG_DANGER  [1, 0.4, 0.4, 1]

#define DBG_BACK(TO) ["< Back", fnc_debug_menu, TO, DBG_PAGE]
