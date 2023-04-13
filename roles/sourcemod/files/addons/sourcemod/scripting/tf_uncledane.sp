#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2attributes>
#include <tf2>
#include <tf2_stocks>
#include <tf2items>
#include <tf_econ_data>
#include <dhooks>

/** Display name of the humans team */
#define PVE_TEAM_HUMANS_NAME 	"blue"
/** Internal game index of the bots team */
#define PVE_TEAM_BOTS_NAME 		"red"
/** Maximum amount of players that can be on the server in TF2 */
#define TF_MAXPLAYERS 			32

#define GOLDEN_PAN_DEFID 1071 
#define GOLDEN_PAN_CHANCE 1

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

#include <danepve/config.sp>

#define PLUGIN_VERSION "0.1.0"

public Plugin myinfo = 
{
	name = "[TF2] Uncle Dane PVE",
	author = "Moonly Days",
	description = "Uncle Dane PVE",
	version = "1.0.0",
	url = "https://github.com/MoonlyDays"
};

// Plugin ConVars
ConVar sm_danepve_allow_respawnroom_build;

// SDK Call Handles
Handle g_hSdkEquipWearable;
Handle gHook_PointIsWithin;
Handle gHook_EstimateValidBuildPos;
Handle gHook_HandleSwitchTeams;

// Offset cache
int g_nOffset_CBaseEntity_m_iTeamNum;


public OnPluginStart()
{
	//
	// Create plugin ConVars
	//

	CreateConVar("danepve_version", PLUGIN_VERSION, "[TF2] Uncle Dane PVE Version", FCVAR_DONTRECORD);
	sm_danepve_allow_respawnroom_build = CreateConVar("sm_danepve_allow_respawnroom_build", "1", "Can humans build in respawn rooms?");
	RegAdminCmd("sm_danepve_reload", cReload, ADMFLAG_CHANGEMAP, "Reloads Uncle Dane PVE config.");

	//
	// Hook Events
	HookEvent("post_inventory_application", post_inventory_application);
	
	//
	// Offsets Cache
	g_nOffset_CBaseEntity_m_iTeamNum = FindSendPropInfo("CBaseEntity", "m_iTeamNum");

	//
	// Prepare SDK calls from Game Data
	Handle hConf = LoadGameConfigFile("tf2.danepve");
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CTFPlayer::EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSdkEquipWearable = EndPrepSDKCall();

	//
	// Setup DHook Detours
	//

	gHook_PointIsWithin = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Bool, ThisPointer_Address);
	DHookSetFromConf(gHook_PointIsWithin, hConf, SDKConf_Signature, "PointIsWithin");
	DHookAddParam(gHook_PointIsWithin, HookParamType_VectorPtr);
	DHookEnableDetour(gHook_PointIsWithin, false, Detour_OnPointIsWithin);

	gHook_EstimateValidBuildPos = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Bool, ThisPointer_Address);
	DHookSetFromConf(gHook_EstimateValidBuildPos, hConf, SDKConf_Signature, "EstimateValidBuildPos");
	DHookEnableDetour(gHook_EstimateValidBuildPos, false, Detour_EstimateValidBuildPos);
	DHookEnableDetour(gHook_EstimateValidBuildPos, true, Detour_EstimateValidBuildPos_Post);

	int offset = GameConfGetOffset(hConf, "CTFGameRules::HandleSwitchTeams");
	gHook_HandleSwitchTeams = DHookCreate(offset, HookType_GameRules, ReturnType_Void, ThisPointer_Ignore, CTFGameRules_HandleSwitchTeams);

	//
	// Load config and setup the game
	//

	Config_Load();
}

public OnMapStart()
{
	DHookGamerules(gHook_HandleSwitchTeams, false);
}

public bool OnClientConnect(int client, char[] rejectMsg, int maxlen)
{
	if(IsFakeClient(client))
	{
		CreateTimer(0.1, Timer_OnBotConnect, client);
	}

	return true;
}

public Action Timer_OnBotConnect(Handle timer, any client)
{
	PVE_RenameBotClient(client);
	TF2_ChangeClientTeam(client, TFTeam_Bots);

	return Plugin_Handled;
}

//-------------------------------------------------------//
// GAMEMODE STOCKS
//-------------------------------------------------------//

public PVE_RenameBotClient(int client)
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

public PVE_EquipBotItems(int client)
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
}

public PVE_GiveBotRandomSlotWeaponFromArrayList(int client, int slot, ArrayList array)
{
	if(array == INVALID_HANDLE)
		return;

	int rndInt = GetRandomInt(0, array.Length - 1);
	BotItem item;
	array.GetArray(rndInt, item);

	int wepDefId = item.m_iItemDefinitionIndex;

	// Golden Pan Easter Egg!!!
	if(slot == TFWeaponSlot_Melee)
	{
		if(GetRandomInt(0, 100) < GOLDEN_PAN_CHANCE)
		{
			// Bot has 1% chance to have Golden Pan
			// as their melee.
			wepDefId = GOLDEN_PAN_DEFID;
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

	TF2_RemoveWeaponSlot(client, slot);
	EquipPlayerWeapon(client, iWeapon);

	PVE_ApplyBotItemAttributesOnEntity(iWeapon, item);
}

public PVE_ApplyBotItemAttributesOnEntity(int entity, BotItem item)
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

public PVE_ApplyPlayerAttributes(int client)
{
	for(int i = 0; i < g_hPlayerAttributes.Length; i++)
	{
		TFAttribute attrib;
		g_hPlayerAttributes.GetArray(i, attrib);
		TF2Attrib_SetByName(client, attrib.m_szName, attrib.m_flValue);
	}
}

int PVE_GiveWearableToClient(int client, int itemDef)
{
	int hat = CreateEntityByName("tf_wearable");
	if(!IsValidEntity(hat))
		return -1;
	
	SetEntProp(hat, Prop_Send, "m_iItemDefinitionIndex", itemDef);
	SetEntProp(hat, Prop_Send, "m_bInitialized", 1);
	SetEntProp(hat, Prop_Send, "m_iEntityLevel", 50);
	SetEntProp(hat, Prop_Send, "m_iEntityQuality", 6);
	SetEntProp(hat, Prop_Send, "m_bValidatedAttachedEntity", 1);
	SetEntProp(hat, Prop_Send, "m_iAccountID", GetSteamAccountID(client));
	SetEntPropEnt(hat, Prop_Send, "m_hOwnerEntity", client);

	DispatchSpawn(hat);
	SDKCall(g_hSdkEquipWearable, client, hat);
	return hat;
} 

//-------------------------------------------------------//
// ConVars
//-------------------------------------------------------//

public Action cReload(int client, int args)
{
	Config_Load();
	ReplyToCommand(client, "[SM] Uncle Dane PVE config was reloaded!");
	return Plugin_Handled;
}

//-------------------------------------------------------//
// GAME EVENTS
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

//
// DHOOK Detours
//

int g_bAllowNextHumanTeamPointCheck = false;

MRESReturn Detour_EstimateValidBuildPos(Address pThis, Handle hReturn, Handle hParams)
{
	if(!sm_danepve_allow_respawnroom_build.BoolValue)
		return MRES_Ignored;

	g_bAllowNextHumanTeamPointCheck = true;
	return MRES_Ignored;
}

MRESReturn Detour_EstimateValidBuildPos_Post(Address pThis, Handle hReturn, Handle hParams)
{
	g_bAllowNextHumanTeamPointCheck = false;
	return MRES_Ignored;
}

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