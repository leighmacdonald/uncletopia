/**
 * [TF2] Econ Data
 * Functions to read item information from game memory.
 */

#if defined __tf_econ_data_included
	#endinput
#endif

#include <tf2_stocks>

#define __tf_econ_data_included

/**
 * Item definition index for the special "default" item entry, which is returned by the game's
 * CEconItemSchema::GetItemDefinition() if the given item definition does not exist.
 * 
 * Not a valid item, but points to a valid item definition, so this does return information when
 * `TF2Econ_Get*` functions are called on it.
 */
enum {
	TF_ITEMDEF_DEFAULT = -1,
};

/**
 * Value for TF2Econ_GetParticleAttributeList to look up the items in a specific list.
 */
enum TFEconParticleSet {
	ParticleSet_All,
	ParticleSet_CosmeticUnusualEffects,
	ParticleSet_WeaponUnusualEffects,
	ParticleSet_TauntUnusualEffects
};

/**
 * Callback for `TF2Econ_GetItemList`.  Return `true` if the specified item definition index
 * should be added to the returned `ArrayList`.
 */
typedef ItemFilterCriteria = function bool(int itemdef, any data);

/**
 * Callback for `TF2Econ_GetAttributeList`.  Return `true` if the specified attribute definition
 * index should be added to the returned `ArrayList`.
 * 
 * This prototype is the same as `TF2Econ_GetItemList`.  Take care to not mix up the callbacks.
 */
typedef AttributeFilterCriteria = function bool(int attrdef, any data);

/**
 * Returns true if there is an item corresponding to the given item definition index.
 * TF_ITEMDEF_DEFAULT returns false here.
 */
native bool TF2Econ_IsValidItemDefinition(int itemdef);

/**
 * Returns true if item is in base set (corresponds to the "baseitem" key).
 */
native bool TF2Econ_IsItemInBaseSet(int itemdef);

/**
 * Returns the item's name (corresponds to the "name" key).
 */
native bool TF2Econ_GetItemName(int itemdef, char[] name, int maxlen);

/**
 * Returns the item's localization token name (corresponds to the "item_name" key).
 */
native bool TF2Econ_GetLocalizedItemName(int itemdef, char[] name, int maxlen);

/**
 * Stores the item class name in the given buffer and returns true if given a valid item
 * definition, otherwise returns false.
 */
native bool TF2Econ_GetItemClassName(int itemdef, char[] buffer, int maxlen);

/**
 * Returns the item's loadout slot for the given class, or -1 if the item definition or
 * item / class combination is not valid.  This is *not* the same value as the weapon slot used
 * in SourceMod's GetPlayerWeaponSlot native; not all values match.
 * 
 * More information about this distinction is available here:
 * https://github.com/nosoop/SM-TFEconData/wiki/Porting-TF2IDB-and-TF2II-plugins-to-TFEconData#notes-about-loadout-slots
 */
native int TF2Econ_GetItemLoadoutSlot(int itemdef, TFClassType playerClass);

/**
 * Returns the item's default loadout slot.
 */
native int TF2Econ_GetItemDefaultLoadoutSlot(int itemdef);

/**
 * Returns the given item's equipment region mask.  This mask can be and-tested with another
 * mask to determine if items conflict.
 */
native int TF2Econ_GetItemEquipRegionMask(int itemdef);

/**
 * Returns the given item's equipment region groups as a bitfield.
 * 
 * Internally, this is called an EquipRegionBitMask, but for the sake of clarity it's been
 * renamed in this library to specify equip region groups.
 */
native int TF2Econ_GetItemEquipRegionGroupBits(int itemdef);

/**
 * Stores the minimum and maximum item level range in the given cell references and
 * returns true for a valid item definition, otherwise returns false.
 */
native bool TF2Econ_GetItemLevelRange(int itemdef, int &iMinLevel, int &iMaxLevel);

/**
 * Returns the given item's statically defined quality.
 */
native int TF2Econ_GetItemQuality(int itemdef);

/**
 * Returns the given item's rarity, or -1 if the item does not have a statically defined rarity.
 */
native int TF2Econ_GetItemRarity(int itemdef);

/**
 * Returns an `ArrayList` containing attribute defindex / value pairs corresponding to the given
 * item definition, or `null` if not a valid item definition.
 * 
 * The value is a raw 32-bit value which may represent an int, float, or pointer.
 * 
 * This handle is owned by the calling plugin, so it should be `delete`d when not needed
 * anymore.
 */
native ArrayList TF2Econ_GetItemStaticAttributes(int itemdef);

/**
 * Returns an arbitrary string from an item definition's KeyValues structure.
 * You may use subkey notation ('/') to retrieve nested values.
 * 
 * Returns true if the output buffer is not empty.
 */
