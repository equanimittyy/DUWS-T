_loop = true;

playmusic selectRandom["wasteland","fallout","Track11_StageB_stealth","Track09_Night_percussions","BackgroundTrack01a_F","LeadTrack01_F_EPA","LeadTrack02_F"];
waitUntil {chosen_settings};
sleep 300;

while {_loop} do  
{
    waitUntil {sleep 30;daytime < 1 or daytime > 2};
    playmusic "wasteland";

    waitUntil {sleep 30;daytime > 2};
    playmusic "fallout";

    waitUntil {sleep 30;daytime > 4};
    playmusic "Track11_StageB_stealth";

    waitUntil {sleep 30;daytime > 7};
    playMusic "Track09_Night_percussions";

    waitUntil {sleep 30;daytime > 9};
    playMusic "BackgroundTrack01a_F";

    waitUntil {sleep 30;daytime > 12};
    playMusic "LeadTrack01_F_EPA";

    waitUntil {sleep 30;daytime > 16};
    playMusic "LeadTrack02_F";

};