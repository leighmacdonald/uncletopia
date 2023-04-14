#pragma semicolon 1 // Force strict semicolon mode.
#pragma newdecls required // Force new syntax
// ====[ INCLUDES ]====================================================
#include <sourcemod>
#define REQUIRE_EXTENSIONS
#include <tf2items>

// ====[ CONSTANTS ]===================================================
#define PLUGIN_NAME "[TF2Items] Manager"
#define PLUGIN_AUTHOR "Damizean & Asherkin"
#define PLUGIN_VERSION "1.4.4"
#define PLUGIN_CONTACT "http://limetech.org/"

#define ARRAY_SIZE 2
#define ARRAY_ITEM 0
#define ARRAY_FLAGS 1

//#define DEBUG

// ====[ VARIABLES ]===================================================
Handle g_hPlayerInfo;
Handle g_hPlayerArray;
Handle g_hGlobalSettings;
ConVar g_hCvarEnabled;
ConVar g_hCvarPlayerControlEnabled;
bool g_bPlayerEnabled[MAXPLAYERS + 1] =  { true, ... };

// ====[ PLUGIN ]======================================================
public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_NAME,
	version = PLUGIN_VERSION,
	url = PLUGIN_CONTACT
};

// ====[ FUNCTIONS ]===================================================

/* OnPluginStart()
 *
 * When the plugin starts up.
 * -------------------------------------------------------------------------- */
