#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

/* Includes */
#include <sourcemod>

/* Defines */
#define PLUGIN_VERSION			"1.3"
#define PLUGIN_DESCRIPTION		"A NonStatic Network Data Tool."
#define CrazyLiamBitWise(%1,%2) (%1 < %2 ? %2 : %1)
#define defPluginPrefix 		"\x04[Network Tools]\x03"

/* Globals */
int g_iLimit[3];

Handle g_hTimerHandle = INVALID_HANDLE;

bool g_bValidClient[MAXPLAYERS+1][2]; // 10 times faster (ICIG) to use Global bools instead of calling their native counterparts.
int g_iClientChoke[MAXPLAYERS+1][2];
int g_iClientLatency[MAXPLAYERS+1][2];
int g_iClientLoss[MAXPLAYERS+1][2];

/* Global CVars */
bool g_bEnabled = true;
bool g_bChokeEnabled = true;
bool g_bLatencyEnabled = true;
bool g_bLossEnabled = true;
bool g_bKickVocalize = true;
bool g_bWarningVocalize = true;
bool g_bLiamMethod = false;
bool g_bLoggingEnabled = false;

char g_sBasePath[PLATFORM_MAX_PATH];
char g_sLogTimeString[2][64];

int g_iCmdRate[2];

int g_iChokeAddition = 30;
int g_iLatencyAddition = 250;
int g_iLossAddition = 15;
int g_iChokeThreashold = 6;
int g_iLatencyThreashold = 6;
int g_iLossThreashold = 6;
int g_iMinPCount = 12;
int g_iCheckRate = 30;

/* My Info */
public Plugin myinfo =
{
    name 		=		"Network Tools",			// http://www.thesixtyone.com/s/7U7ePI1GYPh/
    author		=		"Kyle Sanderson",
    description	=		 PLUGIN_DESCRIPTION,
    version		=		 PLUGIN_VERSION,
    url			=		"http://SourceMod.net"
};

