if (WARCOM_blufor_ap < 15) exitWith {hint localize "STR_DUWS_T_nysmk8sa";};

commandpointsblu1 = commandpointsblu1 + 10;
WARCOM_blufor_ap = WARCOM_blufor_ap - 15;

ctrlSetText [1000, format["%1",commandpointsblu1]];
ctrlSetText [1002, format["%1",WARCOM_blufor_ap]];

publicVariable "commandpointsblu1";
publicVariable "WARCOM_blufor_ap";

hint localize "STR_DUWS_T_vvmvw9ia";
