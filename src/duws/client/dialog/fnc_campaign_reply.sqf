// Locality: client -- the clipboard and the profile are the machine's own, so the server sends both writes here.
params ["_kind", "_arg"];
switch (_kind) do {
	case "refused": { hint format [localize "STR_DUWS_T_fork_import_refused", localize _arg] };
	case "export": {
		copyToClipboard _arg;
		hint localize "STR_DUWS_T_fork_exported";
	};
	case "carry": {
		profileNamespace setVariable ["DUWST_carry", _arg];
		saveProfileNamespace;
	};
};
