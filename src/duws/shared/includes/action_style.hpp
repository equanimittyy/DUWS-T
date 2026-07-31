/*
    Action-menu title styling. One macro per bucket; each wraps a stringtable
    key, so call sites pass a key and never write markup themselves.

    Colour lives here rather than in stringtable.xml because a value carrying
    its own <t> markup freezes that markup into every translation: the language
    variants drift apart (one shipped coloured in German and plain in English),
    and fnc_open_action_menu has to strip the tags back out again before a
    listbox row can render them. Keys stay plain text; the bucket decides
    how the entry looks.

    #include resolves relative to the including file, so the path varies with
    directory depth -- "duws\shared\includes\action_style.hpp" from the mission
    root, "..\..\shared\includes\action_style.hpp" from duws\client\misc.
*/

// Command entries: direct your forces or your base. Caps is a property of the
// bucket, not of the string, so a key that leaves this bucket stops being
// capitalised without a stringtable edit.
#define ACT_PRIMARY_MENU(S)         ("<t color='#15ff00'>" + toUpper (localize S) + "</t>")

// Services and situational menus: the command hue one tier down, so rank reads
// without a second colour to learn.
#define ACT_SECONDARY_MENU(S)       ("<t color='#0d9900'>" + localize S + "</t>")

#define ACT_EQUIP(S)                ("<t color='#ff8000'>" + localize S + "</t>")
#define ACT_COMMIT(S)               ("<t color='#ff1111'>" + localize S + "</t>")

// Ambient family: navigational, informational and social entries share one blue
// against the loud consequence colours above. Kept as four names rather than
// one because the priority bands key off the bucket, and splitting any single
// blue back out later is then a one-line edit here.
#define ACT_MOVE(S)                 ("<t color='#00b7ff'>" + localize S + "</t>")
#define ACT_AID(S)                  ("<t color='#00b7ff'>" + localize S + "</t>")
#define ACT_CIVILIAN_INTERACTION(S) ("<t color='#00b7ff'>" + localize S + "</t>")
#define ACT_UTIL(S)                 ("<t color='#00b7ff'>" + localize S + "</t>")

// The rescue-pilot set and the hold-to-search entries take no macro and stay
// plain; the searches are already identified by their hold icon.

// Row forms of the buckets above, for a menu that lists what used to be scroll
// entries. A listbox renders <t> markup literally, so a row takes an [r,g,b,a]
// float array instead of the tags. The four blues become one row colour: only
// the scroll priority they keyed ever differed between them.
#define ACT_ROW_PRIMARY_MENU        [0.082, 1, 0, 1]
#define ACT_ROW_SECONDARY_MENU      [0.051, 0.6, 0, 1]
#define ACT_ROW_EQUIP               [1, 0.502, 0, 1]
#define ACT_ROW_AMBIENT             [0, 0.718, 1, 1]
#define ACT_ROW_COMMIT              [1, 0.067, 0.067, 1]
