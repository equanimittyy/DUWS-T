
// this enables manual save
//enableSaving false;
if (!isServer) exitWith {};
if (!savingEnabled) then {
	hint localize "STR_DUWS_T_vmhut3p1";
	enableSaving true;
};
sleep 0.1;
saveGame;
