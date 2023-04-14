#pragma semicolon 1 // Force strict semicolon mode.

// ====[ INCLUDES ]====================================================
#include <sourcemod>
#define REQUIRE_EXTENSIONS
#include <tf2items>

// ====[ CONSTANTS ]===================================================
#define PLUGIN_NAME		"[TF2Items] Manager"
#define PLUGIN_AUTHOR		"Damizean & Asherkin"
#define PLUGIN_VERSION		"1.4.3"
#define PLUGIN_CONTACT		"http://limetech.org/"

#define ARRAY_SIZE			2
#define ARRAY_ITEM			0
#define ARRAY_FLAGS		1

//#define DEBUG

// ====[ VARIABLES ]===================================================
new Handle:g_hPlayerInfo;
new Handle:g_hPlayerArray;
new Handle:g_hGlobalSettings;
new Handle:g_hCvarEnabled;
new bool:g_bPlayerEnabled[MAXPLAYERS + 1] = { true, ... };
new Handle:g_hCvarPlayerControlEnabled;

// ====[ PLUGIN ]======================================================
public Plugin:myinfo =
{
	name			= PLUGIN_NAME,
	author			= PLUGIN_AUTHOR,
	description	= PLUGIN_NAME,
	version		= PLUGIN_VERSION,
	url				= PLUGIN_CONTACT
};

// ====[ FUNCTIONS ]===================================================

/* OnPluginStart()
 *
 * When the plugin starts up.
 * -------------------------------------------------------------------------- */
