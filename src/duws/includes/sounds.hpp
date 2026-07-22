class CfgSounds
{
	sounds[] = {};
	class loadgun
	{
		// how the sound is referred to in the editor (e.g. trigger effects)
		name = "loadgun";
		// filename, volume, pitch
		sound[] = {"duws\sounds_npics\support\loadgun.ogg", 1, 1};
		titles[] = {};
	};	
	class boots
	{
		// how the sound is referred to in the editor (e.g. trigger effects)
		name = "boots";
		// filename, volume, pitch
		sound[] = {"duws\sounds_npics\support\boots.ogg", 2, 1};
		titles[] = {};
	};
	class rappel
    {
        name = "rappel";
        sound[] = {"duws\sounds_npics\support\fastrope.ogg", 3, 0.9};
        titles[] = {};
    };
    class DUWS_Radio_Start {
        name = "DUWS_Radio_Start";
        sound[] = {"duws\sounds_npics\support\radioinnout.ogg", 1.7, 1};
        titles[] = {};
    };
    class DUWS_Radio_End {
        name = "DUWS_Radio_End";
        sound[] = {"duws\sounds_npics\support\radioinnout.ogg", 1.5, 1.1};
        titles[] = {};
    };
};
