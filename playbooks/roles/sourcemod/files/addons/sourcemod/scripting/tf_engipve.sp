#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2attributes>
#include <tf2>
#include <tf2_stocks>
#include <tf2items>
#include <tf_econ_data>
#include <dhooks>

#define PLUGIN_VERSION "0.8.2"

#define PVE_TEAM_HUMANS_NAME "blue"
#define PVE_TEAM_BOTS_NAME "red"

#define UNCLE_DANE_STEAMID "STEAM_0:0:48866904"

#define MAX_COSMETIC_ATTRS 8
#define GIBS_CLEANUP_PERIOD 10.0

#define GOLDEN_PAN_DEFID 1071
#define GOLDEN_PAN_CHANCE 1

#define TFTeam_Humans TFTeam_Blue
#define TFTeam_Bots TFTeam_Red

public Plugin myinfo = 
{
	name = "[TF2] Engineer PVE",
	author = "Moonly Days, Uncle Dane",
	description = "Engineer PVE",
	version = PLUGIN_VERSION,
	url = "https://github.com/MoonlyDays"
};

enum struct TFAttribute
{
	char m_szName[PLATFORM_MAX_PATH];
	float m_flValue;
}

enum struct BotItem
{
	int m_iItemDefinitionIndex;
	char m_szClassName[32];
	ArrayList m_Attributes;
} 

ArrayList g_hBotCosmetics;
ArrayList g_hPlayerAttributes;
ArrayList g_hBotNames;

ArrayList g_hPrimaryWeapons;
ArrayList g_hSecondaryWeapons;
ArrayList g_hMeleeWeapons;

// Plugin ConVars
ConVar sm_engipve_bot_sapper_insta_remove;
ConVar sm_engipve_respawn_bots_on_round_end;
ConVar sm_engipve_allow_respawnroom_build;
ConVar sm_engipve_clear_gibs;

ConVar tf_bot_quota;

// SDK Call Handles
Handle g_hSdkEquipWearable;
DynamicHook gHook_HandleSwitchTeams;
DynamicDetour gHook_PointIsWithin;
DynamicDetour gHook_EstimateValidBuildPos;
DynamicDetour gHook_CreateObjectGibs;
DynamicDetour gHook_DropAmmoPack;
DynamicDetour gHook_CreateRagdollEntity;

// Offset cache
int g_nOffset_CBaseEntity_m_iTeamNum;

int g_iTeamRoundTimer;
bool g_bIsRoundEnd = false;
bool g_bIsRoundActive = false;
float g_flRoundStartTime = 0.0;

char g_szCleanupEntities[][] = {
	"keyframe_rope",
	"move_rope",
	"env_sprite",
	"env_lightglow",
	"env_smokestack",
	"func_smokevolume",
	"func_dust",
	"func_dustmotes",
	"point_spotlight",
	"env_smoketrail",
	"env_sun"
}