public OnPluginStart()
{
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
public Action:TF2Items_OnGiveNamedItem(iClient, String:strClassName[], iItemDefinitionIndex, &Handle:hItemOverride)
{
	// If disabled, use the default values.
	if (!GetConVarBool(g_hCvarEnabled) || (GetConVarBool(g_hCvarPlayerControlEnabled) && !g_bPlayerEnabled[iClient]))
		return Plugin_Continue;
	
	// If another plugin already tryied to override the item, let him go ahead.
	if (hItemOverride != INVALID_HANDLE)
		return Plugin_Continue; // Plugin_Changed
	
	// Find item. If any is found, override the attributes with these.
	new Handle:hItem = FindItem(iClient, iItemDefinitionIndex);
	if (hItem != INVALID_HANDLE)
	{
		hItemOverride = hItem;
		return Plugin_Changed;
	}
	
	// None found, use default values.
	return Plugin_Continue;
}

// Fuck it, only one is needed.
// Doing this for just-in-casenesses sake

public OnClientConnected(client)
{
	g_bPlayerEnabled[client] = true;
}

public OnClientDisconnect(client)
{
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
public Action:CmdReload(iClient, iAction)
{
	// Fire a message telling about the operation.
	if (iClient)
		ReplyToCommand(iClient, "Reloading items list");
	else
		LogMessage("Reloading items list");
	
	// Call the ParseItems function.
	ParseItems();
	return Plugin_Handled;
}

public Action:CmdEnable(iClient, iAction)
{
	if (!GetConVarBool(g_hCvarPlayerControlEnabled))
	{
		ReplyToCommand(iClient, "The server administrator has disabled this command.");
		return Plugin_Handled;
	}

	ReplyToCommand(iClient, "Re-enabling TF2Items for you.");
	g_bPlayerEnabled[iClient] = true;
	return Plugin_Handled;
}

public Action:CmdDisable(iClient, iAction)
{
	if (!GetConVarBool(g_hCvarPlayerControlEnabled))
	{
		ReplyToCommand(iClient, "The server administrator has disabled this command.");
		return Plugin_Handled;
	}
	
	ReplyToCommand(iClient, "Disabling TF2Items for you.");
	g_bPlayerEnabled[iClient] = false;
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
Handle:FindItem(iClient, iItemDefinitionIndex)
{
	// Check if the player is valid
	if (!IsValidClient(iClient))
		return INVALID_HANDLE;
	
	// Retrieve the STEAM auth string
	new String:strAuth[64];
	GetClientAuthString(iClient, strAuth, sizeof(strAuth));
	
	// Check if it's on the list. If not, try with the global settings.
	new Handle:hItemArray = INVALID_HANDLE; 
	GetTrieValue(g_hPlayerInfo, strAuth, hItemArray);
	
	// Check for each.
	new Handle:hOutput;
	hOutput = FindItemOnArray(iClient, hItemArray, iItemDefinitionIndex);
	if (hOutput == INVALID_HANDLE)
		hOutput = FindItemOnArray(iClient, g_hGlobalSettings, iItemDefinitionIndex);
	
	// Done
	return hOutput;
}

/* FindItemOnArray()
**
** 
** -------------------------------------------------------------------------- */
Handle:FindItemOnArray(iClient, Handle:hArray, iItemDefinitionIndex)
{
	// Check if the array is valid.
	if (hArray == INVALID_HANDLE)
		return INVALID_HANDLE;
		
	new Handle:hWildcardItem = INVALID_HANDLE;
	
	// Iterate through each item entry and close the handle.
	for (new iItem = 0; iItem < GetArraySize(hArray); iItem++)
	{
		// Retrieve item
		new Handle:hItem = GetArrayCell(hArray, iItem, ARRAY_ITEM);
		new iItemFlags = GetArrayCell(hArray, iItem, ARRAY_FLAGS);
		if (hItem == INVALID_HANDLE)
			continue;
		
		// Is a wildcard item? If so, store it.
		if (TF2Items_GetItemIndex(hItem) == -1 && hWildcardItem == INVALID_HANDLE)
			if (CheckItemUsage(iClient, iItemFlags))
				hWildcardItem = hItem;
			
		// Is the item we're looking for? If so return item, but first
		// check if it's possible due to the 
		if (TF2Items_GetItemIndex(hItem) == iItemDefinitionIndex)
			if (CheckItemUsage(iClient, iItemFlags))
				return hItem;
		}
	
	// Done, returns wildcard item if it exists.
	return hWildcardItem;
}

/* CheckItemUsage()
 *
 * Checks if a client has any of the specified flags.
 * -------------------------------------------------------------------------- */
bool:CheckItemUsage(iClient, iFlags)
{
	if (iFlags == 0)
		return true;
	
	new iClientFlags = GetUserFlagBits(iClient);
	if (iClientFlags & ADMFLAG_ROOT)
		return true;
	else 
		return (iClientFlags & iFlags) != 0;
}

/* ParseItems()
 *
 * Reads up the items information from the Key-Values.
 * -------------------------------------------------------------------------- */
ParseItems()
{
	decl String:strBuffer[256];
	decl String:strSplit[16][64];
	
	// Destroy the current items data.
	DestroyItems();
	
	// Create key values object and parse file.
	BuildPath(Path_SM, strBuffer, sizeof(strBuffer), "configs/tf2items.weapons.txt");
	new Handle:hKeyValues = CreateKeyValues("TF2Items");
	if (FileToKeyValues(hKeyValues, strBuffer) == false)
		SetFailState("Error, can't read file containing the item list : %s", strBuffer);
	
	// Check the version
	KvGetSectionName(hKeyValues, strBuffer, sizeof(strBuffer));
	if (StrEqual("custom_weapons_v3", strBuffer) == false)
		SetFailState("tf2items.weapons.txt structure corrupt or incorrect version: \"%s\"", strBuffer);
	
	// Create the array and trie to store & access the item information.
	g_hPlayerArray = CreateArray();
	g_hPlayerInfo = CreateTrie();
	
	#if defined DEBUG
		LogMessage("Parsing items");
		LogMessage("{");
	#endif 
	
	// Jump into the first subkey and go on.
	if (KvGotoFirstSubKey(hKeyValues))
	{
		do
		{
			// Retrieve player information and split into multiple strings.
			KvGetSectionName(hKeyValues, strBuffer, sizeof(strBuffer));
			new iNumAuths = ExplodeString(strBuffer, ";", strSplit, 16, 64);
			
			// Create new array entry and upload to the array.
			new Handle:hEntry = CreateArray(2);
			PushArrayCell(g_hPlayerArray, hEntry);
			
			#if defined DEBUG
				LogMessage("  Entry", strBuffer);
				LogMessage("  {");
				LogMessage("    Used by:");
			#endif
			
			// Iterate through each player auth strings and make an
			// entry for each.
			for (new iAuth = 0; iAuth < iNumAuths; iAuth++)
			{
				TrimString(strSplit[iAuth]);
				SetTrieValue(g_hPlayerInfo, strSplit[iAuth], hEntry);
				
				#if defined DEBUG
					LogMessage("    \"%s\"", strSplit[iAuth]);
				#endif
			}
			
			#if defined DEBUG
				LogMessage("");
			#endif
			
			// Read all the item entries
			ParseItemsEntry(hKeyValues, hEntry);
			
			#if defined DEBUG
				LogMessage("  }");
			#endif
		}
		while (KvGotoNextKey(hKeyValues));
			KvGoBack(hKeyValues);
	}
	
	// Close key values
	CloseHandle(hKeyValues);
	
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
ParseItemsEntry(Handle:hKeyValues, Handle:hEntry)
{
	decl String:strBuffer[64];
	decl String:strBuffer2[64];
	decl String:strSplit[2][64];
	
	// Jump into the first subkey.
	if (KvGotoFirstSubKey(hKeyValues))
	{
		do
		{
			new Handle:hItem = TF2Items_CreateItem(OVERRIDE_ALL);
			new iItemFlags = 0;
			
			// Retrieve item definition index and store.
			KvGetSectionName(hKeyValues, strBuffer, sizeof(strBuffer));
			if (strBuffer[0] == '*')
				TF2Items_SetItemIndex(hItem, -1);
			else
				TF2Items_SetItemIndex(hItem, StringToInt(strBuffer));
			
			#if defined DEBUG
				LogMessage("    Item: %i", TF2Items_GetItemIndex(hItem));
				LogMessage("    {");
			#endif
			
			// Retrieve entity level
			new iLevel = KvGetNum(hKeyValues, "level", -1);
			if (iLevel != -1)
			{
				TF2Items_SetLevel(hItem, iLevel);
				iItemFlags |= OVERRIDE_ITEM_LEVEL;
			}
			
			#if defined DEBUG
				if (iItemFlags & OVERRIDE_ITEM_LEVEL)
					LogMessage("      Level: %i", TF2Items_GetLevel(hItem));
			#endif
			
			// Retrieve entity quality
			new iQuality = KvGetNum(hKeyValues, "quality", -1);
			if (iQuality != -1)
			{
				TF2Items_SetQuality(hItem, iQuality);
				iItemFlags |= OVERRIDE_ITEM_QUALITY;
			}
			
			#if defined DEBUG
				if (iItemFlags & OVERRIDE_ITEM_QUALITY)
					LogMessage("      Quality: %i", TF2Items_GetQuality(hItem));
			#endif
			
			// Check for attribute preservation key
			new iPreserve = KvGetNum(hKeyValues, "preserve-attributes", -1);
			if (iPreserve == 1)
			{
				iItemFlags |= PRESERVE_ATTRIBUTES;
			} else {
				iPreserve = KvGetNum(hKeyValues, "preserve_attributes", -1);
				if (iPreserve == 1)
					iItemFlags |= PRESERVE_ATTRIBUTES;
			}
			
			#if defined DEBUG
				LogMessage("      Preserve Attributes: %s", (iItemFlags & PRESERVE_ATTRIBUTES)?"true":"false");
			#endif
			
			// Read all the attributes
			new iAttributeCount = 0;
			for (;;)
			{
				// Format the attribute entry name
				Format(strBuffer, sizeof(strBuffer), "%i", iAttributeCount+1);
				
				// Try to read the attribute
				KvGetString(hKeyValues, strBuffer, strBuffer2, sizeof(strBuffer2));
				
				// If not found, break.
				if (strBuffer2[0] == '\0') break;
				
				// Split the information in two buffers
				ExplodeString(strBuffer2, ";", strSplit, 2, 64);
				new iAttributeIndex = StringToInt(strSplit[0]);
				new Float:fAttributeValue = StringToFloat(strSplit[1]);
				
				// Attribute found, set information.
				TF2Items_SetAttribute(hItem, iAttributeCount, iAttributeIndex, fAttributeValue);
				
				#if defined DEBUG
					LogMessage("      Attribute[%i] : %i / %f",
						iAttributeCount,
						TF2Items_GetAttributeId(hItem, iAttributeCount),
						TF2Items_GetAttributeValue(hItem, iAttributeCount)
					);
				#endif
				
				// Increase attribute count and continue.
				iAttributeCount++;
			}
			
			// Done, set attribute count and upload.
			if (iAttributeCount != 0)
			{
				TF2Items_SetNumAttributes(hItem, iAttributeCount);
				iItemFlags |= OVERRIDE_ATTRIBUTES;
			}
			
			// Retrieve the admin flags
			KvGetString(hKeyValues, "admin-flags", strBuffer, sizeof(strBuffer), "");
			new iFlags = ReadFlagString(strBuffer);
			
			// Set flags and upload.
			TF2Items_SetFlags(hItem, iItemFlags);
			PushArrayCell(hEntry, 0);
			SetArrayCell(hEntry, GetArraySize(hEntry)-1, hItem, ARRAY_ITEM);
			SetArrayCell(hEntry, GetArraySize(hEntry)-1, iFlags, ARRAY_FLAGS);
			
			#if defined DEBUG
				LogMessage("      Flags: %05b", TF2Items_GetFlags(hItem));
				LogMessage("      Admin: %s", ((iFlags == 0)? "(none)":strBuffer));
				LogMessage("    }");
			#endif
		}
		while (KvGotoNextKey(hKeyValues));
			KvGoBack(hKeyValues);
	}
}

/* DestroyItems()
 *
 * Destroys the current list for items.
 * -------------------------------------------------------------------------- */
DestroyItems()
{
	if (g_hPlayerArray != INVALID_HANDLE)
	{
		// Iterate through each player and retrieve the internal
		// weapon list.
		for (new iEntry = 0; iEntry < GetArraySize(g_hPlayerArray); iEntry++)
		{
			// Retrieve the item array.
			new Handle:hItemArray = GetArrayCell(g_hPlayerArray, iEntry);
			if (hItemArray == INVALID_HANDLE)
				continue;
			
			// Iterate through each item entry and close the handle.
			for (new iItem = 0; iItem < GetArraySize(hItemArray); iItem++)
			{
				// Retrieve item
				new Handle:hItem = GetArrayCell(hItemArray, iItem);
				if (hItem == INVALID_HANDLE)
					continue;
				
				// Close handle
				CloseHandle(hItem);
			}
		}
		
		// Done, free array
		CloseHandle(g_hPlayerArray);
	}
	
	// Free player trie
	if (g_hPlayerInfo != INVALID_HANDLE)
	{
		CloseHandle(g_hPlayerInfo);
	}
	
	// Done
	g_hPlayerInfo = INVALID_HANDLE;
	g_hPlayerArray = INVALID_HANDLE;
	g_hGlobalSettings = INVALID_HANDLE;
}

/* IsValidClient()
 *
 * Checks if a client is valid.
 * -------------------------------------------------------------------------- */
bool:IsValidClient(iClient)
{
	if (iClient < 1 || iClient > MaxClients)
		return false;
	if (!IsClientConnected(iClient))
		return false;
	return IsClientInGame(iClient);
}
