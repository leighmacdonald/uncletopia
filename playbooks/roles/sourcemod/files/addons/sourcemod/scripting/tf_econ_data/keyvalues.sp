/**
 * Helper functions to deal with KeyValues instances.
 */

Handle g_SDKCallGetKeyValuesString;
Handle g_SDKCallGetKeyValuesFindKey;

/**
 * Returns true if the given KeyValues instance contains the given key.
 */
bool KeyValuesPtrKeyExists(Address pKeyValues, const char[] key) {
	if (!pKeyValues) {
		return false;
	}
	return !!SDKCall(g_SDKCallGetKeyValuesFindKey, pKeyValues, key, false);
}

/**
 * Stores the value of the given key into the buffer, or stores defaultValue if the key doesn't
 * exist.
 */
void KeyValuesPtrGetString(Address pKeyValues, const char[] key, char[] buffer, int maxlen,
		const char[] defaultValue) {
	SDKCall(g_SDKCallGetKeyValuesString, pKeyValues, buffer, maxlen, key, defaultValue);
}
