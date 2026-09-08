// The furniture catalog: one row per furniture class, the single place class-specific knowledge is
// allowed to live (building geometry is inferred, never keyed on class -- but the furniture is ours).
// Included as the body of an array literal, the same shape as mission_types.hpp:
//
//     private _rows = [
//     #include "..\..\shared\includes\furniture_catalog.hpp"
//     ];
//
// fnc_furnish_catalog reads it into a class->entry HashMap once. A class that resolves in neither
// CfgVehicles, CfgMagazines nor CfgWeapons is logged and skipped there (this file cannot see the
// engine config); the lint (tests/lint/check_furniture_catalog.py) checks row shape and vocabulary.
//
// Columns: [class, role, frontYaw, set[], seats, backToWall, wants[]]
//   role       table / desk / chair / sofa / bed / cabinet / rug / clutter -- selects the placer pass.
//   frontYaw   degrees to subtract from a target bearing so the MODEL's real front lands on it:
//              heading = targetFrontBearing - frontYaw. It is the compass bearing the model's front
//              points at when the object sits at heading 0 (its +Y due north). No command reports a
//              model's front, so it is hand-read once per class with the calibration debug tool and
//              recorded here. 0 = uncalibrated (front assumed +Y); a mis-faced piece is a playtest
//              fix, not a crash. At 0 a seat's facing reduces to the plain bearing-to-anchor.
//   seats      anchors only: -1 = a chair on every open side (dining table); N = exactly N on the
//              front (a desk is 1). Ignored for non-anchors.
//   backToWall 1 = must sit in a near-wall cell, back to the wall (sofa, bed, cabinet, wall desk).
//   wants[]    roles the placer pairs with the piece (a table/desk wants a chair).

// -- living: dining tables + their chairs, soft seating, floor covers, tabletop clutter --
["Land_CampingTable_small_F",       "table",   0, ["living"], -1, 0, ["chair"]],
["Land_CampingTable_F",             "table",   0, ["living"], -1, 0, ["chair"]],
["Land_CampingTable_small_white_F", "table",   0, ["living"], -1, 0, ["chair"]],
["Land_CampingTable_white_F",       "table",   0, ["living"], -1, 0, ["chair"]],
["Land_WoodenTable_large_F",        "table",   0, ["living"], -1, 0, ["chair"]],
["Land_WoodenTable_small_F",        "table",   0, ["living"], -1, 0, ["chair"]],
["Land_TableSmall_01_F",            "table",   0, ["living"], -1, 0, ["chair"]],
["Land_TableBig_01_F",              "table",   0, ["living"], -1, 0, ["chair"]],
["Land_CampingChair_V2_F",          "chair",   0, ["living"],  0, 0, []],
["Land_CampingChair_V2_white_F",    "chair",   0, ["living"],  0, 0, []],
["Land_ChairPlastic_F",             "chair",   0, ["living"],  0, 0, []],
["Land_RattanChair_01_F",           "chair",   0, ["living"],  0, 0, []],
["Land_ChairWood_F",                "chair",   0, ["living"],  0, 0, []],
["Land_ArmChair_01_F",              "sofa",    0, ["living"],  0, 1, []],
["Land_Sofa_01_F",                  "sofa",    0, ["living"],  0, 1, []],
["Land_Bench_F",                    "sofa",    0, ["living"],  0, 1, []],
["Land_Rug_01_F",                   "rug",     0, ["living"],  0, 0, []],
["Land_Rug_01_Traditional_F",       "rug",     0, ["living"],  0, 0, []],
["Land_BakedBeans_F",               "clutter", 0, ["living"],  0, 0, []],
["Land_Can_Dented_F",               "clutter", 0, ["living"],  0, 0, []],
["Land_Can_V2_F",                   "clutter", 0, ["living"],  0, 0, []],
["Land_Can_V3_F",                   "clutter", 0, ["living"],  0, 0, []],
["Land_Can_Rusty_F",                "clutter", 0, ["living"],  0, 0, []],
["Land_Can_V1_F",                   "clutter", 0, ["living"],  0, 0, []],
["Land_CerealsBox_F",               "clutter", 0, ["living"],  0, 0, []],
["Land_Tableware_01_fork_F",        "clutter", 0, ["living"],  0, 0, []],
["Land_Tableware_01_knife_F",       "clutter", 0, ["living"],  0, 0, []],
["Land_Tableware_01_spoon_F",       "clutter", 0, ["living"],  0, 0, []],
["Land_Tableware_01_stackOfNapkins_F", "clutter", 0, ["living"], 0, 0, []],
["Land_Tableware_01_napkin_F",      "clutter", 0, ["living"],  0, 0, []],
["Land_Tableware_01_cup_F",         "clutter", 0, ["living"],  0, 0, []],
["Land_BottlePlastic_V1_F",         "clutter", 0, ["living"],  0, 0, []],
["Land_BottlePlastic_V2_F",         "clutter", 0, ["living"],  0, 0, []],
["Land_PowderedMilk_F",             "clutter", 0, ["living"],  0, 0, []],
["Land_RiceBox_F",                  "clutter", 0, ["living"],  0, 0, []],
["Land_TacticalBacon_F",            "clutter", 0, ["living"],  0, 0, []],
["Land_TinContainer_F",             "clutter", 0, ["living"],  0, 0, []],
["Lantern_01_red_F",                "clutter", 0, ["living"],  0, 0, []],
["Lantern_01_green_F",              "clutter", 0, ["living"],  0, 0, []],
["Lantern_01_blue_F",               "clutter", 0, ["living"],  0, 0, []],
["Lantern_01_black_F",              "clutter", 0, ["living"],  0, 0, []],
["Land_Antibiotic_F",               "clutter", 0, ["living"],  0, 0, []],
["Land_Antimalaricum_01_F",         "clutter", 0, ["living"],  0, 0, []],
["Land_Bandage_F",                  "clutter", 0, ["living"],  0, 0, []],
["Land_BloodBag_F",                 "clutter", 0, ["living"],  0, 0, []],
["Land_HeatPack_F",                 "clutter", 0, ["living"],  0, 0, []],
["Land_DisinfectantSpray_F",        "clutter", 0, ["living"],  0, 0, []],
["Land_PainKillers_F",              "clutter", 0, ["living"],  0, 0, []],
["Land_VitaminBottle_F",            "clutter", 0, ["living"],  0, 0, []],

