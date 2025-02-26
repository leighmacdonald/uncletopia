#include <sourcemod>
#include <sdktools>
#include <dhooks>
#include <sourcescramble>
#pragma newdecls required
#pragma semicolon 1

#define MAX_EDICTS 2048

bool edictExists[MAX_EDICTS + 1];


int edicts = 0;
float nextActionIn = 0.0;
float nextForwardIn = 0.0;
float nextCleanupIn = 0.0;
bool isBlocking = false;
int isWindows = 0;

Handle g_hAttemptTimer = INVALID_HANDLE;
Handle g_hHudMessage;
int g_iAttempts = 0;

GlobalForward g_entityLockdownForward;
ConVar g_cvLowEdictAction;
ConVar g_cvLowEdictThreshold;
ConVar g_cvLowEdictBlockThreshold;
ConVar g_cvLowEdictCleanThreshold;
ConVar g_cvForwardCooldown;
ConVar g_cvMaxAttempts;
ConVar g_cvAttemptResetTime;
ConVar g_cvHardCleanupThreshold;
ConVar ed_aggressive_ent_culling;

public Plugin myinfo =
{
    name        = "Edict Limiter",
    author      = "Poggu & https://sappho.io",
    description = "Prevents edict limit crashes",
    version     = "3.1.1"
};

public void OnMapEnd()
{
    nextActionIn = 0.0;
    nextForwardIn = 0.0;
    nextCleanupIn = 0.0;
    g_iAttempts = 0;
    g_hAttemptTimer = INVALID_HANDLE;
}

/*
    int     num_edicts;     // 0x1E4
    int     max_edicts;     // 0x1E8 ??
    int     free_edicts;    // 0x1EC ??? how many edicts in num_edicts are free, in use is num_edicts - free_edicts
    edict_t   *edicts;      // Can array index now, edict_t is fixed
*/
Address sv;

int OFFS_num_edicts     = 0x1E4;
int OFFS_max_edicts     = 0x1E8;
int OFFS_free_edicts    = 0x1EC;

int GetSvOffs(int offs)
{
    return LoadFromAddress(sv + view_as<Address>(offs), NumberType_Int32);
}

public void OnPluginStart()
{
    // edicts = MaxClients + 1; // +1 for worldspawn
    edicts = ExpensivelyGetUsedEdicts();

    RegAdminCmd("sm_edictcount", Command_EdictCount, ADMFLAG_ROOT);
    RegAdminCmd("sm_spewedicts", Command_SpewEdicts, ADMFLAG_ROOT);
    RegAdminCmd("sm_murder", Command_Murder, ADMFLAG_ROOT);
    RegAdminCmd("sm_tptoclassname", Command_TPToClassname, ADMFLAG_ROOT);
    RegAdminCmd("sm_addtostripper", Command_AddToStripper, ADMFLAG_ROOT);

    g_entityLockdownForward     = new GlobalForward("OnEntityLockdown", ET_Ignore);
    g_cvLowEdictAction          = CreateConVar("ed_lowedict_action",            "1", "0 - no action, 1 - only prevent entity spawns, 2 - attempt to restart the game, if applicable, 3 - restart the map, 4 - go to the next map in the map cycle, 5 - spew all edicts.", _, true, 0.0, true, 5.0);
    g_cvLowEdictThreshold       = CreateConVar("ed_lowedict_threshold",         "8", "When only this many edicts are free, take the action specified by sv_lowedict_action.", _, true, 0.0, true, 1920.0);
    g_cvLowEdictBlockThreshold  = CreateConVar("ed_lowedict_block_threshold",   "8", "When only this many edicts are free, prevent entity spawns.", _, true, 0.0, true, 1920.0);
    g_cvLowEdictCleanThreshold  = CreateConVar("ed_lowedict_clean_threshold",   "16", "When only this many edicts are free, clear less important entities.", _, true, 0.0, true, 1920.0);
    g_cvHardCleanupThreshold    = CreateConVar("ed_hard_cleanup_threshold",     "100", "If less entities than this get cleaned nuke harder", _, true, 0.0, false);
    g_cvForwardCooldown         = CreateConVar("ed_announce_cooldown",          "1", "OnEntityLockdown cooldown", _, true, 0.0, false);
    g_cvMaxAttempts             = CreateConVar("ed_max_attempts",               "3", "How many attempts before giving up and calling action", _, true, 0.0, false);
    g_cvAttemptResetTime        = CreateConVar("ed_attempt_reset_time",         "90", "After how many seconds should attempts be reset", _, true, 0.0, false);

    ed_aggressive_ent_culling   = CreateConVar("ed_aggressive_ent_culling",     "1", "1 - Enable aggressive culling of entities, 2 - enable HYPER AGGRESSIVE, and likely unstable methods of entity culling.", _, true, 0.0, false);

    DoGameData();

    g_hHudMessage = CreateHudSynchronizer();
}