public OnPluginStart()
{
	//-----------------------------------------------------//
	// Create plugin ConVars
	CreateConVar("engipve_version", PLUGIN_VERSION, "[TF2] Engineer PVE Version", FCVAR_DONTRECORD);
	sm_engipve_allow_respawnroom_build 		= CreateConVar("sm_engipve_allow_respawnroom_build", "1", "Can humans build in respawn rooms?");
	sm_engipve_bot_sapper_insta_remove 		= CreateConVar("sm_engipve_bot_sapper_insta_remove", "1");
	sm_engipve_respawn_bots_on_round_end 	= CreateConVar("sm_engipve_respawn_bots_on_round_end", "0");
	sm_engipve_clear_gibs					= CreateConVar("sm_engipve_clear_gibs", "1");
	tf_bot_quota 							= FindConVar("tf_bot_quota");

	RegAdminCmd("sm_engipve_reload", cReload, ADMFLAG_CHANGEMAP, "Reloads Engineer PVE config.");
	RegAdminCmd("sm_becomeengibot", cBecomeEngiBot, ADMFLAG_ROOT, "Switches the client to the bot team.");
	
	AddCommandListener(cJoinTeam, "jointeam");
	AddCommandListener(cAutoTeam, "autoteam");

	//-----------------------------------------------------//
	// Hook Events
	HookEvent("post_inventory_application", post_inventory_application);
	HookEvent("teamplay_round_start", 		teamplay_round_start);
	HookEvent("teamplay_round_win", 		teamplay_round_win);
	HookEvent("teamplay_setup_finished", 	teamplay_setup_finished);
	HookEvent("player_death",				player_death);
	
	//-----------------------------------------------------//
	// Offsets Cache
	g_nOffset_CBaseEntity_m_iTeamNum = FindSendPropInfo("CBaseEntity", "m_iTeamNum");

	//-----------------------------------------------------//
	// Prepare SDK calls from Game Data
	Handle hConf = LoadGameConfigFile("tf2.engipve");
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CTFPlayer::EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSdkEquipWearable = EndPrepSDKCall();

	CreateTimer(0.5, Timer_UpdateRoundTime, _, TIMER_REPEAT);

	//-----------------------------------------------------//
	// CTFGameRules::HandleSwitchTeams
	gHook_HandleSwitchTeams = new DynamicHook(0, HookType_GameRules, ReturnType_Void, ThisPointer_Ignore);
	if(gHook_HandleSwitchTeams.SetFromConf(hConf, SDKConf_Virtual, "CTFGameRules::HandleSwitchTeams") == false) {
		SetFailState("Failed to load CTFGameRules::HandleSwitchTeams detour.");
	}

	//-----------------------------------------------------//
	// PointIsWithin
	gHook_PointIsWithin = new DynamicDetour(Address_Null, CallConv_THISCALL, ReturnType_Bool, ThisPointer_Address);
	if(! gHook_PointIsWithin.SetFromConf(hConf, SDKConf_Signature, "PointIsWithin")) {
		SetFailState("Failed to load PointIsWithin detour.");
	}
	gHook_PointIsWithin.AddParam(HookParamType_VectorPtr);
	gHook_PointIsWithin.Enable(Hook_Pre, Detour_OnPointIsWithin);

	//-----------------------------------------------------//
	// EstimateValidBuildPos
	gHook_EstimateValidBuildPos = new DynamicDetour(Address_Null, CallConv_THISCALL, ReturnType_Bool, ThisPointer_Address);
	gHook_EstimateValidBuildPos.SetFromConf(hConf, SDKConf_Signature, "EstimateValidBuildPos");
	if(! gHook_PointIsWithin.SetFromConf(hConf, SDKConf_Signature, "EstimateValidBuildPos")) {
		SetFailState("Failed to load EstimateValidBuildPos detour.");
	}
	gHook_EstimateValidBuildPos.Enable(Hook_Pre, Detour_EstimateValidBuildPos);
	gHook_EstimateValidBuildPos.Enable(Hook_Post, Detour_EstimateValidBuildPos_Post);
	
	//-----------------------------------------------------//
	// CBaseObject::CreateObjectGibs
	gHook_CreateObjectGibs = new DynamicDetour(Address_Null, CallConv_THISCALL, ReturnType_Void, ThisPointer_CBaseEntity);
	if(! gHook_CreateObjectGibs.SetFromConf(hConf, SDKConf_Signature, "CBaseObject::CreateObjectGibs")) {
		SetFailState("Failed to load CBaseObject::CreateObjectGibs detour.");
	}
	gHook_CreateObjectGibs.Enable(Hook_Pre, Detour_CreateObjectGibs);
	
	//-----------------------------------------------------//
	// CBaseObject::CreateObjectGibs
	gHook_DropAmmoPack = new DynamicDetour(Address_Null, CallConv_THISCALL, ReturnType_Void, ThisPointer_CBaseEntity);
	if(! gHook_DropAmmoPack.SetFromConf(hConf, SDKConf_Signature, "CTFPlayer::DropAmmoPack")) {
		SetFailState("Failed to load CTFPlayer::DropAmmoPack detour.");
	}
	gHook_DropAmmoPack.AddParam(HookParamType_ObjectPtr);
	gHook_DropAmmoPack.AddParam(HookParamType_Bool);
	gHook_DropAmmoPack.AddParam(HookParamType_Bool);
	gHook_DropAmmoPack.Enable(Hook_Pre, Detour_DropAmmoPack);
	
	//-----------------------------------------------------//
	// CTFPlayer::CreateRagdollEntity
	gHook_CreateRagdollEntity = new DynamicDetour(Address_Null, CallConv_THISCALL, ReturnType_Void, ThisPointer_CBaseEntity);
	if(! gHook_CreateRagdollEntity.SetFromConf(hConf, SDKConf_Signature, "CTFPlayer::CreateRagdollEntity")) {
		SetFailState("Failed to load CTFPlayer::CreateRagdollEntity detour.");
	}
	gHook_CreateRagdollEntity.AddParam(HookParamType_Bool);
	gHook_CreateRagdollEntity.AddParam(HookParamType_Bool);
	gHook_CreateRagdollEntity.AddParam(HookParamType_Bool);
	gHook_CreateRagdollEntity.AddParam(HookParamType_Bool);
	gHook_CreateRagdollEntity.AddParam(HookParamType_Bool);
	gHook_CreateRagdollEntity.AddParam(HookParamType_Bool);
	gHook_CreateRagdollEntity.AddParam(HookParamType_Bool);
	gHook_CreateRagdollEntity.AddParam(HookParamType_Bool);
	gHook_CreateRagdollEntity.AddParam(HookParamType_Int);
	gHook_CreateRagdollEntity.AddParam(HookParamType_Bool);
	gHook_CreateRagdollEntity.Enable(Hook_Pre, Detour_CreateRagdollEntity);

	AutoExecConfig(true, "tf_engipve");
}

