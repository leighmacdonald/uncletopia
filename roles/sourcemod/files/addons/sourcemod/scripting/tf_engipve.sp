#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2attributes>
#include <tf2>
#include <tf2_stocks>
#include <tf2items>
#include <tf_econ_data>
#include <dhooks>

#define PLUGIN_VERSION       "0.9.2"

#define PVE_TEAM_HUMANS_NAME "blue"
#define PVE_TEAM_BOTS_NAME   "red"

#define UNCLE_DANE_STEAMID   "STEAM_0:0:48866904"

#define MAX_COSMETIC_ATTRS   8
#define GIBS_CLEANUP_PERIOD  10.0

#define GOLDEN_PAN_DEFID     1071
#define GOLDEN_PAN_CHANCE    1

#define TFTeam_Humans        TFTeam_Blue
#define TFTeam_Bots          TFTeam_Red

public Plugin myinfo =
{
    name        = "[TF2] Engineer PVE",
    author      = "Moonly Days, Uncle Dane",
    description = "Engineer PVE",
    version     = PLUGIN_VERSION,
    url         = "https://github.com/MoonlyDays/TF2_EngineerPVE"
};

/**
 * Definition of a TF2 attribute to apply to the bot.
 */
enum struct TFAttribute
{
    char  m_szName[PLATFORM_MAX_PATH];
    float m_flValue;
}

/**
 * Definition of a special game item to apply to the bot.
 */
enum struct BotItem
{
    int       m_iItemDefinitionIndex;
    char      m_szClassName[32];
    ArrayList m_Attributes;
}

//-----------------------------------------------------//
// List of Definitions
//-----------------------------------------------------//
ArrayList     g_hBotCosmetics;
ArrayList     g_hPlayerAttributes;
ArrayList     g_hBotNames;
ArrayList     g_hPrimaryWeapons;
ArrayList     g_hSecondaryWeapons;
ArrayList     g_hMeleeWeapons;

//-----------------------------------------------------//
// ConVar Definitions
//-----------------------------------------------------//
ConVar        tf_bot_quota;
ConVar        tf_gamemode_cp;
ConVar        sm_engipve_bot_sapper_insta_remove;
ConVar        sm_engipve_respawn_bots_on_round_end;
ConVar        sm_engipve_allow_respawnroom_build;
ConVar        sm_engipve_clear_gibs;
ConVar        sm_engipve_spy_capblock_time;

//-----------------------------------------------------//
// SDK Calls and Detours
//-----------------------------------------------------//
Handle        g_SdkEquipWearable;
DynamicHook   g_HookHandleSwitchTeams;
DynamicDetour g_DetourPointIsWithin;
DynamicDetour g_DetourEstimateValidBuildPos;
DynamicDetour g_DetourCreateObjectGibs;
DynamicDetour g_DetourDropAmmoPack;
DynamicDetour g_DetourCreateRagdollEntity;
DynamicDetour g_DetourComputeIncursionDistance;

//-----------------------------------------------------//
// Memory Patches
//-----------------------------------------------------//

int           g_nOffset_CBaseEntity_m_iTeamNum;

// Reference to the team_round_timer entity to modify its' time value.
int           g_eTeamRoundTimer;
// Are we currently in round end period?
bool          g_bIsRoundEnd           = false;
// Are we currently in active round period?
bool          g_bIsRoundActive        = false;
// When did the round start?
float         g_flRoundStartTime      = 0.0;
// Is spy capblocking feature enabled right now?
bool          g_bSpyCapBlocking       = false;
// Current round time if a multimap stage
float         g_flCurrentMapTime      = 0.0;
// Is this map a multistage map
bool          g_bIsMultiStageMap      = false;

// List of entities that need to be cleaned up on arrival to save
// on edict count.
char          g_szCleanupEntities[][] = {
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
    "env_sun",
    "halloween_souls_pack"
}