void DoGameData()
{
    GameData hGameConf;
    char error[128];

    hGameConf = LoadGameConfigFile("edict_limiter");
    if(!hGameConf)
    {
        Format(error, sizeof error, "Failed to find edict_limiter gamedata");
        SetFailState(error);
    }


    // Patch TF2 not reusing edict slots and crashing with a ton of free slots
    {
        MemoryPatch ED_Alloc_IgnoreFree = MemoryPatch.CreateFromConf(hGameConf, "ED_Alloc::nop");
        if (!ED_Alloc_IgnoreFree.Validate())
        {
            SetFailState("Failed to verify ED_Alloc::nop.");
        }
        else if (ED_Alloc_IgnoreFree.Enable())
        {
            LogMessage("-> Enabled ED_Alloc::nop.");
        }
        else
        {
            SetFailState("Failed to enable ED_Alloc::nop.");
        }
    }


    {
        isWindows = hGameConf.GetOffset("WindowsOrLinux");
        if(isWindows)
        {
            LogMessage("-> Running on Windows");
            OFFS_num_edicts     = 0x1EC;
            OFFS_max_edicts     = 0x1F0;
            OFFS_free_edicts    = 0x1F4;
        }
    }


    // @sv - for sv.num_entities and other offsets
    {
        if(isWindows)
            sv = hGameConf.GetAddress("sv");
        else
            sv = hGameConf.GetMemSig("sv");
        if (!sv)
        {
            SetFailState("Couldn't find sv.");
        }
        LogMessage("-> Got sv pointer           = 0x%X", sv);
    }

    // Set up IServerPluginCallbacks detours
    {
        Handle DHook_OnEdictAllocated = DHookCreateFromConf(hGameConf, "IServerPluginCallbacks::OnEdictAllocated");
        if( !DHook_OnEdictAllocated )
        {
            SetFailState("Failed to find IServerPluginCallbacks::OnEdictAllocated");
        }
        Handle DHook_OnEdictFreed = DHookCreateFromConf(hGameConf, "IServerPluginCallbacks::OnEdictFreed");
        if( !DHook_OnEdictFreed )
        {
            SetFailState("Failed to find IServerPluginCallbacks::OnEdictFreed");
        }

        // Create Interface
        Address CreateIfacePtr;
        {
            // SDK call the thing
            StartPrepSDKCall(SDKCall_Static);
            if(!PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CreateInterface"))
            {
                SetFailState("Failed to get CreateInterface signature");
            }
            PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
            PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
            PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
            Handle createInterfaceCall = EndPrepSDKCall();

            // Get the ptr of the thing
            CreateIfacePtr = SDKCall(createInterfaceCall, "ISERVERPLUGINHELPERS001", 0);
            if (!CreateIfacePtr)
            {
                SetFailState("Failed to get ISERVERPLUGINHELPERS001 ptr");
            }
            LogMessage("-> Got CreateInterface ptr  = 0x%X", CreateIfacePtr);
        }

        int hookid = INVALID_HOOK_ID;
        hookid = DHookRaw(DHook_OnEdictAllocated, true  /* post */, CreateIfacePtr, _, IServerPluginCallbacks__OnEdictAllocated_Post);
        if (hookid == INVALID_HOOK_ID)
        {
            SetFailState("Invalid hookid for DHook_OnEdictAllocated");
        }
        LogMessage("-> Set up [POST] IServerPluginCallbacks::OnEdictAllocated detour");


        hookid = DHookRaw(DHook_OnEdictFreed, false /* pre  */, CreateIfacePtr, _, IServerPluginCallbacks__OnEdictFreed_Pre);
        if (hookid == INVALID_HOOK_ID)
        {
            SetFailState("Invalid hookid for DHook_OnEdictFreed");
        }
        LogMessage("-> Set up [PRE]  IServerPluginCallbacks::OnEdictFreed detour");
    }

    // Hook engine entities
    {
        Handle hCreateEntityByName = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Int, ThisPointer_Ignore);
        if (!hCreateEntityByName)
        {
            SetFailState("Failed to setup detour for CEntityFactoryDictionary::Create");
        }
        if (!DHookSetFromConf(hCreateEntityByName, hGameConf, SDKConf_Signature, "CEntityFactoryDictionary::Create"))
        {
            SetFailState("Failed to load CEntityFactoryDictionary::Create signature from gamedata");
        }
        DHookAddParam(hCreateEntityByName, HookParamType_CharPtr);
        if (!DHookEnableDetour(hCreateEntityByName, false /* pre */, CEntityFactoryDictionary__Create_Pre))
        {
            SetFailState("Failed to detour CEntityFactoryDictionary::Create.");
        }
        LogMessage("-> Set up [PRE]  CEntityFactoryDictionary::Create detour");
    }

    // ED_Alloc - unused for now, maybe eventually an escape hatch
    {
        Handle ED_Alloc = DHookCreateFromConf(hGameConf, "ED_Alloc");
        if (!ED_Alloc)
        {
            SetFailState("Couldn't create DHOOK for ED_Alloc");
        }
        if (!DHookEnableDetour(ED_Alloc, false /* pre */, Detour_ED_Alloc_Pre))
        {
            SetFailState("Couldn't set up detour for ED_Alloc");
        }
        LogMessage("-> Set up [PRE]  ED_Alloc detour");
    }

    Handle CreateFeignDeathRagdoll = DHookCreateFromConf(hGameConf, "CTFPlayer::CreateFeignDeathRagdoll");
    if (!CreateFeignDeathRagdoll)
    {
        SetFailState("Couldn't create DHOOK for CreateFeignDeathRagdoll");
    }
    if (!DHookEnableDetour(CreateFeignDeathRagdoll, false /* pre */, CTFPlayer__CreateFeignDeathRagdoll))
    {
        SetFailState("Couldn't set up detour for CreateFeignDeathRagdoll");
    }
    LogMessage("-> Set up [PRE]  CreateFeignDeathRagdoll detour");

    if (ed_aggressive_ent_culling.IntValue == 2)
    {
        // Destroy ents that get created when a player speaks while firing a weapon
        Handle SpeakWepFire = DHookCreateFromConf(hGameConf, "CTFPlayer::SpeakWeaponFire");
        if (!SpeakWepFire)
        {
            SetFailState("Couldn't create DHOOK for SpeakWepFire");
        }
        if (!DHookEnableDetour(SpeakWepFire, false /* pre */, CTFPlayer__SpeakWeaponFire))
        {
            SetFailState("Couldn't set up detour for SpeakWepFire");
        }
        LogMessage("-> Set up [PRE]  SpeakWepFire detour");

        Handle UpdateExpression = DHookCreateFromConf(hGameConf, "CTFPlayer::UpdateExpression");
        if (!UpdateExpression)
        {
            SetFailState("Couldn't create DHOOK for UpdateExpression");
        }
        if (!DHookEnableDetour(UpdateExpression, false /* pre */, CTFPlayer__UpdateExpression_Pre))
        {
            SetFailState("Couldn't set up detour for UpdateExpression");
        }
        LogMessage("-> Set up [PRE]  UpdateExpression detour");
    }

    delete hGameConf;
}

