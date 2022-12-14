#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

public
int onPluginStartStopwatch() {
    HookEvent("teamplay_round_start", onTeamplayRoundStart, EventHookMode_PostNoCopy);
    RegConsoleCmd("tournament_readystate", cmd_block);
    RegConsoleCmd("tournament_teamname", cmd_block);
    return 0;
}

public
int onMapEndStopwatch() {
    if (GetConVarBool(FindConVar("mp_tournament"))) {
        SetConVarBool(FindConVar("mp_tournament"), false);
    }
    return 0;
}

public
Action cmd_mp_tournament_teamname(int client, const char[] command, int argc) {
    if (GetUserAdmin(client) == INVALID_ADMIN_ID) {
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

bool isValidStopwatchMap() {
    char mapName[256];
    GetCurrentMap(mapName, sizeof(mapName));
    if (StrContains(mapName, "workshop/")) {
        gbLog("matched workshop: %s", mapName);
        return StrContains(mapName, "workshop/pl_", false) == 0;
    }
    return StrContains(mapName, "pl_", false) == 0;
}

public
int onTeamplayRoundStart(Handle event, const char[] name, bool dontBroadcast) {
    if (!gStopwatchEnabled.BoolValue || !isValidStopwatchMap() || GetConVarBool(FindConVar("mp_tournament"))) {
        return -1;
    }
    // set cvars
    SetConVarBool(FindConVar("mp_tournament"), true);
    SetConVarBool(FindConVar("mp_tournament_allow_non_admin_restart"), false);
    SetConVarBool(FindConVar("mp_tournament_stopwatch"), true);

    // set team names
    char teamnameA[16];
    gStopwatchNameBlu.GetString(teamnameA, sizeof(teamnameA));
    SetConVarString(FindConVar("mp_tournament_blueteamname"), teamnameA);

    char teamnameB[16];
    gStopwatchNameRed.GetString(teamnameB, sizeof(teamnameB));
    SetConVarString(FindConVar("mp_tournament_redteamname"), teamnameB);

    // wait for players, then start the tournament
    ServerCommand("mp_restartgame %d", GetConVarInt(FindConVar("mp_waitingforplayers_time")));

    AllowMatch();
    return 0;
}

stock void AllowMatch() {
    for (int i = 1; i <= MaxClients; i++) {
        GameRules_SetProp("m_bTeamReady", 1, .element = i);
    }
}

public
Action cmd_block(int client, int args) {
    return (gStopwatchEnabled.BoolValue ? Plugin_Handled : Plugin_Continue);
}