public OnPluginStart()
{
    GameData conf = new GameData("tf2.engipve");
    CreateTimer(0.5, Timer_UpdateRoundTime, _, TIMER_REPEAT);

    //-----------------------------------------------------//
    // CONVARS
    //-----------------------------------------------------//
    CreateConVar("engipve_version", PLUGIN_VERSION, "[TF2] Engineer PVE Version", FCVAR_DONTRECORD);
    sm_engipve_allow_respawnroom_build   = CreateConVar("sm_engipve_allow_respawnroom_build", "1", "Can humans build in respawn rooms?");
    sm_engipve_bot_sapper_insta_remove   = CreateConVar("sm_engipve_bot_sapper_insta_remove", "1", "Bots remove sappers with just one hit");
    sm_engipve_respawn_bots_on_round_end = CreateConVar("sm_engipve_respawn_bots_on_round_end", "0", "Should we instantly respawn bots on round end? (Engineer Massacre)");
    sm_engipve_clear_gibs                = CreateConVar("sm_engipve_clear_gibs", "1", "Should we clean up gibs to save up on edicts?");
    sm_engipve_spy_capblock_time         = CreateConVar("sm_engipve_spy_capblock_time", "20", "For how long should the spy block feature work?");
    tf_bot_quota                         = FindConVar("tf_bot_quota");
    tf_gamemode_cp                       = FindConVar("tf_gamemode_cp");

    //-----------------------------------------------------//
    // EVENTS
    //-----------------------------------------------------//
    HookEvent("post_inventory_application", post_inventory_application);
    HookEvent("teamplay_round_start", teamplay_round_start);
    HookEvent("teamplay_round_win", teamplay_round_win);
    HookEvent("teamplay_setup_finished", teamplay_setup_finished);
    HookEvent("teamplay_point_captured", teamplay_point_captured);
    HookEvent("player_death", player_death);

    //-----------------------------------------------------//
    // OFFSETS
    //-----------------------------------------------------//
    g_nOffset_CBaseEntity_m_iTeamNum = FindSendPropInfo("CBaseEntity", "m_iTeamNum");

    //-----------------------------------------------------//
    // SDK CALLS
    //-----------------------------------------------------//
    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(conf, SDKConf_Virtual, "CTFPlayer::EquipWearable");
    PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
    g_SdkEquipWearable      = EndPrepSDKCall();

    //-----------------------------------------------------//
    // DYNAMIC HOOKS
    //-----------------------------------------------------//
    g_HookHandleSwitchTeams = DynamicHook.FromConf(conf, "CTFGameRules::HandleSwitchTeams");

    //-----------------------------------------------------//
    // DETOURS
    //-----------------------------------------------------//
    g_DetourPointIsWithin   = DynamicDetour.FromConf(conf, "PointIsWithin");
    g_DetourPointIsWithin.Enable(Hook_Pre, Detour_OnPointIsWithin);

    g_DetourEstimateValidBuildPos = DynamicDetour.FromConf(conf, "EstimateValidBuildPos");
    g_DetourEstimateValidBuildPos.Enable(Hook_Pre, Detour_EstimateValidBuildPos);
    g_DetourEstimateValidBuildPos.Enable(Hook_Post, Detour_EstimateValidBuildPos_Post);

    g_DetourCreateObjectGibs = DynamicDetour.FromConf(conf, "CBaseObject::CreateObjectGibs");
    g_DetourCreateObjectGibs.Enable(Hook_Pre, Detour_CreateObjectGibs);

    g_DetourDropAmmoPack = DynamicDetour.FromConf(conf, "CTFPlayer::DropAmmoPack");
    g_DetourDropAmmoPack.Enable(Hook_Pre, Detour_DropAmmoPack);

    g_DetourCreateRagdollEntity = DynamicDetour.FromConf(conf, "CTFPlayer::DropAmmoPack");
    g_DetourCreateRagdollEntity.Enable(Hook_Pre, Detour_CreateRagdollEntity);

    g_DetourComputeIncursionDistance = DynamicDetour.FromConf(conf, "CTFNavMesh::ComputeIncursionDistances");
    g_DetourComputeIncursionDistance.Enable(Hook_Pre, CTFNavMesh_ComputeIncursionDistance);
    g_DetourComputeIncursionDistance.Enable(Hook_Post, CTFNavMesh_ComputeIncursionDistance_Post);

    //-----------------------------------------------------//
    // COMMANDS
    //-----------------------------------------------------//
    RegAdminCmd("sm_engipve_reload", cReload, ADMFLAG_CHANGEMAP, "Reloads Engineer PVE config.");
    RegAdminCmd("sm_becomeengibot", cBecomeEngiBot, ADMFLAG_ROOT, "Switches the client to the bot team.");

    AddCommandListener(cJoinTeam, "jointeam");
    AddCommandListener(cAutoTeam, "autoteam");

    AutoExecConfig(true, "tf_engipve");
}