public MRESReturn CTFPlayer__CreateFeignDeathRagdoll(Handle hParams)
{
    return MRES_Supercede;
}

public MRESReturn CTFPlayer__SpeakWeaponFire(Handle hParams)
{
    return MRES_Supercede;
}

public MRESReturn CTFPlayer__UpdateExpression_Pre()
{
    return MRES_Supercede;
}

public MRESReturn Detour_ED_Alloc_Pre(Handle hParams)
{
    // this should NEVER EVER HAPPEN but just in case
    int num_eds = GetSvOffs(OFFS_num_edicts);
    // bomb is about to explode
    if ( num_eds >= (MAX_EDICTS - 1) )
    {
        LogMessage("\n\n\n\n\n\
            -> ALERT <- WE ARE ABOUT TO CRASH\n\
            -> ALERT <- WE ARE ABOUT TO CRASH\n\
            -> ALERT <- WE ARE ABOUT TO CRASH");

        PrintToChatAll(" \
            -> ALERT <- SERVER IS ABOUT TO CRASH\n\
            -> ALERT <- SERVER IS ABOUT TO CRASH\n\
            -> ALERT <- SERVER IS ABOUT TO CRASH");
        //PrintToChatAll("FORCIBLY RECONNECTING EVERYONE");
        //for (int cl = 1; cl <= MaxClients; cl++)
        //{
        //    if (IsClientConnected(cl) && !IsFakeClient(cl))
        //    {
        //        ClientCommand(cl, "retry");
        //    }
        //}
        LogMessage("LAST DITCH EFFORT TO SPEW ENTS AND CHANGE TO THE NEXT MAP\n\n\n\n\n");

        SpewEdicts();
        DoLowEntAction(4);
        // Assume we crash immediately after
        return MRES_Handled;
    }

    return MRES_Ignored;
}