public void OnConfigsExecuted()
{
	Config_Load();
}

public OnMapStart()
{
	gHook_HandleSwitchTeams.HookGamerules(Hook_Pre, CTFGameRules_HandleSwitchTeams);
}

public OnClientPutInServer(int client)
{
	if(IsClientSourceTV(client))
		return;

	CreateTimer(0.1, Timer_OnClientConnect, client);
}

public bool OnClientConnect(int client, char[] rejectMsg, int maxlen)
{
	int maxHumans = MaxClients - tf_bot_quota.IntValue;
	if(PVE_GetHumanCount() > maxHumans)
	{
		Format(rejectMsg, maxlen, "[1000 Engis] No more human slots are available, sorry :C");
		return false;
	}

	return true;
}

public OnEntityCreated(int entity, const char[] szClassname)
{
	for (int i = 0; i < sizeof(g_szCleanupEntities); i++) {
		if (StrEqual(szClassname, g_szCleanupEntities[i])) {
			RemoveEntity(entity);
			return;
		}
	}

	if (StrEqual(szClassname, "obj_attachment_sapper"))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, OnSapperTakeDamage);
	}
}

//-------------------------------------------------------//
// CONFIG
//-------------------------------------------------------//

/** Reload the plugin config */
void Config_Load()
{
	// Build the path to the config file. 
	char szCfgPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szCfgPath, sizeof(szCfgPath), "configs/tf_engipve.cfg");

	// Load the keyvalues.
	KeyValues kv = new KeyValues("EngineerPVE");
	if(kv.ImportFromFile(szCfgPath) == false)
	{
		SetFailState("Failed to read configs/tf_engipve.cfg");
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
	FindConVar("tf_bot_auto_vacate")		.SetBool(false);
	FindConVar("tf_bot_quota")				.SetInt(kv.GetNum("Count"));
	FindConVar("mp_disable_respawn_times")	.SetBool(true);
	FindConVar("mp_teams_unbalance_limit")	.SetInt(0);
}

/** Reload the bot names that will be on the bot team. */
void Config_LoadNamesFromKV(KeyValues kv)
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
void Config_LoadAttributesFromKV(KeyValues kv)
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

void Config_LoadItemFromKV(KeyValues kv, BotItem buffer)
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
void Config_LoadCosmeticsFromKV(KeyValues kv)
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
void Config_LoadWeaponsFromKV(KeyValues kv)
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
void Config_LoadWeaponsFromKVToArray(KeyValues kv, ArrayList& array)
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

void Config_DisposeOfBotItemArrayList(ArrayList array)
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

//-------------------------------------------------------//
// GAMEMODE STOCKS
//-------------------------------------------------------//

// Return the amount of connected(-ing) human players.
int PVE_GetHumanCount()
{
	int count = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
        if (IsClientConnected(i) && !IsFakeClient(i))
            count++;
	}
	
	return count;
}