public void OnConfigsExecuted()
{
    Config_Load();
}

public OnMapStart()
{
    g_HookHandleSwitchTeams.HookGamerules(Hook_Pre, CTFGameRules_HandleSwitchTeams);
    g_bIsRoundActive = false;
    g_bIsMultiStageMap = false;
    g_flCurrentMapTime = 0.0;
}

public OnClientPutInServer(int client)
{
    if (IsClientSourceTV(client) || IsClientReplay(client))
        return;

    CreateTimer(0.1, Timer_OnClientConnect, client);
}

public bool OnClientConnect(int client, char[] rejectMsg, int maxlen)
{
    int maxHumans = MaxClients - tf_bot_quota.IntValue;
    if (PVE_GetHumanCount() > maxHumans)
    {
        Format(rejectMsg, maxlen, "[1000 Engis] No more human slots are available, sorry :C");
        return false;
    }

    return true;
}

public OnEntityCreated(int entity, const char[] szClassname)
{
    for (int i = 0; i < sizeof(g_szCleanupEntities); i++)
    {
        if (StrEqual(szClassname, g_szCleanupEntities[i]))
        {
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
    if (kv.ImportFromFile(szCfgPath) == false)
    {
        SetFailState("Failed to read configs/tf_engipve.cfg");
        return;
    }

    // Try to load bot names.
    if (kv.JumpToKey("Names"))
    {
        Config_LoadNamesFromKV(kv);
        kv.GoBack();
    }

    // Try to load bot cosmetics.
    if (kv.JumpToKey("Cosmetics"))
    {
        Config_LoadCosmeticsFromKV(kv);
        kv.GoBack();
    }

    // Try to load bot cosmetics.
    if (kv.JumpToKey("Weapons"))
    {
        Config_LoadWeaponsFromKV(kv);
        kv.GoBack();
    }

    // Try to load bot cosmetics.
    if (kv.JumpToKey("Attributes"))
    {
        Config_LoadAttributesFromKV(kv);
        kv.GoBack();
    }

    char szClassName[32];
    kv.GetString("Class", szClassName, sizeof(szClassName));
    FindConVar("tf_bot_force_class").SetString(szClassName);
    FindConVar("tf_bot_auto_vacate").SetBool(false);
    FindConVar("tf_bot_quota").SetInt(kv.GetNum("Count"));
    FindConVar("tf_bot_difficulty").SetInt(kv.GetNum("Difficulty"));
    FindConVar("mp_disable_respawn_times").SetBool(true);
    FindConVar("mp_teams_unbalance_limit").SetInt(0);
    FindConVar("tf_bot_max_teleport_entrance_travel").SetInt(-1);
}

/** Reload the bot names that will be on the bot team. */
void Config_LoadNamesFromKV(KeyValues kv)
{
    delete g_hBotNames;
    g_hBotNames = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));

    if (kv.GotoFirstSubKey(false))
    {
        do
        {
            char szName[PLATFORM_MAX_PATH];
            kv.GetString(NULL_STRING, szName, sizeof(szName));
            g_hBotNames.PushString(szName);
        }
        while (kv.GotoNextKey(false));

        kv.GoBack();
    }
}

