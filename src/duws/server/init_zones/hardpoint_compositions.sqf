// Locality: server -- hardpoint layout data, read by the hardpoint placer.
//
// Offsets are in a frame whose +Y is the hardpoint's facing. The placer rotates the whole layout
// about the site centre, so a heading turns the cover with the core instead of turning the core
// inside a fixed ring of props.
//
// Each array holds a single sandbag and nothing else: the composition TUI raises its origin and
// facing markers from a fence that already exists, so a layout has to be fenced in source before it
// can be authored in Eden. The sandbag is an ordinary row and goes when the real layout is pasted
// back. Round trip: docs/info/architecture/composition_tooling.md.
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

// --DUWS-COMPOSITION BEGIN name="Hardpoint: GMG Emplacement" schema=A--
DUWS_hardpointComp_GMG = [    ["CamoNet_BLUFOR_open_F", 0.168701, 0.11084, 1.16854, 0.00104801, false],
    ["Land_BagFence_Round_F", -3.94617, 0.465332, 0.420007, 94.5918, false],
    ["Land_BagFence_Round_F", -0.497559, -2.89648, 0.420007, 2.71297, false],
    ["Land_BagFence_Round_F", 3.24548, -0.0541992, 0.420007, 281.642, false],
    ["I_GMG_01_high_F", -0.174683, 0.305176, 1.66083, 0, true]];
// --DUWS-COMPOSITION END--

// --DUWS-COMPOSITION BEGIN name="Hardpoint: Mortar Pit" schema=A--
DUWS_hardpointComp_MORTAR = [
    ["Land_HBarrier_5_F", -5.04614, 0.517578, 0.74121, 89.9076, false],
    ["Land_HBarrier_5_F", 2.62061, 4.30078, 0.74121, 358.18, false],
    ["Land_HBarrier_5_F", -2.99255, 4.1875, 0.74121, 358.18, false],
    ["Land_HBarrier_5_F", 4.81384, 0.812988, 0.74121, 89.9076, false],
    ["Land_Razorwire_F", 7.58386, -7.02002, 0.755762, 124.469, false],
    ["Land_HBarrier_5_F", 6.30579, -6.02344, 0.74121, 125.05, false],
    ["Land_Razorwire_F", -8.26318, -6.98877, 0.755762, 230.52, false],
    ["Land_HBarrier_5_F", -6.95215, -6.03613, 0.74121, 231.101, false],
    ["Land_Razorwire_F", -0.0106201, 6.03711, 0.755762, 359.228, false],
    ["I_Mortar_01_F", 0.0826416, -3.24463, 0.723015, 1.35923, true],
    ["I_Mortar_01_F", 2.39014, -0.19043, 0.723015, 0.686763, true],
    ["I_Mortar_01_F", -2.00403, -0.265625, 0.722321, 358.9, true],
    ["Land_HBarrier_5_F", -0.330444, -8.38818, 0.74121, 359.415, false],
    ["Box_FIA_Ammo_F", -2.28699, -6.21826, 1.36147, 269.614, false],
    ["Land_CratesWooden_F", 0.365845, -6.28613, 0.739696, 357.625, false]
];
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

