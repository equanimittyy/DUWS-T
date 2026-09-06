// Throwable stone and molotov on base-game assets: a CfgAmmo pair, a CfgMagazines pair, and two muzzles
// appended to the base-game Throw weapon every unit carries. The molotov ammo does not explode; a Fired
// handler ignites it on landing and trails it in flight (client_init, fnc_molotov_ignite, fnc_molotov_trail).

class CfgAmmo
{
	class GrenadeHand;
	// A thrown rock: a hand grenade that never fuzes, so it flies and lands with no blast and no damage.
	class DUWS_StoneAmmo: GrenadeHand
	{
		model = "\A3\weapons_f\ammo\stone_3.p3d";
		simulation = "shotGrenade";
		timeToLive = 20;
		explosionTime = 30;   // > timeToLive, so it self-deletes before it could detonate
	};
	// The molotov bottle in flight: inert until it lands, where fnc_molotov_ignite scripts the fire.
	class DUWS_MolotovAmmo: GrenadeHand
	{
		model = "\A3\structures_f\items\food\bottleplastic_v1_f.p3d";
		simulation = "shotGrenade";
		timeToLive = 20;
		explosionTime = 30;
	};
};

class CfgMagazines
{
	class HandGrenade;
	class DUWS_StoneMag: HandGrenade
	{
		scope = 2;
		displayName = "Stone";
		displayNameShort = "Stone";
		descriptionShort = "Thrown stone.";
		model = "\A3\weapons_f\ammo\stone_3.p3d";
		ammo = "DUWS_StoneAmmo";
		count = 1;
		mass = 3;
	};
	class DUWS_MolotovMag: HandGrenade
	{
		scope = 2;
		displayName = "Molotov";
		displayNameShort = "Molotov";
		descriptionShort = "Improvised incendiary.";
		model = "\A3\structures_f\items\food\bottleplastic_v1_f.p3d";
		ammo = "DUWS_MolotovAmmo";
		count = 1;
		mass = 5;
	};
};

class CfgWeapons
{
	// Append muzzles to the base-game Throw weapon every unit already carries, so the stone and molotov
	// throw with no weapon to grant. removeAllWeapons strips Throw, so a stripped thrower re-adds "Throw".
	class Throw
	{
		class ThrowMuzzle;
		muzzles[] += {"DUWS_StoneMuzzle", "DUWS_MolotovMuzzle"};
		class DUWS_StoneMuzzle: ThrowMuzzle
		{
			magazines[] = {"DUWS_StoneMag"};
		};
		class DUWS_MolotovMuzzle: ThrowMuzzle
		{
			magazines[] = {"DUWS_MolotovMag"};
		};
	};
};