// Give bot a name from the config
void PVE_RenameBotClient(int client)
{
	// Figure out the name of the bot.
	// Make a static variable to store current local name index.
	static int currentName = -1;
	// Rotate the names
	int maxNames = g_hBotNames.Length;
	currentName++;
	currentName = currentName % maxNames;

	char szName[PLATFORM_MAX_PATH];
	g_hBotNames.GetString(currentName, szName, sizeof(szName));
	SetClientName(client, szName);
}

// Equip bots with appropriate weapons
void PVE_EquipBotItems(int client)
{
	for(int i = 0; i < g_hBotCosmetics.Length; i++)
	{
		BotItem cosmetic;
		g_hBotCosmetics.GetArray(i, cosmetic);

		int hat = PVE_GiveWearableToClient(client, cosmetic.m_iItemDefinitionIndex);
		if(hat <= 0)
			continue;
			
		PVE_ApplyBotItemAttributesOnEntity(hat, cosmetic);
	}

	PVE_GiveBotRandomSlotWeaponFromArrayList(client, TFWeaponSlot_Primary, 		g_hPrimaryWeapons);
	PVE_GiveBotRandomSlotWeaponFromArrayList(client, TFWeaponSlot_Secondary, 	g_hSecondaryWeapons);
	PVE_GiveBotRandomSlotWeaponFromArrayList(client, TFWeaponSlot_Melee, 		g_hMeleeWeapons);

	for(int i = TFWeaponSlot_Primary; i <= TFWeaponSlot_Melee; i++)
	{
		int weapon = GetPlayerWeaponSlot(client, i);
		if(!IsValidEntity(weapon))
			continue;

		int specKs = GetRandomInt(2002, 2008);
		int profKs = GetRandomInt(1, 7);

		TF2Attrib_SetByName(weapon, "killstreak tier", 			3.0);
		TF2Attrib_SetByName(weapon, "killstreak effect",		float(specKs));
		TF2Attrib_SetByName(weapon, "killstreak idleeffect",	float(profKs));
	}
}

// Give a bot a random weapon in slot from an array defined in ArrayList 
void PVE_GiveBotRandomSlotWeaponFromArrayList(int client, int slot, ArrayList array)
{
	if(array == INVALID_HANDLE)
		return;

	int rndInt = GetRandomInt(0, array.Length - 1);
	BotItem item;
	array.GetArray(rndInt, item);

	int wepDefId = item.m_iItemDefinitionIndex;
	bool isGoldenPan = false;

	// Golden Pan Easter Egg!!!
	if(slot == TFWeaponSlot_Melee)
	{
		if(GetRandomInt(0, 100) < GOLDEN_PAN_CHANCE)
		{
			// Bot has 1% chance to have Golden Pan
			// as their melee.
			wepDefId = GOLDEN_PAN_DEFID;
			isGoldenPan = true;
		}
	}

	char szClassName[64];
	TF2Econ_GetItemClassName(wepDefId, szClassName, sizeof(szClassName));
	TF2Econ_TranslateWeaponEntForClass(szClassName, sizeof(szClassName), TF2_GetPlayerClass(client));

	Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL | FORCE_GENERATION | PRESERVE_ATTRIBUTES);
	TF2Items_SetClassname(hWeapon, szClassName);
	TF2Items_SetItemIndex(hWeapon, wepDefId);

	int iWeapon = TF2Items_GiveNamedItem(client, hWeapon);
	delete hWeapon;

	if(isGoldenPan)
	{
		TF2Attrib_SetByName(iWeapon, "item style override", 0.0);
	}

	TF2_RemoveWeaponSlot(client, slot);
	EquipPlayerWeapon(client, iWeapon);

	PVE_ApplyBotItemAttributesOnEntity(iWeapon, item);
}

// Apply attributes from config item defintion on entity.
void PVE_ApplyBotItemAttributesOnEntity(int entity, BotItem item)
{
	if(item.m_Attributes)
	{
		for(int j = 0; j < item.m_Attributes.Length; j++)
		{
			TFAttribute attrib;
			item.m_Attributes.GetArray(j, attrib);
			TF2Attrib_SetByName(entity, attrib.m_szName, attrib.m_flValue);
		}
	}
}