public MRESReturn IServerPluginCallbacks__OnEdictAllocated_Post(Handle hParams)
{
    int edict = DHookGetParam(hParams, 1);
    if (edict > MaxClients && !edictExists[edict]) // Engine reserves MaxClients edicts for players including wordspawn. We don't want to count those as they are always non-free.
    {
        edicts++;
        edictExists[edict] = true;
    }
    return MRES_Ignored;
}

public MRESReturn IServerPluginCallbacks__OnEdictFreed_Pre(Handle hParams)
{
    int edict = DHookGetParam(hParams, 1);
    if(edict > MaxClients && edictExists[edict])
    {
        edicts--;
        edictExists[edict] = false;
    }

    if(isBlocking && MAX_EDICTS - edicts > g_cvLowEdictBlockThreshold.IntValue)
    {
        isBlocking = false;
        PrintToChatAll("[Edict Limiter] Entity creation is no longer blocked.");
        PrintToServer("[Edict Limiter] Entity creation is no longer blocked.");
    }
    return MRES_Ignored;
}

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int err_max)
{
    RegPluginLibrary("EdictLimiter");
    CreateNative("GetEdictCount", Native_GetEdictCount);
    return APLRes_Success;
}


// This is a list of entities that are allowed to be created even if the edict limit is reached, could result in a crash otherwise.
char ignoreEnts[][] =
{
    "spotlight_end",
    "tf_bot",
    "player",
    "ai_network",
    "tf_player_manager",
    "worldspawn",
    "info_target",
    "tf_team",
    "tf_gamerules",
    "tf_objective_resource",
    "monster_resource",
    "scene_manager",
    "team_round_timer",
    "team_control_point_master",
    "team_control_point",
    "tf_logic_koth",
    "logic_auto",
    "logic_relay",
    "item_teamflag",
    "trigger_capture_area",
    "tf_logic_arena",
    "passtime_ball",
    "instanced_scripted_scene",
    "tf_viewmodel",
    "beam",
    "env_spritetrail",
    "env_sprite",
    "vgui_screen",
};

void DoLowEntAction(int doAction = -1)
{
    if (doAction == -1)
    {
        doAction = g_cvLowEdictAction.IntValue;
    }
    switch(doAction)
    {
        case 2: // restart game
        {
            PrintToServer("Trying to restart game as requested by ed_lowedict_action");
            ServerCommand("mp_restartgame 1");
            nextActionIn = GetGameTime() + 1.0;
        }

        case 3: // restart map
        {
            PrintToServer("Trying to restart map as requested by ed_lowedict_action");
            char map[PLATFORM_MAX_PATH];
            GetCurrentMap(map, sizeof map);
            ForceChangeLevel(map, "Action of ed_lowedict_action");
            nextActionIn = GetGameTime() + 2.0;
        }

        case 4: // go to the next map
        {
            PrintToServer("Trying to cycle to the next map as requested by ed_lowedict_action");
            char map[PLATFORM_MAX_PATH];
            if(GetNextMap(map, sizeof map))
            {
                ForceChangeLevel(map, "Action of ed_lowedict_action");
            }
            else
            {
                PrintToServer("[Edict Limiter] No available next map, forcibly restarting map instead");
                DoLowEntAction(3);
            }

            nextActionIn = GetGameTime() + 1.0;
        }
        case 5: // spew all edicts
        {
            PrintToServer("Spewing edict counts as requested by ed_lowedict_action");
            SpewEdicts();
            nextActionIn = GetGameTime() + 5.0;
        }
    }
}


