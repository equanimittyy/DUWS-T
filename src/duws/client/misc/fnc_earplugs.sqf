// Locality: client -- passed as an addAction function value in client/client_init.sqf and
// onPlayerRespawn.sqf, so it runs on whoever toggles their earplugs.

if (soundVolume == 0.15) then {
	1 fadesound 1;
	//remove
	hint localize "STR_DUWS_T_b5ri931u";
} else {
	1 fadesound 0.15;
	hint localize "STR_DUWS_T_6ecpsh0b";
};	