// Apply player attributes from config on a given client 
void PVE_ApplyPlayerAttributes(int client)
{
	for(int i = 0; i < g_hPlayerAttributes.Length; i++)
	{
		TFAttribute attrib;
		g_hPlayerAttributes.GetArray(i, attrib);
		TF2Attrib_SetByName(client, attrib.m_szName, attrib.m_flValue);
	}
}

// Create and give wearable to client with a given item definition
int PVE_GiveWearableToClient(int client, int itemDef)
{
	int hat = CreateEntityByName("tf_wearable");
	if(!IsValidEntity(hat))
		return -1;
	
	SetEntProp(hat, Prop_Send, "m_iItemDefinitionIndex", itemDef);
	SetEntProp(hat, Prop_Send, "m_bInitialized", 1);
	SetEntProp(hat, Prop_Send, "m_iEntityLevel", 50);
	SetEntProp(hat, Prop_Send, "m_bValidatedAttachedEntity", 1);
	SetEntProp(hat, Prop_Send, "m_iAccountID", GetSteamAccountID(client));
	SetEntPropEnt(hat, Prop_Send, "m_hOwnerEntity", client);
	DispatchSpawn(hat);
	
	SDKCall(g_hSdkEquipWearable, client, hat);
	return hat;
}

//-------------------------------------------------------//
// Commands
//-------------------------------------------------------//

// sv_danepve_reload
Action cReload(int client, int args)
{
	Config_Load();
	ReplyToCommand(client, "[SM] Engineer PVE config was reloaded!");
	return Plugin_Handled;
}

Action cJoinTeam(int client, const char[] command, int argc)
{
	// A human wishes to change their team.
	char szTeamArg[11];
	GetCmdArg(1, szTeamArg, sizeof(szTeamArg));

	// Selecting red team automatically redirect to selecting blue team.
	if(StrEqual(szTeamArg, "red", false))
	{
		ClientCommand(client, "jointeam blue");
		return Plugin_Handled;
	}

	if(StrEqual(szTeamArg, "blue", false))
	{
		// Client is already on the blue team, do nothing.
		if(TF2_GetClientTeam(client) == TFTeam_Humans)
			return Plugin_Handled;

		return Plugin_Continue;
	}


	// Whitelist spectator commands.
	if(	StrEqual(szTeamArg, "spec", false) || 
		StrEqual(szTeamArg, "spectate", false) || 
		StrEqual(szTeamArg, "spectator", false))
	{
		return Plugin_Continue;
	}
	
	// Block eveything else.
	return Plugin_Handled;
}

Action cAutoTeam(int client, const char[] command, int argc)
{
	ReplyToCommand(client, "[SM] \"autoteam\" command is disabled.");
	return Plugin_Handled;
}


// sm_becomeengibot
Action cBecomeEngiBot(int client, int args)
{
	TF2_ChangeClientTeam(client, TFTeam_Bots);
	PrintCenterText(client, "You are now an Engineer bot!");
	return Plugin_Handled;
}

//-------------------------------------------------------//
// Game Events
//-------------------------------------------------------//

public Action post_inventory_application(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(IsFakeClient(client))
	{
		PVE_EquipBotItems(client);
		PVE_ApplyPlayerAttributes(client);
	}

	return Plugin_Continue;
}

public Action player_death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	bool isBot = IsFakeClient(client);

	// If we're on round end
	if(g_bIsRoundEnd)
	{
		// And we don't want to respawn bots during round end.
		if(! sm_engipve_respawn_bots_on_round_end.BoolValue)
		{
			// Bail out.
			return Plugin_Handled;
		}
	}

	if(isBot)
	{
		CreateTimer(0.1, Timer_RespawnBot, client);
	}

	return Plugin_Continue;
}

public Action teamplay_setup_finished(Event event, const char[] name, bool dontBroadcast)
{
	g_bIsRoundActive = true;
	g_flRoundStartTime = GetGameTime();
	g_iTeamRoundTimer = FindEntityByClassname(-1, "team_round_timer");

	return Plugin_Continue;
}

public Action teamplay_round_win(Event event, const char[] name, bool dontBroadcast)
{
	g_bIsRoundActive = false;
	g_bIsRoundEnd = true;
	return Plugin_Continue;
}

public Action teamplay_round_start(Event event, const char[] name, bool dontBroadcast)
{
	g_bIsRoundEnd = false;
	g_bIsRoundActive = false;
	return Plugin_Continue;
}

