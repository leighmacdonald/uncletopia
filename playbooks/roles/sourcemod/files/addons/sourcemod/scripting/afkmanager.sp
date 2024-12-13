#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define VERSION "2.9"

#define _DEBUG 0 // set to 1 to enable debug

// global variables
float g_Position[MAXPLAYERS+1][3];
int g_TimeAFK[MAXPLAYERS+1];
bool g_IsSynergy = false;
bool g_IsTF2Arena;
bool g_IsLateLoad = false;
int g_MaxPlayers = 0;

// cvars
Handle g_Cvar_Enabled = INVALID_HANDLE;
Handle g_Cvar_MinPlayersMove = INVALID_HANDLE;
Handle g_Cvar_MinPlayersKick = INVALID_HANDLE;
Handle g_Cvar_AdminsImmune = INVALID_HANDLE;
Handle g_Cvar_MoveSpec = INVALID_HANDLE;
Handle g_Cvar_TimeToMove = INVALID_HANDLE;
Handle g_Cvar_TimeToKick = INVALID_HANDLE;

public Plugin myinfo =
{
    name = "AFK Manager",
    author = "Liam, Leigh MacDonald",
    description = "Handles AFK Players",
    version = VERSION,
    url = "http://www.wcugaming.org"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_IsLateLoad = late;
    return APLRes_Success;
}

public void OnPluginStart( )
{
    char f_ModName[64];

    LoadTranslations("common.phrases");
    RegisterHooks();
    RegisterCvars();
    AutoExecConfig(true, "afk_manager");
    g_MaxPlayers = MaxClients;

    GetGameDescription(f_ModName, sizeof(f_ModName), true);

    if(!strcmp(f_ModName, "Synergy"))
	{
        g_IsSynergy = true;
	}
	
    if (g_IsLateLoad == true)
    {
        if (FindEntityByClassname(MaxClients + 1, "tf_arena_logic") == INVALID_ENT_REFERENCE)
        {
            g_IsTF2Arena = false;
        }
        else
        {
            g_IsTF2Arena = true;
        }
	}
}