// --DUWS-COMPOSITION BEGIN name="Hardpoint: Radio Tower" schema=A--
// The mast is the CommStation prefab's comms tower, dressed with the OP composition's comms hub. Unlike
// every other prop the mast is left live -- simulated and damageable -- so the tower is cleared by
// destroying the mast, not by beating its garrison: the walls, nests and bunkers stay frozen
// invulnerable cover, so the defenders can be wiped and the tower still stands until the mast comes
// down. Clearing it drops DUWS_opforRadioLevel and removes its 7 km of coverage. It is a fortified
// base, not a bare nest: HBarrier-walled and razorwire-ringed, with seven crewed HMG nests and an AA
// static, so it costs the player far more than a combat hardpoint.
DUWS_hardpointComp_RADIO = [
    ["Land_HBarrier_Big_F", -5.17578, 17.6191, 1.2107, 180.105, false],
    ["Land_HBarrier_Big_F", 3.05859, 17.8027, 1.2107, 180.105, false],
    ["Land_HBarrier_Big_F", 11.2949, 18.1387, 1.2107, 180.105, false],
    ["Land_HBarrier_Big_F", -21.0801, 14.6309, 1.2107, 147.124, false],
    ["Land_HBarrier_Big_F", 19.0703, 16.5371, 1.2107, 207.383, false],
    ["Land_HBarrier_Big_F", 13.6152, -5.24805, 1.2107, 89.7639, false],
    ["Land_HBarrier_Big_F", 14.1836, -24.5059, 1.2107, 268.058, false],
    ["Land_HBarrier_Big_F", 14.8574, -32.9531, 1.2107, 268.676, false],
    ["Land_HBarrier_Big_F", -15.0137, -22.5059, 1.2107, 359.461, false],
    ["Land_HBarrier_Big_F", 18.748, -20.6875, 1.2107, 356.604, false],
    ["Land_HBarrier_Big_F", -9.67578, -25.5801, 1.2107, 269.324, false],
    ["Land_HBarrier_Big_F", -27.6074, 9.64844, 1.2107, 139.818, false],
    ["Land_HBarrier_Big_F", 26.3477, 12.8574, 1.2107, 211.518, false],
    ["Land_HBarrier_Big_F", -23.4453, -22.9043, 1.2107, 359.461, false],
    ["Land_HBarrier_Big_F", 26.6113, -20.2852, 1.2107, 359.461, false],
    ["Land_HBarrier_Big_F", 31.7617, -16.5723, 1.2107, 268.913, false],
    ["Land_HBarrier_Big_F", 33.3008, 8.55664, 1.2107, 214.943, false],
    ["Land_HBarrier_Big_F", -33.6973, 4.44336, 1.2107, 319.629, false],
    ["Land_HBarrier_Big_F", -29.248, -19.8672, 1.2107, 265.82, false],
    ["Land_HBarrier_Big_F", 9.95703, -36.6641, 1.2107, 357.833, false],
    ["Land_HBarrier_Big_F", 2.32227, -37.0527, 1.2107, 357.833, false],
    ["Land_HBarrier_Big_F", -5.9375, -37.5137, 1.2107, 357.833, false],
    ["Land_HBarrier_Big_F", -9.28516, -33.9023, 1.2107, 269.234, false],
    ["Land_Cargo_HQ_V1_F", -1.29688, -26.8262, 3.8761, 88.8286, false],
    ["Land_Cargo_Patrol_V1_F", 28.1895, -15.7422, 4.9057, 268.315, false],
    ["Land_HBarrier_Big_F", 28.4023, -11.1973, 1.2107, 181.742, false],
    ["Land_Cargo_Patrol_V1_F", -26.0156, -18.5508, 4.9057, 84.5663, false],
    ["Land_HBarrier_Big_F", -26.5254, -14.3438, 1.2107, 175.196, false],
    ["Land_HBarrier_Big_F", -13.4902, 17.207, 1.2107, 176.476, false],
    ["Land_BagBunker_Tower_F", 33.7793, 1.8418, 2.21072, 168.251, false],
    ["Land_HBarrier_Big_F", 37.5059, 2.45312, 1.2107, 83.2004, false],
    ["Land_BagBunker_Tower_F", -32.1641, -1.35547, 2.21072, 355.516, false],
    ["Land_HBarrier_Big_F", -36.2441, -1.78711, 1.2107, 267.615, false],
    ["Land_HBarrier_Big_F", -12.0625, -6.20312, 1.2107, 88.9417, false],
    ["Land_HBarrier_Big_F", -12.5703, 2.10742, 1.2107, 88.9417, false],
    ["Land_Cargo_Patrol_V1_F", -0.0625, 15.9707, 4.9057, 177.409, false],
    ["Land_Cargo_House_V1_F", 18.5254, 4.6543, 0.690695, 267.976, false],
    ["Land_Cargo_House_V1_F", 19.1504, -3.71875, 0.690695, 267.976, false],
    ["Land_Cargo_House_V1_F", -17.4082, -6.4668, 0.690695, 87.9155, false],
    ["Land_Cargo_House_V1_F", -18.1543, 2.4375, 0.690695, 87.9155, false],
    ["Land_Razorwire_F", 30.4609, -36.8906, 0.755762, 150.166, false],
    ["Land_Razorwire_F", 23.3516, -40.8535, 0.755762, 149.637, false],
    ["Land_Razorwire_F", 15.5645, -43.2383, 0.755762, 178.5, false],
    ["Land_Razorwire_F", 7.42578, -43.3516, 0.755762, 177.971, false],
    ["Land_Razorwire_F", -1.02539, -43.7109, 0.755762, 178.5, false],
    ["Land_Razorwire_F", -9.16406, -43.8242, 0.755762, 177.971, false],
    ["Land_Razorwire_F", -22.6035, -36.2109, 0.755762, 219.719, false],
    ["Land_Razorwire_F", -16.4551, -41.5449, 0.755762, 220.249, false],
    ["Land_Razorwire_F", -28.8027, -31.1719, 0.755762, 225.914, false],
    ["Land_Razorwire_F", -32.1953, -23.6797, 0.755762, 263.549, false],
    ["Land_Razorwire_F", 37.0527, -22.2324, 0.755762, 85.1226, false],
    ["Land_Razorwire_F", 35.7266, -30.625, 0.755762, 114.35, false],
    ["Land_Razorwire_F", -36.4883, 14.0977, 0.755762, 321.375, false],
    ["Land_Razorwire_F", -30.0684, 19.0996, 0.755762, 320.845, false],
    ["Land_Razorwire_F", -22.9844, 23.0449, 0.755762, 343.05, false],
    ["Land_Razorwire_F", -14.9023, 24.3555, 0.755762, 358.846, false],
    ["Land_Razorwire_F", -8.98828, 24.8281, 0.755762, 359.125, false],
    ["Land_Razorwire_F", -0.849609, 24.8535, 0.755762, 358.595, false],
    ["Land_Razorwire_F", 7.48438, 25.082, 0.755762, 357.001, false],
    ["Land_Razorwire_F", 15.7656, 24.2539, 0.755762, 15.039, false],
    ["Land_Razorwire_F", 23.6406, 20.9961, 0.755762, 30.9063, false],
    ["Land_Razorwire_F", 30.5723, 16.7305, 0.755762, 30.3766, false],
    ["Land_Razorwire_F", -40.8711, 7.39062, 0.755762, 285.765, false],
    ["Land_Razorwire_F", 37.1934, 11.0957, 0.755762, 46.2963, false],
    ["I_static_AA_F", -0.931641, -27.793, 4.11115, 354.365, true],
    ["I_HMG_02_high_F", -3.02734, -33.8574, 4.80766, 186.148, true],
    ["I_HMG_02_high_F", 29.3555, -14.1426, 6.02518, 82.7178, true],
    ["I_HMG_02_high_F", 1.46875, 17.1777, 6.02517, 0.96579, true],
    ["I_HMG_02_high_F", -27.207, -17.2461, 6.02518, 270.381, true],
    ["I_HMG_02_high_F", 33.8223, 3.20898, 4.46114, 67.4252, true],
    ["I_HMG_02_high_F", -32.3535, -2.61719, 4.46114, 268.872, true],
    ["Land_TTowerBig_2_F", 0.873047, -1.05273, 23.232, 0, false],
    ["Land_HBarrier_Big_F", 13.2266, 3.06836, 1.2107, 89.7639, false],
    ["RuggedTerminal_01_communications_hub_F", 11.2051, -1.60156, 4.56508, 262.725, false],
    ["Land_TBox_F", -9.05859, -7.04688, 1.70755, 267.207, false],
    ["Land_WoodenBox_F", -10.2773, -3.49023, 0.000695467, 90.7893, false],
    ["Land_WoodenBox_F", -9.58984, -3.41016, 0.000695467, 86.1215, false],
    ["Land_WoodenBox_F", -8.74414, -3.90234, 0.000695467, 101.047, false],
    ["Land_ToiletBox_F", -10.4219, 5.55273, 1.22076, 263.444, false],
    ["Land_ToiletBox_F", -10.2363, 3.68164, 1.22076, 263.444, false],
    ["Land_ToiletBox_F", -10.0117, 1.63477, 1.22076, 263.444, false],
    ["CamoNet_BLUFOR_open_F", -15.6973, -16.2285, 1.16854, 179.074, false],
    ["CamoNet_BLUFOR_open_F", 18.2695, -14.8789, 1.16854, 358.176, false]
];
// --DUWS-COMPOSITION END--
