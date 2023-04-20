//-------------------------------------------------------//
// CONFIG
//-------------------------------------------------------//

/** Reload the plugin config */
public Config_Load()
{
	// Build the path to the config file. 
	char szCfgPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szCfgPath, sizeof(szCfgPath), "configs/danepve.cfg");

	// Load the keyvalues.
	KeyValues kv = new KeyValues("UncleDanePVE");
	if(kv.ImportFromFile(szCfgPath) == false)
	{
		SetFailState("Failed to read configs/danepve.cfg");
		return;
	}

	// Try to load bot names.
	if(kv.JumpToKey("Names"))
	{
		Config_LoadNamesFromKV(kv);
		kv.GoBack();
	}

	// Try to load bot cosmetics.
	if(kv.JumpToKey("Cosmetics"))
	{
		Config_LoadCosmeticsFromKV(kv);
		kv.GoBack();
	}

	// Try to load bot cosmetics.
	if(kv.JumpToKey("Weapons"))
	{
		Config_LoadWeaponsFromKV(kv);
		kv.GoBack();
	}

	// Try to load bot cosmetics.
	if(kv.JumpToKey("Attributes"))
	{
		Config_LoadAttributesFromKV(kv);
		kv.GoBack();
	}

	char szClassName[32];
	kv.GetString("Class", szClassName, sizeof(szClassName));
	FindConVar("tf_bot_force_class")		.SetString(szClassName);
	FindConVar("tf_bot_difficulty")			.SetInt(kv.GetNum("Difficulty"));
	FindConVar("tf_bot_auto_vacate")		.SetBool(false);
	FindConVar("tf_bot_quota")				.SetInt(kv.GetNum("Count"));
	FindConVar("mp_disable_respawn_times")	.SetBool(true);
	FindConVar("mp_teams_unbalance_limit")	.SetInt(0);
}

/** Reload the bot names that will be on the bot team. */
public Config_LoadNamesFromKV(KeyValues kv)
{
	delete g_hBotNames;
	g_hBotNames = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	
	if(kv.GotoFirstSubKey(false))
	{
		do {
			char szName[PLATFORM_MAX_PATH];
			kv.GetString(NULL_STRING, szName, sizeof(szName));
			g_hBotNames.PushString(szName);
		} while (kv.GotoNextKey(false));

		kv.GoBack();
	}
}

/** Reload the bot names that will be on the bot team. */
public Config_LoadAttributesFromKV(KeyValues kv)
{
	delete g_hPlayerAttributes;
	g_hPlayerAttributes = new ArrayList(sizeof(TFAttribute));
	
	if(kv.GotoFirstSubKey(false))
	{
		do {
			// Read name and float value, add the pair to the attributes array.
			TFAttribute attrib;
			kv.GetSectionName(attrib.m_szName, sizeof(attrib.m_szName));
			attrib.m_flValue = kv.GetFloat(NULL_STRING);
			g_hPlayerAttributes.PushArray(attrib);

		} while (kv.GotoNextKey(false));

		kv.GoBack();
	}
}

public Config_LoadItemFromKV(KeyValues kv, BotItem buffer)
{
	// First check inlined definition.
	int inlineDefId = kv.GetNum(NULL_STRING, 0);
	if(inlineDefId > 0)
	{
		buffer.m_iItemDefinitionIndex = inlineDefId;
		return;
	}

	// Definition is not inlined
	buffer.m_iItemDefinitionIndex = kv.GetNum("Index");

	// Check if cosmetic definition contains attributes.
	if(kv.JumpToKey("Attributes"))
	{
		// If so, create an array list.
		buffer.m_Attributes = new ArrayList(sizeof(TFAttribute));

		// Try going to the first attribute scope.
		if(kv.GotoFirstSubKey(false))
		{
			do {
				// Read name and float value, add the pair to the attributes array.
				TFAttribute attrib;
				kv.GetSectionName(attrib.m_szName, sizeof(attrib.m_szName));
				attrib.m_flValue = kv.GetFloat(NULL_STRING);
				buffer.m_Attributes.PushArray(attrib);
			} while (kv.GotoNextKey(false))
			kv.GoBack();
		}
		kv.GoBack();
	}
}

/**
 * Load bot cosmetics definitions from config.
 */
public Config_LoadCosmeticsFromKV(KeyValues kv)
{
	Config_DisposeOfBotItemArrayList(g_hBotCosmetics);
	g_hBotCosmetics = new ArrayList(sizeof(BotItem));
	
	if(kv.GotoFirstSubKey(false))
	{
		do {
            // Create bot cosmetic definition.
            BotItem item;
            Config_LoadItemFromKV(kv, item);
            g_hBotCosmetics.PushArray(item);

		} while (kv.GotoNextKey(false));

		kv.GoBack();
	}
}

/**
 * Load bot cosmetics definitions from config.
 */
public Config_LoadWeaponsFromKV(KeyValues kv)
{
	Config_DisposeOfBotItemArrayList(g_hPrimaryWeapons);
	Config_DisposeOfBotItemArrayList(g_hSecondaryWeapons);
	Config_DisposeOfBotItemArrayList(g_hMeleeWeapons);

	if(kv.JumpToKey("Primary"))
	{
		Config_LoadWeaponsFromKVToArray(kv, g_hPrimaryWeapons);
		kv.GoBack();
	}

	if(kv.JumpToKey("Secondary"))
	{
		Config_LoadWeaponsFromKVToArray(kv, g_hSecondaryWeapons);
		kv.GoBack();
	}

	if(kv.JumpToKey("Melee"))
	{
		Config_LoadWeaponsFromKVToArray(kv, g_hMeleeWeapons);
		kv.GoBack();
	}
}

/**
 * Load bot cosmetics definitions from config.
 */
public Config_LoadWeaponsFromKVToArray(KeyValues kv, ArrayList& array)
{
	array = new ArrayList(sizeof(BotItem));
	
	if(kv.GotoFirstSubKey(false))
	{
		do {
            // Create bot cosmetic definition.
            BotItem item;
            Config_LoadItemFromKV(kv, item);
            array.PushArray(item);

		} while (kv.GotoNextKey(false));

		kv.GoBack();
	}
}

public Config_DisposeOfBotItemArrayList(ArrayList array)
{
	if(array)
	{
		for(int i = 0; i < array.Length; i++)
		{
			BotItem item;
			array.GetArray(i, item);
			delete item.m_Attributes;
		}
	}
	
	delete array;
}
