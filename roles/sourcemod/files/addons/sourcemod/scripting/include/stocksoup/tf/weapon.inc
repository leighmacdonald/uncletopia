/**
 * Provides stocks that deal with weapon entities.
 */

#if defined __stocksoup_tf_weapon_included
	#endinput
#endif

#define __stocksoup_tf_weapon_included

#include <sdktools_functions>

/**
 * Gives a weapon ammo.  Rather, it gives ammo to the player holding the weapon.
 * This stock uses GivePlayerAmmo, so it obeys the maximum ammo count that the player can carry.
 * 
 * @return Amount of ammo actually given.
 */
stock int TF2_GiveWeaponAmmo(int weapon, int amount, bool supressSound = true) {
	int ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwner");
	
	if (client > 0 && client <= MaxClients) {
		return GivePlayerAmmo(client, amount, ammoType, supressSound);
	}
	return 0;
}

/**
 * Directly sets the amount of ammo a client can carry for a specific weapon.
 */
stock void TF2_SetWeaponAmmo(int weapon, int amount) {
	int ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwner");
	
	if (client > 0 && client <= MaxClients && ammoType != -1) {
		SetEntProp(client, Prop_Send, "m_iAmmo", amount, 4, ammoType);
	}
}

/**
 * Empties and refills the amount of ammo a client can carry for a specific weapon.
 */
stock void TF2_ResetWeaponAmmo(int weapon) {
	TF2_SetWeaponAmmo(weapon, 0);
	TF2_GiveWeaponAmmo(weapon, 1000);
}

/** 
 * Converts general weapon class names to the ones used by specific classes.
 * 
 * Reference:
 * https://github.com/sigsegv-mvm/sigsegv-mvm/blob/master/src/mod/bot/multiclass_weapon.cpp
 */
stock bool TF2_TranslateWeaponEntForClass(TFClassType playerClass, char[] className,
		int maxlen) {
	if (StrEqual(className, "tf_weapon_shotgun")) {
		switch (playerClass) {
			case TFClass_Soldier: {
				strcopy(className, maxlen, "tf_weapon_shotgun_soldier");
			}
			case TFClass_Pyro: {
				strcopy(className, maxlen, "tf_weapon_shotgun_pyro");
			}
			case TFClass_Heavy: {
				strcopy(className, maxlen, "tf_weapon_shotgun_hwg");
			}
			case TFClass_Engineer: {
				strcopy(className, maxlen, "tf_weapon_shotgun_primary");
			}
			default: {
				strcopy(className, maxlen, "tf_weapon_shotgun_primary");
			}
		}
		return true;
	} else if (StrEqual(className, "tf_weapon_pistol")) {
		switch (playerClass) {
			case TFClass_Scout: {
				strcopy(className, maxlen, "tf_weapon_pistol_scout");
				return true;
			}
			case TFClass_Engineer: {
				strcopy(className, maxlen, "tf_weapon_pistol");
			}
			default: {
				strcopy(className, maxlen, "tf_weapon_pistol");
			}
		}
	} else if (StrEqual(className, "tf_weapon_shovel")
			|| StrEqual(className, "tf_weapon_bottle")) {
		switch (playerClass) {
			case TFClass_Soldier: {
				strcopy(className, maxlen, "tf_weapon_shovel");
				return true;
			}
			case TFClass_DemoMan: {
				strcopy(className, maxlen, "tf_weapon_bottle");
				return true;
			}
		}
		return false;
		
	} else if (StrEqual(className, "saxxy")) {
		static char SAXXY_CLASSES[][] = {
			"saxxy", "tf_weapon_bat", "tf_weapon_club", "tf_weapon_shovel", "tf_weapon_bottle", 
			"tf_weapon_bonesaw", "tf_weapon_fists", "tf_weapon_fireaxe", "tf_weapon_knife",
			"tf_weapon_wrench"
		};
		
		if (playerClass) {
			strcopy(className, maxlen, SAXXY_CLASSES[view_as<int>(playerClass)]);
			return true;
		}
		
	} else if (StrEqual(className, "tf_weapon_throwable")) {
		switch (playerClass) {
			case TFClass_Medic: {
				strcopy(className, maxlen, "tf_weapon_throwable_primary");
			}
			default: {
				strcopy(className, maxlen, "tf_weapon_throwable_secondary");
			}
		}
		return true;
		
	} else if (StrEqual(className, "tf_weapon_parachute")) {
		switch (playerClass) {
			case TFClass_Soldier: {
				strcopy(className, maxlen, "tf_weapon_parachute_secondary");
				return true;
			}
			case TFClass_DemoMan: {
				strcopy(className, maxlen, "tf_weapon_parachute_primary");
				return true;
			}
		}
		return false;
	} else if (StrEqual(className, "tf_weapon_revolver")) {
		switch (playerClass) {
			case TFClass_Engineer: {
				strcopy(className, maxlen, "tf_weapon_revolver_secondary");
				return true;
			}
		}
	}
	return false;
}
