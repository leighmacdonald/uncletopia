/**
 * Natives / functions for accessing CEconItemDefinition / CTFItemDefinition properties.
 */

Address offs_CEconItemDefinition_pKeyValues,
		offs_CEconItemDefinition_u8MinLevel,
		offs_CEconItemDefinition_u8MaxLevel,
		offs_CEconItemDefinition_u8ItemQuality,
		offs_CEconItemDefinition_si8ItemRarity,
		offs_CEconItemDefinition_AttributeList,
		offs_CEconItemDefinition_pszLocalizedItemName,
		offs_CEconItemDefinition_pszItemClassname,
		offs_CEconItemDefinition_pszItemName,
		offs_CEconItemDefinition_bBaseItem,
		offs_CEconItemDefinition_bitsEquipRegionGroups,
		offs_CEconItemDefinition_bitsEquipRegionConflicts;
Address offs_CEconItemDefinition_aiItemSlot,
		offs_CTFItemDefinition_iDefaultItemSlot;

Address sizeof_static_attrib_t;

// in CEconItemDefinition, defindex is at 0x08 (we never use this information though)

/**
 * native bool(int itemdef, char[] buffer, int maxlen);
 * 
 * Stores the internal item name into the buffer.  Returns true if the item definition exists.
 */
int Native_GetItemName(Handle hPlugin, int nParams) {
	int defindex = GetNativeCell(1);
	int maxlen = GetNativeCell(3);
	
	char[] buffer = new char[maxlen];
	bool bResult = LoadEconItemDefinitionString(defindex, offs_CEconItemDefinition_pszItemName,
			buffer, maxlen);
	
	if (bResult) {
		SetNativeString(2, buffer, maxlen, true);
	}
	return bResult;
}

/**
 * native bool(int itemdef, char[] buffer, int maxlen);
 * 
 * Stores the item's localization token into the buffer.  Returns true if the item definition
 * exists.
 */
int Native_GetLocalizedItemName(Handle hPlugin, int nParams) {
	int defindex = GetNativeCell(1);
	int maxlen = GetNativeCell(3);
	
	char[] buffer = new char[maxlen];
	bool bResult = LoadEconItemDefinitionString(defindex,
			offs_CEconItemDefinition_pszLocalizedItemName, buffer, maxlen);
	
	if (bResult) {
		SetNativeString(2, buffer, maxlen, true);
	}
	return bResult;
}

/**
 * native bool(int itemdef, char[] buffer, int maxlen);
 * 
 * Stores the item class name into the buffer.  Returns true if the item definition exists.
 */
int Native_GetItemClassName(Handle hPlugin, int nParams) {
	int defindex = GetNativeCell(1);
	int maxlen = GetNativeCell(3);
	
	char[] buffer = new char[maxlen];
	bool bResult = LoadEconItemDefinitionString(defindex,
			offs_CEconItemDefinition_pszItemClassname, buffer, maxlen);
	
	if (bResult) {
		SetNativeString(2, buffer, maxlen, true);
	}
	return bResult;
}

/**
 * native int(int itemdef, TFClassType playerClass);
 * 
 * Stores the item loadout slot for the given class.  Returns -1 if the item definition does 
 * not exist or if the item is not valid for the given player class.
 */
int Native_GetItemSlot(Handle hPlugin, int nParams) {
	int defindex = GetNativeCell(1);
	int playerClass = GetNativeCell(2);
	
	Address pItemDef = GetEconItemDefinition(defindex);
	if (!pItemDef) {
		return -1;
	}
	
	return LoadFromAddress(pItemDef + offs_CEconItemDefinition_aiItemSlot +
			view_as<Address>(playerClass * 4), NumberType_Int32);
}

/**
 * native int();
 * 
 * Returns the default assigned item loadout slot, or -1 if the item definition does not exist.
 */
int Native_GetItemDefaultSlot(Handle hPlugin, int nParams) {
	int defindex = GetNativeCell(1);
	Address pItemDef = GetEconItemDefinition(defindex);
	if (!pItemDef) {
		return -1;
	}
	return LoadFromAddress(pItemDef + offs_CTFItemDefinition_iDefaultItemSlot,
			NumberType_Int32);
}

/**
 * native int(int itemdef);
 * 
 * Returns a bitset indicating group conflicts (that is, item cannot be worn with an item with
 * that bit set).
 */
int Native_GetItemEquipRegionMask(Handle hPlugin, int nParams) {
	int defindex = GetNativeCell(1);
	Address pItemDef = GetEconItemDefinition(defindex);
	
	if (!pItemDef) {
		ThrowNativeError(1, "Item definition index %d is not valid", defindex);
	}
	
	return LoadFromAddress(
			pItemDef + offs_CEconItemDefinition_bitsEquipRegionConflicts, NumberType_Int32);
}

/**
 * native int(int itemdef);
 * 
 * Returns a bitset indicating item group membership.
 */
int Native_GetItemEquipRegionGroupBits(Handle hPlugin, int nParams) {
	int defindex = GetNativeCell(1);
	Address pItemDef = GetEconItemDefinition(defindex);
	
	if (!pItemDef) {
		ThrowNativeError(1, "Item definition index %d is not valid", defindex);
	}
	
	return LoadFromAddress(
			pItemDef + offs_CEconItemDefinition_bitsEquipRegionGroups, NumberType_Int32);
}

/**
 * native bool(int itemdef, int &min, int &max);
 * 
 * Returns true on a valid item, populating `min` and `max` with the item's min / max level
 * range.
 */