//-------------------------------------------------------//
// TIMERS
//-------------------------------------------------------//

public Action Timer_OnClientConnect(Handle timer, any client)
{
	if(IsFakeClient(client))
	{
		// Bots need to be renamed, and force their team to RED.
		PVE_RenameBotClient(client);
		TF2_ChangeClientTeam(client, TFTeam_Bots);
	}

	return Plugin_Handled;
}

public Action Timer_RespawnBot(Handle timer, any client)
{
	TF2_RespawnPlayer(client);
	return Plugin_Handled;
}

public Action Timer_UpdateRoundTime(Handle timer, any ent)
{
	// Round is not active - do nothing.
	if(!g_bIsRoundActive)
		return Plugin_Handled;

	if(g_iTeamRoundTimer <= 0)
		return Plugin_Handled;

	float curTime = GetGameTime();
	float startTime = g_flRoundStartTime;
	float elapsTime = curTime - startTime;
	int iElapsTime = RoundToFloor(elapsTime);

	SetVariantInt(iElapsTime);
	AcceptEntityInput(g_iTeamRoundTimer, "SetMaxTime");
	SetVariantInt(iElapsTime);
	AcceptEntityInput(g_iTeamRoundTimer, "SetTime");
	AcceptEntityInput(g_iTeamRoundTimer, "Pause");

	return Plugin_Handled;
}

//-------------------------------------------------------//
// SDK Hooks
//-------------------------------------------------------//
public Action OnSapperTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	if(!sm_engipve_bot_sapper_insta_remove.BoolValue)
		return Plugin_Handled;

	if(IsClientInGame(attacker))
	{
		if(TF2_GetClientTeam(attacker) == TFTeam_Bots)
		{
			damage = 9999.0;
			return Plugin_Changed;
		}
	}

	return Plugin_Handled;
}

//-------------------------------------------------------//
// DHook 
//-------------------------------------------------------//

int g_bAllowNextHumanTeamPointCheck = false;

// CBaseObject::CreateObjectGibs
MRESReturn Detour_CreateObjectGibs(int pThis)
{
	return sm_engipve_clear_gibs.BoolValue
		? MRES_Supercede
		: MRES_Ignored;
}

// CBaseObject::CreateObjectGibs
MRESReturn Detour_DropAmmoPack(int pThis, Handle hParams)
{
	return sm_engipve_clear_gibs.BoolValue
		? MRES_Supercede
		: MRES_Ignored;
}

// CTFPlayer::CreateRagdollEntity
MRESReturn Detour_CreateRagdollEntity(int pThis, Handle hParams)
{
	if(sm_engipve_clear_gibs.BoolValue) {
		TFTeam team = TF2_GetClientTeam(pThis);
		if(team == TFTeam_Bots) {
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}

// CBaseObject::EstimateValidBuildPos
MRESReturn Detour_EstimateValidBuildPos(Address pThis, Handle hReturn, Handle hParams)
{
	if(! sm_engipve_allow_respawnroom_build.BoolValue)
		return MRES_Ignored;

	g_bAllowNextHumanTeamPointCheck = true;
	return MRES_Ignored;
}

// CBaseObject::EstimateValidBuildPos
MRESReturn Detour_EstimateValidBuildPos_Post(Address pThis, Handle hReturn, Handle hParams)
{
	g_bAllowNextHumanTeamPointCheck = false;
	return MRES_Ignored;
}

// CBaseTrigger::PointIsWithin
MRESReturn Detour_OnPointIsWithin(Address pThis, Handle hReturn, Handle hParams)
{
	if(g_bAllowNextHumanTeamPointCheck)
	{
		Address addrTeam = pThis + view_as<Address>(g_nOffset_CBaseEntity_m_iTeamNum);
		TFTeam iTeam = view_as<TFTeam>(LoadFromAddress(addrTeam, NumberType_Int8));
		
		if(iTeam == TFTeam_Humans)
		{
			DHookSetReturn(hReturn, false);
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}

// void CTFGameRules::HandleSwitchTeams( void );
public MRESReturn CTFGameRules_HandleSwitchTeams( int pThis, Handle hParams ) 
{
	PrintToChatAll("Team switching is disabled.");
	return MRES_Supercede;
}