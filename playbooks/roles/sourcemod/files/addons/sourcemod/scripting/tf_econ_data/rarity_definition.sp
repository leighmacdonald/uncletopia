Address offs_CEconItemSchema_ItemRarities;
Address offs_CEconItemSchema_iLastValidRarity;

Address offs_CEconItemRarityDefinition_iValue,
		offs_CEconItemRarityDefinition_pszName;

/**
 * native bool(int rarity, char[] buffer, int maxlen);
 * 
 * Stores the name of the provided rarity value into the given buffer, returning whether or not
 * it exists.
 */
int Native_GetRarityName(Handle hPlugin, int nParams) {
	int rarity = GetNativeCell(1);
	
	Address pRarityDef = GetEconRarityDefinition(rarity);
	if (!pRarityDef) {
		return false;
	}
	
	int maxlen = GetNativeCell(3);
	
	char[] buffer = new char[maxlen];
	GetRarityName(pRarityDef, buffer, maxlen);
	SetNativeString(2, buffer, maxlen, true);
	return true;
}

/**
 * native int(const char[] name, bool caseSensitive = true);
 * 
 * Checks if any of the rarity definitions match the given name, returning the rarity value
 * if found, else -1.
 */
int Native_TranslateRarityNameToValue(Handle hPlugin, int nParams) {
	// TODO always disable case-sensitivity, same as quality
	bool caseSensitive = GetNativeCell(2);
	
	int maxlen;
	GetNativeStringLength(1, maxlen);
	maxlen++;
	
	char[] input = new char[maxlen];
	GetNativeString(1, input, maxlen);
	
	int nRarityCount = GetEconRarityDefinitionCount();
	for (int i; i < nRarityCount; i++) {
		char buffer[32];
		Address pRarityDef = GetEconRarityDefinitionFromMemoryIndex(i);
		GetRarityName(pRarityDef, buffer, sizeof(buffer));
		if (StrEqual(input, buffer, caseSensitive)) {
			return GetRarityValue(pRarityDef);
		}
	}
	
	return -1;
}

/**
 * native ArrayList<cell_t>(void);
 * 
 * Returns a list containing valid rarity values.
 */
int Native_GetRarityList(Handle hPlugin, int nParams) {
	ArrayList rarityValues = new ArrayList();
	
	int nRarityCount = GetEconRarityDefinitionCount();
	for (int i; i < nRarityCount; i++) {
		Address pRarityDef = GetEconRarityDefinitionFromMemoryIndex(i);
		rarityValues.Push(GetRarityValue(pRarityDef));
	}
	
	return MoveHandleImmediate(rarityValues, hPlugin);
}

/**
 * native Address<CEconItemRarityDefinition>(int index);
 */
int Native_GetRarityDefinitionAddress(Handle hPlugin, int nParams) {
	int value = GetNativeCell(1);
	return view_as<int>(GetEconRarityDefinition(value));
}

Address GetEconRarityDefinition(int rarity) {
	int nRarityCount = GetEconRarityDefinitionCount();
	for (int i; i < nRarityCount; i++) {
		Address pRarityDef = GetEconRarityDefinitionFromMemoryIndex(i);
		if (rarity == GetRarityValue(pRarityDef)) {
			return pRarityDef;
		}
	}
	return Address_Null;
}

static int GetRarityValue(Address pRarityDef) {
	return pRarityDef? LoadFromAddress(pRarityDef + offs_CEconItemRarityDefinition_iValue,
				NumberType_Int32) : -1;
}

static void GetRarityName(Address pRarityDef, char[] buffer, int maxlen) {
	if (!pRarityDef) {
		return;
	}
	LoadStringFromAddress(
				DereferencePointer(pRarityDef + offs_CEconItemRarityDefinition_pszName),
				buffer, maxlen);
}

/**
 * Returns the address of a CEconItemRarityDefinition based on an array index in the schema's
 * internal CEconItemRarityDefinition array.
 */
static Address GetEconRarityDefinitionFromMemoryIndex(int index) {
	if (index < 0 || index >= GetEconRarityDefinitionCount()) {
		return Address_Null;
	}
	
	return DereferencePointer(GetEconRarityDefinitionTree() + view_as<Address>(0x04))
			+ view_as<Address>((index * 0x34) + 0x14);
}

/**
 * Returns the number of valid items in the internal CEconItemRarityDefinition array.
 */
static int GetEconRarityDefinitionCount() {
	Address pSchema = GetEconItemSchema();
	if (pSchema) {
		return LoadFromAddress(pSchema + offs_CEconItemSchema_iLastValidRarity,
				NumberType_Int32) + 1;
	}
	return 0;
}

static Address GetEconRarityDefinitionTree() {
	Address pSchema = GetEconItemSchema();
	if (!pSchema) {
		return Address_Null;
	}
	return pSchema + offs_CEconItemSchema_ItemRarities;
}