int Native_GetItemLevelRange(Handle hPlugin, int nParams) {
	int defindex = GetNativeCell(1);
	
	Address pItemDef = GetEconItemDefinition(defindex);
	if (!pItemDef) {
		return false;
	}
	
	int iMinLevel = LoadFromAddress(pItemDef + offs_CEconItemDefinition_u8MinLevel,
			NumberType_Int8);
	int iMaxLevel = LoadFromAddress(pItemDef + offs_CEconItemDefinition_u8MaxLevel,
			NumberType_Int8);
	
	SetNativeCellRef(2, iMinLevel);
	SetNativeCellRef(3, iMaxLevel);
	return true;
}

/**
 * native int(int itemdef);
 * 
 * Returns the item's given item quality.  Throws if the item is not valid.
 */
int Native_GetItemQuality(Handle hPlugin, int nParams) {
	int defindex = GetNativeCell(1);
	Address pItemDef = GetEconItemDefinition(defindex);
	if (!pItemDef) {
		ThrowNativeError(1, "Item definition index %d is not valid", defindex);
	}
	
	int quality = LoadFromAddress(pItemDef + offs_CEconItemDefinition_u8ItemQuality,
			NumberType_Int8);
	
	// sign extension on byte -- valve's econ support lib uses "any" as a quality of -1
	// this is handled through CEconItemSchema::BGetItemQualityFromName()
	return (quality >> 7)? 0xFFFFFF00 | quality : quality;
}

/**
 * native int(int itemdef);
 * 
 * Returns the item's given item rarity.  Throws if the item is not valid.
 */
int Native_GetItemRarity(Handle hPlugin, int nParams) {
	int defindex = GetNativeCell(1);
	Address pItemDef = GetEconItemDefinition(defindex);
	
	if (!pItemDef) {
		ThrowNativeError(1, "Item definition index %d is not valid", defindex);
	}
	
	int rarity = LoadFromAddress(pItemDef + offs_CEconItemDefinition_si8ItemRarity,
			NumberType_Int8);
	
	// sign extension on byte -- items that don't have rarities assigned are -1
	return (rarity >> 7)? 0xFFFFFF00 | rarity : rarity;
}

/**
 * native ArrayList<int, any>(int itemdef);
 * 
 * Returns an ArrayList containing the item's static attribute index / value pairs.
 */
int Native_GetItemStaticAttributes(Handle hPlugin, int nParams) {
	int defindex = GetNativeCell(1);
	
	Address pItemDef = GetEconItemDefinition(defindex);
	if (!pItemDef) {
		return view_as<int>(INVALID_HANDLE);
	}
	
	// get size from CUtlVector
	int nAttribs = LoadFromAddress(
			pItemDef + offs_CEconItemDefinition_AttributeList + view_as<Address>(0x0C),
			NumberType_Int32);
	Address pAttribList = DereferencePointer(pItemDef + offs_CEconItemDefinition_AttributeList);
	
	// struct { attribute_defindex, value } // (TF2)
	ArrayList attributeList = new ArrayList(2, nAttribs);
	for (int i; i < nAttribs; i++) {
		Address pStaticAttrib = pAttribList
				+ view_as<Address>(i * view_as<int>(sizeof_static_attrib_t));
		
		int attrIndex = LoadFromAddress(pStaticAttrib, NumberType_Int16);
		any attrValue = LoadFromAddress(pStaticAttrib + view_as<Address>(0x04),
				NumberType_Int32);
		
		attributeList.Set(i, attrIndex, 0);
		attributeList.Set(i, attrValue, 1);
	}
	return MoveHandle(attributeList, hPlugin);
}

/**
 * native bool(int itemdef, const char[] key, char[] buffer, int maxlen);
 * 
 * Looks up the key in the item definition's KeyValues instance.  Returns true if the buffer is
 * not empty after the process.
 */
int Native_GetItemDefinitionString(Handle hPlugin, int nParams) {
	int defindex = GetNativeCell(1);
	int keylen;
	GetNativeStringLength(2, keylen);
	keylen++;
	
	char[] key = new char[keylen];
	GetNativeString(2, key, keylen);
	
	int maxlen = GetNativeCell(4);
	char[] buffer = new char[maxlen];
	
	GetNativeString(5, buffer, maxlen);
	
	Address pItemDef = GetEconItemDefinition(defindex);
	if (pItemDef) {
		Address pKeyValues = DereferencePointer(pItemDef + offs_CEconItemDefinition_pKeyValues);
		if (KeyValuesPtrKeyExists(pKeyValues, key)) {
			KeyValuesPtrGetString(pKeyValues, key, buffer, maxlen, buffer);
		}
	}
	
	SetNativeString(3, buffer, maxlen, true);
	return !!buffer[0];
}

/**
 * native int(int itemdef);
 * 
 * Returns whenever item is in base set, false if the item definition does not exist.
 */
int Native_IsItemInBaseSet(Handle hPlugin, int nParams) {
	int defindex = GetNativeCell(1);
	Address pItemDef = GetEconItemDefinition(defindex);
	if (!pItemDef) {
		return false;
	}
	return !!LoadFromAddress(pItemDef + offs_CEconItemDefinition_bBaseItem,
			NumberType_Int8);
}

/**
 * native bool(int itemdef);
 * 
 * Returns true if the given item definition corresponds to an item.
 */
int Native_IsValidItemDefinition(Handle hPlugin, int nParams) {
	int defindex = GetNativeCell(1);
	return ValidItemDefIndex(defindex);
}

/**
 * Reads the `char*` at the given item definition offset.
 */
static bool LoadEconItemDefinitionString(int defindex, Address offset, char[] buffer,
		int maxlen) {
	Address pItemDef = GetEconItemDefinition(defindex);
	if (!pItemDef) {
		return false;
	}
	
	LoadStringFromAddress(DereferencePointer(pItemDef + offset), buffer, maxlen);
	return true;
}
