// The default mission site-finder: accepts any candidate position the picker proposes and returns it
// unchanged. A mission that needs particular terrain overrides this with fnc_site_<name> (dispatched
// in fnc_stratmap by stripping "_mission" off the thread name); every mission without one keeps the
// picker's original behaviour through this.
//
// Contract: [_candidatePos] -> [] to reject the candidate, or [_precisePos, ...] to accept it.
params ["_pos"];
[_pos]
