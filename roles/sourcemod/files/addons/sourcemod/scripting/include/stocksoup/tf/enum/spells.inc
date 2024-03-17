/**
 * Provides an enumerable definition of TF2 spellbook spells, as well as stocks for getting /
 * setting spell type and number of charges.
 */

#if defined __stocksoup_tf_enum_spells_included
	#endinput
#endif

#define __stocksoup_tf_enum_spells_included

#include <sdktools>

/**
 * Names based off the corresponding localization strings in resource/tf_english.txt
 */
enum TFSpellType {
	TFSpell_Invalid = -1,
	TFSpell_Fireball = 0,
	TFSpell_Bats,
	TFSpell_OverHeal,
	TFSpell_MIRV,
	TFSpell_BlastJump,
	TFSpell_Stealth,
	TFSpell_Teleport,
	TFSpell_LightningBall,
	TFSpell_Athletic,
	TFSpell_Meteor,
	TFSpell_SpawnBoss,
	TFSpell_SkeletonHorde
};

stock TFSpellType TF2_GetPlayerSpellType(int client) {
	int spellbook = TF2_GetPlayerSpellBook(client);
	if (IsValidEntity(spellbook)) {
		TFSpellType spell = GetEntProp(spellbook, Prop_Send, "m_iSelectedSpellIndex");
		return (spell && spell < TFSpellType)? spell : TFSpell_Invalid;
	}
	return TFSpell_Invalid;
}

stock bool TF2_SetPlayerSpellType(int client, TFSpellType spell) {
	int spellbook = TF2_GetPlayerSpellBook(client);
	if (IsValidEntity(spellbook)) {
		SetEntProp(spellbook, Prop_Send, "m_iSelectedSpellIndex", spell);
		return true;
	}
	return false;
}

stock int TF2_GetPlayerSpellCharges(int client) {
	int spellbook = TF2_GetPlayerSpellBook(client);
	if (IsValidEntity(spellbook)) {
		return GetEntProp(spellbook, Prop_Send, "m_iSpellCharges");
	}
	return 0;
}

stock int TF2_SetPlayerSpellCharges(int client, int count) {
	int spellbook = TF2_GetPlayerSpellBook(client);
	if (IsValidEntity(spellbook)) {
		SetEntProp(spellbook, Prop_Send, "m_iSpellCharges", count);
		return true;
	}
	return false;
}

stock int TF2_GetPlayerSpellBook(int client) {
	int spellbook = -1;
	while ((spellbook = FindEntityByClassname(spellbook, "tf_weapon_spellbook")) != -1) {
		if (GetEntPropEnt(spellbook, Prop_Send, "m_hOwnerEntity") == client
				&& !GetEntProp(spellbook, Prop_Send, "m_bDisguiseWeapon")) {
			return spellbook;
		}
	}
	return INVALID_ENT_REFERENCE;
}
