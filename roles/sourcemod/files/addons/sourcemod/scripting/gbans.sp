#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include <basecomm>
#include <json> // sm-json
#include <sdktools>
#include <sourcemod>
#include <system2> // system2 extension
#include <connect> // connect extension
#include <gbans>

#include "gbans/globals.sp"
#include "gbans/common.sp"
#include "gbans/ban.sp"
#include "gbans/commands.sp"
#include "gbans/connect.sp"
#include "gbans/auth.sp"
#include "gbans/stv.sp"
#include "gbans/stopwatch.sp"

#define DEBUG

public
Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, description = "gbans game client",
                 version = PLUGIN_VERSION, url = "https://github.com/leighmacdonald/gbans"};

public
void OnPluginStart() {
    LoadTranslations("common.phrases.txt");

    // Core settings
    g_host = CreateConVar("gb_core_host", "localhost", "Remote gbans host");
	g_port = CreateConVar("gb_core_port", "6006", "Remote gbans port", _, true, 1.0, true, 65535.0);
	g_server_name = CreateConVar("gb_core_server_name", "", "Short hand server name");
	g_server_key = CreateConVar("gb_core_server_key", "", "GBans server key used to authenticate with the service");
    
    // STV settings
    g_hAutoRecord = CreateConVar("gb_stv_enable", "1", "Enable automatic recording", _, true, 0.0, true, 1.0);
	g_hMinPlayersStart = CreateConVar("gb_stv_minplayers", "1", "Minimum players on server to start recording", _, true, 0.0);
	g_hIgnoreBots = CreateConVar("gb_stv_ignorebots", "1", "Ignore bots in the player count", _, true, 0.0, true, 1.0);
	g_hTimeStart = CreateConVar("gb_stv_timestart", "-1", "Hour in the day to start recording (0-23, -1 disables)");
	g_hTimeStop = CreateConVar("gb_stv_timestop", "-1", "Hour in the day to stop recording (0-23, -1 disables)");
	g_hFinishMap = CreateConVar("gb_stv_finishmap", "1", "If 1, continue recording until the map ends", _, true, 0.0, true, 1.0);
	g_hDemoPath = CreateConVar("gb_stv_path", "stv_demos/active", "Path to store currently recording demos");
	g_hDemoPathComplete = CreateConVar("gb_stv_path_complete", "stv_demos/complete", "Path to store complete demos");

    // Stopwatch mode settings
    g_hStopwatchEnabled = CreateConVar("gb_stopwatch_enabled", "0", "Enables stopwatch mode", _, true, 0.0, true, 1.0);
	g_hStopwatchNameBlu = CreateConVar("gb_stopwatch_blueteamname", "Team A", "Name for the team that starts BLU.");
	g_hStopwatchNameRed = CreateConVar("gb_stopwatch_redteamname", "Team B", "Name for the team that starts RED.");

    AutoExecConfig(true, "gbans");

    RegConsoleCmd("gb_version", CmdVersion, "Get gbans version");
    RegConsoleCmd("gb_mod", CmdMod, "Ping a moderator");
    RegConsoleCmd("mod", CmdMod, "Ping a moderator");
    RegAdminCmd("gb_ban", AdminCmdBan, ADMFLAG_BAN);
    RegAdminCmd("gb_reauth", AdminCmdReauth, ADMFLAG_ROOT);
    RegAdminCmd("gb_reload", AdminCmdReload, ADMFLAG_ROOT);
    RegConsoleCmd("gb_help", CmdHelp, "Get a list of gbans commands");

    onPluginStartStopwatch();
}

public
void OnConfigsExecuted() {
    setupSTV();
    refreshToken();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("GB_BanClient", Native_GB_BanClient);
	return APLRes_Success;
}
