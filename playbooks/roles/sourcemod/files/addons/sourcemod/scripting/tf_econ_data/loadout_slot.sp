/**
 * Natives for loadout slot information.
 */

// CUtlVector of item slot names.
Address offs_CTFItemSchema_ItemSlotNames;

/**
 * native int(const char[] name);
 * 
 * Returns the loadout slot index given the name.
 */
int Native_TranslateLoadoutSlotNameToIndex(Handle hPlugin, int nParams) {
	char slot[64];
	GetNativeString(1, slot, sizeof(slot));
	
	int nItemSlots = GetLoadoutSlotCount();
	for (int i = 0; i < nItemSlots; i++) {
		char slotData[32];
		if (TranslateLoadoutSlotIndexToName(i, slotData, sizeof(slotData))
				&& StrEqual(slot, slotData, false)) {
			return i;
		}
	}
	return -1;
}

/**
 * native bool(int index, char[] buffer, int maxlen);
 * 
 * Returns true if the loadout slot exists, storing the name in the given buffer.
 */
int Native_TranslateLoadoutSlotIndexToName(Handle hPlugin, int nParams) {
	int index = GetNativeCell(1);
	int maxlen = GetNativeCell(3);
	
	char[] buffer = new char[maxlen];
	if (TranslateLoadoutSlotIndexToName(index, buffer, maxlen)) {
		SetNativeString(2, buffer, maxlen, true);
		return true;
	}
	return false;
}

/**
 * Returns the name at the given index.
 */
static bool TranslateLoadoutSlotIndexToName(int index, char[] buffer, int maxlen) {
	Address pSchema = GetEconItemSchema();
	if (!pSchema) {
		return false;
	}
	
	Address pItemSlotNames = pSchema + offs_CTFItemSchema_ItemSlotNames;
	if (index < 0 || index >= GetLoadoutSlotCount()) {
		return false;
	}
	
	/**
	 * CTFItemSchema::ItemSlotNames is a CUtlVector<char*>, so deref to get to the underlying
	 * memory then do an array access
	 */
	Address pItemSlotData = DereferencePointer(pItemSlotNames);
	Address pItemSlotEntry = DereferencePointer(pItemSlotData + view_as<Address>(0x04 * index));
	
	bool bNull;
	LoadStringFromAddress(pItemSlotEntry, buffer, maxlen, bNull);
	return !bNull && strlen(buffer);
}

/**
 * Returns the number of loadout slots.
 */
int Native_GetLoadoutSlotCount(Handle hPlugin, int nParams) {
	return GetLoadoutSlotCount();
}

static int GetLoadoutSlotCount() {
	Address pSchema = GetEconItemSchema();
	if (!pSchema) {
		return 0;
	}
	
	return LoadFromAddress(pSchema + offs_CTFItemSchema_ItemSlotNames + view_as<Address>(0x0C),
			NumberType_Int32);
}
