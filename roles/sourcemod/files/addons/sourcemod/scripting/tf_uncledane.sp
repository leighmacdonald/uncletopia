#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2attributes>
#include <tf2>
#include <tf2_stocks>
#include <tf2items>
#include <tf_econ_data>
#include <dhooks>

#define PLUGIN_VERSION "0.7.1"

/** Display name of the humans team */
#define PVE_TEAM_HUMANS_NAME 	"blue"
/** Internal game index of the bots team */
#define PVE_TEAM_BOTS_NAME 		"red"
/** Maximum amount of players that can be on the server in TF2 */
#define TF_MAXPLAYERS 			32

#define GOLDEN_PAN_DEFID 		1071 
#define GOLDEN_PAN_CHANCE 		1

const TFTeam TFTeam_Humans = TFTeam_Blue;
const TFTeam TFTeam_Bots = TFTeam_Red;

/** Maximum amount of attributes on a bot cosmetic */
#define PVE_MAX_COSMETIC_ATTRS 8

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

// Weapon random choices.
ArrayList g_hPrimaryWeapons;
ArrayList g_hSecondaryWeapons;
ArrayList g_hMeleeWeapons;

public Plugin myinfo = 
{
	name = "[TF2] Uncle Dane PVE",
	author = "Moonly Days",
	description = "Uncle Dane PVE",
	version = PLUGIN_VERSION,
	url = "https://github.com/MoonlyDays"
};

// Plugin ConVars
ConVar sm_danepve_bot_sapper_insta_remove;
ConVar sm_danepve_respawn_bots_on_round_end;
ConVar sm_danepve_clear_bots_building_gibs;
ConVar sm_danepve_allow_respawnroom_build;
ConVar sm_danepve_max_playing_humans;
ConVar sm_danepve_max_connected_humans;

// SDK Call Handles
Handle g_hSdkEquipWearable;
DynamicHook gHook_HandleSwitchTeams;
DynamicDetour gHook_PointIsWithin;
DynamicDetour gHook_EstimateValidBuildPos;
DynamicDetour gHook_CreateAmmoPack;

// Offset cache
int g_nOffset_CBaseEntity_m_iTeamNum;

int g_iTeamRoundTimer;
bool g_bIsRoundEnd = false;
float g_flForceClearGibsUntil = 0.0;
bool g_bIsRoundActive = false;
float g_flRoundStartTime = 0.0;
bool g_bLastDeathWasBot = false;

#include <danepve/config.sp>