// -- sleeping --
["Land_WoodenBed_01_F",             "bed",     0, ["sleeping"], 0, 1, []],

// -- work: desks + office chair + desk clutter --
["OfficeTable_01_new_F",            "desk",    0, ["work"],     1, 1, ["chair"]],
["OfficeTable_01_old_F",            "desk",    0, ["work"],     1, 1, ["chair"]],
["Land_OfficeChair_01_F",           "chair",   0, ["work"],     0, 0, []],
["Land_Laptop_unfolded_F",          "clutter", 0, ["work"],     0, 0, []],
["Land_Laptop_F",                   "clutter", 0, ["work"],     0, 0, []],
["Land_Laptop_device_F",            "clutter", 0, ["work"],     0, 0, []],
["Land_Camera_01_F",                "clutter", 0, ["work"],     0, 0, []],
["Land_FMradio_F",                  "clutter", 0, ["work"],     0, 0, []],
["Land_HandyCam_F",                 "clutter", 0, ["work"],     0, 0, []],
["Leaflet_05_Stack_F",              "clutter", 0, ["work"],     0, 0, []],
["Leaflet_05_Old_F",                "clutter", 0, ["work"],     0, 0, []],
["Leaflet_05_New_F",                "clutter", 0, ["work"],     0, 0, []],
["Newspaper_01_F",                  "clutter", 0, ["work"],     0, 0, []],
["Land_Notepad_F",                  "clutter", 0, ["work"],     0, 0, []],
["Land_PenBlack_F",                 "clutter", 0, ["work"],     0, 0, []],
["Land_PenRed_F",                   "clutter", 0, ["work"],     0, 0, []],
["Land_PencilBlue_F",               "clutter", 0, ["work"],     0, 0, []],
["Land_PencilGreen_F",              "clutter", 0, ["work"],     0, 0, []],
["Land_PencilRed_F",                "clutter", 0, ["work"],     0, 0, []],
["Land_PencilYellow_F",             "clutter", 0, ["work"],     0, 0, []],
["Land_PensAndPencils_F",           "clutter", 0, ["work"],     0, 0, []],
["Land_Wallet_01_F",                "clutter", 0, ["work"],     0, 0, []],
["Land_Creditcard_01_F",            "clutter", 0, ["work"],     0, 0, []],
["Land_Key_01_F",                   "clutter", 0, ["work"],     0, 0, []],
["Land_Battery_F",                  "clutter", 0, ["work"],     0, 0, []],
["Land_DuctTape_F",                 "clutter", 0, ["work"],     0, 0, []],
["Land_Pliers_F",                   "clutter", 0, ["work"],     0, 0, []],
["Land_MultiMeter_F",               "clutter", 0, ["work"],     0, 0, []],
["Land_Screwdriver_V2_F",           "clutter", 0, ["work"],     0, 0, []],
["Land_Screwdriver_V1_F",           "clutter", 0, ["work"],     0, 0, []],
["Land_Meter3m_F",                  "clutter", 0, ["work"],     0, 0, []],
["Land_Wrench_F",                   "clutter", 0, ["work"],     0, 0, []],
["Land_DustMask_F",                 "clutter", 0, ["work"],     0, 0, []],
["Land_Gloves_F",                   "clutter", 0, ["work"],     0, 0, []],
["AluminiumFoil_01_F",              "clutter", 0, ["work"],     0, 0, []],
["Land_Matches_F",                  "clutter", 0, ["work"],     0, 0, []]
