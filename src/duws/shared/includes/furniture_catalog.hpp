// The furniture catalog: one row per furniture class, the single place class-specific knowledge is
// allowed to live (building geometry is inferred, never keyed on class -- but the furniture is ours).
// Included as the body of an array literal, the same shape as mission_types.hpp:
//
//     private _rows = [
//     #include "..\..\shared\includes\furniture_catalog.hpp"
//     ];
//
// fnc_furnish_catalog reads it into a class->entry map once. A class that resolves in neither
// CfgVehicles, CfgMagazines nor CfgWeapons is logged and skipped there (this file cannot see the
// engine config); the lint (tests/lint/check_furniture_catalog.py) checks row shape and vocabulary.
//
// Columns: [class, role, frontYaw, family, seats, slot, maxPerRoom?]  (maxPerRoom optional, default 0)
//   role       one of five placement categories, each its own placer pass:
//                anchor    -- needs open floor; takes seats beside it (a table, a desk).
//                seat      -- placed at an anchor's edge, facing in; never standalone.
//                wall      -- placed back-flush and perpendicular to a wall (sofa, shelf, cabinet).
//                clutter   -- seated on an anchor's top.
//                freestand -- stands in the open middle like an anchor but inert: no seats, no tabletop
//                             clutter (a crate stack, a sack heap). Carries no family (family "", slot "").
//   frontYaw   degrees subtracted from a target bearing so the model's real front lands on it (heading =
//              target - frontYaw); i.e. the bearing the front points at when placed at heading 0 (+Y due
//              north). Hand-read per class with the calibration tool, since no command reports a model's
//              front. 0 = uncalibrated (front assumed +Y); a mis-face is a playtest fix, not a crash.
//   family     companion group tying an anchor to its seats and tabletop clutter -- an anchor draws only
//              chairs and clutter of its own family (a desk takes an office chair, a dining table its own
//              chairs). "" for wall and freestand pieces, which take no companions.
//   seats      anchors only: -1 = a seat on every open side (dining table); N = exactly N on the front
//              (a desk is 1). 0 (ignored) for every other role.
//   slot       anchors only: "center" fills the mid-room slot, "wall" backs onto a wall (a desk). "" else.
//   maxPerRoom optional cap on how many of this class one room gets across the wall / anchor passes.
//              Absent or 0 = no limit. Not applied to per-anchor seats or clutter.

