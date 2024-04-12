#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include <sourcemod>

ConVar g_cvarEnabled;
ConVar g_cvarVoice;
ConVar g_cvarConnect;
ConVar g_cvarDisconnect;
ConVar g_cvarChangeClass;
ConVar g_cvarTeam;
ConVar g_cvarArenaResize;
ConVar g_cvarArenaMaxStreak;
ConVar g_cvarCvar;
ConVar g_cvarAllText;

EngineVersion g_engine = Engine_Unknown;

#define PLUGIN_VERSION "0.5"
public Plugin myinfo = 
{
	name = "Tidy Chat",
	author = "linux_lover",
	description = "Cleans up the chat area.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=101340",
};

public void OnPluginStart()
{
	CreateConVar("sm_tidychat_version", PLUGIN_VERSION, "Tidy Chat Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	g_cvarEnabled = CreateConVar("sm_tidychat_on", "1", "0/1 On/off");
	g_cvarVoice = CreateConVar("sm_tidychat_voice", "1", "0/1 Tidy (Voice) messages");
	g_cvarConnect = CreateConVar("sm_tidychat_connect", "0", "0/1 Tidy connect messages");
	g_cvarDisconnect = CreateConVar("sm_tidychat_disconnect", "0", "0/1 Tidy disconnect messsages");
	g_cvarChangeClass = CreateConVar("sm_tidychat_class", "1", "0/1 Tidy class change messages");
	g_cvarTeam = CreateConVar("sm_tidychat_team", "1", "0/1 Tidy team join messages");
	g_cvarArenaResize = CreateConVar("sm_tidychat_arena_resize", "1", "0/1 Tidy arena team resize messages");
	g_cvarArenaMaxStreak = CreateConVar("sm_tidychat_arena_maxstreak", "1", "0/1 Tidy (arena) team scramble messages");
	g_cvarCvar = CreateConVar("sm_tidychat_cvar", "1", "0/1 Tidy cvar messages");
	g_cvarAllText = CreateConVar("sm_tidychat_alltext", "0", "0/1 Tidy all chat messages from plugins");
	
	// Mod independant hooks
	HookEvent("player_connect_client", Event_PlayerConnect, EventHookMode_Pre);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
	HookEvent("server_cvar", Event_Cvar, EventHookMode_Pre);
	HookUserMessage(GetUserMessageId("TextMsg"), UserMsg_TextMsg, true);
	
	g_engine = GetEngineVersion();

	// TF2 dependant hooks
	if(g_engine == Engine_TF2)
	{
		HookUserMessage(GetUserMessageId("VoiceSubtitle"), UserMsg_VoiceSubtitle, true);
		HookEvent("arena_match_maxstreak", Event_MaxStreak, EventHookMode_Pre);
	}	
}

public Action Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast)
{
	if(g_cvarEnabled.BoolValue && g_cvarConnect.BoolValue)
	{
		event.BroadcastDisabled = true;
	}
	
	return Plugin_Continue;
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	if(g_cvarEnabled.BoolValue && g_cvarDisconnect.BoolValue)
	{
		event.BroadcastDisabled = true;
	}
	
	return Plugin_Continue;
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if(g_cvarEnabled.BoolValue && g_cvarTeam.BoolValue)
	{
		if(!event.GetBool("silent"))
		{
			event.BroadcastDisabled = true;
		}
	}
	
	return Plugin_Continue;
}

public Action Event_MaxStreak(Event event, const char[] name, bool dontBroadcast)
{
	if(g_cvarEnabled.BoolValue && g_cvarArenaMaxStreak.BoolValue)
	{
		event.BroadcastDisabled = true;
	}
	
	return Plugin_Continue;
}

public Action Event_Cvar(Event event, const char[] name, bool dontBroadcast)
{
	if(g_cvarEnabled.BoolValue && g_cvarCvar.BoolValue)
	{
		event.BroadcastDisabled = true;
	}
	
	return Plugin_Continue;
}

public Action UserMsg_VoiceSubtitle(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	if(g_cvarEnabled.BoolValue && g_cvarVoice.BoolValue)
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action UserMsg_TextMsg(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	if(g_cvarEnabled.BoolValue)
	{
		if(g_cvarAllText.BoolValue) return Plugin_Handled;

		if(g_engine == Engine_TF2)
		{
			char message[32];
			msg.ReadByte();
			msg.ReadString(message, sizeof(message));

			//PrintToServer("message = \"%s\"", message);

			if(g_cvarChangeClass.BoolValue && (strcmp(message, "#game_respawn_as") == 0 || strcmp(message, "#game_spawn_as") == 0))
			{
				return Plugin_Handled;
			}

			if(g_cvarArenaResize.BoolValue && strncmp(message, "#TF_Arena_TeamSize", 18) == 0) // #TF_Arena_TeamSizeIncreased/Decreased
			{
				return Plugin_Handled;
			}
		}
	}
	
	return Plugin_Continue;
}