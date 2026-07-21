
player setVariable["Saved_Loadout", getUnitLoadout player];
player setVariable["Saved_Face", face player];      // 保存面部
player setVariable["Saved_Speaker", speaker player]; // 保存声音
player setVariable["Saved_Goggles", goggles player];
// FOR SP RESPAWN SCRIPT
/*
player setVariable["Player_Name", name player];

if (!isMultiplayer) then {
	nul = [player] execVM "misc\SP_respawn.sqf";
};
*/