Address offs_MapDef_t_m_nDefIndex; // 12/24 (0x0C/0x18)

/**
 * native int(const char[] name);
 */
int Native_GetMapDefinitionIndex(Handle hPlugin, int nParams) {
	int len;
	GetNativeStringLength(1, len);
	
	char[] name = new char[++len];
	GetNativeString(1, name, len);
	
	Address pMapDef = GetMapDefinitionByName(name);
	if (!pMapDef) {
		return 0;
	}
	return LoadFromAddress(pMapDef + offs_MapDef_t_m_nDefIndex, NumberType_Int32);
}