native bool TF2Econ_GetItemDefinitionString(int itemdef, const char[] key,
		char[] buffer, int maxlen, const char[] defaultValue = "");

/**
 * Returns an ArrayList containing all valid item definition indices.  If an ItemFilterCriteria
 * callback is passed in, the ArrayList only contains defindexes that the callback returned
 * `true` on.
 * 
 * The resulting ArrayList does not have a defined order.
 * 
 * This handle is owned by the calling plugin, so it should be `delete`d when not needed
 * anymore.
 */
native ArrayList TF2Econ_GetItemList(ItemFilterCriteria func = INVALID_FUNCTION, any data = 0);

/**
 * Returns true if the specified className was translated for the given player class.
 * The buffer is not modified if the className was not translated.
 * 
 * This is used for multiclass weapons -- if given a player class-specific classname,
 * this function returns false.
 */
native bool TF2Econ_TranslateWeaponEntForClass(char[] className, int maxlen,
		TFClassType playerClass);

/**
 * Returns true if the given loadout slot index has a name, false otherwise.
 */
native bool TF2Econ_TranslateLoadoutSlotIndexToName(int index, char[] buffer, int maxlen);

/**
 * Returns the loadout slot index for the given slot name, or -1 if not a valid slot.
 */
native int TF2Econ_TranslateLoadoutSlotNameToIndex(const char[] slotName);

/**
 * Returns the number of valid loadout slots.
 */
native int TF2Econ_GetLoadoutSlotCount();

/**
 * Returns true if there is an attribute corresponding to the given attribute definition index.
 */
native bool TF2Econ_IsValidAttributeDefinition(int attrdef);

/**
 * Returns true if the attribute is considered hidden (corresponds to the "hidden" key).
 */
native bool TF2Econ_IsAttributeHidden(int attrdef);

/** 
 * Returns true if the attribute is stored as an integer (corresponds to the "stored_as_integer"
 * key).
 * 
 * Not sure when this is actually used -- certain attributes such as
 * "mod max primary clip override" are flagged as true, but are float values when retrieved
 * via `TF2Econ_GetItemStaticAttributes()`.
 */
native bool TF2Econ_IsAttributeStoredAsInteger(int attrdef);

/**
 * Stores the attribute name in the given buffer and returns true if given a valid attribute
 * definition, otherwise returns false.
 */
native bool TF2Econ_GetAttributeName(int attrdef, char[] buffer, int maxlen);

/**
 * Stores the attribute class name in the given buffer and returns true if given a valid
 * attribute definition, otherwise returns false.
 */
native bool TF2Econ_GetAttributeClassName(int attrdef, char[] buffer, int maxlen);

/**
 * Returns an arbiitrary string from an item attribute definition's KeyValues structure.
 * You may use subkey notation ('/') to retrieve nested values.
 * 
 * Returns true if the output buffer is not empty.
 */
native bool TF2Econ_GetAttributeDefinitionString(int attrdef, const char[] key,
		char[] buffer, int maxlen, const char[] defaultValue = "");

/**
 * Returns the attribute definition index for a given name, or -1 if the name does not
 * correspond to an attribute.
 */
native int TF2Econ_TranslateAttributeNameToDefinitionIndex(const char[] name);

/**
 * Returns an ArrayList containing all valid attribute definition indices.  If an
 * AttributeFilterCriteria callback is passed in, the ArrayList only contains attribute
 * definition indices that the callback returned `true` on.
 * 
 * The resulting ArrayList does not have a defined order.
 * 
 * This handle is owned by the calling plugin, so it should be `delete`d when not needed
 * anymore.
 */
native ArrayList TF2Econ_GetAttributeList(AttributeFilterCriteria func = INVALID_FUNCTION,
		any data = 0);

/**
 * Stores the quality name in the given buffer and returns true if given a valid quality value,
 * otherwise returns false;
 */
native bool TF2Econ_GetQualityName(int quality, char[] buffer, int maxlen);

/**
 * Returns the quality value for a given name, or -1 if the name does not correspond to an item
 * quality.
 */
native int TF2Econ_TranslateQualityNameToValue(const char[] name, bool caseSensitive = true);

/**
 * Returns an ArrayList containing all valid quality values.
 * 
 * This handle is owned by the calling plugin, so it should be `delete`d when not needed
 * anymore.
 */
native ArrayList TF2Econ_GetQualityList();

/**
 * Stores the rarity name in the given buffer and returns true if given a valid rarity value,
 * otherwise returns false;
 * 
 * Note:  Rarity names returned by this value correspond to the localized "weapon grade" names,
 * but are completely different.  "Civilian Grade" corresponds to "common", "Freelance Grade" to
 * "uncommon", and so on.
 */
native bool TF2Econ_GetRarityName(int rarity, char[] buffer, int maxlen);

