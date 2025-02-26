/*
 * Adapted from: Auto Recorder http://forums.alliedmods.net/showthread.php?t=92072
 */
#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(convar == gb_stv_path || convar == gb_stv_path_complete)
	{
		if(!DirExists(newValue))
		{
			initDirectory(newValue);
		}
	}
	else
	{
		CheckStatus();
	}
}


public Action Timer_CheckStatus(Handle timer)
{
	CheckStatus();
	return Plugin_Handled;
}


public Action Command_Record(int client, int args)
{
	if(gIsRecording)
	{
		ReplyToCommand(client, "[GB] SourceTV is already recording!");
		return Plugin_Handled;
	}

	StartRecord();
	gIsManual = true;
	ReplyToCommand(client, "[GB] SourceTV is now recording...");
	return Plugin_Handled;
}


public Action Command_StopRecord(int client, int args)
{
	if(!gIsRecording)
	{
		ReplyToCommand(client, "[GB] SourceTV is not recording!");
		return Plugin_Handled;
	}

	StopRecord();

	if(gIsManual)
	{
		gIsManual = false;
		CheckStatus();
	}

	ReplyToCommand(client, "[GB] Stopped recording.");

	return Plugin_Handled;
}


void CheckStatus()
{
	if(GetConVarBool(gb_auto_record) && !gIsManual)
	{
		int iTimeStart = GetConVarInt(gb_stv_timestart);
		int iTimeStop = GetConVarInt(gb_stv_timestop);
		bool bReverseTimes = (iTimeStart > iTimeStop);
		char sCurrentTime[4];
		FormatTime(sCurrentTime, sizeof sCurrentTime, "%H", GetTime());
		int iCurrentTime = StringToInt(sCurrentTime);
		if(GetPlayerCount() >= GetConVarInt(gb_stv_minplayers) && (iTimeStart < 0 || (iCurrentTime >= iTimeStart && (bReverseTimes || iCurrentTime < iTimeStop))))
		{
			StartRecord();
		}
		else if(gIsRecording && !GetConVarBool(gb_stv_finishmap) && (iTimeStop < 0 || iCurrentTime >= iTimeStop))
		{
			StopRecord();
		}
	}
}

int GetPlayerCount()
{
	bool bIgnoreBots = GetConVarBool(gb_stv_ignorebots);

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
	if(GetConVarBool(gb_stv_enable) && !gIsRecording)
	{
		char sPath[PLATFORM_MAX_PATH];
		char sTime[16];
		char sMap[64];

		gb_stv_path.GetString(sPath, sizeof sPath);
		FormatTime(sTime, sizeof sTime, "%Y%m%d-%H%M%S", GetTime());
		GetCurrentMap(sMap, sizeof sMap);

		// replace slashes in map path name with dashes, to prevent fail on workshop maps
		ReplaceString(sMap, sizeof sMap, "/", "-", false);
		ReplaceString(sMap, sizeof sMap, ".", "-", false);

		ServerCommand("tv_record \"%s/%s-%s\"", sPath, sTime, sMap);
		gIsRecording = true;

		gbLog("Recording to %s-%s.dem", sTime, sMap);
	}
}

void StopRecord()
{
	if(GetConVarBool(gb_stv_enable))
	{
		ServerCommand("tv_stoprecord");
		gIsRecording = false;
	}
}

public void SourceTV_OnStopRecording(int instance, const char[] filename, int recordingtick)
{	
	char sPieces[32][PLATFORM_MAX_PATH];
	char outPath[PLATFORM_MAX_PATH];

	GetConVarString(gb_stv_path_complete, outPath, sizeof outPath);

	int iNumPieces = ExplodeString(filename, "/", sPieces, sizeof sPieces, sizeof sPieces[] );

	Format(outPath, sizeof outPath, "%s/%s", outPath, sPieces[iNumPieces - 1]);

	gbLog("Writing stv: %s dest: %s", filename, outPath);
	if(!RenameFile(outPath, filename))
	{
		gbLog("Failed to rename completed demo file");
		return ;
	}
	gbLog("Wrote demo");
}

void initDirectory(const char[] sDir)
{
	char sPieces[32][PLATFORM_MAX_PATH];
	char sPath[PLATFORM_MAX_PATH];
	int iNumPieces = ExplodeString(sDir, "/", sPieces, sizeof sPieces, sizeof sPieces[] );

	for(int i = 0; i < iNumPieces; i++)
	{
		Format(sPath, sizeof sPath, "%s/%s", sPath, sPieces[i]);
		if(!DirExists(sPath))
		{
			CreateDirectory(sPath, 509);
		}
	}
}