public OnPluginStart()
{
	//-----------------------------------------------------//
	// Create plugin ConVars
	CreateConVar("danepve_version", PLUGIN_VERSION, "[TF2] Uncle Dane PVE Version", FCVAR_DONTRECORD);
	sm_danepve_allow_respawnroom_build = CreateConVar("sm_danepve_allow_respawnroom_build", "1", "Can humans build in respawn rooms?");
	sm_danepve_max_playing_humans = CreateConVar("sm_danepve_max_playing_humans", "12");
	sm_danepve_max_connected_humans = CreateConVar("sm_danepve_max_connected_humans", "16");
	sm_danepve_bot_sapper_insta_remove = CreateConVar("sm_danepve_bot_sapper_insta_remove", "1");
	sm_danepve_clear_bots_building_gibs = CreateConVar("sm_danepve_clear_bots_building_gibs", "1");
	sm_danepve_respawn_bots_on_round_end = CreateConVar("sm_danepve_respawn_bots_on_round_end", "0");
	RegAdminCmd("sm_danepve_reload", cReload, ADMFLAG_CHANGEMAP, "Reloads Uncle Dane PVE config.");
	RegConsoleCmd("sm_becomedanebot", cBecomeUncleDane);
	
	// Since 'jointeam' command is exists in most games, use AddCommandListener instead of Reg*Cmd
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
	Handle hConf = LoadGameConfigFile("tf2.danepve");
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CTFPlayer::EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSdkEquipWearable = EndPrepSDKCall();

	CreateTimer(0.5, Timer_UpdateRoundTime, _, TIMER_REPEAT);

	//-----------------------------------------------------//
	// CTFGameRules::HandleSwitchTeams
	gHook_HandleSwitchTeams = new DynamicHook(0, HookType_GameRules, ReturnType_Void, ThisPointer_Ignore);
	if(gHook_HandleSwitchTeams.SetFromConf(hConf, SDKConf_Virtual, "CTFGameRules::HandleSwitchTeams") == false)
		SetFailState("Failed to load CTFGameRules::HandleSwitchTeams detour.");

	//-----------------------------------------------------//
	// PointIsWithin
	gHook_PointIsWithin = new DynamicDetour(Address_Null, CallConv_THISCALL, ReturnType_Bool, ThisPointer_Address);
	if(gHook_PointIsWithin.SetFromConf(hConf, SDKConf_Signature, "PointIsWithin") == false)
		SetFailState("Failed to load PointIsWithin detour.");
	gHook_PointIsWithin.AddParam(HookParamType_VectorPtr);
	gHook_PointIsWithin.Enable(Hook_Pre, Detour_OnPointIsWithin);

	//-----------------------------------------------------//
	// EstimateValidBuildPos
	gHook_EstimateValidBuildPos = new DynamicDetour(Address_Null, CallConv_THISCALL, ReturnType_Bool, ThisPointer_Address);
	gHook_EstimateValidBuildPos.SetFromConf(hConf, SDKConf_Signature, "EstimateValidBuildPos");
	if(gHook_PointIsWithin.SetFromConf(hConf, SDKConf_Signature, "EstimateValidBuildPos") == false)
		SetFailState("Failed to load EstimateValidBuildPos detour.");
	gHook_EstimateValidBuildPos.Enable(Hook_Pre, Detour_EstimateValidBuildPos);
	gHook_EstimateValidBuildPos.Enable(Hook_Post, Detour_EstimateValidBuildPos_Post);
	
	//-----------------------------------------------------//
	// CBaseObject::CreateAmmoPack
	gHook_CreateAmmoPack = new DynamicDetour(Address_Null, CallConv_THISCALL, ReturnType_CBaseEntity, ThisPointer_CBaseEntity);
	if(gHook_CreateAmmoPack.SetFromConf(hConf, SDKConf_Signature, "CBaseObject::CreateAmmoPack") == false)
		SetFailState("Failed to load CBaseObject::CreateAmmoPack detour.");
	gHook_CreateAmmoPack.AddParam(HookParamType_CharPtr);
	gHook_CreateAmmoPack.AddParam(HookParamType_Int);
	gHook_CreateAmmoPack.Enable(Hook_Pre, Detour_CreateAmmoPack);

}

public OnMapStart()
{
	gHook_HandleSwitchTeams.HookGamerules(Hook_Pre, CTFGameRules_HandleSwitchTeams);

	//-----------------------------------------------------//
	// Load config and setup the game
	Config_Load();
}

public OnClientPutInServer(int client)
{
	if(IsClientSourceTV(client))
		return;

	CreateTimer(0.1, Timer_OnClientConnect, client);
}

public bool OnClientConnect(int client, char[] rejectMsg, int maxlen)
{
	if(PVE_GetHumanCount() > sm_danepve_max_connected_humans.IntValue)
	{
		Format(rejectMsg, maxlen, "[PVE] Server is full");
		return false;
	}

	return true;
}

public OnEntityCreated(int entity, const char[] szClassname)
{
	if((g_bIsRoundEnd && g_bLastDeathWasBot) || g_flForceClearGibsUntil > GetGameTime())
	{
		// Remove these entities on round end / humiliation.
		if(	StrEqual(szClassname, "tf_ammo_pack") || 
			StrEqual(szClassname, "tf_dropped_weapon") ||
			StrEqual(szClassname, "tf_ragdoll"))
		{
			AcceptEntityInput(entity, "Kill");
		}
	}

	// No halloween allowed >:C
	if(StrEqual(szClassname, "halloween_souls_pack"))
	{
		AcceptEntityInput(entity, "Kill");
	}

	if(StrEqual(szClassname, "obj_attachment_sapper"))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, OnSapperTakeDamage);
	}
}

//-------------------------------------------------------//
// GAMEMODE STOCKS
//-------------------------------------------------------//

// Return the amount of connected(-ing) human players.
public int PVE_GetHumanCount()
{
	int count = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
        if (IsClientConnected(i) && !IsFakeClient(i))
            count++;
	}
	
	return count;
}

// Return the amount of clients on a given team.
public int PVE_GetClientCountOnTeam(TFTeam team)
{
	int count = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;

		if (TF2_GetClientTeam(i) == team)
			count++;
	}
	
	return count;
}