// -- lounge + dining: center tables, their chairs, tabletop clutter (family "dining"); lounge/kitchen wall pieces (flat) --
["Land_CampingTable_small_F",       "anchor",   0, "dining", -1, "center"],
["Land_CampingTable_F",             "anchor",   0, "dining", -1, "center"],
["Land_CampingTable_small_white_F", "anchor",   0, "dining", -1, "center"],
["Land_CampingTable_white_F",       "anchor",   0, "dining", -1, "center"],
["Land_WoodenTable_large_F",        "anchor",  90, "dining", -1, "center"],
["Land_WoodenTable_small_F",        "anchor",  90, "dining", -1, "center"],
["Land_TableSmall_01_F",            "wall",    90, "",        0, ""],
["Land_TableBig_01_F",              "anchor",   0, "dining", -1, "center"],
["Land_WoodenCounter_01_F",         "anchor",   0, "dining",  2, "center"],   // counter bar: stools on the front
["Land_CampingChair_V2_F",          "seat",   180, "dining",  0, ""],
["Land_CampingChair_V2_white_F",    "seat",   180, "dining",  0, ""],
["Land_ChairPlastic_F",             "seat",    90, "dining",  0, ""],
["Land_RattanChair_01_F",           "wall",   180, "",        0, ""],
["Land_ChairWood_F",                "seat",   180, "dining",  0, ""],
["Land_ArmChair_01_F",              "wall",     0, "",        0, ""],
["Land_Sofa_01_F",                  "wall",     0, "",        0, ""],
["Land_Bench_F",                    "wall",    90, "",        0, ""],
["Land_Bench_05_F",                 "wall",     0, "",        0, ""],
["Land_RattanTable_01_F",           "wall",     0, "",        0, ""],
["Fridge_01_closed_F",              "wall",   180, "",        0, ""],
["Fridge_01_open_F",                "wall",   180, "",        0, ""],
["Land_BakedBeans_F",               "clutter",  0, "dining",  0, ""],
["Land_Can_Dented_F",               "clutter",  0, "dining",  0, ""],
["Land_Can_V2_F",                   "clutter",  0, "dining",  0, ""],
["Land_Can_V3_F",                   "clutter",  0, "dining",  0, ""],
["Land_Can_Rusty_F",                "clutter",  0, "dining",  0, ""],
["Land_Can_V1_F",                   "clutter",  0, "dining",  0, ""],
["Land_CerealsBox_F",               "clutter",  0, "dining",  0, ""],
["Land_Tableware_01_fork_F",        "clutter",  0, "dining",  0, ""],
["Land_Tableware_01_knife_F",       "clutter",  0, "dining",  0, ""],
["Land_Tableware_01_spoon_F",       "clutter",  0, "dining",  0, ""],
["Land_Tableware_01_stackOfNapkins_F","clutter",  0, "dining",  0, ""],
["Land_Tableware_01_napkin_F",      "clutter",  0, "dining",  0, ""],
["Land_Tableware_01_cup_F",         "clutter",  0, "dining",  0, ""],
["Land_BottlePlastic_V1_F",         "clutter",  0, "dining",  0, ""],
["Land_BottlePlastic_V2_F",         "clutter",  0, "dining",  0, ""],
["Land_PowderedMilk_F",             "clutter",  0, "dining",  0, ""],
["Land_RiceBox_F",                  "clutter",  0, "dining",  0, ""],
["Land_TacticalBacon_F",            "clutter",  0, "dining",  0, ""],
["Land_TinContainer_F",             "clutter",  0, "dining",  0, ""],
["Land_Antibiotic_F",               "clutter",  0, "dining",  0, ""],
["Land_Antimalaricum_01_F",         "clutter",  0, "dining",  0, ""],
["Land_Bandage_F",                  "clutter",  0, "dining",  0, ""],
["Land_BloodBag_F",                 "clutter",  0, "dining",  0, ""],
["Land_HeatPack_F",                 "clutter",  0, "dining",  0, ""],
["Land_DisinfectantSpray_F",        "clutter",  0, "dining",  0, ""],
["Land_PainKillers_F",              "clutter",  0, "dining",  0, ""],
["Land_VitaminBottle_F",            "clutter",  0, "dining",  0, ""],

// -- storage: racks, shelves, pots; wall-flush, flat pool, any room --
["Land_Metal_rack_F",               "wall",   180, "",        0, ""],
["Land_Metal_rack_Tall_F",          "wall",     0, "",        0, ""],
["Land_Rack_F",                     "wall",    90, "",        0, ""],
["Land_ShelvesWooden_F",            "wall",    90, "",        0, ""],
["Land_ShelvesWooden_blue_F",       "wall",    90, "",        0, ""],
["Land_ShelvesWooden_khaki_F",      "wall",    90, "",        0, ""],
["Land_FlowerPot_01_Flower_F",      "wall",     0, "",        0, ""],
["Land_FlowerPot_01_F",             "wall",     0, "",        0, ""],

// -- containers: single crate/sack, buckets, baskets, trolleys; wall-flush, fit any room --
["Land_Basket_F",                   "wall",     0, "",        0, ""],
["Land_Sack_F",                     "wall",     0, "",        0, ""],
["Land_WoodenCrate_01_F",           "wall",     0, "",        0, ""],
["Land_ToolTrolley_01_F",           "wall",   270, "",        0, ""],
["Land_ToolTrolley_02_F",           "wall",   270, "",        0, ""],
["Land_CanisterPlastic_F",          "wall",     0, "",        0, ""],
["Land_PlasticBucket_01_closed_F",  "wall",     0, "",        0, ""],
["Land_PlasticBucket_01_open_F",    "wall",     0, "",        0, ""],
["Land_Bucket_F",                   "wall",     0, "",        0, ""],
["Land_Bucket_clean_F",             "wall",     0, "",        0, ""],
["Land_Bucket_painted_F",           "wall",     0, "",        0, ""],

