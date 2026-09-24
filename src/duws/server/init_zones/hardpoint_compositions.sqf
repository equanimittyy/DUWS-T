// Locality: server -- hardpoint layout data, read by the hardpoint placer.
//
// Offsets are in a frame whose +Y is the hardpoint's facing. The placer rotates the whole layout
// about the site centre, so a heading turns the cover with the core instead of turning the core
// inside a fixed ring of props.
//
// A global's suffix is the type token carried in hardpoint_type_array, so the placer resolves a
// composition by name rather than through a switch that has to be taught every new type. Each layout
// is an Eden composition: docs/info/architecture/composition_tooling.md.

DUWS_hardpointComp_OP = ["duws_hp_op"] call fnc_composition_rows;
DUWS_hardpointComp_ROADBLOCK = ["duws_hp_roadblock"] call fnc_composition_rows;
DUWS_hardpointComp_AA = ["duws_hp_aa"] call fnc_composition_rows;
DUWS_hardpointComp_AT = ["duws_hp_at"] call fnc_composition_rows;
DUWS_hardpointComp_MG = ["duws_hp_mg"] call fnc_composition_rows;
DUWS_hardpointComp_GMG = ["duws_hp_gmg"] call fnc_composition_rows;
DUWS_hardpointComp_MORTAR = ["duws_hp_mortar"] call fnc_composition_rows;
DUWS_hardpointComp_ARTY = ["duws_hp_arty"] call fnc_composition_rows;
// A fortified base rather than a bare nest -- HBarrier-walled, razorwire-ringed, seven crewed HMG
// nests and an AA static -- because the mast outlives its garrison and must cost the player far more
// than a combat hardpoint to reach.
DUWS_hardpointComp_RADIO = ["duws_hp_radio"] call fnc_composition_rows;