// Give bot a name from the config
public void PVE_RenameBotClient(int client)
{
	// Figure out the name of the bot.
	// Make a static variable to store current local name index.
	static int currentName = -1;
	// Rotate the names
	int maxNames = g_hBotNames.Length;
	currentName++;
	currentName %= maxNames;

	char szName[PLATFORM_MAX_PATH];
	g_hBotNames.GetString(currentName, szName, sizeof(szName));
	SetClientName(client, szName);
}

// Equip bots with appropriate weapons
public void PVE_EquipBotItems(int client)
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

		TF2Attrib_SetByName(weapon, "killstreak tier", 3.0);
		TF2Attrib_SetByName(weapon, "killstreak effect", 		float(specKs));
		TF2Attrib_SetByName(weapon, "killstreak idleeffect", 	float(profKs));
	}
}

// Give a bot a random weapon in slot from an array defined in ArrayList 
public void PVE_GiveBotRandomSlotWeaponFromArrayList(int client, int slot, ArrayList array)
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
public void PVE_ApplyBotItemAttributesOnEntity(int entity, BotItem item)
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

public bool PVE_CanMoreHumansJoin()
{
	return PVE_GetClientCountOnTeam(TFTeam_Humans) < sm_danepve_max_playing_humans.IntValue;
}

// Apply player attributes from config on a given client 
public void PVE_ApplyPlayerAttributes(int client)
{
	for(int i = 0; i < g_hPlayerAttributes.Length; i++)
	{
		TFAttribute attrib;
		g_hPlayerAttributes.GetArray(i, attrib);
		TF2Attrib_SetByName(client, attrib.m_szName, attrib.m_flValue);
	}
}

// Create and give wearable to client with a given item definition
public int PVE_GiveWearableToClient(int client, int itemDef)
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
public Action cReload(int client, int args)
{
	Config_Load();
	ReplyToCommand(client, "[SM] Uncle Dane PVE config was reloaded!");
	return Plugin_Handled;
}

public Action cJoinTeam(int client, const char[] command, int argc)
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

		// Check if there is enough humans.
		if(!PVE_CanMoreHumansJoin())
		{
			// If there isn't, show the message and change their team.
			int humanCount = PVE_GetClientCountOnTeam(TFTeam_Humans);
			PrintCenterText(client, "There are no open slots on the HUMAN team (%d/%d). Please try again later.", humanCount, humanCount);
			ClientCommand(client, "jointeam spectator");
			return Plugin_Handled;
		} 

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

public Action cAutoTeam(int client, const char[] command, int argc)
{
	ReplyToCommand(client, "[SM] \"autoteam\" command is disabled.");
	return Plugin_Handled;
}

#define UNCLE_DANE_STEAMID "STEAM_0:0:48866904"

// sm_becomedanebot
public Action cBecomeUncleDane(int client, int args)
{
	char szSteamId[PLATFORM_MAX_PATH];
	GetClientAuthId(client, AuthId_Steam2, szSteamId, sizeof(szSteamId));
	if(!StrEqual(szSteamId, UNCLE_DANE_STEAMID))
	{
		ReplyToCommand(client, "[SM] Sorry, you are not Uncle Dane. You can't do that. :C");
		return Plugin_Handled;
	}

	TF2_ChangeClientTeam(client, TFTeam_Bots);
	PrintCenterText(client, "You are now an Uncle Dane bot!");
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
	g_bLastDeathWasBot = isBot;

	// If we're on round end
	if(g_bIsRoundEnd)
	{
		// And we don't want to respawn bots during round end.
		if(!sm_danepve_respawn_bots_on_round_end.BoolValue)
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
	if(!sm_danepve_bot_sapper_insta_remove.BoolValue)
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
// DHook Sapper
//-------------------------------------------------------//

int g_bAllowNextHumanTeamPointCheck = false;

// CBaseObject::CreateAmmoPack
MRESReturn Detour_CreateAmmoPack(int pThis, DHookReturn hReturn)
{
	if(sm_danepve_clear_bots_building_gibs.BoolValue)
	{
		// Clear gibs from bots buildings.
		if(GetEntProp(pThis, Prop_Send, "m_iTeamNum") == view_as<int>(TFTeam_Bots))
		{
			hReturn.Value = -1;
			return MRES_Supercede;
		}
	}

	return MRES_Ignored;
}

// CBaseObject::EstimateValidBuildPos
MRESReturn Detour_EstimateValidBuildPos(Address pThis, Handle hReturn, Handle hParams)
{
	if(!sm_danepve_allow_respawnroom_build.BoolValue)
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