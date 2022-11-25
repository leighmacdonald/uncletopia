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

#define DEBUG

public
Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, description = "gbans game client",
                 version = PLUGIN_VERSION, url = "https://github.com/leighmacdonald/gbans"};

// public Extension __ext_Connect = 
// {
// 	name = "Connect",
// 	file = "connect.ext",
// 	autoload = 1,
// 	required = 1,
// }

public
void OnPluginStart() {
    LoadTranslations("common.phrases.txt");

    g_host = CreateConVar("sm_gbans_host", "localhost", "Remote gbans host");
	g_port = CreateConVar("sm_gbans_port", "6006", "Remote gbans port", _, true, 1.0, true, 65535.0);
	g_server_name = CreateConVar("sm_gbans_server_name", "", "Short hand server name");
	g_server_key = CreateConVar("sm_gbans_server_key", "", "GBans server key used to authenticate with the service");
    
    g_hAutoRecord = CreateConVar("sm_gbans_stv_enable", "1", "Enable automatic recording", _, true, 0.0, true, 1.0);
	g_hMinPlayersStart = CreateConVar("sm_gbans_stv_minplayers", "1", "Minimum players on server to start recording", _, true, 0.0);
	g_hIgnoreBots = CreateConVar("sm_gbans_stv_ignorebots", "1", "Ignore bots in the player count", _, true, 0.0, true, 1.0);
	g_hTimeStart = CreateConVar("sm_gbans_stv_timestart", "-1", "Hour in the day to start recording (0-23, -1 disables)");
	g_hTimeStop = CreateConVar("sm_gbans_stv_timestop", "-1", "Hour in the day to stop recording (0-23, -1 disables)");
	g_hFinishMap = CreateConVar("sm_gbans_stv_finishmap", "1", "If 1, continue recording until the map ends", _, true, 0.0, true, 1.0);
	g_hDemoPath = CreateConVar("sm_gbans_stv_path", "stv_demos/active", "Path to store currently recording demos");
	g_hDemoPathComplete = CreateConVar("sm_gbans_stv_path_complete", "stv_demos/complete", "Path to store complete demos");

    AutoExecConfig(true, "gbans");

    RegConsoleCmd("gb_version", CmdVersion, "Get gbans version");
    RegConsoleCmd("gb_mod", CmdMod, "Ping a moderator");
    RegConsoleCmd("mod", CmdMod, "Ping a moderator");
    RegAdminCmd("gb_ban", AdminCmdBan, ADMFLAG_BAN);
    RegAdminCmd("gb_reauth", AdminCmdReauth, ADMFLAG_ROOT);
    RegAdminCmd("gb_reload", AdminCmdReload, ADMFLAG_ROOT);
    RegConsoleCmd("gb_help", CmdHelp, "Get a list of gbans commands");
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
