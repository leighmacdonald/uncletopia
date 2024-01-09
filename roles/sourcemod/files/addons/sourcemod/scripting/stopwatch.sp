#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include <sdktools>

public Plugin myinfo =
{
	name = "Stopwatch Mode",
	author = "leigh MacDonald",
	description = "Enables stopwatch mode for pub servers",
	version = "0.0.1",
	url = "https://github.com/leighmacdonald/stopwatch",
};

bool g_bHasWaitedForPlayers;
int g_iRoundsCompleted;

ConVar gStopwatchEnabled = null;
ConVar gStopwatchNameRed = null;
ConVar gStopwatchNameBlu = null;
ConVar gStopwatchChangelvlTime = null;

void log(const char[] format, any...)
{
	char buffer[254];
	VFormat(buffer, sizeof buffer, format, 2);
	PrintToServer("[Stopwatch] %s", buffer);
}

public void OnPluginStart()
{
    // Stopwatch mode settings
	gStopwatchEnabled = CreateConVar("stopwatch_enabled", "0", "Enables stopwatch mode", _, true, 0.0, true, 1.0);
	gStopwatchNameBlu = CreateConVar("stopwatch_blueteamname", "Team A", "Name for the team that starts BLU.");
	gStopwatchNameRed = CreateConVar("stopwatch_redteamname", "Team B", "Name for the team that starts RED.");
	gStopwatchChangelvlTime = CreateConVar("stopwatch_changelevel_time", "35", "Time to wait (in seconds) before changelevel after map end.", _, true, 0.0);
	AddCommandListener(cmd_mp_tournament_teamname, "mp_tournament_redteamname");
	AddCommandListener(cmd_mp_tournament_teamname, "mp_tournament_blueteamname");
	HookEvent("teamplay_round_start", onTeamplayRoundStart, EventHookMode_PostNoCopy);
	HookEvent("teamplay_win_panel", onRoundCompleted, EventHookMode_Pre);
	// HookEvent("mp_match_end_at_timelimit", onMatchEnd, EventHookMode_PostNoCopy);

	RegConsoleCmd("tournament_readystate", cmd_block);
	RegConsoleCmd("tournament_teamname", cmd_block);

	AutoExecConfig(true, "stopwatch");
}


public void OnMapStart()
{
// Don't enable for non-pl maps
	if(gStopwatchEnabled.BoolValue && GetConVarBool(FindConVar("mp_tournament")) && !isValidStopwatchMap())
	{
		log("Disabling mp_tournament");
		SetConVarBool(FindConVar("mp_tournament"), false);
	}

	g_bHasWaitedForPlayers = false;
	g_iRoundsCompleted = 0;
}


public void onRoundCompleted(Event event, const char[] name, bool dontBroadcast)
{
// Don't enable for non-pl maps
	if(!gStopwatchEnabled.BoolValue || !GetConVarBool(FindConVar("mp_tournament")))
	{
		return ;
	}

	if(event.GetInt("round_complete") == 1 || StrEqual(name, "arena_win_panel"))
	{
		g_iRoundsCompleted++;
	}

	// Stopwatch only works on PL and maybe A/D? This should be fine as they use maxrounds
	if(g_iRoundsCompleted >= GetConVarInt(FindConVar("mp_maxrounds")))
	{
		CreateTimer(gStopwatchChangelvlTime.FloatValue, handleChangelevel);
	}
}


public Action handleChangelevel(Handle timer)
{
	char map[PLATFORM_MAX_PATH];
	GetNextMap(map, sizeof map);
	ServerCommand("changelevel %s", map);

	return Plugin_Continue;
}

public int onMapEndStopwatch()
{
	if(GetConVarBool(FindConVar("mp_tournament")))
	{
		SetConVarBool(FindConVar("mp_tournament"), false);
	}

	return 0;
}


public Action cmd_mp_tournament_teamname(int client, const char[] command, int argc)
{
	if(GetUserAdmin(client) == INVALID_ADMIN_ID)
	{
		return Plugin_Stop;
	}

	return Plugin_Continue;
}


bool isValidStopwatchMap()
{
	char mapName[256];
	GetCurrentMap(mapName, sizeof mapName);
	if(StrContains(mapName, "workshop/", false) == 0)
	{
		log("matched workshop: %s", mapName);
		return StrContains(mapName, "workshop/pl_", false) == 0;
	}
	log("mapName: %s", mapName);

	return StrContains(mapName, "pl_", false) == 0;
}


public int onTeamplayRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if(!gStopwatchEnabled.BoolValue || !isValidStopwatchMap() || g_bHasWaitedForPlayers)
	{
		return 0;
	}

	log("Enabling stopwatch mode (mp_tournament)");

	// set cvars
	SetConVarBool(FindConVar("mp_tournament"), true);
	SetConVarBool(FindConVar("mp_tournament_allow_non_admin_restart"), false);
	SetConVarBool(FindConVar("mp_tournament_stopwatch"), true);

	// set team names
	char teamnameA[16];
	gStopwatchNameBlu.GetString(teamnameA, sizeof teamnameA);
	SetConVarString(FindConVar("mp_tournament_blueteamname"), teamnameA);

	char teamnameB[16];
	gStopwatchNameRed.GetString(teamnameB, sizeof teamnameB);
	SetConVarString(FindConVar("mp_tournament_redteamname"), teamnameB);

	// wait for players, then start the tournament
	ServerCommand("mp_restartgame %d", GetConVarInt(FindConVar("mp_waitingforplayers_time")));
	g_bHasWaitedForPlayers = true;

	AllowMatch();

	return 0;
}


stock void AllowMatch()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		GameRules_SetProp("m_bTeamReady", 1, .element = i);
	}
}


public Action cmd_block(int client, int args)
{
	return (gStopwatchEnabled.BoolValue ? Plugin_Handled : Plugin_Continue);
}
