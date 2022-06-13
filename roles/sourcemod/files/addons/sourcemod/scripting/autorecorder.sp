/*
* 
* Auto Recorder
* http://forums.alliedmods.net/showthread.php?t=92072
* 
* Description:
* Automates SourceTV recording based on player count
* and time of day. Also allows admins to manually record.
* 
* Changelog
* May 09, 2009 - v.1.0.0:
*   [*] Initial Release
* May 11, 2009 - v.1.1.0:
*   [+] Added path cvar to control where demos are stored
*   [*] Changed manual recording to override automatic recording
*   [+] Added seconds to demo names
* May 04, 2016 - v.1.1.1:
*   [*] Changed demo file names to replace slashes with hyphens [ajmadsen]
* Aug 26, 2016 - v.1.2.0:
*   [*] Now ignores bots in the player count by default
*   [*] The SourceTV client is now always ignored in the player count
*   [+] Added sm_autorecord_ignorebots to control whether to ignore bots
*   [*] Now checks the status of the server immediately when a setting is changed
* Jun 21, 2017 - v.1.3.0:
*   [*] Fixed minimum player count setting being off by one
*   [*] Fixed player counting code getting out of range
*   [*] Updated source code to the new syntax
* 
*/

#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.3.0"

public Plugin myinfo = 
{
	name = "Auto Recorder",
	author = "Stevo.TVR",
	description = "Automates SourceTV recording based on player count and time of day.",
	version = PLUGIN_VERSION,
	url = "http://www.theville.org"
}

ConVar g_hTvEnabled = null;
ConVar g_hAutoRecord = null;
ConVar g_hMinPlayersStart = null;
ConVar g_hIgnoreBots = null;
ConVar g_hTimeStart = null;
ConVar g_hTimeStop = null;
ConVar g_hFinishMap = null;
ConVar g_hDemoPath = null;

bool g_bIsRecording = false;
bool g_bIsManual = false;