/* Plugin Start */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(late)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				OnClientPostAdminCheck(i);
			}
		}
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("sm_nt_verison", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_SPONLY|FCVAR_UNLOGGED|FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);
	Handle hRandom; // I HATE Handles.
	
	HookConVarChange((hRandom = CreateConVar("nt_enabled",				"1",	"Should I even be running?", _, true, 0.0, true, 1.0)),												OnEnabledChange);
	g_bEnabled = GetConVarBool(hRandom);
	HookConVarChange((hRandom = CreateConVar("nt_minplayercount",		"12",	"How many players need to be ingame for any check to occur.", _, true, 0.0)),						OnMinPlayChange);
	g_iMinPCount = GetConVarInt(hRandom);
	HookConVarChange((hRandom = CreateConVar("nt_checkrate",			"30",	"How many seconds between each check.", _, true, 0.0)),												OnCheckRateChange);
	g_iCheckRate = GetConVarInt(hRandom);
	
	HookConVarChange((hRandom = CreateConVar("nt_logenabled",			"0",	"Should I be logging kicks?", _, true, 0.0, true, 1.0)),											OnLoggingChange);
	g_bLoggingEnabled = GetConVarBool(hRandom);
	HookConVarChange((hRandom = CreateConVar("nt_logformatext",			"%Y_%m_%d",	"Log Filename Format.")),																		OnExtLogFormatChange);
	GetConVarString(hRandom, g_sLogTimeString[0], sizeof(g_sLogTimeString[]));
	HookConVarChange((hRandom = CreateConVar("nt_logformatint",			"%x",	"Internal File logging format.")),																	OnIntLogFormatChange);
	GetConVarString(hRandom, g_sLogTimeString[1], sizeof(g_sLogTimeString[]));
	
	HookConVarChange((hRandom = CreateConVar("nt_kickvocalize",			"1",	"Should Kick Messages be Printed to Chat?", _, true, 0.0, true, 1.0)), 								OnKickMessageChange);
	g_bKickVocalize = GetConVarBool(hRandom);
	HookConVarChange((hRandom = CreateConVar("nt_warningvocalize",		"1",	"Warn the player that he has an impending kick comming up.", _, true, 0.0, true, 1.0)),				OnWarningMessageChange);
	g_bWarningVocalize = GetConVarBool(hRandom);
	
	HookConVarChange((hRandom = CreateConVar("nt_choke_enable",			"1",	"Should this plugin be checking Clients for Choke?", _, true, 0.0, true, 1.0)),						OnChokeEnableChange);
	g_bChokeEnabled = GetConVarBool(hRandom);
	HookConVarChange((hRandom = CreateConVar("nt_choke_addition",		"30",	"How high should I be increasing the Choke Kick value?", _, true, 0.0)),							OnChokeAdditionChange);
	g_iChokeAddition = GetConVarInt(hRandom);
	HookConVarChange((hRandom = CreateConVar("nt_choke_threashold", 	"6",	"How many checks until a client is kicked for High Choke.", _, true, 0.0)),							OnChokeThreasholdChange);
	g_iChokeThreashold = GetConVarInt(hRandom);
	
	HookConVarChange((hRandom = CreateConVar("nt_latency_enable",		"1",	"Should this plugin be checking Client Latencies?", _, true, 0.0, true, 1.0)),						OnLatencyEnableChange);
	g_bLatencyEnabled = GetConVarBool(hRandom);
	HookConVarChange((hRandom = CreateConVar("nt_latency_addition",		"250",	"How high should I be increasing the Latency Kick value?", _, true, 0.0)),							OnLatencyAdditionChange);
	g_iLatencyAddition = GetConVarInt(hRandom);
	HookConVarChange((hRandom = CreateConVar("nt_lat_threashold",		"6",	"How many checks until a client is kicked for High Latency.", _, true, 0.0)),						OnLatencyThreasholdChange);
	g_iLatencyThreashold = GetConVarInt(hRandom);
	HookConVarChange((hRandom = CreateConVar("nt_liammethod",			"0",	"Are we using Liam's method from HPK-Lite for getting client latency?", _, true, 0.0, true, 1.0)),	OnLiamMethodChange);
	g_bLiamMethod = GetConVarBool(hRandom);
	
	HookConVarChange((hRandom = CreateConVar("nt_loss_enable",			"1",	"Should this plugin be checking Clients for Loss?", _, true, 0.0, true, 1.0)),						OnLossEnableChange);
	g_bLossEnabled = GetConVarBool(hRandom);
	HookConVarChange((hRandom = CreateConVar("nt_loss_addition",		"15",	"How high should I be increasing the Loss Kick value?", _, true, 0.0)),								OnLossAdditionChange);
	g_iLossAddition = GetConVarInt(hRandom);
	HookConVarChange((hRandom = CreateConVar("nt_loss_threashold",		"6",	"How many checks until a client is kicked for High Loss.", _, true, 0.0)),							OnLossThreasholdChange);
	g_iLossThreashold = GetConVarInt(hRandom);
	
	RegAdminCmd("nt_display",		DisplayInformation,	ADMFLAG_RESERVATION,	"Display stored client information.");
	RegAdminCmd("nt_toggle",		ToggleImmune,		ADMFLAG_ROOT,			"Toggles whether or not this plugin is active on a specific client.");
	
	AutoExecConfig(true, "networktools");

	if((hRandom = FindConVar("sv_mincmdrate")) != INVALID_HANDLE)
	{
		g_iCmdRate[0] = GetConVarInt(hRandom);
		HookConVarChange(hRandom, OnMinCmdRateChange);
	}
	else
	{
		LogError("Warning. Missing sv_mincmdrate.");
	}

	if((hRandom = FindConVar("sv_maxcmdrate")) != INVALID_HANDLE)
	{
		g_iCmdRate[1] = GetConVarInt(hRandom);
		HookConVarChange(hRandom, OnMaxCmdRateChange);
	}
	else
	{
		LogError("Warning. Missing sv_maxcmdrate.");
	}
	
	CloseHandle(hRandom); // I HATE Handles.
	
	BuildPath(Path_SM, g_sBasePath, sizeof(g_sBasePath), "");
}