public MRESReturn CEntityFactoryDictionary__Create_Pre(Handle hReturn, Handle hParams)
{
    char classname[32];
    DHookGetParamString(hParams, 1, classname, sizeof classname);


    // will make this an array eventually
    if
    (
        ed_aggressive_ent_culling.IntValue >= 1
        &&
        (
                StrEqual(classname, "tf_dropped_weapon")
             || StrEqual(classname, "tf_ragdoll")
             || StrEqual(classname, "halloween_souls_pack")
             || StrEqual(classname, "tf_mann_vs_machine_stats")
        )
    )
    {
        DHookSetReturn(hReturn, 0);
        return MRES_Supercede;
    }

    int freeEdicts = MAX_EDICTS - edicts;

    if (g_cvLowEdictCleanThreshold.IntValue > 0 && freeEdicts <= g_cvLowEdictCleanThreshold.IntValue && (nextCleanupIn <= GetGameTime() || nextCleanupIn == 0.0))
    {
      DoEntCleanup();
    }

    if (g_cvLowEdictAction.IntValue > 0 && freeEdicts <= g_cvLowEdictThreshold.IntValue)
    {
        PrintToServer("[Edict Limiter] Warning: free edicts below threshold. %i free edict%s remaining", freeEdicts, freeEdicts == 1 ? "" : "s");

        if(nextActionIn <= GetGameTime() || nextActionIn == 0.0)
        {
            DoLowEntAction();
        }
    }

    for(int i = 0; i < sizeof ignoreEnts; i++)
    {
        if(StrEqual(classname, ignoreEnts[i]))
        {
            return MRES_Ignored;
        }
    }

    if (g_cvLowEdictBlockThreshold.IntValue > 0 && freeEdicts <= g_cvLowEdictBlockThreshold.IntValue)
    {
        if((nextForwardIn <= GetGameTime() || nextForwardIn == 0.0) && !isBlocking)
        {
            AnnounceEntityLockDown();
            nextForwardIn = GetGameTime() + g_cvForwardCooldown.FloatValue;
        }

        isBlocking = true;
        PrintToServer("[Edict Limiter] Blocking entity creation of %s", classname);
        DHookSetReturn(hReturn, 0);

        return MRES_Supercede;
    }


    return MRES_Ignored;
}

Action ClearLockDownAttempts(Handle timer)
{
    g_hAttemptTimer = INVALID_HANDLE;
    g_iAttempts = 0;

    return Plugin_Handled;
}

char uselessEntsSoft[][] =
{
    "tf_ammo_pack"
};

char uselessEntsHard[][] =
{
    "func_dustmotes",
    "func_smokevolume"
};

char uselessEntsHarder[][] =
{
    "ambient_generic",
    "info_particle_system",
    "trigger_soundscape"
};

int NukeEntityClassname(const char[][] array, int size)
{
    int ents_nuked;
    for(int i = 0; i < size; i++)
    {
        int ent = 0;
        while((ent = FindEntityByClassname(ent, array[i])) != -1)
        {
            RemoveEntity(ent);
            ents_nuked++;
        }
    }

    return ents_nuked;
}

void DoEntCleanup()
{
    if(g_hAttemptTimer != INVALID_HANDLE)
      delete g_hAttemptTimer;

    // too many attempts, give up
    if(++g_iAttempts >= g_cvMaxAttempts.IntValue)
    {
        g_iAttempts = 0;
        if(nextActionIn <= GetGameTime() || nextActionIn == 0.0)
        {
            GlobalPrint("[Edict Limiter] Too many attempts, taking action.");
            DoLowEntAction();
        }
        nextCleanupIn = GetGameTime() + 5.0;
        return;
    }

    g_hAttemptTimer = CreateTimer(g_cvAttemptResetTime.FloatValue, ClearLockDownAttempts, _, TIMER_FLAG_NO_MAPCHANGE);

    PrintToServer("[Edict Limiter] Attempting to clear less important entities.");

    int ents_nuked;
    ents_nuked += NukeEntityClassname(uselessEntsSoft, sizeof uselessEntsSoft);

    if(ents_nuked < g_cvHardCleanupThreshold.IntValue)
        ents_nuked += NukeEntityClassname(uselessEntsHard, sizeof uselessEntsHard);

    if(g_iAttempts >= 2)
    {
        ents_nuked += NukeEntityClassname(uselessEntsHarder, sizeof uselessEntsHarder);
        nextCleanupIn = GetGameTime() + 1.0;
    }

    GlobalPrint("[Edict Limiter] Nuked %i entities.", ents_nuked);
}