public void OnPluginStart() {
	// Create convars
	CreateConVar("tf2items_manager_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	g_hCvarEnabled = CreateConVar("tf2items_manager", "1", "Enables/disables the manager (0 - Disabled / 1 - Enabled", FCVAR_REPLICATED|FCVAR_NOTIFY);
	g_hCvarPlayerControlEnabled = CreateConVar("tf2items_manager_playercontrol", "1", "Enables/disables the player's ability to control the manager (0 - Disabled / 1 - Enabled");
	
	// Register console commands
	RegAdminCmd("tf2items_manager_reload", CmdReload, ADMFLAG_GENERIC);
	
	RegConsoleCmd("tf2items_enable", CmdEnable);
	RegConsoleCmd("tf2items_disable", CmdDisable);
	
	// Parse the items list
	ParseItems();
}

/* TF2Items_OnGiveNamedItem()
 *
 * When an item is about to be given to a client.
 * -------------------------------------------------------------------------- */
public Action TF2Items_OnGiveNamedItem(int client, char[] classname, int itemDefIndex, Handle &override) {
	// If disabled, use the default values.
	if (!GetConVarBool(g_hCvarEnabled) || (GetConVarBool(g_hCvarPlayerControlEnabled) && !g_bPlayerEnabled[client]))
		return Plugin_Continue;
	
	// If another plugin already tryied to override the item, let him go ahead.
	if (override != null)
		return Plugin_Continue; // Plugin_Changed
	
	// Find item. If any is found, override the attributes with these.
	Handle item = FindItem(client, itemDefIndex);
	if (item != null) {
		override = item;
		return Plugin_Changed;
	}
	
	// None found, use default values.
	return Plugin_Continue;
}

// Fuck it, only one is needed.
// Doing this for just-in-casenesses sake

public void OnClientConnected(int client) {
	g_bPlayerEnabled[client] = true;
}

public void OnClientDisconnect(int client) {
	g_bPlayerEnabled[client] = true;
}

/*
 * ------------------------------------------------------------------
 *    ______                                          __    
 *   / ____/___  ____ ___  ____ ___  ____ _____  ____/ /____
 *  / /   / __ \/ __ `__ \/ __ `__ \/ __ `/ __ \/ __  / ___/
 * / /___/ /_/ / / / / / / / / / / / /_/ / / / / /_/ (__  ) 
 * \____/\____/_/ /_/ /_/_/ /_/ /_/\__,_/_/ /_/\__,_/____/  
 * ------------------------------------------------------------------
 */

/* CmdReload()
**
** Reloads the item list.
** -------------------------------------------------------------------------- */
public Action CmdReload(int client, int action) {
	// Fire a message telling about the operation.
	if (client)
		ReplyToCommand(client, "Reloading items list");
	else
		LogMessage("Reloading items list");
	
	// Call the ParseItems function.
	ParseItems();
	return Plugin_Handled;
}

public Action CmdEnable(int client, int action) {
	if (!GetConVarBool(g_hCvarPlayerControlEnabled)) {
		ReplyToCommand(client, "The server administrator has disabled this command.");
		return Plugin_Handled;
	}

	ReplyToCommand(client, "Re-enabling TF2Items for you.");
	g_bPlayerEnabled[client] = true;
	return Plugin_Handled;
}

public Action CmdDisable(int client, int action) {
	if (!GetConVarBool(g_hCvarPlayerControlEnabled)) {
		ReplyToCommand(client, "The server administrator has disabled this command.");
		return Plugin_Handled;
	}
	
	ReplyToCommand(client, "Disabling TF2Items for you.");
	g_bPlayerEnabled[client] = false;
	return Plugin_Handled;
}

/*
 * ------------------------------------------------------------------
 *     __  ___                                                  __ 
 *    /  |/  /___ _____  ____ _____ ____  ____ ___  ___  ____  / /_
 *   / /|_/ / __ `/ __ \/ __ `/ __ `/ _ \/ __ `__ \/ _ \/ __ \/ __/
 *  / /  / / /_/ / / / / /_/ / /_/ /  __/ / / / / /  __/ / / / /_  
 * /_/  /_/\__,_/_/ /_/\__,_/\__, /\___/_/ /_/ /_/\___/_/ /_/\__/  
 *                          /____/                                 
 * ------------------------------------------------------------------
 */

/* FindItem()
**
** Tryies to find a custom item usable by the client.
** -------------------------------------------------------------------------- */
Handle FindItem(int client, int itemDefIndex) {
	// Check if the player is valid
	if (!IsValidClient(client))
		return null;
	
	// Retrieve the STEAM auth string
	char auth[64];
	GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
	
	// Check if it's on the list. If not, try with the global settings.
	Handle itemArray = null; 
	GetTrieValue(g_hPlayerInfo, auth, itemArray);
	
	// Check for each.
	Handle output;
	output = FindItemOnArray(client, itemArray, itemDefIndex);
	if (output == null)
		output = FindItemOnArray(client, g_hGlobalSettings, itemDefIndex);
	
	// Done
	return output;
}

/* FindItemOnArray()
**
** 
** -------------------------------------------------------------------------- */
Handle FindItemOnArray(int client, Handle array, int itemDefIndex) {
	// Check if the array is valid.
	if (array == null)
		return null;
		
	Handle wildcardItem = null;
	
	// Iterate through each item entry and close the handle.
	for (int itemEntry = 0; itemEntry < GetArraySize(array); itemEntry++) {
		// Retrieve item
		Handle item = GetArrayCell(array, itemEntry, ARRAY_ITEM);
		int itemflags = GetArrayCell(array, itemEntry, ARRAY_FLAGS);
		if (item == null)
			continue;
		
		// Is a wildcard item? If so, store it.
		if (TF2Items_GetItemIndex(item) == -1 && wildcardItem == null)
			if (CheckItemUsage(client, itemflags))
				wildcardItem = item;
			
		// Is the item we're looking for? If so return item, but first
		// check if it's possible due to the 
		if (TF2Items_GetItemIndex(item) == itemDefIndex)
			if (CheckItemUsage(client, itemflags))
				return item;
		}
	
	// Done, returns wildcard item if it exists.
	return wildcardItem;
}

/* CheckItemUsage()
 *
 * Checks if a client has any of the specified flags.
 * -------------------------------------------------------------------------- */
bool CheckItemUsage(int client, int flags) {
	if (flags == 0)
		return true;
	
	int clientFlags = GetUserFlagBits(client);
	if (clientFlags & ADMFLAG_ROOT)
		return true;
	else 
		return (clientFlags & flags) != 0;
}

/* ParseItems()
 *
 * Reads up the items information from the Key-Values.
 * -------------------------------------------------------------------------- */
void ParseItems() {
	char buffer[256], split[16][64];
	
	// Destroy the current items data.
	DestroyItems();
	
	// Create key values object and parse file.
	BuildPath(Path_SM, buffer, sizeof(buffer), "configs/tf2items.weapons.txt");
	KeyValues kv = CreateKeyValues("TF2Items");
	if (FileToKeyValues(kv, buffer) == false)
		SetFailState("Error, can't read file containing the item list : %s", buffer);
	
	// Check the version
	KvGetSectionName(kv, buffer, sizeof(buffer));
	if (StrEqual("custom_weapons_v3", buffer) == false)
		SetFailState("tf2items.weapons.txt structure corrupt or incorrect version: \"%s\"", buffer);
	
	// Create the array and trie to store & access the item information.
	g_hPlayerArray = CreateArray();
	g_hPlayerInfo = CreateTrie();
	
	#if defined DEBUG
		LogMessage("Parsing items");
		LogMessage("{");
	#endif 
	
	// Jump into the first subkey and go on.
	if (KvGotoFirstSubKey(kv)) {
		do {
			// Retrieve player information and split into multiple strings.
			KvGetSectionName(kv, buffer, sizeof(buffer));
			int auths = ExplodeString(buffer, ";", split, 16, 64);
			
			// Create new array entry and upload to the array.
			Handle entry = CreateArray(2);
			PushArrayCell(g_hPlayerArray, entry);
			
			#if defined DEBUG
				LogMessage("  Entry", buffer);
				LogMessage("  {");
				LogMessage("    Used by:");
			#endif
			
			// Iterate through each player auth strings and make an
			// entry for each.
			for (int auth = 0; auth < auths; auth++) {
				TrimString(split[auth]);
				SetTrieValue(g_hPlayerInfo, split[auth], entry);
				
				#if defined DEBUG
					LogMessage("    \"%s\"", split[auth]);
				#endif
			}
			
			#if defined DEBUG
				LogMessage("");
			#endif
			
			// Read all the item entries
			ParseItemsEntry(kv, entry);
			
			#if defined DEBUG
				LogMessage("  }");
			#endif
		}
		while (KvGotoNextKey(kv));
			KvGoBack(kv);
	}
	
	// Close key values
	delete kv;
	
	// Try to find the global item settings.
	GetTrieValue(g_hPlayerInfo, "*", g_hGlobalSettings);
	
	// Done.
	#if defined DEBUG
		LogMessage("}");
	#endif
}

/* ParseItemsEntry()
 *
 * Reads up a particular items entry.
 * -------------------------------------------------------------------------- */
void ParseItemsEntry(KeyValues kv, Handle entry) {
	char buffer[64], buffer2[64], split[2][64];
	
	// Jump into the first subkey.
	if (KvGotoFirstSubKey(kv)) {
		do {
			Handle item = TF2Items_CreateItem(OVERRIDE_ALL);
			int attrflags = 0;
			
			// Retrieve item definition index and store.
			KvGetSectionName(kv, buffer, sizeof(buffer));
			if (buffer[0] == '*')
				TF2Items_SetItemIndex(item, -1);
			else
				TF2Items_SetItemIndex(item, StringToInt(buffer));
			
			#if defined DEBUG
				LogMessage("    Item: %i", TF2Items_GetItemIndex(item));
				LogMessage("    {");
			#endif
			
			// Retrieve entity level
			int level = KvGetNum(kv, "level", -1);
			if (level != -1) {
				TF2Items_SetLevel(item, level);
				attrflags |= OVERRIDE_ITEM_LEVEL;
			}
			
			#if defined DEBUG
				if (attrflags & OVERRIDE_ITEM_LEVEL)
					LogMessage("      Level: %i", TF2Items_GetLevel(item));
			#endif
			
			// Retrieve entity quality
			int quality = KvGetNum(kv, "quality", -1);
			if (quality != -1) {
				TF2Items_SetQuality(item, quality);
				attrflags |= OVERRIDE_ITEM_QUALITY;
			}
			
			#if defined DEBUG
				if (attrflags & OVERRIDE_ITEM_QUALITY)
					LogMessage("      Quality: %i", TF2Items_GetQuality(item));
			#endif
			
			// Check for attribute preservation key
			int preserve = KvGetNum(kv, "preserve-attributes", -1);
			if (preserve == 1)
				attrflags |= PRESERVE_ATTRIBUTES;
			else {
				preserve = KvGetNum(kv, "preserve_attributes", -1);
				if (preserve == 1)
					attrflags |= PRESERVE_ATTRIBUTES;
			}
			
			#if defined DEBUG
				LogMessage("      Preserve Attributes: %s", (attrflags & PRESERVE_ATTRIBUTES)?"true":"false");
			#endif
			
			// Read all the attributes
			int attributeCount = 0;
			for (;;) {
				// Format the attribute entry name
				Format(buffer, sizeof(buffer), "%i", attributeCount+1);
				
				// Try to read the attribute
				KvGetString(kv, buffer, buffer2, sizeof(buffer2));
				
				// If not found, break.
				if (buffer2[0] == '\0') break;
				
				// Split the information in two buffers
				ExplodeString(buffer2, ";", split, 2, 64);
				int attribute = StringToInt(split[0]);
				float value = StringToFloat(split[1]);
				
				// Attribute found, set information.
				TF2Items_SetAttribute(item, attributeCount, attribute, value);
				
				#if defined DEBUG
					LogMessage("      Attribute[%i] : %i / %f",
						attributeCount,
						TF2Items_GetAttributeId(item, attributeCount),
						TF2Items_GetAttributeValue(item, attributeCount)
					);
				#endif
				
				// Increase attribute count and continue.
				attributeCount++;
			}
			
			// Done, set attribute count and upload.
			if (attributeCount != 0) {
				TF2Items_SetNumAttributes(item, attributeCount);
				attrflags |= OVERRIDE_ATTRIBUTES;
			}
			
			// Retrieve the admin flags
			KvGetString(kv, "admin-flags", buffer, sizeof(buffer), "");
			int flags = ReadFlagString(buffer);
			
			// Set flags and upload.
			TF2Items_SetFlags(item, attrflags);
			PushArrayCell(entry, 0);
			SetArrayCell(entry, GetArraySize(entry)-1, item, ARRAY_ITEM);
			SetArrayCell(entry, GetArraySize(entry)-1, flags, ARRAY_FLAGS);
			
			#if defined DEBUG
				LogMessage("      Flags: %05b", TF2Items_GetFlags(item));
				LogMessage("      Admin: %s", ((flags == 0)? "(none)":buffer));
				LogMessage("    }");
			#endif
		}
		while (KvGotoNextKey(kv));
			KvGoBack(kv);
	}
}

/* DestroyItems()
 *
 * Destroys the current list for items.
 * -------------------------------------------------------------------------- */
void DestroyItems() {
	if (g_hPlayerArray != null) {
		// Iterate through each player and retrieve the internal
		// weapon list.
		for (int entry = 0; entry < GetArraySize(g_hPlayerArray); entry++) {
			// Retrieve the item array.
			Handle itemArray = GetArrayCell(g_hPlayerArray, entry);
			if (itemArray == null)
				continue;
			
			// Iterate through each item entry and close the handle.
			for (int itemEntry = 0; itemEntry < GetArraySize(itemArray); itemEntry++) {
				// Retrieve item
				Handle item = GetArrayCell(itemArray, itemEntry);
				
				// Close handle
				delete item;
			}
		}
		
		// Done, free array
		delete g_hPlayerArray;
	}
	
	// Free player trie
	delete g_hPlayerInfo;
	
	// Done
	g_hGlobalSettings = null;
}

/* IsValidClient()
 *
 * Checks if a client is valid.
 * -------------------------------------------------------------------------- */
bool IsValidClient(int client) {
	if (client < 1 || client > MaxClients)
		return false;
	if (!IsClientConnected(client))
		return false;
	return IsClientInGame(client);
}
