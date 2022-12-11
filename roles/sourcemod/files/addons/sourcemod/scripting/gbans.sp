#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include <basecomm>
#include <connect> // connect extension
#include <gbans>
#include <json> // sm-json
#include <sdktools>
#include <sourcemod>
#include <system2> // system2 extension

#include "gbans/auth.sp"
#include "gbans/ban.sp"
#include "gbans/commands.sp"
#include "gbans/common.sp"
#include "gbans/connect.sp"
#include "gbans/globals.sp"
#include "gbans/report.sp"
#include "gbans/stopwatch.sp"
#include "gbans/stv.sp"

#define DEBUG

public
Plugin myinfo = {
    name = PLUGIN_NAME,
    author = PLUGIN_AUTHOR,
    description = "gbans game client",
    version = PLUGIN_VERSION,
    url = "https://github.com/leighmacdonald/gbans",
};

public
void OnPluginStart() {
    LoadTranslations("common.phrases.txt");

    // Core settings
    gHost = CreateConVar("gb_core_host", "localhost", "Remote gbans host");
    gPort = CreateConVar("gb_core_port", "6006", "Remote gbans port", _, true, 1.0, true, 65535.0);
    gServerName = CreateConVar("gb_core_server_name", "", "Short hand server name");
    gServerKey = CreateConVar("gb_core_server_key", "", "GBans server key used to authenticate with the service");

    // STV settings
    gAutoRecord = CreateConVar("gb_stv_enable", "1", "Enable automatic recording", _, true, 0.0, true, 1.0);
    gMinPlayersStart =
        CreateConVar("gb_stv_minplayers", "1", "Minimum players on server to start recording", _, true, 0.0);
    gIgnoreBots = CreateConVar("gb_stv_ignorebots", "1", "Ignore bots in the player count", _, true, 0.0, true, 1.0);
    gTimeStart = CreateConVar("gb_stv_timestart", "-1", "Hour in the day to start recording (0-23, -1 disables)");
    gTimeStop = CreateConVar("gb_stv_timestop", "-1", "Hour in the day to stop recording (0-23, -1 disables)");
    gFinishMap =
        CreateConVar("gb_stv_finishmap", "1", "If 1, continue recording until the map ends", _, true, 0.0, true, 1.0);
    gDemoPathActive = CreateConVar("gb_stv_path", "stv_demos/active", "Path to store currently recording demos");
    gDemoPathComplete = CreateConVar("gb_stv_path_complete", "stv_demos/complete", "Path to store complete demos");

    // Stopwatch mode settings
    gStopwatchEnabled = CreateConVar("gb_stopwatch_enabled", "0", "Enables stopwatch mode", _, true, 0.0, true, 1.0);
    gStopwatchNameBlu = CreateConVar("gb_stopwatch_blueteamname", "Team A", "Name for the team that starts BLU.");
    gStopwatchNameRed = CreateConVar("gb_stopwatch_redteamname", "Team B", "Name for the team that starts RED.");

    AutoExecConfig(true, "gbans");

    RegConsoleCmd("gb_version", onCmdVersion, "Get gbans version");
    RegConsoleCmd("gb_help", onCmdHelp, "Get a list of gbans commands");
    RegConsoleCmd("gb_mod", onCmdMod, "Ping a moderator");
    RegConsoleCmd("mod", onCmdMod, "Ping a moderator");
    RegConsoleCmd("report", onCmdReport, "Report a player");

    RegAdminCmd("gb_ban", onAdminCmdBan, ADMFLAG_BAN);
    RegAdminCmd("gb_reauth", onAdminCmdReauth, ADMFLAG_ROOT);
    RegAdminCmd("gb_reload", onAdminCmdReload, ADMFLAG_ROOT);

    onPluginStartStopwatch();
}

public
void OnConfigsExecuted() {
    setupSTV();
    refreshToken();
}

public
APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    CreateNative("GB_BanClient", Native_GB_BanClient);
    return APLRes_Success;
}