/**
 * Returns the rarity value for a given name, or -1 if the name does not correspond to an item
 * rarity.
 */
native int TF2Econ_TranslateRarityNameToValue(const char[] name, bool caseSensitive = true);

/**
 * Returns an ArrayList containing all valid rarity values.
 * 
 * This handle is owned by the calling plugin, so it should be `delete`d when not needed
 * anymore.
 */
native ArrayList TF2Econ_GetRarityList();

/**
 * Returns a StringMap containing all valid equip region names mapped to their equip region
 * group indices.
 */
native StringMap TF2Econ_GetEquipRegionGroups();

/**
 * Returns true if the given equip region name is valid, storing its equip region mask in the
 * given by-ref``mask` argument.
 */
native bool TF2Econ_GetEquipRegionMask(const char[] equipRegion, int &mask);

/**
 * Stores the "system" name for the given particle attribute index in the given buffer.
 * Returns true if the index corresponds to a particle, false otherwise.
 */
native bool TF2Econ_GetParticleAttributeSystemName(int particleIndex, char[] buffer, int maxlen);

/**
 * Returns an ArrayList containing all particle attribute values, or just those in a particular
 * set (currently valid sets are for cosmetic, taunt, or weapon effects).  Particle effects in
 * the "other_particles" and "killstreak_eyeglows" categories are only available in "all" set.
 * 
 * Throws an error if the given TFEconParticleSet value is not recognized.
 * 
 * Handle is owned by the calling plugin.
 */
native ArrayList TF2Econ_GetParticleAttributeList(
		TFEconParticleSet particleSet = ParticleSet_All);

/**
 * Returns an ArrayList containing all valid paint kit protodef indices.  `delete` when
 * unneeded.
 * 
 * This includes paint kits that are only applied to weapons, but does not include unused paint
 * kits (as defined in resource/tf_proto_obj_defs_english.txt and other languages).
 * 
 * Handle is owned by the calling plugin.
 */
native ArrayList TF2Econ_GetPaintKitDefinitionList();

/**
 * Returns the definition index of a given map name, or 0 if not valid.
 * 
 * Note that the name "Missing" also points to a valid map definition, and will also return 0;
 * the zero-on-invalid case is intended to match the behavior of the game.
 */
native int TF2Econ_GetMapDefinitionIndexByName(const char[] name);

/**
 * Returns the address of the singleton CTFItemSchema (subclass of CEconItemSchema).
 * 
 * Here be dragons.
 */
native Address TF2Econ_GetItemSchemaAddress();

/**
 * Returns the address of the singleton CProtoBufScriptObjectDefinitionManager.
 * 
 * Here be dragons.
 */
native Address TF2Econ_GetProtoDefManagerAddress();

/**
 * Returns the address of the CEconItemDefinition for the item with the given definition index,
 * or Address_Null if not valid.  The special "default" item definition is returned iff
 * TF_ITEMDEF_DEFAULT is used as the defindex.
 * 
 * Here be dragons.
 */
native Address TF2Econ_GetItemDefinitionAddress(int itemdef);

/**
 * Returns the address of the CEconItemAttributeDefinition for the attribute with the given
 * definition index, or Address_Null if not valid.
 * 
 * Here be dragons.
 */
native Address TF2Econ_GetAttributeDefinitionAddress(int attrdef);

/**
 * Returns the address of the CEconItemRarityDefinition for the rarity with the given value,
 * or Address_Null if not valid.
 * 
 * You know the drill at this point.
 */
native Address TF2Econ_GetRarityDefinitionAddress(int rarity);

/**
 * Returns the address of the attachedparticlesystem_t for the system corresponding to the given
 * index, or Address_Null if not valid.
 */
native Address TF2Econ_GetParticleAttributeAddress(int particleIndex);

/**
 * Returns the address of the CPaintKitDefinition for the paintkit with the given protodef
 * index, or Address_Null if not valid.
 */
native Address TF2Econ_GetPaintKitDefinitionAddress(int protoDefIndex);

/**
 * @deprecated Renamed native to TF2Econ_IsValidItemDefinition so there is a better distinction
 * between item and attribute definitions.
 * 
 * This native will still be present for backwards compatibility.
 */
#pragma deprecated Use TF2Econ_IsValidItemDefinition instead
native bool TF2Econ_IsValidDefinitionIndex(int itemdef);

/**
 * @deprecated Renamed native to TF2Econ_GetItemLoadoutSlot to remove the confusion on weapon
 * and loadout slots.
 * 
 * This native will still be present for backwards compatibility.
 */
#pragma deprecated Use TF2Econ_GetItemLoadoutSlot instead
native int TF2Econ_GetItemSlot(int itemdef, TFClassType playerClass);

public SharedPlugin __pl_tf_econ_data = {
	name = "tf_econ_data",
	file = "tf_econ_data.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