void AnnounceEntityLockDown()
{
    PrintToServer("[Edict Limiter] Entity creation is blocked until edicts are freed.");
    PrintToChatAll("[Edict Limiter] Entity creation is blocked until edicts are freed.\nThe server will probably change level soon.");

    Call_StartForward(g_entityLockdownForward);
    Call_Finish();
}

int ExpensivelyGetUsedEdicts()
{
    int edict_ents = MaxClients + 1; // +1 for worldspawn
    for(int i = MaxClients + 1; i < MAX_EDICTS; i++)
    {
        if(IsValidEdict(i))
        {
            edict_ents++;
            edictExists[i] = true;
        }
    }

    return edict_ents;
}

public Action Command_EdictCount(int client, int args)
{
    ReplyToCommand(client, "GetEntityCount: %i | Used edicts: %i | Used edicts (Precise, expensive): %i", GetEntityCount(), edicts, ExpensivelyGetUsedEdicts());
    return Plugin_Handled;
}

char g_szTargetClassname[128];

public bool RayRemoveTarget(int entity, int client)
{
    if(entity != client)
    {
        if(!IsValidEdict(entity) || entity == 0 || (entity > 0 && entity <= MaxClients))
            return true;

        TR_ClipCurrentRayToEntity(MASK_ALL, entity);

        if(TR_DidHit())
		{
            char classname[128];
            GetEdictClassname(entity, classname, sizeof classname);

            if(StrEqual(classname, g_szTargetClassname))
            {
                PrintToChat(client ,"Removed and added to list");

                char map[PLATFORM_MAX_PATH];
                GetCurrentMap(map, sizeof(map));

                File file;
                char dataDir[PLATFORM_MAX_PATH];
                FormatEx(dataDir, sizeof(dataDir), "../tf/addons/stripper/maps/%s.cfg", map);
                if(!FileExists(dataDir)) file = OpenFile(dataDir, "a+");
                else if(FileExists(dataDir)) file = OpenFile(dataDir, "a");
                file.WriteLine("filter:");
                file.WriteLine("{");
                file.WriteLine("	\"hammerid\" \"%i\"", GetEntProp(entity, Prop_Data, "m_iHammerID"));
                file.WriteLine("	\"classname\" \"%s\"", classname);
                file.WriteLine("}");
                delete file;

                RemoveEntity(entity);
                return false;
            }
        }

        return true;
    }
    return true;
}

public Action Command_AddToStripper(int client, int args)
{
    if(!client)
    {
        PrintToServer("This command can only be used in-game");
        return Plugin_Handled;
    }

    if(args != 1)
    {
        ReplyToCommand(client, "Usage: sm_addtostripper <classname>");
        return Plugin_Handled;
    }

    GetCmdArg(1, g_szTargetClassname, sizeof g_szTargetClassname);

    float ang[3], pos[3];
    GetClientEyeAngles(client, ang);
    GetClientEyePosition(client, pos);

    TR_EnumerateEntities(pos, ang, PARTITION_NON_STATIC_EDICTS | PARTITION_SOLID_EDICTS | PARTITION_STATIC_PROPS | PARTITION_TRIGGER_EDICTS, RayType_Infinite, RayRemoveTarget, client);
    return Plugin_Handled;
}

public Action Command_TPToClassname(int client, int args)
{
    if(args != 2)
    {
        ReplyToCommand(client, "Usage: sm_tptoclassname <classname> <index>");
        return Plugin_Handled;
    }

    char classname[128];
    GetCmdArg(1, classname, sizeof classname);

    int ent = 0;
    int index;
    while((ent = FindEntityByClassname(ent, classname)) != -1)
    {
        if(index == GetCmdArgInt(2))
        {
            float origin[3];
            GetEntPropVector(ent, Prop_Send, "m_vecOrigin", origin);
            TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);
            break;
        }
        index++;
    }

    return Plugin_Handled;
}
public Action Command_Murder(int client, int args)
{
    if(args != 1)
    {
        ReplyToCommand(client, "Usage: sm_murder <classname>");
        return Plugin_Handled;
    }

    char classname[128];
    GetCmdArg(1, classname, sizeof classname);

    int ent = 0;
    int ents_nuked;
    while((ent = FindEntityByClassname(ent, classname)) != -1)
    {
        RemoveEntity(ent);
        ents_nuked++;
    }

    ReplyToCommand(client, "Killed %i entities", ents_nuked);
    return Plugin_Handled;
}

