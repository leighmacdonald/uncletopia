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
	return LoadFromAddress(pMapDef + view_as<Address>(0xC), NumberType_Int32);
}
