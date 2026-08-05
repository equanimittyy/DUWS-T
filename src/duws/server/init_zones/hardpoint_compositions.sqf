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
DUWS_hardpointComp_OP = [    ["Land_BagBunker_Tower_F", -0.0583496, 2.79736, 2.21122, 90.9814, false],
    ["CamoNet_BLUFOR_open_F", -0.303467, -3.64307, 1.16904, 0, false],
    ["Land_HBarrier_5_F", -5.42334, -2.78857, 0.74171, 86.7635, false],
    ["Land_HBarrier_5_F", 3.84778, -3.11963, 0.74171, 86.7635, false],
    ["Land_HBarrier_5_F", -3.04358, -6.39795, 0.74171, 180.433, false],
    ["Land_CampingTable_F", -2.67896, -3.021, 0.41275, 79.8318, false],
    ["Land_CampingChair_V2_F", -3.41187, -3.83838, 0.50768, 240.277, false],
    ["Land_CampingChair_V2_F", -2.38916, -2.48193, 0.50768, 86.6711, false],
    ["MapBoard_altis_F", -3.21143, -0.920898, 0.97008, 322.8, false],
    ["Land_Ammobox_rounds_F", -2.75647, -3.23877, 0.10656, 71.7106, false],
    ["RuggedTerminal_01_communications_hub_F", -0.28772, -9.33252, 4.56558, 88.4434, false],
    ["Land_Ammobox_rounds_F", -2.5603, -3.66504, 0.10656, 96.0366, false],
    ["Land_Ammobox_rounds_F", -2.49805, -3.12207, 0.10656, 230.385, false]
];
// --DUWS-COMPOSITION END--

// --DUWS-COMPOSITION BEGIN name="Hardpoint: Roadblock" schema=A--
DUWS_hardpointComp_ROADBLOCK = [    ["Land_BarGate_F", -0.224609, -0.0253906, 4.0514758, 0.344852, false],
    ["Land_BagBunker_Small_F", -6.92761, -1.99951, 0.96683, 180.263, false],
    ["Land_BagBunker_Small_F", 6.97339, -1.77783, 0.96683, 180.263, false],
    ["Land_BagFence_Long_F", 7.00818, -4.33496, 0.42051, 178.687, false],
    ["I_HMG_02_high_F", -6.71375, -1.62158, 1.68163, 357.391, true],
    ["I_HMG_02_high_F", 7.20386, -1.3042, 1.68094, 357.391, true],
    ["Land_BagFence_Long_F", -7.02368, -4.50342, 0.42051, 178.687, false]
];
// --DUWS-COMPOSITION END--

// --DUWS-COMPOSITION BEGIN name="Hardpoint: AA Emplacement" schema=A--
DUWS_hardpointComp_AA = [
    ["Land_HBarrier_5_F", -7.11267, -0.390625, 0.74121, 89.7718, false],
    ["Land_HBarrier_5_F", -0.0450439, 5.73145, 0.74121, 359.05, false],
    ["Land_HBarrier_5_F", 0.215698, -7.01709, 0.74121, 358.861, false],
    ["Land_HBarrier_5_F", 6.45398, -0.177246, 0.74121, 268.781, false],
    ["Land_Razorwire_F", -8.6615, -0.244629, 0.75576, 270.581, false],
    ["Land_Razorwire_F", -0.0549316, 7.15381, 0.75576, 0.9464, false],
    ["Land_Razorwire_F", 8.07776, -0.302734, 0.75576, 89.3498, false],
    ["Land_Razorwire_F", 0.194336, -8.58496, 0.75576, 359.237, false],
    ["I_static_AA_F", -0.138428, -0.65332, 0.98391, 359.369, true]
];
// --DUWS-COMPOSITION END--

// --DUWS-COMPOSITION BEGIN name="Hardpoint: AT Emplacement" schema=A--
DUWS_hardpointComp_AT = [    ["CamoNet_BLUFOR_open_F", 0.168701, 0.11084, 1.16854, 0.00104801, false],
    ["Land_BagFence_Round_F", -3.94617, 0.465332, 0.42001, 94.5918, false],
    ["Land_BagFence_Round_F", -0.497559, -2.89648, 0.42001, 2.71297, false],
    ["Land_BagFence_Round_F", 3.24548, -0.0541992, 0.42001, 281.642, false],
    ["I_static_AT_F", -0.0291748, -0.046875, 0.98223, 0, true]];
// --DUWS-COMPOSITION END--

// --DUWS-COMPOSITION BEGIN name="Hardpoint: MG Nest" schema=A--
DUWS_hardpointComp_MG = [    ["Land_BagBunker_Small_F", -0.145386, 0.259277, 0.96683, 177.192, false],
    ["I_HMG_02_high_F", 0.0183105, 0.622559, 1.68094, 359.501, true],
    ["Land_BagFence_Long_F", -0.0167236, -2.34717, 0.42051, 177.607, false]
];
// --DUWS-COMPOSITION END--