public void OnPluginStart()
{
	CreateConVar("sm_autorecord_version", PLUGIN_VERSION, "Auto Recorder plugin version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_hAutoRecord = CreateConVar("sm_autorecord_enable", "1", "Enable automatic recording", _, true, 0.0, true, 1.0);
	g_hMinPlayersStart = CreateConVar("sm_autorecord_minplayers", "4", "Minimum players on server to start recording", _, true, 0.0);
	g_hIgnoreBots = CreateConVar("sm_autorecord_ignorebots", "1", "Ignore bots in the player count", _, true, 0.0, true, 1.0);
	g_hTimeStart = CreateConVar("sm_autorecord_timestart", "-1", "Hour in the day to start recording (0-23, -1 disables)");
	g_hTimeStop = CreateConVar("sm_autorecord_timestop", "-1", "Hour in the day to stop recording (0-23, -1 disables)");
	g_hFinishMap = CreateConVar("sm_autorecord_finishmap", "1", "If 1, continue recording until the map ends", _, true, 0.0, true, 1.0);
	g_hDemoPath = CreateConVar("sm_autorecord_path", ".", "Path to store recorded demos");

	AutoExecConfig(true, "autorecorder");

	RegAdminCmd("sm_record", Command_Record, ADMFLAG_KICK, "Starts a SourceTV demo");
	RegAdminCmd("sm_stoprecord", Command_StopRecord, ADMFLAG_KICK, "Stops the current SourceTV demo");

	g_hTvEnabled = FindConVar("tv_enable");

	char sPath[PLATFORM_MAX_PATH];
	g_hDemoPath.GetString(sPath, sizeof(sPath));
	if(!DirExists(sPath))
	{
		InitDirectory(sPath);
	}

	g_hMinPlayersStart.AddChangeHook(OnConVarChanged);
	g_hIgnoreBots.AddChangeHook(OnConVarChanged);
	g_hTimeStart.AddChangeHook(OnConVarChanged);
	g_hTimeStop.AddChangeHook(OnConVarChanged);
	g_hDemoPath.AddChangeHook(OnConVarChanged);

	CreateTimer(300.0, Timer_CheckStatus, _, TIMER_REPEAT);

	StopRecord();
	CheckStatus();
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char [] newValue)
{
	if(convar == g_hDemoPath)
	{
		if(!DirExists(newValue))
		{
			InitDirectory(newValue);
		}
	}
	else
	{
		CheckStatus();
	}
}

public void OnMapEnd()
{
	if(g_bIsRecording)
	{
		StopRecord();
		g_bIsManual = false;
	}
}

public void OnClientPutInServer(int client)
{
	CheckStatus();
}

public void OnClientDisconnect_Post(int client)
{
	CheckStatus();
}

public Action Timer_CheckStatus(Handle timer)
{
	CheckStatus();
}

public Action Command_Record(int client, int args)
{
	if(g_bIsRecording)
	{
		ReplyToCommand(client, "[SM] SourceTV is already recording!");
		return Plugin_Handled;
	}

	StartRecord();
	g_bIsManual = true;

	ReplyToCommand(client, "[SM] SourceTV is now recording...");

	return Plugin_Handled;
}

public Action Command_StopRecord(int client, int args)
{
	if(!g_bIsRecording)
	{
		ReplyToCommand(client, "[SM] SourceTV is not recording!");
		return Plugin_Handled;
	}

	StopRecord();

	if(g_bIsManual)
	{
		g_bIsManual = false;
		CheckStatus();
	}

	ReplyToCommand(client, "[SM] Stopped recording.");

	return Plugin_Handled;
}

void CheckStatus()
{
	if(g_hAutoRecord.BoolValue && !g_bIsManual)
	{
		int iMinClients = g_hMinPlayersStart.IntValue;

		int iTimeStart = g_hTimeStart.IntValue;
		int iTimeStop = g_hTimeStop.IntValue;
		bool bReverseTimes = (iTimeStart > iTimeStop);

		char sCurrentTime[4];
		FormatTime(sCurrentTime, sizeof(sCurrentTime), "%H", GetTime());
		int iCurrentTime = StringToInt(sCurrentTime);

		if(GetPlayerCount() >= iMinClients && (iTimeStart < 0 || (iCurrentTime >= iTimeStart && (bReverseTimes || iCurrentTime < iTimeStop))))
		{
			StartRecord();
		}
		else if(g_bIsRecording && !g_hFinishMap.BoolValue && (iTimeStop < 0 || iCurrentTime >= iTimeStop))
		{
			StopRecord();
		}
	}
}

int GetPlayerCount()
{
	bool bIgnoreBots = g_hIgnoreBots.BoolValue;

	int iNumPlayers = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && (!bIgnoreBots || !IsFakeClient(i)))
		{
			iNumPlayers++;
		}
	}

	if(!bIgnoreBots)
	{
		iNumPlayers--;
	}

	return iNumPlayers;
}

void StartRecord()
{
	if(g_hTvEnabled.BoolValue && !g_bIsRecording)
	{
		char sPath[PLATFORM_MAX_PATH];
		char sTime[16];
		char sMap[32];

		g_hDemoPath.GetString(sPath, sizeof(sPath));
		FormatTime(sTime, sizeof(sTime), "%Y%m%d-%H%M%S", GetTime());
		GetCurrentMap(sMap, sizeof(sMap));

		// replace slashes in map path name with dashes, to prevent fail on workshop maps
		ReplaceString(sMap, sizeof(sMap), "/", "-", false);		

		ServerCommand("tv_record \"%s/auto-%s-%s\"", sPath, sTime, sMap);
		g_bIsRecording = true;

		LogMessage("Recording to auto-%s-%s.dem", sTime, sMap);
	}
}

void StopRecord()
{
	if(g_hTvEnabled.BoolValue)
	{
		ServerCommand("tv_stoprecord");
		g_bIsRecording = false;
	}
}

void InitDirectory(const char[] sDir)
{
	char sPieces[32][PLATFORM_MAX_PATH];
	char sPath[PLATFORM_MAX_PATH];
	int iNumPieces = ExplodeString(sDir, "/", sPieces, sizeof(sPieces), sizeof(sPieces[]));

	for(int i = 0; i < iNumPieces; i++)
	{
		Format(sPath, sizeof(sPath), "%s/%s", sPath, sPieces[i]);
		if(!DirExists(sPath))
		{
			CreateDirectory(sPath, 509);
		}
	}
}