/** Reload the bot names that will be on the bot team. */
void Config_LoadAttributesFromKV(KeyValues kv)
{
    delete g_hPlayerAttributes;
    g_hPlayerAttributes = new ArrayList(sizeof(TFAttribute));

    if (kv.GotoFirstSubKey(false))
    {
        do
        {
            // Read name and float value, add the pair to the attributes array.
            TFAttribute attrib;
            kv.GetSectionName(attrib.m_szName, sizeof(attrib.m_szName));
            attrib.m_flValue = kv.GetFloat(NULL_STRING);
            g_hPlayerAttributes.PushArray(attrib);
        }
        while (kv.GotoNextKey(false));

        kv.GoBack();
    }
}

void Config_LoadItemFromKV(KeyValues kv, BotItem buffer)
{
    // First check inlined definition.
    int inlineDefId = kv.GetNum(NULL_STRING, 0);
    if (inlineDefId > 0)
    {
        buffer.m_iItemDefinitionIndex = inlineDefId;
        return;
    }

    // Definition is not inlined
    buffer.m_iItemDefinitionIndex = kv.GetNum("Index");

    // Check if cosmetic definition contains attributes.
    if (kv.JumpToKey("Attributes"))
    {
        // If so, create an array list.
        buffer.m_Attributes = new ArrayList(sizeof(TFAttribute));

        // Try going to the first attribute scope.
        if (kv.GotoFirstSubKey(false))
        {
            do
            {
                // Read name and float value, add the pair to the attributes array.
                TFAttribute attrib;
                kv.GetSectionName(attrib.m_szName, sizeof(attrib.m_szName));
                attrib.m_flValue = kv.GetFloat(NULL_STRING);
                buffer.m_Attributes.PushArray(attrib);
            }
            while (kv.GotoNextKey(false));
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

    if (kv.GotoFirstSubKey(false))
    {
        do
        {
            // Create bot cosmetic definition.
            BotItem item;
            Config_LoadItemFromKV(kv, item);
            g_hBotCosmetics.PushArray(item);
        }
        while (kv.GotoNextKey(false));

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

    if (kv.JumpToKey("Primary"))
    {
        Config_LoadWeaponsFromKVToArray(kv, g_hPrimaryWeapons);
        kv.GoBack();
    }

    if (kv.JumpToKey("Secondary"))
    {
        Config_LoadWeaponsFromKVToArray(kv, g_hSecondaryWeapons);
        kv.GoBack();
    }

    if (kv.JumpToKey("Melee"))
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

    if (kv.GotoFirstSubKey(false))
    {
        do
        {
            // Create bot cosmetic definition.
            BotItem item;
            Config_LoadItemFromKV(kv, item);
            array.PushArray(item);
        }
        while (kv.GotoNextKey(false));

        kv.GoBack();
    }
}

void Config_DisposeOfBotItemArrayList(ArrayList array)
{
    if (array)
    {
        for (int i = 0; i < array.Length; i++)
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
    for (int i = 1; i <= MaxClients; i++)
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
    int        maxNames    = g_hBotNames.Length;
    currentName++;
    currentName = currentName % maxNames;

    char szName[PLATFORM_MAX_PATH];
    g_hBotNames.GetString(currentName, szName, sizeof(szName));
    SetClientName(client, szName);
}

// Equip bots with appropriate weapons
void PVE_EquipBotItems(int client)
{
    for (int i = 0; i < g_hBotCosmetics.Length; i++)
    {
        BotItem cosmetic;
        g_hBotCosmetics.GetArray(i, cosmetic);

        int hat = PVE_GiveWearableToClient(client, cosmetic.m_iItemDefinitionIndex);
        if (hat <= 0)
        {
            continue;
        }

        PVE_ApplyBotItemAttributesOnEntity(hat, cosmetic);
    }

    PVE_GiveBotRandomSlotWeaponFromArrayList(client, TFWeaponSlot_Primary, g_hPrimaryWeapons);
    PVE_GiveBotRandomSlotWeaponFromArrayList(client, TFWeaponSlot_Secondary, g_hSecondaryWeapons);
    PVE_GiveBotRandomSlotWeaponFromArrayList(client, TFWeaponSlot_Melee, g_hMeleeWeapons);

    for (int i = TFWeaponSlot_Primary; i <= TFWeaponSlot_Melee; i++)
    {
        int weapon = GetPlayerWeaponSlot(client, i);
        if (!IsValidEntity(weapon))
            continue;

        int specKs = GetRandomInt(2002, 2008);
        int profKs = GetRandomInt(1, 7);

        TF2Attrib_SetByName(weapon, "killstreak tier", 3.0);
        TF2Attrib_SetByName(weapon, "killstreak effect", float(specKs));
        TF2Attrib_SetByName(weapon, "killstreak idleeffect", float(profKs));
    }
}

// Give a bot a random weapon in slot from an array defined in ArrayList
void PVE_GiveBotRandomSlotWeaponFromArrayList(int client, int slot, ArrayList array)
{
    if (array == INVALID_HANDLE)
    {
        return;
    }

    int     rndInt = GetRandomInt(0, array.Length - 1);
    BotItem item;
    array.GetArray(rndInt, item);

    int  wepDefId    = item.m_iItemDefinitionIndex;
    bool isGoldenPan = false;

    // Golden Pan Easter Egg!!!
    if (slot == TFWeaponSlot_Melee)
    {
        if (GetRandomInt(0, 100) < GOLDEN_PAN_CHANCE)
        {
            // Bot has 1% chance to have Golden Pan
            // as their melee.
            wepDefId    = GOLDEN_PAN_DEFID;
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

    if (isGoldenPan)
    {
        TF2Attrib_SetByName(iWeapon, "item style override", 0.0);
    }

    int prevWeapon = GetPlayerWeaponSlot(client, slot);
    if (prevWeapon != -1)
    {
        int accountId = GetEntProp(prevWeapon, Prop_Send, "m_iAccountID");
        SetEntProp(iWeapon, Prop_Send, "m_iAccountID", accountId);
    }

    TF2_RemoveWeaponSlot(client, slot);
    EquipPlayerWeapon(client, iWeapon);

    PVE_ApplyBotItemAttributesOnEntity(iWeapon, item);
}

// Apply attributes from config item defintion on entity.
void PVE_ApplyBotItemAttributesOnEntity(int entity, BotItem item)
{
    if (item.m_Attributes)
    {
        for (int j = 0; j < item.m_Attributes.Length; j++)
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
    for (int i = 0; i < g_hPlayerAttributes.Length; i++)
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
    if (!IsValidEntity(hat))
    {
        return -1;
    }

    SetEntProp(hat, Prop_Send, "m_iItemDefinitionIndex", itemDef);
    SetEntProp(hat, Prop_Send, "m_bInitialized", 1);
    SetEntProp(hat, Prop_Send, "m_iEntityLevel", 50);
    SetEntProp(hat, Prop_Send, "m_bValidatedAttachedEntity", 1);
    SetEntProp(hat, Prop_Send, "m_iAccountID", GetSteamAccountID(client));
    SetEntPropEnt(hat, Prop_Send, "m_hOwnerEntity", client);
    DispatchSpawn(hat);
    ActivateEntity(hat);

    SDKCall(g_SdkEquipWearable, client, hat);
    return hat;
}

void PVE_EndSpyBlocking()
{
    if (!g_bSpyCapBlocking)
    {
        return;
    }

    g_bSpyCapBlocking = false;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
        {
            continue;
        }

        PVE_EnableCapture(i);
    }
}

void PVE_StartSpyBlocking()
{
    if (g_bSpyCapBlocking)
    {
        return;
    }

    if (sm_engipve_spy_capblock_time.FloatValue <= 0)
    {
        return;
    }

    g_bSpyCapBlocking = true;
    CreateTimer(sm_engipve_spy_capblock_time.FloatValue, Timer_DisableSpyBlocking);

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
        {
            continue;
        }

        if (TF2_GetPlayerClass(i) != TFClass_Spy)
        {
            continue;
        }

        PrintHintText(i, "Capturing points is not allowed for Spies for the next %.2f seconds", sm_engipve_spy_capblock_time.FloatValue);
        PVE_DisableCapture(i);
    }
}

void PVE_DisableCapture(int client)
{
    TF2Attrib_SetByName(client, "increase player capture value", -1.0);
}

void PVE_EnableCapture(int client)
{
    TF2Attrib_RemoveByName(client, "increase player capture value");
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

    // Whitelist spectator commands.
    if (StrEqual(szTeamArg, "spec", false) || StrEqual(szTeamArg, "spectate", false) || StrEqual(szTeamArg, "spectator", false) || StrEqual(szTeamArg, "blue", false))
    {
        return Plugin_Continue;
    }

    ClientCommand(client, "jointeam blue");
    return Plugin_Handled;
}

Action cAutoTeam(int client, const char[] command, int argc)
{
    ClientCommand(client, "jointeam blue");
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

    if (IsFakeClient(client))
    {
        PVE_EquipBotItems(client);
        PVE_ApplyPlayerAttributes(client);
    }
    else {
        if (g_bSpyCapBlocking && TF2_GetPlayerClass(client) == TFClass_Spy)
        {
            PVE_DisableCapture(client);
        }
        else {
            PVE_EnableCapture(client);
        }
    }

    return Plugin_Continue;
}

public Action player_death(Event event, const char[] name, bool dontBroadcast)
{
    int  client = GetClientOfUserId(event.GetInt("userid"));
    bool isBot  = IsFakeClient(client);

    // If we're on round end
    if (g_bIsRoundEnd)
    {
        // And we don't want to respawn bots during round end.
        if (!sm_engipve_respawn_bots_on_round_end.BoolValue)
        {
            // Bail out.
            return Plugin_Handled;
        }
    }

    if (isBot)
    {
        CreateTimer(0.1, Timer_RespawnBot, client);
    }

    return Plugin_Continue;
}

public Action teamplay_setup_finished(Event event, const char[] name, bool dontBroadcast)
{
    g_bIsRoundActive   = true;
    g_flRoundStartTime = GetGameTime();

    if (g_bIsMultiStageMap)
    {
        g_flRoundStartTime = g_flCurrentMapTime;
    }
    g_eTeamRoundTimer  = FindEntityByClassname(-1, "team_round_timer");

    return Plugin_Continue;
}

public Action teamplay_point_captured(Event event, const char[] name, bool dontBroadcast)
{
    if (!tf_gamemode_cp.BoolValue)
    {
        return Plugin_Continue;
    }

    PVE_StartSpyBlocking();
    return Plugin_Continue;
}

public Action teamplay_round_win(Event event, const char[] name, bool dontBroadcast)
{
    int FullRound = event.GetInt("full_round");
    g_bIsRoundActive = false;
    g_bIsRoundEnd    = true;

    if (FullRound <= 0)
    {
        if (g_eTeamRoundTimer != -1)
        {
            g_bIsMultiStageMap = true;
            g_flCurrentMapTime = GetEntPropFloat(g_eTeamRoundTimer, Prop_Send, "m_flTimeRemaining");
        }
    }

    return Plugin_Continue;
}

public Action teamplay_round_start(Event event, const char[] name, bool dontBroadcast)
{
    g_bIsRoundEnd    = false;
    g_bIsRoundActive = false;

    return Plugin_Continue;
}

//-------------------------------------------------------//
// TIMERS
//-------------------------------------------------------//
public Action Timer_OnClientConnect(Handle timer, any client)
{
    if (IsFakeClient(client))
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

public Action Timer_DisableSpyBlocking(Handle timer, any client)
{
    PVE_EndSpyBlocking();
    return Plugin_Handled;
}

public Action Timer_UpdateRoundTime(Handle timer, any ent)
{
    // Round is not active - do nothing.
    if (!g_bIsRoundActive)
    {
        return Plugin_Handled;
    }

    if (g_eTeamRoundTimer <= 0)
    {
        return Plugin_Handled;
    }

    float curTime    = GetGameTime();
    float startTime  = g_flRoundStartTime;
    float elapsTime  = curTime - startTime;
    int   iElapsTime = RoundToFloor(elapsTime);

    SetVariantInt(iElapsTime);
    AcceptEntityInput(g_eTeamRoundTimer, "SetMaxTime");
    SetVariantInt(iElapsTime);
    AcceptEntityInput(g_eTeamRoundTimer, "SetTime");
    AcceptEntityInput(g_eTeamRoundTimer, "Pause");

    return Plugin_Handled;
}

//-------------------------------------------------------//
// SDK Hooks
//-------------------------------------------------------//
public Action OnSapperTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
    if (!sm_engipve_bot_sapper_insta_remove.BoolValue)
        return Plugin_Handled;

    if (IsClientInGame(attacker))
    {
        if (TF2_GetClientTeam(attacker) == TFTeam_Bots)
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

int        g_bAllowNextHumanTeamPointCheck = false;

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
    if (sm_engipve_clear_gibs.BoolValue)
    {
        TFTeam team = TF2_GetClientTeam(pThis);
        if (team == TFTeam_Bots)
        {
            return MRES_Supercede;
        }
    }

    return MRES_Ignored;
}

// CBaseObject::EstimateValidBuildPos
MRESReturn Detour_EstimateValidBuildPos(Address pThis, Handle hReturn, Handle hParams)
{
    if (!sm_engipve_allow_respawnroom_build.BoolValue)
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
    if (g_bAllowNextHumanTeamPointCheck)
    {
        Address addrTeam = pThis + view_as<Address>(g_nOffset_CBaseEntity_m_iTeamNum);
        TFTeam  iTeam    = view_as<TFTeam>(LoadFromAddress(addrTeam, NumberType_Int8));

        if (iTeam == TFTeam_Humans)
        {
            DHookSetReturn(hReturn, false);
            return MRES_Supercede;
        }
    }

    return MRES_Ignored;
}

// void CTFGameRules::HandleSwitchTeams( void );
public MRESReturn CTFGameRules_HandleSwitchTeams(int pThis, Handle hParams)
{
    PrintToChatAll("Team switching is disabled.");
    return MRES_Supercede;
}

// void CTFNavMesh::ComputeIncursionDistance( void );
public MRESReturn CTFNavMesh_ComputeIncursionDistance()
{
    PerformEnclosureFixes(true);
    return MRES_Ignored;
}

// void CTFNavMesh::ComputeIncursionDistance( void );
public MRESReturn CTFNavMesh_ComputeIncursionDistance_Post()
{
    PerformEnclosureFixes(false);
    return MRES_Ignored;
}

void PerformEnclosureFixes(bool apply)
{
    char szMap[32];
    GetCurrentMap(szMap, sizeof(szMap));
    const float upOffset = 48.0;

    if (!StrEqual(szMap, "pl_enclosure_final"))
    {
        return;
    }

    int point = -1;
    while ((point = FindEntityByClassname(point, "info_player_teamspawn")) != -1)
    {
        char szName[32];
        GetEntPropString(point, Prop_Data, "m_iszRoundBlueSpawn", szName, sizeof(szName));
        int teamNum  = GetEntProp(point, Prop_Send, "m_iTeamNum");
        int disabled = GetEntProp(point, Prop_Data, "m_bDisabled");

        if (!(!disabled && teamNum == 3 && StrEqual(szName, "mspl_round_2")))
        {
            continue;
        }

        float vecPos[3];
        GetEntPropVector(point, Prop_Data, "m_vecAbsOrigin", vecPos);
        vecPos[2] += apply ? upOffset : -upOffset;
        SetEntPropVector(point, Prop_Data, "m_vecAbsOrigin", vecPos);
    }
}
