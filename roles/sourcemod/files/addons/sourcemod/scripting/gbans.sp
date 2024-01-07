#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include <admin>
#include <basecomm>
#include <connect>	// connect extension
#include <gbans>
#include <json>	// sm-json
#include <sdktools>
#include <sourcemod>
#include <system2>	// system2 extension

#include "gbans/auth.sp"
#include "gbans/balance.sp"
#include "gbans/ban.sp"
#include "gbans/commands.sp"
#include "gbans/common.sp"
#include "gbans/connect.sp"
#include "gbans/globals.sp"
#include "gbans/report.sp"
#include "gbans/rules.sp"
#include "gbans/stats.sp"
#include "gbans/stv.sp"

#define DEBUG 

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = "gbans game client",
	version = PLUGIN_VERSION,
	url = "https://github.com/leighmacdonald/gbans",
};


public void OnPluginStart()
{
	onPluginStartCore();
	onPluginStartRules();
	onPluginStartSTV();
}


public void onPluginStartCore()
{
	LoadTranslations("common.phrases.txt");

	// Core settings
	gHost = CreateConVar("gb_core_host", "localhost", "Remote gbans host");
	gPort = CreateConVar("gb_core_port", "6006", "Remote gbans port", _, true, 1.0, true, 65535.0);
	gServerName = CreateConVar("gb_core_server_name", "", "Short hand server name");
	gServerKey = CreateConVar("gb_core_server_key", "", "GBans server key used to authenticate with the service");

	gHideConnections = CreateConVar("gb_hide_connections", "1", "Dont show the disconnect message to users", _, true, 0.0, true, 1.0);
	gDisableAutoTeam = CreateConVar("gb_disable_autoteam", "1", "Dont allow the use of autoteam command", _, true, 0.0, true, 1.0);

	AutoExecConfig(true, "gbans");

	RegConsoleCmd("gb_version", onCmdVersion, "Get gbans version");
	RegConsoleCmd("gb_help", onCmdHelp, "Get a list of gbans commands");
	RegConsoleCmd("gb_mod", onCmdMod, "Ping a moderator");
	RegConsoleCmd("mod", onCmdMod, "Ping a moderator");
	RegConsoleCmd("report", onCmdReport, "Report a player");
	RegConsoleCmd("autoteam", onCmdAutoTeamAction);

	RegAdminCmd("gb_ban", onAdminCmdBan, ADMFLAG_BAN);
	RegAdminCmd("gb_reauth", onAdminCmdReauth, ADMFLAG_ROOT);
	RegAdminCmd("gb_reload", onAdminCmdReload, ADMFLAG_ROOT);

	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookEvent("player_connect_client", Event_PlayerConnect, EventHookMode_Pre);

	gSvVisibleMaxPlayers = FindConVar("sv_visiblemaxplayers");
	gHostname = FindConVar("hostname");
}


public void OnConfigsExecuted()
{
	setupSTV();
	refreshToken();
	
}


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("GB_BanClient", Native_GB_BanClient);
	return APLRes_Success;
}
