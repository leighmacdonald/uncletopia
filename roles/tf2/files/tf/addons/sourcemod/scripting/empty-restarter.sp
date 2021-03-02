#include <sourcemod>

#define MAX_MAPNANE_LENGTH 128
#define MAX_INT_STRING 6
#define PLUGIN_VERSION "1.2"

public Plugin:myinfo =
{
	name = "Empty Server Map Restarter",
	author = "Daniel Hambraeus",
	description = "Restarts map if server is empty",
	version = PLUGIN_VERSION,
	url = "none"
};

new Handle:g_Cvar_Enable = INVALID_HANDLE; //Enable/Disable the plugin
new Handle:g_Cvar_Timer = INVALID_HANDLE; //For how long server is to be empty before it restarts map/round/server/goes to default map
new Handle:g_PlayerIDs; // Map with key/value pairs of all currently connected userids
new Handle:g_Cvar_RestartType; //What happens when server get empty

new g_Players = 0;		// Total players connected. Doesn't include fake clients.

new String:g_DefaultMap[MAX_MAPNANE_LENGTH]; //default map the servers starts on

public OnPluginStart()
{
	SetConVarString(CreateConVar("empty_restarter_version", PLUGIN_VERSION, "version of Empty Server Map Restarter for TF2", FCVAR_SPONLY | FCVAR_NOTIFY | FCVAR_PLUGIN), PLUGIN_VERSION);
	g_Cvar_Enable = CreateConVar("sm_restart_empty_map", "1.0", "1 to enable plugin. Restarts map if server is empty", FCVAR_PLUGIN);
	g_Cvar_Timer = CreateConVar("sm_empty_restarter_timer", "0.0", "Seconds from server being empty to restarting", FCVAR_PLUGIN);
	g_Cvar_RestartType = CreateConVar("sm_empty_restarter_type", "1.0", "0 for restart server, 1 for restart map, 2 for restart round, 3 for default map", FCVAR_PLUGIN);
	//hooks the event player_disconnect which only happens when a player really disconnect, not when map changes
	HookEvent("player_disconnect", EventPlayerDisconnect, EventHookMode_Pre);
	g_PlayerIDs = CreateTrie();
	GetCurrentMap(g_DefaultMap, sizeof(g_DefaultMap));
}

public OnMapStart()
{
	/* Handle late load */
	for (new i=1; i<=MaxClients; i++)
	{
		if (IsClientConnected(i))
		{
			OnClientConnected(i);	
		}
	}
	
}

public OnMapEnd()
{
	
}

//Runs both when a player really connects and when a player reconnects after a mapchange
public OnClientConnected(client)
{
	decl String:index[MAX_INT_STRING];
	
	//filters out fake clients
	if(!client || IsFakeClient(client))
		return;
	
	IntToString(GetClientUserId(client),index,MAX_INT_STRING);
	
	//Uses a trie to store key value pairs of the user IDs, if it already exist, then it will return false
	if( SetTrieValue(g_PlayerIDs, index, 1,false) )
	{
		g_Players++;
	}
	return;
}

public Action:EventPlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl String:index[MAX_INT_STRING];
	new userid = GetEventInt(event, "userid");
	//filters out fake clients
	if(!userid)
		return;
		
	IntToString(userid,index,MAX_INT_STRING);
	
	if (RemoveFromTrie(g_PlayerIDs, index))
	{
		g_Players--;
	}
	//If last player disconnect the map restarts
	if((g_Players == 0) && (GetConVarBool(g_Cvar_Enable)))
	{
		CreateTimer(GetConVarFloat(g_Cvar_Timer), CheckRestart);
	}
}

public Action:CheckRestart(Handle:timer)
{
	//restarting server
	if(GetConVarInt(g_Cvar_RestartType) == 0)
	{
		LogToGame("Restarting server, since server is empty");
		ServerCommand("_restart");
		return;
	}
	//restarting current map
	if(GetConVarInt(g_Cvar_RestartType) == 1)
	{
		decl String:currentMap[PLATFORM_MAX_PATH];
		GetCurrentMap(currentMap, sizeof(currentMap));
		ForceChangeLevel(currentMap, "Restarting current map, since server is empty");
		return;
	}
	//restarting the round
	if(GetConVarInt(g_Cvar_RestartType) == 2)
	{
		LogToGame("Restarting the round, since server is empty");
		ServerCommand("mp_restartgame 1");
		return;
	}
	//reseting server to default map
	if(GetConVarInt(g_Cvar_RestartType) == 3)
	{
		ForceChangeLevel(g_DefaultMap, "Changing to default map, since server is empty");
		return;
	}
}