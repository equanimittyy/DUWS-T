_length = _this select 0;

_operation = "Operation ";
_first = "--blank--";

_first_array = [
"Homing",
"Flaming",
"Screaming",
"Final",
"Fiery",
"Brave",
"Hardened",
"Crazy",
"Last",
"Raging",
"Blazing",
"Covered",
"Smoking",
"Firing",
"Mobile",
"Crimson",
"Broken",
"Lightning",
"Surviving",
"Enduring",
"Hunting",
"Killing",
"Fragging",
"Overwhelming",
"Thrusting",
"Lone",
"Armed",
"Banned",
"Sleeping",
"Retired",
"Retaliating",
"Rushing",
"Burning",
"Striking",
"Sweeping",
"Masterful",
"Mourning",
"Black",
"Yellow",
"Purple",
"Turquoise",
"Red",
"Green",
"Blue",
"Smashing",
"Drowned",
"Swift",
"Courageous",
"Fearful",
"Barking",
"Ruthless",
"Rightful",
"Hidden",
"Marked"
];

_second_array = [
"Switchblade",
"Knight",
"Guardian",
"Trident",
"Wraith",
"Rage",
"Hawk",
"Thunder",
"Poltergeist",
"Steel",
"Grave",
"Shield",
"Iron",
"Assault",
"Arrow",
"Bolt",
"Freedom",
"Sword",
"Lance",
"Witch",
"Nightmare",
"Force",
"Lion",
"Claw",
"Wolf",
"Blade",
"Sabre",
"Warrior",
"God",
"Cannon",
"Vengeance",
"Dagger",
"Fist",
"Warlock",
"Copper",
"Bronze",
"Talon",
"Viper",
"Cobra",
"Falcon",
"Eagle",
"Onslaught",
"Phoenix",
"Raven",
"Dragon",
"Crusader",
"Devil",
"Angel",
"Hammer",
"Cleaver",
"Nova",
"Marauder",
"Dart",
"Rodent",
"Swordfish",
"Boar",
"Rhino",
"Shark",
"Goul",
"Anvil",
"Star",
"Sun",
"Morgenstern",
"Gladius",
"Chieftain",
"Spirit",
"Paladin"
];

_first_array = _first_array call BIS_fnc_arrayShuffle;
_second_array = _second_array call BIS_fnc_arrayShuffle;
_first = "";

if (_length == 0) then {
	_first = _first_array call BIS_fnc_selectRandom;
};

_second = "--blank--";
_second = _second_array call BIS_fnc_selectRandom;

if (_length==1) exitWith {
    _second
};

if (_length==0) then {
    _gen_operation_fullname = _operation+_first+_second;
    _gen_operation_fullname
};