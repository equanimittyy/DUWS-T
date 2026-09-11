class CfgSounds
{
	sounds[] = {};
	class loadgun
	{
		// how the sound is referred to in the editor (e.g. trigger effects)
		name = "loadgun";
		// filename, volume, pitch
		sound[] = {"duws\shared\media\sounds\loadgun.ogg", 1, 1};
		titles[] = {};
	};	
	class boots
	{
		// how the sound is referred to in the editor (e.g. trigger effects)
		name = "boots";
		// filename, volume, pitch
		sound[] = {"duws\shared\media\sounds\boots.ogg", 2, 1};
		titles[] = {};
	};
	class rappel
    {
        name = "rappel";
        sound[] = {"duws\shared\media\sounds\fastrope.ogg", 3, 0.9};
        titles[] = {};
    };
    class killhouse_bell {
        name = "killhouse_bell";
        sound[] = {"duws\shared\media\sounds\bell.ogg", 3, 1};
        titles[] = {};
    };
    class DUWS_Radio_Start {
        name = "DUWS_Radio_Start";
        sound[] = {"duws\shared\media\sounds\radioinnout.ogg", 1.088, 1};
        titles[] = {};
    };
    // Angry-crowd loop for the harassment mob (say3D'd on a live rioter, re-fired each clip-length in
    // fnc_random_event_mob). WAV, not OGG: the source was transcoded offline with no OGG encoder available.
    class DUWS_angry_mob {
        name = "DUWS_angry_mob";
        sound[] = {"duws\shared\media\sounds\angry_mob.wav", 1.4, 1};
        titles[] = {};
    };
};
