#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include <admin>
#include <basecomm>
#include <connect>	// connect extension
#include <gbans>
#include <sdktools>
#include <sourcemod>
#include <autoexecconfig>


#include "gbans/globals.sp"
#include "gbans/auth.sp"
#include "gbans/balance.sp"
#include "gbans/ban.sp"
#include "gbans/commands.sp"
#include "gbans/common.sp"
#include "gbans/connect.sp"
#include "gbans/match.sp"
#include "gbans/report.sp"
#include "gbans/stats.sp"
#include "gbans/stv.sp"

public Plugin myinfo =
{
	name = "gbans",
	author = "Leigh MacDonald",
	description = "gbans game client",
	version = PLUGIN_VERSION,
	url = "https://github.com/leighmacdonald/gbans",
};

public void onPluginStart()
{
	LoadTranslations("common.phrases.txt");

	RegConsoleCmd("gb_version", onCmdVersion, "Get gbans version");
	RegConsoleCmd("gb_help", onCmdHelp, "Get a list of gbans commands");
	RegConsoleCmd("gb_mod", onCmdMod, "Ping a moderator");
	RegConsoleCmd("mod", onCmdMod, "Ping a moderator");
	RegConsoleCmd("report", onCmdReport, "Report a player");
	RegConsoleCmd("autoteam", onCmdAutoTeamAction);

	RegAdminCmd("gb_ban", onAdminCmdBan, ADMFLAG_BAN);
	RegAdminCmd("gb_reauth", onAdminCmdReauth, ADMFLAG_ROOT);
	RegAdminCmd("gb_reload", onAdminCmdReload, ADMFLAG_ROOT);
	RegAdminCmd("gb_stv_record", Command_Record, ADMFLAG_KICK, "Starts a SourceTV demo");
	RegAdminCmd("gb_stv_stoprecord", Command_StopRecord, ADMFLAG_KICK, "Stops the current SourceTV demo");
	
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookEvent("player_connect_client", Event_PlayerConnect, EventHookMode_Pre);
	HookEvent("teamplay_round_start", onRoundStart, EventHookMode_Pre);
	HookEvent("teamplay_game_over", onRoundEnd, EventHookMode_Post);

	// Core settings
	CreateConVar("gb_core_host", "localhost", "Remote gbans host", FCVAR_NONE);

    CreateConVar("gb_core_port", "6006", "Remote gbans port", FCVAR_NONE, true, 1.0, true, 65535.0);
	CreateConVar("gb_core_server_name", "", "Short hand server name", FCVAR_NONE);
	CreateConVar("gb_core_server_key", "", "GBans server key used to authenticate with the service", FCVAR_NONE);

	// In Game Tweaks
	CreateConVar("gb_hide_connections", "1", "Dont show the disconnect message to users", FCVAR_NONE, true, 0.0, true, 1.0);
	CreateConVar("gb_disable_autoteam", "1", "Dont allow the use of autoteam command", FCVAR_NONE, true, 0.0, true, 1.0);

	// STV settings
	CreateConVar("gb_stv_enable", "1", "Enable SourceTV", FCVAR_NONE, true, 0.0, true, 1.0);
	CreateConVar("gb_auto_record", "1", "Enable automatic recording", FCVAR_NONE, true, 0.0, true, 1.0);
	CreateConVar("gb_stv_minplayers", "1", "Minimum players on server to start recording", _, true, 0.0);
	CreateConVar("gb_stv_ignorebots", "1", "Ignore bots in the player count", FCVAR_NONE, true, 0.0, true, 1.0);
	CreateConVar("gb_stv_timestart", "-1", "Hour in the day to start recording (0-23, -1 disables)", FCVAR_NONE);
	CreateConVar("gb_stv_timestop", "-1", "Hour in the day to stop recording (0-23, -1 disables)", FCVAR_NONE);
	CreateConVar("gb_stv_finishmap", "1", "If 1, continue recording until the map ends", FCVAR_NONE, true, 0.0, true, 1.0);
	CreateConVar("gb_stv_path", "stv_demos/active", "Path to store currently recording demos", FCVAR_NONE);
    CreateConVar("gb_stv_path_complete", "stv_demos/complete", "Path to store complete demos", FCVAR_NONE);

	//AutoExecConfig(true, "gbans");
}

public void OnConfigsExecuted()
{
	ConVar stv_mp = FindConVar("gb_stv_minplayers");
	stv_mp.AddChangeHook(OnConVarChanged);

	ConVar stv_ignorebots = FindConVar("gb_stv_ignorebots");
	stv_ignorebots.AddChangeHook(OnConVarChanged);

	ConVar stv_timestart = FindConVar("gb_stv_timestart");
	stv_timestart.AddChangeHook(OnConVarChanged);

	ConVar stv_timestop = FindConVar("gb_stv_timestop");
	stv_timestop.AddChangeHook(OnConVarChanged);

	ConVar stv_path = FindConVar("gb_stv_path");
	stv_path.AddChangeHook(OnConVarChanged);

	ConVar stv_path_complete = FindConVar("gb_stv_path_complete");

	refreshToken();

	char sPath[PLATFORM_MAX_PATH];
	
	gbLog("gb_stv_path: %b", stv_path == null);

	stv_path.GetString(sPath, sizeof(sPath));
	if(!DirExists(sPath))
	{
		initDirectory(sPath);
	}

	char sPathComplete[PLATFORM_MAX_PATH];
	GetConVarString(stv_path_complete, sPathComplete, sizeof sPathComplete);
	if(!DirExists(sPathComplete))
	{
		initDirectory(sPathComplete);
	}

	CreateTimer(300.0, Timer_CheckStatus, _, TIMER_REPEAT);

	StopRecord();	

	if(!gStvMapChanged)
	{
		// STV does not function until a map change has occurred.
		gbLog("Restarting map to enabled STV");
		gStvMapChanged = true;
		char mapName[128];
		GetCurrentMap(mapName, sizeof mapName);
		ForceChangeLevel(mapName, "Enable STV");
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("GB_BanClient", Native_GB_BanClient);
	
	return APLRes_Success;
}
