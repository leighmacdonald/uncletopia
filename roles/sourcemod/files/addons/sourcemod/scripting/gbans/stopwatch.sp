
public onPluginStartStopwatch() {
	HookEvent("teamplay_round_start", round_start, EventHookMode_PostNoCopy);
	RegConsoleCmd("tournament_readystate", cmd_block);
	RegConsoleCmd("tournament_teamname", cmd_block);
}

public onMapEndStopwatch() {
    if (GetConVarBool(FindConVar("mp_tournament"))) {
	    SetConVarBool(FindConVar("mp_tournament"), false);
    }
}

public round_start(Handle:event, const String:name[], bool:dontBroadcast) {
	if (!g_hStopwatchEnabled.BoolValue || GetConVarBool(FindConVar("mp_tournament"))) {
        return 
    }
    // set cvars
    SetConVarBool(FindConVar("mp_tournament"), true);
    SetConVarBool(FindConVar("mp_tournament_allow_non_admin_restart"), false);
    SetConVarBool(FindConVar("mp_tournament_stopwatch"), true);

    // set team names
    char teamnameA[16];
    g_hStopwatchNameBlu.GetString(teamnameA, sizeof(teamnameA));
    SetConVarString(FindConVar("mp_tournament_blueteamname"), teamnameA);

    char teamnameB[16];
    g_hStopwatchNameRed.GetString(teamnameB, sizeof(teamnameB));
    SetConVarString(FindConVar("mp_tournament_redteamname"), teamnameB);
    
    // wait for players, then start the tournament
    ServerCommand("mp_restartgame %d", GetConVarInt(FindConVar("mp_waitingforplayers_time")));
	
}

public Action:cmd_block(client, args) {
	return (g_hStopwatchEnabled.BoolValue ? Plugin_Handled : Plugin_Continue);
}
