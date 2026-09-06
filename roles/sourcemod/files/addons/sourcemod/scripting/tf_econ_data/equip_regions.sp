/**
 * Natives for accessing the item schema's equip region data.
 */

// offset into CEconItemSchema
Address offs_CEconItemSchema_EquipRegions;

/**
 * I'm not going to bother putting these in gamedata for now.  It's a struct.
 */
Address offs_CEconItemSchema_EquipRegion_pszName = view_as<Address>(0x00),
		offs_CEconItemSchema_EquipRegion_iGroup = view_as<Address>(0x04),
		offs_CEconItemSchema_EquipRegion_bitsRegionMask = view_as<Address>(0x08);

int sizeof_EquipRegion = 0x0C;

/**
 * native StringMap<int>();
 * 
 * Returns a mapping of group name to group index.
 */
int Native_GetEquipRegionGroups(Handle hPlugin, int nParams) {
	Address pSchema = GetEconItemSchema();
	if (!pSchema) {
		return view_as<int>(INVALID_HANDLE);
	}
	
	StringMap equipRegionMap = new StringMap();
	
	// CUtlVector lookup
	Address pEquipRegions = pSchema + offs_CEconItemSchema_EquipRegions;
	
	int nEquipRegions = LoadFromAddress(
			pEquipRegions + view_as<Address>(0x0C), NumberType_Int32);
	
	Address pEquipRegionData = DereferencePointer(pEquipRegions);
	for (int i; i < nEquipRegions; i++) {
		char equipRegion[32];
		
		Address pEquipRegionEntry = pEquipRegionData + view_as<Address>(i * sizeof_EquipRegion);
		Address pName = DereferencePointer(
				pEquipRegionEntry + offs_CEconItemSchema_EquipRegion_pszName);
		LoadStringFromAddress(pName, equipRegion, sizeof(equipRegion));
		
		int group = LoadFromAddress(pEquipRegionEntry + offs_CEconItemSchema_EquipRegion_iGroup,
				NumberType_Int32);
		
		equipRegionMap.SetValue(equipRegion, group);
	}
	return MoveHandle(equipRegionMap, hPlugin);
}

/**
 * native bool(const char[] name, int &mask);
 * 
 * Returns a bitset of groups the given group-by-name conflicts with.
 */
int Native_GetEquipRegionMask(Handle hPlugin, int nParams) {
	Address pSchema = GetEconItemSchema();
	if (!pSchema) {
		return false;
	}
	
	int maxlen;
	GetNativeStringLength(1, maxlen);
	
	maxlen++;
	
	char[] desiredEquipRegion = new char[maxlen];
	GetNativeString(1, desiredEquipRegion, maxlen);
	
	// CUtlVector lookup
	Address pEquipRegions = pSchema + offs_CEconItemSchema_EquipRegions;
	int nEquipRegions = LoadFromAddress(
			pEquipRegions + view_as<Address>(0x0C), NumberType_Int32);
	
	Address pEquipRegionData = DereferencePointer(pEquipRegions);
	for (int i; i < nEquipRegions; i++) {
		char equipRegion[64];
		
		Address pEquipRegionEntry = pEquipRegionData + view_as<Address>(i * sizeof_EquipRegion);
		Address pName = DereferencePointer(
				pEquipRegionEntry + offs_CEconItemSchema_EquipRegion_pszName);
		LoadStringFromAddress(pName, equipRegion, sizeof(equipRegion));
		
		if (!StrEqual(equipRegion, desiredEquipRegion)) {
			continue;
		}
		
		int group = LoadFromAddress(
				pEquipRegionEntry + offs_CEconItemSchema_EquipRegion_bitsRegionMask,
				NumberType_Int32);
		SetNativeCellRef(2, group);
		return true;
	}
	return false;
}