void RegisterCvars( )
{
    CreateConVar("sm_afk_version", VERSION, "Current version of the AFK Manager", FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
    g_Cvar_Enabled = CreateConVar("sm_afkenable", "1", "Is the AFK manager enabled or disabled? [0 = FALSE, 1 = TRUE]");
    g_Cvar_MinPlayersMove = CreateConVar("sm_minplayersmove", "16", "Minimum amount of connected clients needed to move AFK clients to spec.");
    g_Cvar_MinPlayersKick = CreateConVar("sm_minplayerskick", "16", "Minimum amount of connected clients needed to kick AFK clients.");
    g_Cvar_AdminsImmune = CreateConVar("sm_adminsimmune", "1", "Admins immune to being kicked? [0 = FALSE, 1 = TRUE]");
    g_Cvar_MoveSpec = CreateConVar("sm_movespec", "0", "Move AFK clients to spec before kicking them? [0 = FALSE, 1 = TRUE]");
    g_Cvar_TimeToMove = CreateConVar("sm_timetomove", "60.0", "Time in seconds before moving an AFK player.");
    g_Cvar_TimeToKick = CreateConVar("sm_timetokick", "180.0", "Time in seconds before kicking an AFK player.");
}

public void OnMapStart( )
{
    for(int i = 1; i <= g_MaxPlayers; i++)
	{
        g_TimeAFK[i] = 0;
	}

    CreateTimer(60.0, Timer_StartTimers, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_StartTimers(Handle timer)
{
    CreateTimer(7.0, Timer_UpdateView, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(10.0, Timer_CheckPlayers, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

    return Plugin_Continue;
}

void RegisterHooks( )
{
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_team", Event_PlayerTeam);
    HookEventEx("arena_round_start", Event_ArenaRoundStart);
    HookEventEx("teamplay_round_start", Event_RoundStart);
    HookEventEx("round_start", Event_RoundStart);
}

public Action Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    g_TimeAFK[client] = 0;

    return Plugin_Continue;
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
    g_IsTF2Arena = false;

    return Plugin_Continue;
}

public Action Event_ArenaRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
    g_IsTF2Arena = true;

    return Plugin_Continue;
}

public Action Event_PlayerTeam(Handle event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    if(!g_IsSynergy)
    {        
        if(GetEventInt(event, "team") > 1)
        {
            g_TimeAFK[client] = 0;
        }
    }
    else
    {
        g_TimeAFK[client] = 0;
    }

    return Plugin_Continue;
}

public Action Timer_UpdateView(Handle timer)
{
    for(int i = 1; i <= g_MaxPlayers; i++)
    {
        if(IsRealPlayer(i) == false
			|| IsPlayerAlive(i) == false)
		{
            continue;
		}
        GetPlayerEye(i, g_Position[i]);
    }

    return Plugin_Continue;
}

public Action Timer_CheckPlayers(Handle timer)
{
    if(GetConVarInt(g_Cvar_Enabled) == 0)
        return Plugin_Stop;

    if(GetConVarInt(g_Cvar_MinPlayersMove) >= GetClientCount( ))
	{
        return Plugin_Continue;
	}

    for(int i = 1; i < g_MaxPlayers; i++)
    {
        if(IsRealPlayer(i) == false)
		{
            continue;
		}
        CheckForAFK(i);
        HandleAFKClient(i);
    }

    return Plugin_Continue;
}

void CheckForAFK(int client)
{
    float f_Loc[3];
    int f_Team = GetClientTeam(client);
    bool f_SamePlace[3];

    if (f_Team > 1 || g_IsSynergy) {
        GetPlayerEye(client, f_Loc);

        for(int i = 0; i < 3; i++)
        {
            if(g_Position[client][i] == f_Loc[i])
			{
                f_SamePlace[i] = true;
            }
			else
			{
                f_SamePlace[i] = false;
			}
        }
    }

    if((f_SamePlace[0] == true
		&& f_SamePlace[1] == true
        && f_SamePlace[2] == true)
        || (f_Team < 2 && g_IsSynergy == false))
    {
        g_TimeAFK[client]++;
    }
    else
    {
        g_TimeAFK[client] = 0;
    }
}

void HandleAFKClient(int client)
{
    int f_SpecTime = RoundToZero(GetConVarFloat(g_Cvar_TimeToMove)) / 10;
    int f_KickTime = RoundToZero(GetConVarFloat(g_Cvar_TimeToKick)) / 10;
    int f_MoveSpec = GetConVarInt(g_Cvar_MoveSpec);
    int f_MinKick = GetConVarInt(g_Cvar_MinPlayersKick);
    char f_Name[MAX_NAME_LENGTH];
    int f_Team = GetClientTeam(client);

    GetClientName(client, f_Name, sizeof(f_Name));

    if (g_IsSynergy == false
		&& f_MoveSpec == 1
		&& g_TimeAFK[client] < f_KickTime 
		&& g_TimeAFK[client] >= f_SpecTime)
    {
        if(f_Team == 2 || f_Team == 3)
        {
            PrintToChatAll("%s was moved to spectate for being AFK.", f_Name);
            LogAction(0, -1, "\"%L\" was moved to spectate for being AFK too long.", client);
            ChangeClientTeam(client, 1);
			
            if (g_IsTF2Arena == true)
            {
                SetEntProp(client, Prop_Send, "m_bArenaSpectator", true);
            }
        }
        return;
    }
	
    // added to do a last final check. Maybe they moved during the timer update and max count?
    CheckForAFK(client);

    if(g_TimeAFK[client] >= f_KickTime
        && !IsAdmin(client))
    {
#if _DEBUG
        LogAction(0, -1, "Kicking Client: %d, Team: %d - CVar_MinKick: %d - ClientCount: %d", client, f_Team, f_MinKick, GetClientCount(false));
#endif
        if(GetClientCount(false) >= f_MinKick) // this shouldn't matter but wtf ever
        {
            PrintToChatAll("%s was kicked for being AFK.", f_Name);
            LogAction(0, -1, "\"%L\" was kicked for being AFK too long.", client);
            KickClient(client, "You were AFK for too long.");
        }
    }
}

// This code was borrowed from Nican's spraytracer
bool GetPlayerEye(int client, float pos[3])
{
	float vAngles[3];
    float vOrigin[3];
	GetClientEyePosition(client,vOrigin);
	GetClientEyeAngles(client, vAngles);
	
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
	
	if(TR_DidHit(trace))
	{
	 	//This is the first function i ever saw that anything comes before the handle
		TR_GetEndPosition(pos, trace);
		CloseHandle(trace);
		return true;
	}
	CloseHandle(trace);
	return false;
}

bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
    return entity > MaxClients;
}

bool IsAdmin(int client) {
#if _DEBUG
    LogAction(0, -1, "Checking for admins.");
#endif

    if(GetConVarInt(g_Cvar_AdminsImmune) == 0)
    {
#if _DEBUG
        LogAction(0, -1, "Admins are not immune to being kicked.");
#endif
        return false;
    }

    AdminId admin = GetUserAdmin(client);
    
#if _DEBUG
    decl String:name[MAX_NAME_LENGTH];

    GetClientName(client, name, sizeof(name));
    LogAction(0, -1, "Checking for valid AdminID: Found: %d for client %s", _:admin, name);
#endif

    if(admin == INVALID_ADMIN_ID || !admin.HasFlag(Admin_Kick))
    {
#if _DEBUG
        LogAction(0, -1, "Client %s has an invalid Admin ID.", name);
#endif
        return false;
    }
#if _DEBUG
    LogAction(0, -1, "Client %s has a valid Admin ID and is immune.", name);
#endif
    return true;
}

bool IsRealPlayer(int client)
{
	if(!IsClientConnected(client)
		|| !IsClientInGame(client)
		|| IsFakeClient(client))
	{
		return false;
	}
	return true;
}