public Action Command_SpewEdicts(int client, int args)
{
    if(client)
    {
        PrintToChat(client, "Open console for edict spew");
    }

    SpewEdicts(client);
    return Plugin_Handled;
}

int Native_GetEdictCount(Handle plugin, int numParams)
{
    return edicts;
}

void SpewEdicts(int client = 0)
{
    StringMap classnames = new StringMap();
    ArrayList clsCount = new ArrayList(2);

    for(int i = 0; i < MAX_EDICTS; i++)
    {
        if(IsValidEdict(i))
        {
            char classname[64];
            GetEdictClassname(i, classname, sizeof classname);

            char netname[64] = "No Netclass!";
            if (IsValidEntity(i))
            {
                GetEntityNetClass(i, netname, sizeof netname);
            }

            char final[129];
            Format(final, sizeof(final), "%s - %s", classname, netname);

            int index;
            bool isFound = classnames.GetValue(final, index);
            if(!isFound)
            {
                int newIndex = clsCount.Push(1);
                classnames.SetValue(final, newIndex);
                clsCount.Set(newIndex, newIndex, 1);
            }
            else
            {
                int count = clsCount.Get(index);
                clsCount.Set(index, count + 1);
            }
        }
    }

    clsCount.Sort(Sort_Descending, Sort_Integer);
    StringMapSnapshot clsSnapshot = classnames.Snapshot();

    if(client == 0)
    {
        PrintToServer("(Percent)  \tCount\tClassname (Sorted by count)");
        PrintToServer("-------------------------------------------------");
    }
    else
    {
        PrintToConsole(client, "(Percent)  \tCount\tClassname (Sorted by count)");
        PrintToConsole(client, "-------------------------------------------------");
    }
    for(int i = 0; i < clsCount.Length; i++)
    {
        int count = clsCount.Get(i);

        for(int x = 0; x < clsSnapshot.Length; x++)
        {
            char classname[64];
            clsSnapshot.GetKey(x, classname, sizeof classname);

            int index;
            if(classnames.GetValue(classname, index))
            {
                if(index == clsCount.Get(i, 1))
                {
                    if(client == 0)
                        PrintToServer("(%3.2f%%)  \t%i\t%s", float(count) / float(edicts) * 100.0, count, classname);
                    else
                        PrintToConsole(client, "(%3.2f%%)  \t%i\t%s", float(count) / float(edicts) * 100.0, count, classname);
                    break;
                }
            }
        }
    }

    delete clsSnapshot;
    delete clsCount;
    delete classnames;

    if(client == 0)
    {
        PrintToServer("Total edicts: %i", edicts);
        PrintToServer("sv.num_edicts %i", GetSvOffs(OFFS_num_edicts));
        PrintToServer("sv.max_edicts %i", GetSvOffs(OFFS_max_edicts));
        PrintToServer("sv.free_edicts %i", GetSvOffs(OFFS_free_edicts));
    }
    else
    {
        PrintToConsole(client, "Total edicts: %i", edicts);
        PrintToConsole(client, "sv.num_edicts %i", GetSvOffs(OFFS_num_edicts));
        PrintToConsole(client, "sv.max_edicts %i", GetSvOffs(OFFS_max_edicts));
        PrintToConsole(client, "sv.free_edicts %i", GetSvOffs(OFFS_free_edicts));
    }
}

void GlobalPrint(const char[] format, any ...)
{
    char message[256];
    VFormat(message, sizeof(message), format, 2);

    SetHudTextParams(-1.0, 0.75, 5.0, 255, 255, 255, 255, _, _, _, _);
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i))
        {
            ShowSyncHudText(i, g_hHudMessage, "%s", message);
        }
    }

    PrintToChatAll("%s", message);
    PrintToServer("%s", message);
}
