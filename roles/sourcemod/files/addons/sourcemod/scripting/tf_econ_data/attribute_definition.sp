Address offs_CEconItemAttributeDefinition_pKeyValues,
		offs_CEconItemAttributeDefinition_iAttributeDefinitionIndex,
		offs_CEconItemAttributeDefinition_bHidden,
		offs_CEconItemAttributeDefinition_bIsInteger,
		offs_CEconItemAttributeDefinition_pszAttributeName,
		offs_CEconItemAttributeDefinition_pszAttributeClass;

/**
 * native bool(int attrdef);
 * 
 * Returns true if the given attribute is marked as hidden.
 */
int Native_IsAttributeHidden(Handle hPlugin, int nParams) {
	int defindex = GetNativeCell(1);
	Address pAttributeDef = GetEconAttributeDefinition(defindex);
	if (!pAttributeDef) {
		return false;
	}
	
	return !!LoadFromAddress(pAttributeDef + offs_CEconItemAttributeDefinition_bHidden,
			NumberType_Int8);
}

/**
 * native bool(int attrdef);
 * 
 * Returns true if the given attribute is marked as stored as an integer.
 */
int Native_IsAttributeStoredAsInteger(Handle hPlugin, int nParams) {
	int defindex = GetNativeCell(1);
	Address pAttributeDef = GetEconAttributeDefinition(defindex);
	if (!pAttributeDef) {
		return false;
	}
	
	return !!LoadFromAddress(pAttributeDef + offs_CEconItemAttributeDefinition_bIsInteger,
			NumberType_Int8);
}

/**
 * bool(int attrdef, char[] buffer, int maxlen);
 *
 * Returns true if the given attribute definition is valid, storing its name into the buffer.
 */
int Native_GetAttributeName(Handle hPlugin, int nParams) {
	int defindex = GetNativeCell(1);
	int maxlen = GetNativeCell(3);
	
	char[] buffer = new char[maxlen];
	bool bResult = LoadEconAttributeDefinitionString(defindex,
			offs_CEconItemAttributeDefinition_pszAttributeName, buffer, maxlen);
	
	if (bResult) {
		SetNativeString(2, buffer, maxlen, true);
	}
	return bResult;
}

/**
 * bool(int attrdef, char[] buffer, int maxlen);
 *
 * Returns true if the given attribute definition is valid, storing its attribute class name
 * into the buffer.
 */
int Native_GetAttributeClassName(Handle hPlugin, int nParams) {
	int defindex = GetNativeCell(1);
	int maxlen = GetNativeCell(3);
	
	char[] buffer = new char[maxlen];
	bool bResult = LoadEconAttributeDefinitionString(defindex,
			offs_CEconItemAttributeDefinition_pszAttributeClass, buffer, maxlen);
	
	if (bResult) {
		SetNativeString(2, buffer, maxlen, true);
	}
	return bResult;
}

/**
 * bool(int attrdef, const char[] key, char[] buffer, int maxlen, const char[] defaultVal = "");
 *
 * Retrieves the `key` entry from the attribute's KeyValues struct and returns true if the
 * given output buffer is not empty.  If `defaultVal` is set, it is copied to the output buffer.
 */
int Native_GetAttributeDefinitionString(Handle hPlugin, int nParams) {
	int defindex = GetNativeCell(1);
	int keylen;
	GetNativeStringLength(2, keylen);
	keylen++;
	
	char[] key = new char[keylen];
	GetNativeString(2, key, keylen);
	
	int maxlen = GetNativeCell(4);
	char[] buffer = new char[maxlen];
	
	GetNativeString(5, buffer, maxlen);
	
	Address pItemDef = GetEconAttributeDefinition(defindex);
	if (pItemDef) {
		Address pKeyValues = DereferencePointer(
				pItemDef + offs_CEconItemAttributeDefinition_pKeyValues);
		if (KeyValuesPtrKeyExists(pKeyValues, key)) {
			KeyValuesPtrGetString(pKeyValues, key, buffer, maxlen, buffer);
		}
	}
	
	SetNativeString(3, buffer, maxlen, true);
	return !!buffer[0];
}

bool IsValidAttributeDefinition(int defindex) {
	return !!GetEconAttributeDefinition(defindex);
}

/**
 * bool(int attrdef);
 * 
 * Returns true if the given identifier corresponds to an attribute definition.
 */
int Native_IsValidAttributeDefinition(Handle hPlugin, int nParams) {
	int defindex = GetNativeCell(1);
	return IsValidAttributeDefinition(defindex);
}

static bool LoadEconAttributeDefinitionString(int defindex, Address offset, char[] buffer,
		int maxlen) {
	Address pAttributeDef = GetEconAttributeDefinition(defindex);
	if (!pAttributeDef) {
		return false;
	}
	
	LoadStringFromAddress(DereferencePointer(pAttributeDef + offset), buffer, maxlen);
	return true;
}

// layout of CEconItemAttributeDefinition
// 0x00 = KeyValues* m_pKeyValues
// 0x04 = int m_iAttributeDefinitionIndex
