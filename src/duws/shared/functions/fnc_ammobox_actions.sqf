// Locality: all machines; callers remoteExec to target 0, and each machine adds its own local
// entries. The addAction bodies run on the machine that triggers them, not here.
//
// Both entries are attached by one broadcast rather than two, because a JIP id keyed on an object
// is that object's netId: a second broadcast against the same box would evict the first from the
// queue and leave late joiners with one of the two. Keying the pair on the box also means the
// queue entry dies with it, which the Mobile HQ's box relies on -- undeploy deletes it.
#include "..\includes\action_style.hpp"

params ["_box"];

_box addAction [ACT_EQUIP("STR_DUWS_T_160jkc3a"), fnc_duws_Arsenal, [], 80, false, false, "", "_this distance _target < 8"];
_box addAction [ACT_AID("STR_DUWS_T_xfgokhbc"), fnc_AI_rearm, [], 60, false, false, "", "_this distance _target < 8"];