// --DUWS-COMPOSITION BEGIN name="Hardpoint: Mortar Pit" schema=A--
DUWS_hardpointComp_MORTAR = [    ["Land_HBarrier_5_F", -5.04614, 0.517578, 0.74121, 89.9076, false],
    ["Land_HBarrier_5_F", 2.62061, 4.30078, 0.74121, 358.18, false],
    ["Land_HBarrier_5_F", -2.99255, 4.1875, 0.74121, 358.18, false],
    ["Land_HBarrier_5_F", 4.81384, 0.812988, 0.74121, 89.9076, false],
    ["Land_HBarrier_5_F", -0.306274, -6.49268, 0.74121, 359.415, false],
    ["Land_Razorwire_F", 7.58386, -7.02002, 0.75576, 124.469, false],
    ["Land_HBarrier_5_F", 6.30579, -6.02344, 0.74121, 125.05, false],
    ["Land_Razorwire_F", -8.26318, -6.98877, 0.75576, 230.52, false],
    ["Land_HBarrier_5_F", -6.95215, -6.03613, 0.74121, 231.101, false],
    ["Land_Razorwire_F", -0.0106201, 6.03711, 0.75576, 359.228, false],
    ["I_Mortar_01_F", 0.0826416, -3.24414, 0.72232, 1.35923, true],
    ["I_Mortar_01_F", 2.39014, -0.189941, 0.72232, 0.686763, true],
    ["I_Mortar_01_F", -2.00403, -0.265137, 0.72232, 358.9, true]];
// --DUWS-COMPOSITION END--

// --DUWS-COMPOSITION BEGIN name="Hardpoint: Artillery Battery" schema=A--
DUWS_hardpointComp_ARTY = [    ["Land_HBarrier_5_F", -15.014, -4.16602, 0.74171, 84.2465, false],
    ["B_MBT_01_arty_F", 7.36279, 1.3208, 3.085201, 359.991, true],
    ["B_MBT_01_arty_F", -1.68066, -7.35254, 3.085201, 359.669, true],
    ["B_MBT_01_arty_F", -8.6781, 0.733398, 3.085201, 359.991, true],
    ["Land_HBarrier_5_F", -14.7063, -14.5366, 0.74171, 0.255156, false],
    ["Land_HBarrier_5_F", -20.3317, -14.4419, 0.74171, 0.255156, false],
    ["CamoNet_BLUFOR_open_F", -18.1045, -7.93311, 1.16904, 91.2527, false],
    ["Land_HBarrier_5_F", -18.7751, -2.72266, 0.74171, 172.131, false],
    ["Land_HBarrier_5_F", -22.1422, -5.12646, 0.74171, 270.885, false],
    ["Land_HBarrier_5_F", -22.2874, -10.834, 0.74171, 270.885, false],
    ["Land_Razorwire_F", 17.2214, -10.8159, 0.75626, 98.0904, false],
    ["Land_Razorwire_F", 18.3391, -2.60596, 0.75626, 98.0904, false],
    ["Land_Razorwire_F", 18.1422, 5.32568, 0.75626, 80.8643, false],
    ["Land_Razorwire_F", 13.8604, 11.4512, 0.75626, 28.0497, false],
    ["Land_Razorwire_F", 5.97986, 12.957, 0.75626, 357.099, false],
    ["Land_Razorwire_F", -2.21301, 12.394, 0.75626, 355.111, false],
    ["Land_Razorwire_F", -10.4496, 11.7505, 0.75626, 353.138, false],
    ["Land_Razorwire_F", -18.1144, 9.10645, 0.75626, 321.35, false],
    ["Land_Razorwire_F", -23.0337, 2.49609, 0.75626, 289.123, false],
    ["Box_NATO_AmmoVeh_F", -20.0579, -5.04639, 0.791, 86.9417, false],
    ["Box_NATO_AmmoVeh_F", -20.231, -6.8252, 0.791, 100.812, false],
    ["Box_NATO_AmmoVeh_F", -16.9375, -5.23975, 0.791, 187.943, false],
    ["Land_CampingChair_V2_F", -19.7532, -10.7632, 0.50768, 249.076, false],
    ["Land_CampingTable_F", -18.9894, -10.2163, 0.41275, 38.4917, false],
    ["Land_MetalBarrel_F", -15.0797, -7.46191, 0.42387, 14.2185, false],
    ["Land_MetalBarrel_empty_F", -15.5273, -8.04004, 0.42387, 34.0865, false],
    ["Land_MetalBarrel_F", -14.3979, -7.26123, 0.42387, 326.887, false],
    ["Land_HBarrier_Big_F", 12.7484, 5.93018, 1.2112, 69.6145, false],
    ["Land_HBarrier_Big_F", 14.0784, -2.53174, 1.2112, 96.0709, false],
    ["Land_HBarrier_Big_F", 13.38, -11.0303, 1.2112, 96.0709, false],
    ["Land_HBarrier_Big_F", 6.34363, 9.78662, 1.2112, 357.815, false],
    ["Land_HBarrier_Big_F", -2.15186, 9.37549, 1.2112, 358.652, false],
    ["Land_HBarrier_Big_F", -10.6534, 9.01221, 1.2112, 0.909108, false],
    ["Land_HBarrier_Big_F", -15.6176, 5.52783, 1.2112, 266.81, false],
    ["Land_HBarrier_Big_F", -18.353, -0.506348, 1.2112, 172.467, false]
];
// --DUWS-COMPOSITION END--
