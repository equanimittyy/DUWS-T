// Build identity, logged by INIT.sqf as the first line of every run. repack.cmd overwrites
// this file inside its staging copy only, so the tracked value below is what an unpacked
// working tree reports and no commit ever carries a hash that the next commit makes stale.
#define DUWS_BUILD_STAMP "unpacked-source"
