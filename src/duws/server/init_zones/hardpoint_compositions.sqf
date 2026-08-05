// Locality: server -- hardpoint layout data, read by the hardpoint placer.
//
// Offsets are in a frame whose +Y is the hardpoint's facing. The placer rotates the whole layout
// about the site centre, so a heading turns the cover with the core instead of turning the core
// inside a fixed ring of props.
//
// Each array holds a single sandbag and nothing else: the composition TUI raises its origin and
// facing markers from a fence that already exists, so a layout has to be fenced in source before it
// can be authored in Eden. The sandbag is an ordinary row and goes when the real layout is pasted
// back. Round trip: docs/info/composition_tooling.md.
//
// A global's suffix is the type token carried in hardpoint_type_array, so the placer resolves a
// composition by name rather than through a switch that has to be taught every new type.

// --DUWS-COMPOSITION BEGIN name="Hardpoint: Observation Post" schema=A--
DUWS_hardpointComp_OP = [
    ["Land_BagFence_Short_F", 0, 0, 0, 0, false]
];
// --DUWS-COMPOSITION END--

// --DUWS-COMPOSITION BEGIN name="Hardpoint: Roadblock" schema=A--
DUWS_hardpointComp_ROADBLOCK = [
    ["Land_BagFence_Short_F", 0, 0, 0, 0, false]
];
// --DUWS-COMPOSITION END--

// --DUWS-COMPOSITION BEGIN name="Hardpoint: AA Emplacement" schema=A--
DUWS_hardpointComp_AA = [
    ["Land_BagFence_Short_F", 0, 0, 0, 0, false]
];
// --DUWS-COMPOSITION END--

// --DUWS-COMPOSITION BEGIN name="Hardpoint: AT Emplacement" schema=A--
DUWS_hardpointComp_AT = [
    ["Land_BagFence_Short_F", 0, 0, 0, 0, false]
];
// --DUWS-COMPOSITION END--

// --DUWS-COMPOSITION BEGIN name="Hardpoint: MG Nest" schema=A--
DUWS_hardpointComp_MG = [
    ["Land_BagFence_Short_F", 0, 0, 0, 0, false]
];
// --DUWS-COMPOSITION END--

// --DUWS-COMPOSITION BEGIN name="Hardpoint: Minefield" schema=A--
DUWS_hardpointComp_MINEFIELD = [
    ["Land_BagFence_Short_F", 0, 0, 0, 0, false]
];
// --DUWS-COMPOSITION END--

// --DUWS-COMPOSITION BEGIN name="Hardpoint: Mortar Pit" schema=A--
DUWS_hardpointComp_MORTAR = [
    ["Land_BagFence_Short_F", 0, 0, 0, 0, false]
];
// --DUWS-COMPOSITION END--

// --DUWS-COMPOSITION BEGIN name="Hardpoint: Artillery Battery" schema=A--
DUWS_hardpointComp_ARTY = [
    ["Land_BagFence_Short_F", 0, 0, 0, 0, false]
];
// --DUWS-COMPOSITION END--
