/**
 * Utility functions for dealing with memory.
 */

#if defined __stocksoup_memory_included
	#endinput
#endif

#define __stocksoup_memory_included

/**
 * Loads a null-terminated string from the given address.
 * 
 * The function will return an empty string if the address corresponds to a nullptr.  This
 * functionality is present as a workaround for when an SDKCall that expects a char pointer
 * receives a nullptr and attempts to dereference it (see alliedmodders/sourcemod/issues/874).
 * 
 * If it is necessary to differentiate between an empty string and a null pointer, check if addr
 * is null before calling the function, or pass a reference to bIsNullPointer.
 * 
 * @return Number of bytes written.  0 is returned on an empty string or a null pointer.
 */
stock int LoadStringFromAddress(Address addr, char[] buffer, int maxlen,
		bool &bIsNullPointer = false) {
	if (!addr) {
		bIsNullPointer = true;
		return 0;
	}
	
	int c;
	char ch;
	do {
		ch = LoadFromAddress(addr + view_as<Address>(c), NumberType_Int8);
		buffer[c] = ch;
	} while (ch && ++c < maxlen - 1);
	return c;
}

/**
 * Reads a value stored in a memory address and returns it as an address.
 */
stock Address DereferencePointer(Address addr) {
	// maybe someday we'll do 64-bit addresses
	return view_as<Address>(LoadFromAddress(addr, NumberType_Int32));
}
