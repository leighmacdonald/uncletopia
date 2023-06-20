#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include <sdktools>

bool g_bHasWaitedForPlayers;
int g_iRoundsCompleted;

ConVar g_Cvar_Enabled;
ConVar g_Cvar_Name_Blu;
ConVar g_Cvar_Name_Red;

ConVar g_Cvar_BonusRoundTime;
ConVar g_Cvar_ChatTime;
ConVar g_Cvar_WinLimit;
ConVar g_Cvar_MaxRounds;

public void OnPluginStart() {
    // Stopwatch mode settings
    g_Cvar_Enabled = CreateConVar("pw_enabled", "0", "Enable pub Stopwatch mode", _, true, 0.0, true, 1.0);
    g_Cvar_Name_Blu = CreateConVar("pw_teamname_blu", "Team A", "Name for the team that starts BLU.");
    g_Cvar_Name_Red = CreateConVar("pw_teamname_red", "Team B", "Name for the team that starts RED.");

    // For changing map correctly
    g_Cvar_BonusRoundTime = FindConVar("mp_bonusroundtime");
    g_Cvar_ChatTime = FindConVar("mp_chattime");
    g_Cvar_WinLimit = FindConVar("mp_winlimit");
    g_Cvar_MaxRounds = FindConVar("mp_maxrounds");

    AddCommandListener(cmd_listener_block, "mp_tournament_redteamname");
    AddCommandListener(cmd_listener_block, "mp_tournament_blueteamname");
    HookEvent("teamplay_round_start", OnRoundStart, EventHookMode_PostNoCopy);
    HookEvent("teamplay_restart_round", OnGameRestart);
    HookEvent("teamplay_win_panel", OnRoundCompleted, EventHookMode_Pre);

    RegConsoleCmd("tournament_readystate", cmd_block);
    RegConsoleCmd("tournament_teamname", cmd_block);
}

public void OnMapStart() {
    if (g_Cvar_Enabled.BoolValue && GetConVarBool(FindConVar("mp_tournament")) && !isValidStopwatchMap()) {
        SetConVarBool(FindConVar("mp_tournament"), false);
    }

    g_bHasWaitedForPlayers = false;
    g_iRoundsCompleted = 0;
}

public void OnGameRestart(Event event, const char[] name, bool dontBroadcast)
{
    g_iRoundsCompleted = 0;    
}

public void OnRoundCompleted(Event event, const char[] name, bool dontBroadcast) {
    // Don't enable for non-pl maps
    if (!g_Cvar_Enabled.BoolValue || !GetConVarBool(FindConVar("mp_tournament"))) {
        return;
    }

    if (event.GetInt("round_complete") == 1 || StrEqual(name, "arena_win_panel")) {
        g_iRoundsCompleted++;

        CheckMaxRounds(g_iRoundsCompleted);
		CheckTimeLeft();

        switch(event.GetInt("winning_team"))
        {
            case 3:
            {
                int score = event.GetInt("blue_score");
                CheckWinLimit(score);
            }
            case 2:
            {
                int score = event.GetInt("red_score");
                CheckWinLimit(score);
            }
            default:
            {
                return;
            }
        }
    }
}

public void CheckWinLimit(int winner_score) {    
    if (g_Cvar_WinLimit)
    {
        int winlimit = g_Cvar_WinLimit.IntValue;
        if (winlimit)
        {
            if (winner_score >= winlimit)
            {
                CreateTimer(g_Cvar_BonusRoundTime.FloatValue + g_Cvar_ChatTime.FloatValue, handleChangelevel);
            }
        }
    }
}

public void CheckMaxRounds(int roundcount) {
    if (g_Cvar_MaxRounds)
    {
        int maxrounds = g_Cvar_MaxRounds.IntValue;
        if (maxrounds)
        {
            if (roundcount >= maxrounds)
            {
                CreateTimer(g_Cvar_BonusRoundTime.FloatValue + g_Cvar_ChatTime.FloatValue, handleChangelevel);
            }
        }
    }
}

public void CheckTimeLeft() {
    int timeleft;
    GetMapTimeLeft(timeleft);

    // TF2 forces map change if the time remaining is less than 5 minutes
    // add BonusRoundTime to this and it should catch all cases
    int limit = 300 + GetConVarInt(g_Cvar_BonusRoundTime);

    if (timeleft <= limit && timeleft >= 0) { // timelimit < 0 = map has no time limit
        CreateTimer(g_Cvar_BonusRoundTime.FloatValue + g_Cvar_ChatTime.FloatValue, handleChangelevel);
    }
}

public Action handleChangelevel(Handle timer) {
    char map[PLATFORM_MAX_PATH];
    GetNextMap(map, sizeof(map));
    ServerCommand("changelevel %s", map);

    return Plugin_Continue;
}

public void OnMapEnd() {
    if (GetConVarBool(FindConVar("mp_tournament"))) {
        SetConVarBool(FindConVar("mp_tournament"), false);
    }
}

public Action cmd_mp_tournament_teamname(int client, const char[] command, int argc) {
    if (GetUserAdmin(client) == INVALID_ADMIN_ID) {
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

bool isValidStopwatchMap() {
    char mapName[256];
    GetCurrentMap(mapName, sizeof(mapName));
    if (StrContains(mapName, "workshop/", false) == 0) {
        return StrContains(mapName, "workshop/pl_", false) == 0;
    }
    return StrContains(mapName, "pl_", false) == 0;
}

public void OnRoundStart(Handle event, const char[] name, bool dontBroadcast) {
    if (!g_Cvar_Enabled.BoolValue || !isValidStopwatchMap() || g_bHasWaitedForPlayers) {
        return 0;
    }
    // set cvars
    SetConVarBool(FindConVar("mp_tournament"), true);
    SetConVarBool(FindConVar("mp_tournament_allow_non_admin_restart"), false);
    SetConVarBool(FindConVar("mp_tournament_stopwatch"), true);

    // set team names
    char teamnameA[16];
    g_Cvar_Name_Blu.GetString(teamnameA, sizeof(teamnameA));
    SetConVarString(FindConVar("mp_tournament_blueteamname"), teamnameA);

    char teamnameB[16];
    g_Cvar_Name_Red.GetString(teamnameB, sizeof(teamnameB));
    SetConVarString(FindConVar("mp_tournament_redteamname"), teamnameB);

    // wait for players, then start the tournament
    ServerCommand("mp_restartgame %d", GetConVarInt(FindConVar("mp_waitingforplayers_time")));
    g_bHasWaitedForPlayers = true;

    for (int i = 1; i <= MaxClients; i++) {
        GameRules_SetProp("m_bTeamReady", 1, .element = i);
    }
}

public Action cmd_listener_block(int client, const char[] command, int argc) {
    return (g_Cvar_Enabled.BoolValue ? Plugin_Handled : Plugin_Continue);
}

public Action cmd_block(int client, int args) {
    return (g_Cvar_Enabled.BoolValue ? Plugin_Handled : Plugin_Continue);
}
