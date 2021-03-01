#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>

#define PLUGIN_VERSION "1.1"
#define STOPWATCH_CFG_PATH "cfg/sourcemod/stopwatch.txt"

public Plugin:myinfo = {
	name = "Stopwatch Mode",
	author = "EnigmatiK",
	description = "Runs the stopwatch from mp_tournament without needing to set up tournament settings.",
	version = PLUGIN_VERSION,
	url = "http://theme.freehostia.com/"
};

new Handle:cvar_enabled;
new Handle:cvar_blu;
new Handle:cvar_red;
new enabled;

public OnPluginStart() {
	SetConVarString(CreateConVar("stopwatch_version", PLUGIN_VERSION, "version of Stopwatch for TF2", FCVAR_SPONLY | FCVAR_NOTIFY | FCVAR_PLUGIN), PLUGIN_VERSION);
	cvar_enabled = CreateConVar("stopwatch_enabled", "1", "Enables the stopwatch.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	cvar_blu = CreateConVar("stopwatch_blueteamname", "Team A", "Name for the team that starts BLU.", FCVAR_PLUGIN);
	cvar_red = CreateConVar("stopwatch_redteamname", "Team B", "Name for the team that starts RED.", FCVAR_PLUGIN);
	HookEvent("teamplay_round_start", round_start, EventHookMode_PostNoCopy);
	RegConsoleCmd("tournament_readystate", cmd_block);
	RegConsoleCmd("tournament_teamname", cmd_block);
}

public OnMapStart() {
	enabled = GetConVarBool(cvar_enabled);
	if (!enabled) return;
	//
	decl String:curmap[64];
	GetCurrentMap(curmap, sizeof(curmap));
	if (!FileExists(STOPWATCH_CFG_PATH)) {
		new Handle:file = OpenFile(STOPWATCH_CFG_PATH, "w");
		WriteFileLine(file, "// List all maps for which Stopwatch should be enabled");
		WriteFileLine(file, "");
		WriteFileLine(file, "cp_*");
		WriteFileLine(file, "pl_*");
		CloseHandle(file);
		enabled = (!StrContains(curmap, "cp_", false) || !StrContains(curmap, "pl_", false));
	} else {
		enabled = false;
		decl String:line[128];
		new Handle:file = OpenFile(STOPWATCH_CFG_PATH, "r");
		while (ReadFileLine(file, line, sizeof(line))) {
			ReplaceString(line, sizeof(line), "//", "\0");
			TrimString(line);
			if (line[0] != '\0') {
				if (line[strlen(line) - 1] == '*') {
					line[strlen(line) - 1] = '\0';
					enabled = !StrContains(curmap, line, false);
				} else {
					enabled = StrEqual(curmap, line, false);
				}
			}
			if (enabled) break;
		}
	}
}

public OnMapEnd() {
	SetConVarBool(FindConVar("mp_tournament"), false);
}

public round_start(Handle:event, const String:name[], bool:dontBroadcast) {
	if (enabled && !GetConVarBool(FindConVar("mp_tournament"))) {
		// set cvars
		SetConVarBool(FindConVar("mp_tournament"), true);
		SetConVarBool(FindConVar("mp_tournament_allow_non_admin_restart"), false);
		SetConVarBool(FindConVar("mp_tournament_stopwatch"), true);
		// set team names
		decl String:teamname[16];
		GetConVarString(cvar_blu, teamname, sizeof(teamname));
		SetConVarString(FindConVar("mp_tournament_blueteamname"), teamname);
		GetConVarString(cvar_red, teamname, sizeof(teamname));
		SetConVarString(FindConVar("mp_tournament_redteamname"), teamname);
		// wait for players, then start the tournament
		ServerCommand("mp_restartgame %d", GetConVarInt(FindConVar("mp_waitingforplayers_time")));
	}
}

public Action:cmd_block(client, args) {
	return (enabled ? Plugin_Handled : Plugin_Continue);
}