// -- freestanding floor bulk: crate stacks and sack heaps, stood in the open middle and walked around; no seats, no tabletop --
["Land_CratesPlastic_F",            "freestand", 0, "", 0, ""],
["Land_CratesShabby_F",             "freestand", 0, "", 0, ""],
["Land_CratesWooden_F",             "freestand", 0, "", 0, ""],
["Land_WoodenCrate_01_stack_x3_F",  "freestand", 0, "", 0, ""],
["Land_WoodenCrate_01_stack_x5_F",  "freestand", 0, "", 0, ""],
["Land_Sacks_goods_F",              "freestand", 0, "", 0, ""],
["Land_Sacks_heap_F",               "freestand", 0, "", 0, ""],

// -- office: wall-backed desks (chair on the front) + office chair + desk clutter (family "office"); office wall pieces (flat) --
["OfficeTable_01_new_F",            "anchor", 180, "office",  1, "wall"],
["OfficeTable_01_old_F",            "anchor", 180, "office",  1, "wall"],
["Land_TableDesk_F",                "anchor",   0, "office",  1, "wall"],
["Land_OfficeChair_01_F",           "seat",   180, "office",  0, ""],
["Land_Workbench_01_F",             "wall",   180, "",        0, ""],
["Land_OfficeCabinet_01_F",         "wall",   180, "",        0, ""],
["Land_OfficeCabinet_02_F",         "wall",   180, "",        0, ""],
["Land_Laptop_unfolded_F",          "clutter",  0, "office",  0, ""],
["Land_Laptop_F",                   "clutter",  0, "office",  0, ""],
["Land_Laptop_device_F",            "clutter",  0, "office",  0, ""],
["Land_Camera_01_F",                "clutter",  0, "office",  0, ""],
["Land_FMradio_F",                  "clutter",  0, "office",  0, ""],
["Land_HandyCam_F",                 "clutter",  0, "office",  0, ""],
["Leaflet_05_Stack_F",              "clutter",  0, "office",  0, ""],
["Leaflet_05_Old_F",                "clutter",  0, "office",  0, ""],
["Leaflet_05_New_F",                "clutter",  0, "office",  0, ""],
["Newspaper_01_F",                  "clutter",  0, "office",  0, ""],
["Land_Notepad_F",                  "clutter",  0, "office",  0, ""],
["Land_PenBlack_F",                 "clutter",  0, "office",  0, ""],
["Land_PenRed_F",                   "clutter",  0, "office",  0, ""],
["Land_PencilBlue_F",               "clutter",  0, "office",  0, ""],
["Land_PencilGreen_F",              "clutter",  0, "office",  0, ""],
["Land_PencilRed_F",                "clutter",  0, "office",  0, ""],
["Land_PencilYellow_F",             "clutter",  0, "office",  0, ""],
["Land_PensAndPencils_F",           "clutter",  0, "office",  0, ""],
["Land_Wallet_01_F",                "clutter",  0, "office",  0, ""],
["Land_Creditcard_01_F",            "clutter",  0, "office",  0, ""],
["Land_Key_01_F",                   "clutter",  0, "office",  0, ""],
["Land_Battery_F",                  "clutter",  0, "office",  0, ""],
["Land_DuctTape_F",                 "clutter",  0, "office",  0, ""],
["Land_Pliers_F",                   "clutter",  0, "office",  0, ""],
["Land_MultiMeter_F",               "clutter",  0, "office",  0, ""],
["Land_Screwdriver_V2_F",           "clutter",  0, "office",  0, ""],
["Land_Screwdriver_V1_F",           "clutter",  0, "office",  0, ""],
["Land_Meter3m_F",                  "clutter",  0, "office",  0, ""],
["Land_Wrench_F",                   "clutter",  0, "office",  0, ""],
["Land_DustMask_F",                 "clutter",  0, "office",  0, ""],
["Land_Gloves_F",                   "clutter",  0, "office",  0, ""],
["AluminiumFoil_01_F",              "clutter",  0, "office",  0, ""],
["Land_Matches_F",                  "clutter",  0, "office",  0, ""]
