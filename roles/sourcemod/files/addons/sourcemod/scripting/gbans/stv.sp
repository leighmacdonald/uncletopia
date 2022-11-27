/*
* Adapted from: Auto Recorder http://forums.alliedmods.net/showthread.php?t=92072
*/

#include <sourcemod>
#include <sourcetvmanager>
#include <tf2_stocks>
#include <json>
#include "globals.sp"

#pragma semicolon 1
#pragma newdecls required

bool g_bIsRecording = false;
bool g_bIsManual = false;

JSON_Object g_scores = null;

public void setupSTV()
{
	RegAdminCmd("sm_gbans_stv_record", Command_Record, ADMFLAG_KICK, "Starts a SourceTV demo");
	RegAdminCmd("sm_gbans_stv_stoprecord", Command_StopRecord, ADMFLAG_KICK, "Stops the current SourceTV demo");

	g_scores = new JSON_Object();
	g_hTvEnabled = FindConVar("tv_enable");
	char sPath[PLATFORM_MAX_PATH];
	g_hDemoPath.GetString(sPath, sizeof(sPath));
	if(!DirExists(sPath))
	{
		InitDirectory(sPath);
	}

	char sPathComplete[PLATFORM_MAX_PATH];
	g_hDemoPathComplete.GetString(sPathComplete, sizeof(sPathComplete));
	if(!DirExists(sPathComplete))
	{
		InitDirectory(sPathComplete);
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
	if(convar == g_hDemoPath || convar == g_hDemoPathComplete)
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

public void onMapEndSTV()
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
	return Plugin_Handled;
}

public Action Command_Record(int client, int args)
{
	if(g_bIsRecording)
	{
		ReplyToCommand(client, "[GB] SourceTV is already recording!");
		return Plugin_Handled;
	}

	StartRecord();
	g_bIsManual = true;
	ReplyToCommand(client, "[GB] SourceTV is now recording...");
	return Plugin_Handled;
}

public Action Command_StopRecord(int client, int args)
{
	if(!g_bIsRecording)
	{
		ReplyToCommand(client, "[GB] SourceTV is not recording!");
		return Plugin_Handled;
	}
	StopRecord();
	if(g_bIsManual)
	{
		g_bIsManual = false;
		CheckStatus();
	}
	ReplyToCommand(client, "[GB] Stopped recording.");
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
		char sMap[64];
		// char serverName[128];
		// g_server_name.GetString(serverName, sizeof(serverName));

		g_hDemoPath.GetString(sPath, sizeof(sPath));
		FormatTime(sTime, sizeof(sTime), "%Y%m%d-%H%M%S", GetTime());
		GetCurrentMap(sMap, sizeof(sMap));

		// replace slashes in map path name with dashes, to prevent fail on workshop maps
		ReplaceString(sMap, sizeof(sMap), "/", "-", false);		
	    ReplaceString(sMap, sizeof(sMap), ".", "-", false);	

		ServerCommand("tv_record \"%s/%s-%s\"", sPath, sTime, sMap);
		g_bIsRecording = true;

		LogMessage("[GB] Recording to %s-%s.dem", sTime, sMap);
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

public void OnClientDisconnect(int client) {
	saveClientScore(client);
}


void saveClientScore(int client ) {
	if (!IsValidClient(client)) { 
		return; 
	}
	JSON_Object values = new JSON_Object();
	char authId[60];
	if (!GetClientAuthId(client, AuthId_SteamID64, authId, sizeof(authId), true)) {
		PrintToServer("[GB] Invalid auth id: %d", client);
		return;
	}
	int ent = GetPlayerResourceEntity();
	if (!IsValidEntity(ent)) {
		PrintToServer("[GB] Invalid entity: %d", ent);
		return;
	}
	// TODO These props fail?
	// int assists = GetEntProp(ent, Prop_Send, "m_iKillAssists", _, client);
	// PrintToServer("[GB] Assists: %d", assists);
	// int captures = GetEntProp(ent, Prop_Send, "m_iCaptures", _, client);
	// PrintToServer("[GB] captures: %d", captures);
	// int defenses = GetEntProp(ent, Prop_Send, "m_iDefenses", _, client);
	// PrintToServer("[GB] defenses: %d", defenses);
	//values.SetInt("score", GetEntProp(ent, Prop_Send, "m_iScore"));
	values.SetInt("score", GetEntProp(ent, Prop_Send, "m_iScore", _, client));
	values.SetInt("score_total", GetEntProp(ent, Prop_Send, "m_iTotalScore", _, client));
	//values.SetInt("assists", assists);
	values.SetInt("deaths", GetEntProp(ent, Prop_Send, "m_iDeaths", _, client));
	//values.SetInt("captures", captures);
	//values.SetInt("defenses", defenses);
	// Only trigger for client indexes actually in the game
	//int score = TF2_GetPlayerResourceData(client, TFResource_TotalScore);
	g_scores.SetObject(authId, values);
}


stock bool IsValidClient(int client)
{
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client) || IsFakeClient(client) || IsClientSourceTV(client) || IsClientReplay(client))
	{
		return false;
	}
	return true;
}

// TODO track scores for disconnected
JSON_Object writeMeta() {
	JSON_Object root = new JSON_Object();
	for (int i = 1; i <= MaxClients; i++)
	{
		saveClientScore(i);
	}  
	root.SetObject("scores", g_scores);

	char mapName[256];
	GetCurrentMap(mapName, sizeof(mapName));
	root.SetString("map_name", mapName);

	return root;
}

public void SourceTV_OnStopRecording(int instance, const char[] filename, int recordingtick) {
	char outMeta[4096];
	char sPieces[32][PLATFORM_MAX_PATH];
	char outPath[PLATFORM_MAX_PATH];
	char outPathMeta[PLATFORM_MAX_PATH];

	JSON_Object metaData = writeMeta();
	metaData.Encode(outMeta, sizeof(outMeta));
	PrintToServer(outMeta);
	json_cleanup_and_delete(metaData);
	
	g_hDemoPathComplete.GetString(outPath, sizeof(outPath));
	
	int iNumPieces = ExplodeString(filename, "/", sPieces, sizeof(sPieces), sizeof(sPieces[]));

	Format(outPath, sizeof(outPath), "%s/%s", outPath, sPieces[iNumPieces-1]);
	Format(outPathMeta, sizeof(outPathMeta), "%s.json", outPath);
	PrintToServer("[GB] Writing meta: %s", outPathMeta);
	File outFileMeta = OpenFile(outPathMeta, "w");
	if (outFileMeta != null) {
		if (!WriteFileString(outFileMeta, outMeta, false)) {
			PrintToServer("[GB] Failed to open for writing: %s", outPathMeta);
		}
	}
	outFileMeta.Close();
	PrintToServer("[GB] Writing stv: %s dest: %s", filename, outPath);
	if (!RenameFile(outPath, filename)) {
		PrintToServer("Failed to rename completed demo file");
		return;
	}
	PrintToServer("[GB] Wrote demo");
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