public void OnConfigsExecuted()
{
	if(g_bEnabled)
	{
		g_hTimerHandle = CreateTimer(float(g_iCheckRate), RefreshData, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void OnClientPostAdminCheck(int client)
{
	if((g_bValidClient[client][0] = !IsFakeClient(client)))
	{
		g_bValidClient[client][1] = !CheckCommandAccess(client, "nt_display", ADMFLAG_RESERVATION);
	}
}

public void OnClientDisconnect(int client)
{
	if(g_bValidClient[client][0])
	{
		g_iClientChoke[client][1] = 0;
		g_iClientLatency[client][1] = 0;
		g_iClientLoss[client][1] = 0;
		g_bValidClient[client][0] = false;
	}
}

public void OnMapEnd()
{
	g_hTimerHandle = INVALID_HANDLE;
}

/* Commands */
public Action DisplayInformation(int client, int args)
{
	if(args < 1) { 
		ReplyToCommand(client, "%s\nPlugin Enabled: \x04%i\x03\nPlugin Kicking: \x04%i\x03\nMin Player Count: \x04%i\x03\nKick Vocalization: \x04%i\x03\nLogging Enabled: \x04%i\x03\nFile Logging Format: \x04%s\x03\nInternal File Logging Format: \x04%s\x03", defPluginPrefix, g_bEnabled, PlayerCountIsCorrect(), g_iMinPCount, g_bKickVocalize, g_bLoggingEnabled, g_sLogTimeString[0], g_sLogTimeString[1]);
		ReplyToCommand(client, "\x03Choke Enabled: \x04%i\x03\nChoke Limit: \x04%i\x03\nChoke Slide: \x04%i\x03\nLatency Enabled: \x04%i\x03\nLatency Limit: \x04%i\x03\nLatency Slide: \x04%i\x03\nLoss Enabled: \x04%i\x03\nLoss Limit: \x04%i\x03\nLoss Slide: \x04%i\x03", g_bChokeEnabled, g_iLimit[0], g_iChokeAddition, g_bLatencyEnabled, g_iLimit[1], g_iLatencyAddition, g_bLossEnabled, g_iLimit[2], g_iLossAddition);
		return Plugin_Handled;
	}
	
	char Arg[128];
	char sClientChecking[4];
	GetCmdArgString(Arg, sizeof(Arg));
	
	int iTarget_list[MAXPLAYERS+1];
	char iTarget_name[MAXPLAYERS+1];
	bool iTarget_ml;
	int ListSize = ProcessTargetString(Arg, client, iTarget_list, MAXPLAYERS, COMMAND_FILTER_NO_BOTS, iTarget_name, sizeof(iTarget_name), iTarget_ml);
	if (ListSize > 0)
	{
		int iTarget;
		ReplyToCommand(client, "%s", defPluginPrefix);
		for (int i = 0; i < ListSize; i++)
		{
			iTarget = iTarget_list[i];
			switch(g_bValidClient[iTarget][1])
			{
				case false:
				{
					if(sClientChecking[0] != 'N' || sClientChecking[2] != '\0')
					{
						strcopy(sClientChecking, sizeof(sClientChecking), "No");
					}
				}

				case true:
				{
					if(sClientChecking[0] != 'Y' || sClientChecking[3] != '\0')
					{
						strcopy(sClientChecking, sizeof(sClientChecking), "Yes");
					}
				}
			}
			ReplyToCommand(client, "\x03Name: \x04%N\x03\nReported Choke: (\x04%i\x03|\x04%i\x03/\x04%i\x03).\nReported Latency: (\x04%i\x03|\x04%i\x03/\x04%i\x03).\nReported Loss: (\x04%i\x03|\x04%i\x03/\x04%i\x03).\nChecking Enabled on Client: \x04%s\x03.", iTarget, g_iClientChoke[iTarget][0], g_iClientChoke[iTarget][1], g_iChokeThreashold, g_iClientLatency[iTarget][0], g_iClientLatency[iTarget][1], g_iLatencyThreashold, g_iClientLoss[iTarget][0], g_iClientLoss[iTarget][1], g_iLossThreashold, sClientChecking);
		}
		return Plugin_Handled;
	}
	ReplyToCommand(client, "%s Could not find %s.", defPluginPrefix, Arg);
	return Plugin_Handled;
}

public Action ToggleImmune(int client, int args)
{
	if(args < 1)
	{
		ReplyToCommand(client, "%s nt_toggle [client|#userid]", defPluginPrefix);
		return Plugin_Handled;
	}

	char ArgString[128];
	GetCmdArgString(ArgString, sizeof(ArgString));

	int  iTarget_list[MAXPLAYERS+1]; 
	char iTarget_name[MAXPLAYERS+1];
	bool iTarget_ml;
	int ListSize = ProcessTargetString(ArgString, client, iTarget_list, MAXPLAYERS, COMMAND_FILTER_NO_BOTS, iTarget_name, sizeof(iTarget_name), iTarget_ml);
	if (ListSize > 0)
	{
		int iTarget;
		ReplyToCommand(client, "%s", defPluginPrefix);
		for (int i = 0; i < ListSize; i++)
		{
			iTarget = iTarget_list[i];
			switch(g_bValidClient[iTarget][1])
			{
				case false:
				{
					g_bValidClient[iTarget][1] = true;
					ReplyToCommand(client, "\x04%N\x03 will now be checked by this plugin.", iTarget);
				}

				case true:
				{
					g_bValidClient[iTarget][1] = false;
					ReplyToCommand(client, "\x04%N\x03 will no longer be checked by this plugin.", iTarget);
				}
			}
		}
	}
	return Plugin_Handled;
}

/* Main Work Horse */
public Action RefreshData(Handle Timer)
{
	if(g_bEnabled && PlayerCountIsCorrect())
	{
		GetData();
		ProcessData();
	}
	return Plugin_Handled;
}

public void ProcessData()
{
	int iMaxChoke = g_iLimit[0];
	int iMaxLatency = g_iLimit[1];
	int iMaxLoss = g_iLimit[2];
	bool bWarned;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(g_bValidClient[i][0] && g_bValidClient[i][1])
		{
			if(g_bChokeEnabled)
			{
				if(g_iClientChoke[i][0] < iMaxChoke)
				{
					g_iClientChoke[i][1] = 0;
				}
				else
				{
					if(g_iClientChoke[i][1]++ == g_iChokeThreashold)
					{
						if(g_bKickVocalize)
						{
							PrintToChatAll("%s Kicking %N for High Choke", defPluginPrefix, i);
						}
						LogKick(i, 0);
						KickClient(i, "High Choke.");
						continue;
					}

					if(g_bWarningVocalize && !bWarned)
					{
						PrintToChat(i, "%s Warning, you've failed check \x04%i\x03 for Choke.\nYou have \x04%i\x03 left until you're kicked.", defPluginPrefix, g_iClientChoke[i][1], g_iChokeThreashold - g_iClientChoke[i][1]);
						bWarned = true;
					}
				}
			}

			if(g_bLatencyEnabled)
			{
				if(g_iClientLatency[i][0] < iMaxLatency)
				{
					if(g_iClientLatency[i][1])
					{
						g_iClientLatency[i][1] = 0;
					}
				}
				else
				{
					if(g_iClientLatency[i][1]++ == g_iLatencyThreashold)
					{
						if(g_bKickVocalize)
						{
							PrintToChatAll("%s Kicking %N for High Latency.", defPluginPrefix, i);
						}
						LogKick(i, 1);
						KickClient(i, "High Latency.");
						continue;
					}

					if(g_bWarningVocalize && !bWarned)
					{
						PrintToChat(i, "%s Warning, you've failed check \x04%i\x03 for Latency.\nYou have \x04%i\x03 left until you're kicked.", defPluginPrefix, g_iClientLatency[i][1], g_iLatencyThreashold - g_iClientLatency[i][1]);
						bWarned = true;
					}
				}
			}

			if(g_bLossEnabled)
			{
				if(g_iClientLoss[i][0] < iMaxLoss)
				{
					if(g_iClientLoss[i][1])
					{
						g_iClientLoss[i][1] = 0;
					}
				}
				else
				{
					if(g_iClientLoss[i][1]++ == g_iLossThreashold)
					{
						if(g_bKickVocalize)
						{
							PrintToChatAll("%s Kicking %N for High Loss.", defPluginPrefix, i);
						}
						LogKick(i, 2);
						KickClient(i, "High Loss.");
						continue;
					}

					if(g_bWarningVocalize && !bWarned)
					{
						PrintToChat(i, "%s Warning, you've failed check \x04%i\x03 for Packet Loss.\nYou have \x04%i\x03 left until you're kicked.", defPluginPrefix, g_iClientLoss[i][1], g_iLossThreashold - g_iClientLoss[i][1]);
					}
				}
			}

			if(bWarned)
			{
				bWarned = false;
			}
		}
	}
}

public void GetData()
{
	int CmdRate;
	int RandomVariable;
	int MinCmdRate = g_iCmdRate[0];
	int MaxCmdRate = g_iCmdRate[1];
	int iTickRate;

	for(int i; i < 3; i++)
	{
		g_iLimit[i] = 999;
	}


	char sCmdClientInfo[4];
	if(g_bLiamMethod)
	{
		iTickRate = RoundToNearest(GetTickInterval());
	}

	for(int i = 1; i <= MaxClients; i++)
	{
		if(g_bValidClient[i][0])
		{
			if(-1 < (g_iClientChoke[i][0] = RoundFloat(GetClientAvgChoke(i, NetFlow_Outgoing) * 100.0)) < g_iLimit[0])
			{
				g_iLimit[0] = g_iClientChoke[i][0];
			}

			switch(g_bLiamMethod)
			{
				case false:
				{
					if(-1 < (g_iClientLatency[i][0] = RoundFloat(GetClientAvgLatency(i, NetFlow_Outgoing) * 1000.0)) < g_iLimit[1])
					{
						g_iLimit[1] = g_iClientLatency[i][0];
					}
				}

				case true: // Liam Method - No idea if it's actually better or not, obviously slower.
				{
					if(GetClientInfo(i, "cl_cmdrate", sCmdClientInfo, sizeof(sCmdClientInfo)) && (CmdRate = StringToInt(sCmdClientInfo)))
					{
						/* Ensuring nothing messes up since clients do not respect Max/Min values */
						if(CmdRate > MaxCmdRate)
						{
							CmdRate = MaxCmdRate;
						}
						else if(CmdRate < MinCmdRate)
						{
							CmdRate = MinCmdRate;
						}

						RandomVariable = RoundFloat(GetClientAvgLatency(i, NetFlow_Outgoing));
						RandomVariable -= ((0.5 / CrazyLiamBitWise(CmdRate, 20)) + iTickRate);
						RandomVariable -= (iTickRate * 0.5);

						if(-1 < (g_iClientLatency[i][0] = RandomVariable *= 1000) < g_iLimit[1])
						{
							g_iLimit[1] = RandomVariable;
						}
					}
					else
					{
						if(-1 < (g_iClientLatency[i][0] = RoundFloat(GetClientAvgLatency(i, NetFlow_Outgoing) * 1000.0)) < g_iLimit[1]) // Fallback.
						{
							g_iLimit[1] = g_iClientLatency[i][0];
						}
					}
				}
			}

			if(-1 < (g_iClientLoss[i][0] = RoundFloat(GetClientAvgLoss(i, NetFlow_Outgoing) * 100.0)) < g_iLimit[2])
			{
				g_iLimit[2] = g_iClientLoss[i][0];
			}
		}
	}

	g_iLimit[0] += g_iChokeAddition;
	g_iLimit[1] += g_iLatencyAddition;
	g_iLimit[2] += g_iLossAddition;
}

/* Fun Stocks that shouldn't be messed with */
stock bool PlayerCountIsCorrect()
{
	int k;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(g_bValidClient[i][0])
		{
			if(k++ >= g_iMinPCount)
			{
				return true;
			}
		}
	}

	return false;
}

stock void LogKick(int client, int KickVal)
{
	if(!g_bLoggingEnabled)
	{
		return;
	}

	if(g_sLogTimeString[0][0] == '\0')
	{
		LogError("nt_logformatext cannot be blank. Falling back to defaults.");
		strcopy(g_sLogTimeString[0][0], sizeof(g_sLogTimeString[]), "%Y_%m_%d");
	}

	if(g_sLogTimeString[1][0] == '\0')
	{
		LogError("nt_logformatint cannot be blank. Falling back to defaults.");
		strcopy(g_sLogTimeString[1][0], sizeof(g_sLogTimeString[]), "%x");
	}

	char sFormattedTime[2][512];
	FormatTime(sFormattedTime[0], sizeof(sFormattedTime[]), g_sLogTimeString[0]);
	FormatTime(sFormattedTime[1], sizeof(sFormattedTime[]), g_sLogTimeString[1]);
	Format(sFormattedTime[0], sizeof(sFormattedTime[]), "%slogs/NetworkTools.%s.log", g_sBasePath, sFormattedTime[0]);
	switch(KickVal)
	{
		case 0:
		{
			LogToFile(sFormattedTime[0], "%s: Kicked %N for High Choke (%i/%i).", sFormattedTime[1], client, g_iClientChoke[client][0], g_iLimit[0]);
		}

		case 1:
		{
			LogToFile(sFormattedTime[0], "%s: Kicked %N for High Latency (%i/%i).", sFormattedTime[1], client, g_iClientLatency[client][0], g_iLimit[1]);
		}

		case 2:
		{
			LogToFile(sFormattedTime[0], "%s: Kicked %N for High Loss (%i/%i).", sFormattedTime[1], client, g_iClientLoss[client][0], g_iLimit[2]);
		}
	}
}

/* ConVar Changes */
public void OnEnabledChange(Handle convar, const char[] oldValue, const char[] newValue)
{
	switch(GetConVarBool(convar))
	{
		case false:
		{
			g_bEnabled = false;
			if(g_hTimerHandle != INVALID_HANDLE)
			{
				KillTimer(g_hTimerHandle);
				g_hTimerHandle = INVALID_HANDLE;
			}
		}

		case true:
		{
			g_bEnabled = true;
			if(g_hTimerHandle != INVALID_HANDLE)
			{
				KillTimer(g_hTimerHandle);
			}
			g_hTimerHandle = CreateTimer(float(g_iCheckRate), RefreshData, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public void OnChokeAdditionChange(Handle convar, const char []oldValue, const char[] newValue)
{
	g_iChokeAddition = GetConVarInt(convar);
}

public void OnLatencyAdditionChange(Handle convar, const char []oldValue, const char[] newValue)
{
	g_iLatencyAddition = GetConVarInt(convar);
}

public void OnLossAdditionChange(Handle convar, const char []oldValue, const char[] newValue)
{
	g_iLossAddition = GetConVarInt(convar);
}

public void OnChokeThreasholdChange(Handle convar, const char []oldValue, const char[] newValue)
{
	g_iChokeThreashold = GetConVarInt(convar);
}

public void OnLatencyThreasholdChange(Handle convar, const char []oldValue, const char[] newValue)
{
	g_iLatencyThreashold = GetConVarInt(convar);
}

public void OnLossThreasholdChange(Handle convar, const char []oldValue, const char[] newValue)
{
	g_iLossThreashold = GetConVarInt(convar);
}

public void OnMinPlayChange(Handle convar, const char []oldValue, const char[] newValue)
{
	g_iMinPCount = GetConVarInt(convar);
}

public void OnLoggingChange(Handle convar, const char []oldValue, const char[] newValue)
{
	g_bLoggingEnabled = GetConVarBool(convar);
}

public void OnExtLogFormatChange(Handle convar, const char []oldValue, const char[] newValue)
{
	GetConVarString(convar, g_sLogTimeString[0], sizeof(g_sLogTimeString[]));
}

public void OnIntLogFormatChange(Handle convar, const char []oldValue, const char[] newValue)
{
	GetConVarString(convar, g_sLogTimeString[1], sizeof(g_sLogTimeString[]));
}

public void OnCheckRateChange(Handle convar, const char []oldValue, const char[] newValue)
{
	g_iCheckRate = GetConVarInt(convar);
	switch(g_bEnabled)
	{
		case false:
		{
			if(g_hTimerHandle != INVALID_HANDLE)
			{
				KillTimer(g_hTimerHandle);
				g_hTimerHandle = INVALID_HANDLE;
			}
		}

		case true:
		{
			if(g_hTimerHandle != INVALID_HANDLE)
			{
				KillTimer(g_hTimerHandle);
			}
			g_hTimerHandle = CreateTimer(float(g_iCheckRate), RefreshData, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public void OnKickMessageChange(Handle convar, const char []oldValue, const char[] newValue)
{
	g_bKickVocalize = GetConVarBool(convar);
}

public void OnWarningMessageChange(Handle convar, const char []oldValue, const char[] newValue)
{
	g_bWarningVocalize = GetConVarBool(convar);
}

public void OnChokeEnableChange(Handle convar, const char []oldValue, const char[] newValue)
{
	g_bChokeEnabled = GetConVarBool(convar);
}

public void OnLatencyEnableChange(Handle convar, const char []oldValue, const char[] newValue)
{
	g_bLatencyEnabled = GetConVarBool(convar);
}

public void OnLossEnableChange(Handle convar, const char []oldValue, const char[] newValue)
{
	g_bLossEnabled = GetConVarBool(convar);
}

public void OnLiamMethodChange(Handle convar, const char []oldValue, const char[] newValue)
{
	g_bLiamMethod = GetConVarBool(convar);
}

/* Valve ConVar Changes */

public void OnMinCmdRateChange(Handle convar, const char []oldValue, const char[] newValue)
{
	g_iCmdRate[0] = GetConVarInt(convar);
}

public void OnMaxCmdRateChange(Handle convar, const char []oldValue, const char[] newValue)
{
	g_iCmdRate[1] = GetConVarInt(convar);
}
