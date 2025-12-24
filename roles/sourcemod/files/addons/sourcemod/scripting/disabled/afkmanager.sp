#include <sourcemod>
#include <sdktools>
#include <tf2>

#pragma semicolon 1
#pragma newdecls required

// Observer Modes
#define OBS_MODE_NONE 		0
#define	OBS_MODE_DEATHCAM 	1
#define OBS_MODE_FREEZECAM	2
/*
OBS_MODE_FIXED = 3
OBS_MODE_IN_EYE = 4
OBS_MODE_CHASE = 5
OBS_MODE_POI = 6
*/
int	OBS_MODE_ROAMING =		6;

/**
 * Specifies AFK immunity types.
 */
enum AFKImmunity:
{
	AFKImmunity_None = 0,
	AFKImmunity_Move = 1,
	AFKImmunity_Kick = 2,
	AFKImmunity_Full = 3,
};


// Arena Check Code from controlpoints.inc made by Powerlord
enum
{
	TF2GameType_Unknown,
	TF2GameType_CTF,
	TF2GameType_CP,
	TF2GameType_PL,
	TF2GameType_Arena,
}


enum TF2GameMode:
{
	TF2GameMode_Unknown,		/**< Unknown type, unknown mode */
	TF2GameMode_CTF,			/**< General CTF */
	TF2GameMode_CP_AD,			/**< Attack/Defense Control Points */
	TF2GameMode_CP_Symmetric,	/**< 5CP or unknown Control Points */
	TF2GameMode_TC,				/**< Territory Control CP */
	TF2GameMode_PL,				/**< General Payload */
	TF2GameMode_Arena,			/**< Arena */
	TF2GameMode_ItemTest,		/**< Unknown type, Item Test mode */
	TF2GameMode_Koth,			/**< KOTH Control Points */
	TF2GameMode_HybridCTFCP,	/**< Hybrid CTF/CP mode */
	TF2GameMode_PLR,			/**< Payload Race, 2 team payload */
	TF2GameMode_Training,		/**< Unknown type, training mode */
	TF2GameMode_SD,				/**< CTF, Special Delivery */
	TF2GameMode_MvM,			/**< CTF, Mann Vs. Machine */
	TF2GameMode_RD,				/**< CTF, Robot Destruction */
}


stock TF2GameMode TF2_DetectGameMode()
{
	int gameType = GameRules_GetProp("m_nGameType");

	switch (gameType)
	{
		case TF2GameType_Arena:
			return TF2GameMode_Arena;
	}
	return TF2GameMode_Unknown;
}

// Defines
#if defined _updater_included
#define UPDATE_URL										"http://afkmanager.dawgclan.net/afkmanager4.txt"
#endif

#define AFKM_VERSION									"4.3.1"

// TO DO:
// Fix WFP Events
// Add Sound?
// Add AFK Menu?
// Check ND Support?

#define AFK_WARNING_INTERVAL							5
#define AFK_CHECK_INTERVAL								1.0

// Change this to enable debug
#define _DEBUG 											0 // 1 = Minimum Debug 3 = Full Debug
#define _DEBUG_MODE										1 // 1 = Log to File, 2 = Log to Game Logs, 3 = Print to Chat, 4 = Print to Console

#if !defined MAX_MESSAGE_LENGTH
	#define MAX_MESSAGE_LENGTH							250
#endif

#define SECONDS_IN_DAY									86400

#define LOG_FOLDER										"logs"
#define LOG_PREFIX										"afkm_"
#define LOG_EXT											"log"

// ConVar Defines
#define CONVAR_VERSION									0
#define CONVAR_ENABLED									1
#define CONVAR_MOD_AFK									2
#define CONVAR_PREFIXSHORT								3
#define CONVAR_PREFIXCOLORS								4
#define CONVAR_LANGUAGE									5
#define CONVAR_LOG_WARNINGS								6
#define CONVAR_MINPLAYERSMOVE							7
#define CONVAR_MINPLAYERSKICK							8
#define CONVAR_ADMINS_IMMUNE							9
#define CONVAR_TIMETOMOVE								10
#define CONVAR_TIMETOKICK								11
#define CONVAR_EXCLUDEDEAD								12
#define CONVAR_TF2_ARENAMODE							13
#define CONVAR_BUTTONSBUFFER							14
#define CONVAR_ARRAY_SIZE								15

// Arrays
char AFKM_LogFile[PLATFORM_MAX_PATH];					// Log File
//Handle g_FWD_hPlugins =								INVALID_HANDLE; // Forward Plugin Handles
int g_iPlayerUserID[MAXPLAYERS+1] =						{-1, ...}; // Player User ID
Handle g_hAFKTimer[MAXPLAYERS+1] =						{INVALID_HANDLE, ...}; // AFK Timers
int g_iAFKTime[MAXPLAYERS+1] =							{-1, ...}; // Initial Time of AFK
int g_iSpawnTime[MAXPLAYERS+1] =						{-1, ...}; // Time of Spawn
int g_iPlayerTeam[MAXPLAYERS+1] =						{-1, ...}; // Player Team
int iPlayerAttacker[MAXPLAYERS+1] =						{-1, ...}; // Player Attacker
int iObserverMode[MAXPLAYERS+1] =						{-1, ...}; // Observer Mode
int iObserverTarget[MAXPLAYERS+1] =						{-1, ...}; // Observer Target
AFKImmunity g_iPlayerImmunity[MAXPLAYERS+1] =			{AFKImmunity_None, ...}; // Player Immunity
//int iMouse[MAXPLAYERS+1[2];							// X = Verital, Y = Horizontal
bool bPlayerAFK[MAXPLAYERS+1] =							{true, ...}; // Player AFK Status
bool bPlayerDeath[MAXPLAYERS+1] =						{false, ...};
//float fEyeAngles[MAXPLAYERS+1][3];					// X = Vertical, Y = Height, Z = Horizontal
int g_iMapEndTime =										-1;

#define BUTTONS_MAX_ARRAY								30
int iButtonsArrayIndex[MAXPLAYERS+1] =					{0, ...}; // Button Array Index
int iButtonsArray[MAXPLAYERS+1][BUTTONS_MAX_ARRAY];		// Array of client bitsum of buttons pressed


bool bCvarIsHooked[CONVAR_ARRAY_SIZE] =					{false, ...}; // Console Variable Hook Status

// Global Variables
bool g_bLateLoad = 										false;
// Console Related Variables
bool g_bEnabled =										false;
char g_sPrefix[] =										"AFK Manager";
#if defined _colors_included
bool g_bPrefixColors =									false;
#endif
bool g_bForceLanguage =									false;
bool g_bLogWarnings =									false;
bool g_bExcludeDead =									false;
bool g_bTF2Arena =										false;
int g_iAdminsImmunue =									-1;
int g_iTimeToMove =										-1;
int g_iTimeToKick =										-1;
int g_iButtonsArraySize =								-1;

// Status Variables
bool bMovePlayers =										true;
bool bKickPlayers =										true;
bool g_bWaitRound =										true;

// Spectator Related Variables
int g_iSpec_Team =										1;

// Mod Detection Variables
bool Synergy =											false;
bool TF2 =												false;
bool CSTRIKE =											false;
bool CSGO =												false;
bool GESOURCE =											false;

// Mod Based Console Variables
ConVar hCvarAFK =										null;
ConVar hCvarTF2Arena =									null;

// Handles
// Forwards
Handle g_FWD_hOnInitializePlayer =						INVALID_HANDLE;
Handle g_FWD_hOnAFKEvent =								INVALID_HANDLE;
Handle g_FWD_hOnClientAFK =								INVALID_HANDLE;
Handle g_FWD_hOnClientBack =							INVALID_HANDLE;

// AFK Manager Console Variables
ConVar hCvarVersion =									null;
ConVar hCvarEnabled =									null;
ConVar hCvarAutoUpdate =								null;
ConVar hCvarPrefixShort =								null;
#if defined _colors_included
ConVar hCvarPrefixColor =								null;
#endif
ConVar hCvarLanguage =									null;
ConVar hCvarLogWarnings =								null;
ConVar hCvarLogMoves =									null;
ConVar hCvarLogKicks =									null;
ConVar hCvarLogDays =									null;
ConVar hCvarMinPlayersMove =							null;
ConVar hCvarMinPlayersKick =							null;
ConVar hCvarAdminsImmune =								null;
ConVar hCvarAdminsFlag =								null;
ConVar hCvarMoveSpec =									null;
ConVar hCvarMoveAnnounce =								null;
ConVar hCvarTimeToMove =								null;
ConVar hCvarWarnTimeToMove =							null;
ConVar hCvarKickPlayers =								null;
ConVar hCvarKickAnnounce =								null;
ConVar hCvarTimeToKick =								null;
ConVar hCvarWarnTimeToKick =							null;
ConVar hCvarSpawnTime =									null;
ConVar hCvarWarnSpawnTime =								null;
ConVar hCvarExcludeDead =								null;
ConVar hCvarWarnUnassigned =							null;
ConVar hCvarButtonsBuffer =								null;
#if _DEBUG
ConVar hCvarLogDebug =									null;
#endif

// Plugin Information
public Plugin myinfo =
{
    name = "AFK Manager",
    author = "Rothgar",
    description = "Takes action on AFK players",
    version = AFKM_VERSION,
    url = "http://www.dawgclan.net"
};

// API
void API_Init()
{
	//CreateNative("AFKM_AddPlugin", Native_AddPlugin);
	//CreateNative("AFKM_RemovePlugin", Native_RemovePlugin);
	CreateNative("AFKM_SetClientImmunity", Native_SetClientImmunity);
	CreateNative("AFKM_GetSpectatorTeam", Native_GetSpectatorTeam);
	CreateNative("AFKM_IsClientAFK", Native_IsClientAFK);
	CreateNative("AFKM_GetClientAFKTime", Native_GetClientAFKTime);
	//g_FWD_hOnAFKEvent = CreateForward(ET_Event, Param_String, Param_Cell);
	g_FWD_hOnInitializePlayer = CreateGlobalForward("AFKM_OnInitializePlayer", ET_Event, Param_Cell);
	g_FWD_hOnAFKEvent = CreateGlobalForward("AFKM_OnAFKEvent", ET_Event, Param_String, Param_Cell);
	g_FWD_hOnClientAFK = CreateGlobalForward("AFKM_OnClientAFK", ET_Ignore, Param_Cell);
	g_FWD_hOnClientBack = CreateGlobalForward("AFKM_OnClientBack", ET_Ignore, Param_Cell);
}

// Natives
/*
public int Native_AddPlugin(Handle plugin, int numParams) // native void AFKM_AddPlugin();
{
	AddPlugin(plugin);
}

public int Native_RemovePlugin(Handle plugin, int numParams) // native void AFKM_RemovePlugin();
{
	RemovePlugin(plugin);
}
*/

public int Native_SetClientImmunity(Handle plugin, int numParams) // native void AFKM_SetClientImmunity(int client, AFKImmunity type);
{
	int iClient = GetNativeCell(1);
	AFKImmunity iImmunityType = GetNativeCell(2);

	if (iClient < 1 || iClient > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", iClient);
	else if (iImmunityType < AFKImmunity_None || iImmunityType > AFKImmunity_Full)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid Immunity Type (%d)", iImmunityType);
	else
	{
		SetPlayerImmunity(iClient, view_as<int>(iImmunityType), true);

		if (g_bLogWarnings)
		{
			char Plugin_Name[255];
			if (GetPluginInfo(plugin, PlInfo_Name, Plugin_Name, sizeof(Plugin_Name)))
			{
				LogToFile(AFKM_LogFile, "AFK Manager Native: AFKM_SetClientImmunity has set client: %i immunity type to: %i by external plugin: %s", iClient, view_as<int>(iImmunityType), Plugin_Name);
			}
		}
	}
	return true;
}

public int Native_GetSpectatorTeam(Handle plugin, int numParams) // native int AFKM_GetSpectatorTeam();
{
	return g_iSpec_Team;
}

public int Native_IsClientAFK(Handle plugin, int numParams) // native bool AFKM_IsClientAFK(int client);
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
	else
		return bPlayerAFK[client];
}

public int Native_GetClientAFKTime(Handle plugin, int numParams) // native int AFKM_GetClientAFKTime(int client);
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
	else if (g_iAFKTime[client] == -1)
		return g_iAFKTime[client];
	else
		return (GetTime() - g_iAFKTime[client]);
}

// Forwards
Action Forward_OnInitializePlayer(int client) // forward Action AFKM_OnInitializePlayer(int client);
{
	Action result;

	Call_StartForward(g_FWD_hOnInitializePlayer); // Start Forward
	Call_PushCell(client);
	Call_Finish(result);

	return result;
}

void Forward_OnClientAFK(int client) // forward void AFKM_OnClientAFK(int client);
{
	Call_StartForward(g_FWD_hOnClientAFK); // Start Forward
	Call_PushCell(client);
	Call_Finish();
}

void Forward_OnClientBack(int client) // forward void AFKM_OnClientBack(int client);
{
	Call_StartForward(g_FWD_hOnClientBack); // Start Forward
	Call_PushCell(client);
	Call_Finish();
}

/*
Action Forward_Event(const char[] name, int client) // Internal Function to Loop Forward_OnAFKEvent()
{
	Action result = Plugin_Continue;

	int maxPlugins = GetMaxPlugins();
	for (int i = 0; i < maxPlugins; i++)
	{
		result = Forward_OnAFKEvent(g_FWD_hPlugins[i], name, client);
		if (result != Plugin_Continue)
		{
			char Action_Name[64];
			switch (result)
			{
				case Plugin_Continue:
					Action_Name = "Plugin_Continue";
				case Plugin_Changed:
					Action_Name = "Plugin_Changed";
				case Plugin_Handled:
					Action_Name = "Plugin_Handled";
				case Plugin_Stop:
					Action_Name = "Plugin_Stop";
				default:
					Action_Name = "Plugin_Error";
			}
			char Plugin_Name[256],
			GetPluginInfo(g_FWD_hPlugins[i], PlInfo_Name, Plugin_Name, sizeof(Plugin_Name));
			LogToFile(AFKM_LogFile, "AFK Manager Event: %s has been requested to: %s by Plugin: %s this action will affect the plugin/event outcome.", name, Action_Name, Plugin_Name);
			return result;
		}
	}

	return Plugin_Continue;
}

Action Forward_OnAFKEvent(Handle plugin, const char[] name, int client) // forward Action AFKM_OnAFKEvent(const char[] name, int client);
{
	Action result = Plugin_Continue;
	Function func = GetFunctionByName(plugin, "AFKM_OnAFKEvent");

	if (func != INVALID_FUNCTION)
	{
		if (AddToForward(g_FWD_hOnAFKEvent, plugin, func))
		{
			Call_StartForward(g_FWD_hOnAFKEvent); // Start Forward
			Call_PushString(name);
			Call_PushCell(client);
			Call_Finish(result);
			RemoveAllFromForward(g_FWD_hOnAFKEvent, plugin);
		}
	} else
		RemovePlugin(plugin); // Function is Invalid Remove Plugin

	return result;
}
*/

Action Forward_OnAFKEvent(const char[] name, int client) // forward Action AFKM_OnAFKEvent(const char[] name, int client);
{
	Action result;

	Call_StartForward(g_FWD_hOnAFKEvent); // Start Forward
	Call_PushString(name);
	Call_PushCell(client);
	Call_Finish(result);

	return result;
}


// Log Functions
void BuildLogFilePath() // Build Log File System Path
{
	char sLogPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sLogPath, sizeof(sLogPath), LOG_FOLDER);

	if ( !DirExists(sLogPath) ) // Check if SourceMod Log Folder Exists Otherwise Create One
		CreateDirectory(sLogPath, 511);

	char cTime[64];
	FormatTime(cTime, sizeof(cTime), "%Y%m%d");

	char sLogFile[PLATFORM_MAX_PATH];
	sLogFile = AFKM_LogFile;

	BuildPath(Path_SM, AFKM_LogFile, sizeof(AFKM_LogFile), "%s/%s%s.%s", LOG_FOLDER, LOG_PREFIX, cTime, LOG_EXT);

#if _DEBUG
	LogDebug(false, "BuildLogFilePath - AFK Log Path: %s", AFKM_LogFile);
#endif

	if (!StrEqual(AFKM_LogFile, sLogFile))
		LogAction(0, -1, "[AFK Manager] Log File: %s", AFKM_LogFile);
}

void PurgeOldLogs() // Purge Old Log Files
{
#if _DEBUG
	LogDebug(false, "PurgeOldLogs - Purging Old Log Files");
#endif
	char sLogPath[PLATFORM_MAX_PATH];
	char buffer[256];
	Handle hDirectory = INVALID_HANDLE;
	FileType type = FileType_Unknown;

	BuildPath(Path_SM, sLogPath, sizeof(sLogPath), LOG_FOLDER);

#if _DEBUG
	LogDebug(false, "PurgeOldLogs - Purging Old Log Files from: %s", sLogPath);
#endif
	if ( DirExists(sLogPath) )
	{
		hDirectory = OpenDirectory(sLogPath);
		if (hDirectory != INVALID_HANDLE)
		{
			int iTimeOffset = GetTime() - ((SECONDS_IN_DAY * GetConVarInt(hCvarLogDays)) + 30);
			while ( ReadDirEntry(hDirectory, buffer, sizeof(buffer), type) )
			{
				if (type == FileType_File)
				{
					if (StrContains(buffer, LOG_PREFIX, false) != -1)
					{
						char file[PLATFORM_MAX_PATH];
						Format(file, sizeof(file), "%s/%s", sLogPath, buffer);
#if _DEBUG
						LogDebug(false, "PurgeOldLogs - Checking file: %s", buffer);
#endif
						if ( GetFileTime(file, FileTime_LastChange) < iTimeOffset ) // Log file is old
							if (DeleteFile(file))
								LogAction(0, -1, "[AFK Manager] Deleted Old Log File: %s", file);
					}
				}
			}
		}
	}

	if (hDirectory != INVALID_HANDLE)
	{
		CloseHandle(hDirectory);
		hDirectory = INVALID_HANDLE;
	}
}

// Chat Functions
void AFK_PrintToChat(int client, const char[] sMessage, any ...)
{
	int iStart = client;
	int iEnd = MaxClients;

	if (client > 0)
		iEnd = client;
	else
		iStart = 1;

	char sBuffer[MAX_MESSAGE_LENGTH];

	for (int i = iStart; i <= iEnd; i++)
	{
		if (IsClientInGame(i))
		{
			if (g_bForceLanguage)
				SetGlobalTransTarget(LANG_SERVER);
			else
				SetGlobalTransTarget(i);
			VFormat(sBuffer, sizeof(sBuffer), sMessage, 3);
#if defined _colors_included
			if (g_bPrefixColors)
				CPrintToChat(i, "{olive}[{green}%s{olive}] {default}%s", g_sPrefix, sBuffer);
			else
				PrintToChat(i, "[%s] %s", g_sPrefix, sBuffer);
#else
			PrintToChat(i, "[%s] %s", g_sPrefix, sBuffer);
#endif
		}
	}
}

// Debug Functions
#if _DEBUG
void LogDebug(bool Translation, char[] text, any ...) // Debug Log Function
{
	if (hCvarLogDebug != INVALID_HANDLE)
		if (!GetConVarBool(hCvarLogDebug))
			return;

	char message[255];
	if (Translation)
		VFormat(message, sizeof(message), "%T", 2);
	else
		if (strlen(text) > 0)
			VFormat(message, sizeof(message), text, 3);
		else
			return;

#if _DEBUG_MODE == 1
	LogToFile(AFKM_LogFile, "%s", message);
#elseif _DEBUG_MODE == 2
	LogToGame("[AFK Manager] %s", message);
#elseif _DEBUG_MODE == 3
	PrintToChatAll("[AFK Manager] %s", message);
#elseif _DEBUG_MODE == 4
	for (int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i) && IsClientConnected(i) && !IsClientSourceTV(i) && !IsFakeClient(i) )
			PrintToConsole(i, "[AFK Manager] %s", message);
#endif
}
#endif

#if _DEBUG
public Action Command_Test(int client, int args)
{
	PrintToServer("RAWR");
	PrintToConsole(client, "Team Num: %i", GetEntProp(client, Prop_Send, "m_iTeamNum"));
	PrintToConsole(client, "Pending Team Num: %i", GetEntProp(client, Prop_Send, "m_iPendingTeamNum"));
	//PrintToConsole(client, "Force Team: %f", GetEntPropFloat(client, Prop_Send, "m_fForceTeam"));
	//PrintToConsole(client, "Initial Team Num: %i", GetEntProp(client, Prop_Data, "m_iInitialTeamNum"));
	//PrintToConsole(client, "Move Done Time: %f", GetEntPropFloat(client, Prop_Data, "m_flMoveDoneTime"));
	//PrintToConsole(client, "Class: %i", GetEntProp(client, Prop_Send, "m_iClass"));
	PrintToConsole(client, "Force Team: %f", GetEntPropFloat(client, Prop_Data, "m_fForceTeam"));
	PrintToConsole(client, "Player State: %i", GetEntProp(client, Prop_Send, "m_iPlayerState"));
	//PrintToConsole(client, "Original Team Number: %i", GetEntProp(client, Prop_Send, "m_iOriginalTeamNumber"));

	PrintToConsole(client, "Asherkin Magic #1: %i", FindSendPropInfo("CCSPlayer", "m_unMusicID") - 45);
	PrintToConsole(client, "Asherkin Magic #2: %i", FindSendPropInfo("CCSPlayer", "m_nHeavyAssaultSuitCooldownRemaining") + 48);
	PrintToConsole(client, "Asherkin Magic #3: %i", FindSendPropInfo("CCSPlayer", "m_unMusicID") - 21);
	PrintToConsole(client, "Asherkin Magic #1 2: %i", GetEntData(client, FindSendPropInfo("CCSPlayer", "m_unMusicID") - 45, 1));
	PrintToConsole(client, "Asherkin Magic #2 2: %i", GetEntData(client, FindSendPropInfo("CCSPlayer", "m_nHeavyAssaultSuitCooldownRemaining") + 48, 1));
	PrintToConsole(client, "Asherkin Magic #3 2: %i", GetEntData(client, FindSendPropInfo("CCSPlayer", "m_unMusicID") - 21, 1));
	//SetEntData(client, FindSendPropInfo("CCSPlayer", "m_unMusicID") - 45, 0, 1, true);
	int g_iTeamOffset = FindSendPropInfo("CCSPlayerResource", "m_iTeam");
	static iTeam[MAXPLAYERS+1];
	GetEntDataArray(FindEntityByClassname(MaxClients+1, "cs_player_manager"), g_iTeamOffset, iTeam, MAXPLAYERS+1);
	PrintToConsole(client, "Team: %i", iTeam[client]);
	//int g_iAliveOffset = FindSendPropOffs("CCSPlayerResource", "m_bAlive");
	//static iAlive[MAXPLAYERS+1];
	//GetEntDataArray(FindEntityByClassname(MaxClients+1, "cs_player_manager"), g_iAliveOffset, iAlive, MAXPLAYERS+1);
	//PrintToConsole(client, "Alive: %i", iAlive[client]);
	//SetEntProp(client, Prop_Send, "m_iPendingTeamNum", 0);
	//PrintToConsole(client, "Team Number: %i", GetEntData(client, Prop_Data, "m_nTeamNum"));
	//PrintToConsole(client, "Blocked Team Number: %i", GetEntData(client, Prop_Data, "m_blockedTeamNumber"));

	return Plugin_Handled;
}

public Action Command_Test2(int client, int args)
{
	PrintToServer("RAWR2");
	//SetEntData(client, FindSendPropInfo("CCSPlayer", "m_nHeavyAssaultSuitCooldownRemaining") + 48, 0, 1, true); // Fix by Asherkin
	SetEntData(client, FindSendPropInfo("CCSPlayer", "m_unMusicID") - 21, 0, 1, true);
	PrintToConsole(client, "Asherkin: %i", GetEntData(client, FindSendPropInfo("CCSPlayer", "m_unMusicID") - 21, 1));
	return Plugin_Handled;
}

#endif

// Native Functions
/*
int GetMaxPlugins()
{
	return GetArraySize(g_FWD_hPlugins);
}

void AddPlugin(Handle plugin)
{
	int maxPlugins = GetMaxPlugins();
	for (int i = 0; i < maxPlugins; i++)
		if (plugin == GetArrayCell(g_FWD_hPlugins, i)) // Plugin Already Exists?
			return;

	PushArrayCell(g_FWD_hPlugins, plugin);
}


void RemovePlugin(Handle plugin)
{
	int maxPlugins = GetMaxPlugins();
	for (int i = 0; i < maxPlugins; i++)
		if (plugin == GetArrayCell(g_FWD_hPlugins, i))
			RemoveFromArray(g_FWD_hPlugins, i);
}
*/


// General Functions
char[] ActionToString(Action action)
{
	char Action_Name[32];
	switch (action)
	{
		case Plugin_Continue:
			Action_Name = "Plugin_Continue";
		case Plugin_Changed:
			Action_Name = "Plugin_Changed";
		case Plugin_Handled:
			Action_Name = "Plugin_Handled";
		case Plugin_Stop:
			Action_Name = "Plugin_Stop";
		default:
			Action_Name = "Plugin_Error";
	}
	return Action_Name;
}

bool IsValidClient(int client, bool nobots = true) // Check If A Client ID Is Valid
{
    if (client < 1 || client > MaxClients)
		return false;
	else if (!IsClientConnected(client))
        return false;
	else if (IsClientSourceTV(client))
		return false;
	else if (nobots && IsFakeClient(client))
		return false;
    return IsClientInGame(client);
}

void ResetAFKTimer(int index, bool Full = true)
{
#if _DEBUG
	LogDebug(false, "ResetAFKTimer - Client: %i Full: %i", index, Full);
#endif

	if (g_hAFKTimer[index] != INVALID_HANDLE) // Check for timers and destroy them?
	{
		CloseHandle(g_hAFKTimer[index]);
		g_hAFKTimer[index] = INVALID_HANDLE;
	}
	if (Full)
		ResetPlayer(index);
}

void ResetAttacker(int index)
{
#if _DEBUG > 1
	LogDebug(false, "ResetAttacker - Client: %i", index);
#endif
	iPlayerAttacker[index] = -1;
}

void ResetSpawn(int index)
{
#if _DEBUG > 1
	LogDebug(false, "ResetSpawn - Client: %i", index);
#endif
	g_iSpawnTime[index] =	-1;
}

void ResetObserver(int index)
{
#if _DEBUG > 1
	LogDebug(false, "ResetObserver - Client: %i", index);
#endif
	iObserverMode[index] = -1;
	iObserverTarget[index] = -1;
}

void ResetPlayer(int index, bool FullReset = true) // Player Resetting
{
	ResetSpawn(index);
	bPlayerAFK[index] = true;

	iButtonsArrayIndex[index] = 0;

	if (FullReset)
	{
		g_iPlayerUserID[index] = -1;
		g_iAFKTime[index] = -1;
		g_iPlayerTeam[index] = -1;
		ResetAttacker(index);
		ResetObserver(index);

		for (int i = 0; i < BUTTONS_MAX_ARRAY; i++)
			iButtonsArray[index][i] = 0;
	}
	else
	{
		g_iAFKTime[index] = GetTime();

		for (int i = 0; i < g_iButtonsArraySize; i++)
			iButtonsArray[index][i] = 0;
	}
#if _DEBUG > 1
	LogDebug(false, "ResetPlayer - Client: %i Full Reset: %b AFK Time: %i", index, FullReset, g_iAFKTime[index]);
#endif
}

void SetClientAFK(int client, bool Reset = true)
{
	if (Reset)
		ResetPlayer(client, false);
	else
		bPlayerAFK[client] = true;

	Forward_OnClientAFK(client);
}

void InitializeAFK(int index) // initialize AFK Features
{
	if (g_hAFKTimer[index] == INVALID_HANDLE)
	{
		g_iAFKTime[index] = GetTime();
#if _DEBUG
		LogDebug(false, "InitializeAFK - AFK Time: %i", g_iAFKTime[index]);
#endif
		g_iPlayerTeam[index] = GetClientTeam(index);
		g_hAFKTimer[index] = CreateTimer(AFK_CHECK_INTERVAL, Timer_CheckPlayer, index, TIMER_REPEAT); // Create AFK Timer
	}
}

void InitializePlayer(int index) // Player Initialization
{
#if _DEBUG
	LogDebug(false, "InitializePlayer - Client: %i", index);
#endif
	if (IsValidClient(index))
	{
		int iClientUserID = GetClientUserId(index);

		if (iClientUserID != g_iPlayerUserID[index]) // If UserID is the same keep AFK settings over map changes
		{
			ResetAFKTimer(index);
			g_iPlayerUserID[index] = iClientUserID;
		}


		Action ForwardResult = Forward_OnInitializePlayer(index);

		if (ForwardResult != Plugin_Continue)
		{
			if (g_bLogWarnings)
			{
				char Action_Name[32];
				Action_Name = ActionToString(ForwardResult);
				LogToFile(AFKM_LogFile, "AFK Manager Event: InitializePlayer has been requested to: %s by an external plugin this action will affect the event outcome.", Action_Name);
			}
		}
		else
		{
#if _DEBUG
			LogDebug(false, "InitializePlayer - Client: %i is valid Admins Immune: %i", index, g_iAdminsImmunue);
#endif
			if ( (g_iAdminsImmunue > 0) && (g_iPlayerImmunity[index] == AFKImmunity_None) ) // Check Admin immunity if no immunity exists
				if (CheckAdminImmunity(index))
				{
#if _DEBUG
					LogDebug(false, "InitializePlayer - Client: %i is being set to Immunity: %i", index, g_iAdminsImmunue);
#endif
					SetPlayerImmunity(index, g_iAdminsImmunue);
				}

#if _DEBUG
					LogDebug(false, "InitializePlayer - Client: %i Immunity: %i", index, g_iPlayerImmunity[index]);
#endif
			if (g_iPlayerImmunity[index] != AFKImmunity_Full)
				InitializeAFK(index);
		}
	}
}

void UnInitializePlayer(int index) // Player UnInitialization
{
#if _DEBUG
	LogDebug(false, "UnInitializePlayer - Client: %i", index);
#endif
	ResetAFKTimer(index);
	g_iPlayerImmunity[index] = AFKImmunity_None;
}

int AFK_GetClientCount(bool inGameOnly = true)
{
#if _DEBUG > 1
		LogDebug(false, "AFK_GetClientCount - InGameOnly: %b", inGameOnly);
#endif

	int clients = 0;
	for (int i = 1; i <= MaxClients; i++)
		if( ( ( inGameOnly ) ? IsClientInGame(i) : IsClientConnected(i) ) && !IsClientSourceTV(i) && !IsFakeClient(i) )
			clients++;
	return clients;
}

void CheckMinPlayers()
{
	int MoveMinPlayers = GetConVarInt(hCvarMinPlayersMove);
	int KickMinPlayers = GetConVarInt(hCvarMinPlayersKick);

	int players = AFK_GetClientCount();

	if (players >= MoveMinPlayers)
	{
		if (!bMovePlayers)
			if (g_bLogWarnings)
				LogToFile(AFKM_LogFile, "Player count for AFK Move minimum has been reached, feature is now enabled: sm_afk_move_min_players = %i Current Players = %i", MoveMinPlayers, players);
		bMovePlayers = true;
	}
	else
	{
		if (bMovePlayers)
			if (g_bLogWarnings)
				LogToFile(AFKM_LogFile, "Player count for AFK Move minimum is below requirements, feature is now disabled: sm_afk_move_min_players = %i Current Players = %i", MoveMinPlayers, players);
		bMovePlayers = false;
	}

	if (players >= KickMinPlayers)
	{
		if (!bKickPlayers)
			if (g_bLogWarnings)
				LogToFile(AFKM_LogFile, "Player count for AFK Kick minimum has been reached, feature is now enabled: sm_afk_kick_min_players = %i Current Players = %i", KickMinPlayers, players);
		bKickPlayers = true;
	}
	else
	{
		if (bKickPlayers)
			if (g_bLogWarnings)
				LogToFile(AFKM_LogFile, "Player count for AFK Kick minimum is below requirements, feature is now disabled: sm_afk_kick_min_players = %i Current Players = %i", KickMinPlayers, players);
		bKickPlayers = false;
	}
}

void ChangeButtonsArraySize(int size)
{
	if (size > BUTTONS_MAX_ARRAY)
		size = BUTTONS_MAX_ARRAY;

	g_iButtonsArraySize = size;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (iButtonsArrayIndex[i] >= g_iButtonsArraySize)
			iButtonsArrayIndex[i] = 0;

		for (int j = g_iButtonsArraySize; j < BUTTONS_MAX_ARRAY; j++)
		{
			iButtonsArray[i][j] = 0;
		}
	}
}

// Cvar Hooks
public void CvarChange_Status(Handle cvar, const char[] oldvalue, const char[] newvalue) // Hook ConVar Status
{
#if _DEBUG
	char sCvarName[64];
	GetConVarName(cvar, sCvarName, sizeof(sCvarName));
	LogDebug(false, "CvarChange_Status - ConVar: %s Old Value: %s New Value: %s", sCvarName, oldvalue, newvalue);
#endif

	if (!StrEqual(oldvalue, newvalue))
	{
		if ((cvar == hCvarMinPlayersMove) || (cvar == hCvarMinPlayersKick))
		{
			if (g_bEnabled)
				CheckMinPlayers();
		}
		else if (cvar == hCvarAdminsImmune)
		{
			g_iAdminsImmunue = StringToInt(newvalue);
			ChangeImmunity(g_iAdminsImmunue);
		}
		else if (cvar == hCvarTimeToMove)
			g_iTimeToMove = StringToInt(newvalue);
		else if (cvar == hCvarTimeToKick)
			g_iTimeToKick = StringToInt(newvalue);
		else if (cvar == hCvarButtonsBuffer)
			ChangeButtonsArraySize(StringToInt(newvalue));
		else if (StringToInt(newvalue) == 1)
		{
			if (cvar == hCvarEnabled)
				EnablePlugin();
			else if (cvar == hCvarLanguage)
				g_bForceLanguage = true;
			else if (cvar == hCvarLogWarnings)
				g_bLogWarnings = true;
			else if (cvar == hCvarPrefixShort)
				g_sPrefix = "AFK";
			else if (cvar == hCvarExcludeDead)
				g_bExcludeDead = true;
			else if (cvar == hCvarTF2Arena)
				g_bTF2Arena = true;
#if defined _colors_included
			else if (cvar == hCvarPrefixColor)
				g_bPrefixColors = true;
#endif
		}
		else if (StringToInt(newvalue) == 0)
		{
			if (cvar == hCvarEnabled)
				DisablePlugin();
			else if (cvar == hCvarLanguage)
				g_bForceLanguage = false;
			else if (cvar == hCvarLogWarnings)
				g_bLogWarnings = false;
			else if (cvar == hCvarPrefixShort)
				g_sPrefix = "AFK Manager";
			else if (cvar == hCvarExcludeDead)
				g_bExcludeDead = false;
			else if (cvar == hCvarTF2Arena)
				g_bTF2Arena = false;
#if defined _colors_included
			else if (cvar == hCvarPrefixColor)
				g_bPrefixColors = false;
#endif
		}
	}
}

public void CvarChange_Locked(Handle cvar, const char[] oldvalue, const char[] newvalue) // Lock ConVar
{
#if _DEBUG
	char sCvarName[64];
	GetConVarName(cvar, sCvarName, sizeof(sCvarName));
	LogDebug(false, "CvarChange_Locked - ConVar: %s Old Value: %s New Value: %s", sCvarName, oldvalue, newvalue);
#endif
	if ((cvar == hCvarVersion) && (strcmp(newvalue, AFKM_VERSION) != 0))
		SetConVarString(cvar, AFKM_VERSION);
	else if ((cvar == hCvarAFK) && (StringToInt(newvalue) != 0))
		SetConVarInt(cvar, 0);
}

void HookEvents() // Event Hook Registrations
{
	HookEvent("player_disconnect", Event_PlayerDisconnectPost, EventHookMode_Post);
#if _DEBUG
	LogDebug(false, "HookEvents - Hooked Player Disconnect Event.");
#endif
	HookEvent("player_team", Event_PlayerTeam);
#if _DEBUG
	LogDebug(false, "HookEvents - Hooked Player Team Event.");
#endif
	HookEvent("player_spawn", Event_PlayerSpawn);
#if _DEBUG
	LogDebug(false, "HookEvents - Hooked Player Spawn Event.");
#endif
	HookEvent("player_death", Event_PlayerDeathPost, EventHookMode_Post);
#if _DEBUG
	LogDebug(false, "HookEvents - Hooked Player Death Event.");
#endif
	if (TF2)
	{
		HookEvent("teamplay_round_win", Event_TeamplayRoundWin);
#if _DEBUG
		LogDebug(false, "HookEvents - Hooked Teamplay Round Win Event.");
#endif
		HookEvent("arena_round_start", Event_ArenaRoundStart);
#if _DEBUG
		LogDebug(false, "HookEvents - Hooked Arena Round Start Event.");
#endif
	}
	else if (CSTRIKE || CSGO)
	{
		HookEvent("round_start",Event_RoundStart);
#if _DEBUG
		LogDebug(false, "HookEvents - Hooked Round Start Event.");
#endif
		HookEvent("round_freeze_end",Event_RoundFreezeEnd);
#if _DEBUG
		LogDebug(false, "HookEvents - Hooked Round Freeze End Event.");
#endif
	}
}

void HookConVars() // ConVar Hook Registrations
{
#if _DEBUG
	LogDebug(false, "HookConVars - Running");
#endif
	if (!bCvarIsHooked[CONVAR_VERSION])
	{
		HookConVarChange(hCvarVersion, CvarChange_Locked); // Hook Version Variable
		bCvarIsHooked[CONVAR_VERSION] = true;
#if _DEBUG
		LogDebug(false, "HookConVars - Hooked Version variable.");
#endif
	}
	if (!bCvarIsHooked[CONVAR_ENABLED])
	{
		HookConVarChange(hCvarEnabled, CvarChange_Status); // Hook Enabled Variable
		bCvarIsHooked[CONVAR_ENABLED] = true;
#if _DEBUG
		LogDebug(false, "HookConVars - Hooked Enable variable.");
#endif
	}
	if (hCvarAFK != INVALID_HANDLE)
	{
		if (!bCvarIsHooked[CONVAR_MOD_AFK])
		{
			HookConVarChange(hCvarAFK, CvarChange_Locked); // Hook AFK Variable
			bCvarIsHooked[CONVAR_MOD_AFK] = true;
			SetConVarInt(hCvarAFK, 0);
#if _DEBUG
			LogDebug(false, "HookConVars - Hooked Mod Based AFK variable.");
#endif
		}
	}
	if (!bCvarIsHooked[CONVAR_PREFIXSHORT])
	{
		HookConVarChange(hCvarPrefixShort, CvarChange_Status); // Hook Short Prefix Variable
		bCvarIsHooked[CONVAR_PREFIXSHORT] = true;
#if _DEBUG
		LogDebug(false, "HookConVars - Hooked Short Prefix variable.");
#endif

		if (hCvarPrefixShort.BoolValue)
			g_sPrefix = "AFK";
	}
#if defined _colors_included
	if (!bCvarIsHooked[CONVAR_PREFIXCOLORS])
	{
		HookConVarChange(hCvarPrefixColor, CvarChange_Status); // Hook Color Prefix Variable
		bCvarIsHooked[CONVAR_PREFIXCOLORS] = true;
#if _DEBUG
		LogDebug(false, "HookConVars - Hooked Color Prefix variable.");
#endif

		if (hCvarPrefixColor.BoolValue)
			g_bPrefixColors = true;
	}
#endif
	if (!bCvarIsHooked[CONVAR_LANGUAGE])
	{
		HookConVarChange(hCvarLanguage, CvarChange_Status); // Hook Language Variable
		bCvarIsHooked[CONVAR_LANGUAGE] = true;
#if _DEBUG
		LogDebug(false, "HookConVars - Hooked Language variable.");
#endif
		if (hCvarLanguage.BoolValue)
			g_bForceLanguage = true;
	}
	if (!bCvarIsHooked[CONVAR_LOG_WARNINGS])
	{
		HookConVarChange(hCvarLogWarnings, CvarChange_Status); // Hook Warnings Variable
		bCvarIsHooked[CONVAR_LOG_WARNINGS] = true;
#if _DEBUG
		LogDebug(false, "HookConVars - Hooked Warnings variable.");
#endif

		if (GetConVarBool(hCvarLogWarnings))
			g_bLogWarnings = true;
	}
	if (!bCvarIsHooked[CONVAR_MINPLAYERSMOVE])
	{
		HookConVarChange(hCvarMinPlayersMove, CvarChange_Status); // Hook Minim Players to Move Variable
		bCvarIsHooked[CONVAR_MINPLAYERSMOVE] = true;
#if _DEBUG
		LogDebug(false, "HookConVars - Hooked Minimum Players to Move variable.");
#endif
		CheckMinPlayers();
	}
	if (!bCvarIsHooked[CONVAR_MINPLAYERSKICK])
	{
		HookConVarChange(hCvarMinPlayersKick, CvarChange_Status); // Hook Minim Players to Kick Variable
		bCvarIsHooked[CONVAR_MINPLAYERSKICK] = true;
#if _DEBUG
		LogDebug(false, "HookConVars - Hooked Minimum Players to Kick variable.");
#endif
		CheckMinPlayers();
	}
	if (!bCvarIsHooked[CONVAR_ADMINS_IMMUNE])
	{
		HookConVarChange(hCvarAdminsImmune, CvarChange_Status); // Hook AdminsImmune Variable
		bCvarIsHooked[CONVAR_ADMINS_IMMUNE] = true;
#if _DEBUG
		LogDebug(false, "HookConVars - Hooked AdminsImmune variable.");
#endif
		g_iAdminsImmunue = hCvarAdminsImmune.IntValue;
		ChangeImmunity(g_iAdminsImmunue);
	}

	if (!bCvarIsHooked[CONVAR_TIMETOMOVE])
	{
		HookConVarChange(hCvarTimeToMove, CvarChange_Status); // Hook TimeToMove Variable
		bCvarIsHooked[CONVAR_TIMETOMOVE] = true;
#if _DEBUG
		LogDebug(false, "HookConVars - Hooked TimeToMove variable.");
#endif
		g_iTimeToMove = hCvarTimeToMove.IntValue;
	}
	if (!bCvarIsHooked[CONVAR_TIMETOKICK])
	{
		HookConVarChange(hCvarTimeToKick, CvarChange_Status); // Hook TimeToKick Variable
		bCvarIsHooked[CONVAR_TIMETOKICK] = true;
#if _DEBUG
		LogDebug(false, "HookConVars - Hooked TimeToKick variable.");
#endif
		g_iTimeToKick = hCvarTimeToKick.IntValue;
	}
	if (!bCvarIsHooked[CONVAR_EXCLUDEDEAD])
	{
		HookConVarChange(hCvarExcludeDead, CvarChange_Status); // Hook Exclude Dead Variable
		bCvarIsHooked[CONVAR_EXCLUDEDEAD] = true;
#if _DEBUG
		LogDebug(false, "HookConVars - Hooked Exclude Dead variable.");
#endif

		if (hCvarExcludeDead.BoolValue)
			g_bExcludeDead = true;
	}


	if (TF2)
	{
		if (hCvarTF2Arena != INVALID_HANDLE)
		{
			if (!bCvarIsHooked[CONVAR_TF2_ARENAMODE])
			{
				HookConVarChange(hCvarTF2Arena, CvarChange_Status); // Hook TF2 Arena Variable
				bCvarIsHooked[CONVAR_TF2_ARENAMODE] = true;
#if _DEBUG
				LogDebug(false, "HookConVars - Hooked TF2 Arena variable.");
#endif

				if (hCvarTF2Arena.BoolValue)
					g_bTF2Arena = true;
			}
		}
	}
	if (!bCvarIsHooked[CONVAR_BUTTONSBUFFER])
	{
		HookConVarChange(hCvarButtonsBuffer, CvarChange_Status); // Hook Buttons Buffer Variable
		bCvarIsHooked[CONVAR_BUTTONSBUFFER] = true;
#if _DEBUG
		LogDebug(false, "HookConVars - Hooked Buttons Buffer variable.");
#endif
		g_iButtonsArraySize = hCvarButtonsBuffer.IntValue;
		ChangeButtonsArraySize(g_iButtonsArraySize);
	}

}

void RegisterCvars() // Cvar Registrations
{
	hCvarVersion = CreateConVar("sm_afkm_version", AFKM_VERSION, "Current version of the AFK Manager", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	SetConVarString(hCvarVersion, AFKM_VERSION);
	hCvarEnabled = CreateConVar("sm_afk_enable", "1", "Is the AFK Manager enabled or disabled? [0 = FALSE, 1 = TRUE, DEFAULT: 1]", FCVAR_NONE, true, 0.0, true, 1.0);
	hCvarAutoUpdate = CreateConVar("sm_afk_autoupdate", "0", "Is the AFK Manager automatic plugin update enabled or disabled? (Requires SourceMod Autoupdate plugin) [0 = FALSE, 1 = TRUE]", FCVAR_NONE, true, 0.0, true, 1.0);
	hCvarPrefixShort = CreateConVar("sm_afk_prefix_short", "0", "Should the AFK Manager use a short prefix? [0 = FALSE, 1 = TRUE, DEFAULT: 0]", FCVAR_NONE, true, 0.0, true, 1.0);
	hCvarLanguage = CreateConVar("sm_afk_force_language", "1", "Should the AFK Manager force all message language to the server default? [0 = DISABLED, 1 = ENABLED, DEFAULT: 0]", FCVAR_NONE, true, 0.0, true, 1.0);
	hCvarLogWarnings = CreateConVar("sm_afk_log_warnings", "0", "Should the AFK Manager log plugin warning messages. [0 = FALSE, 1 = TRUE, DEFAULT: 1]", FCVAR_NONE, true, 0.0, true, 1.0);
	hCvarLogMoves = CreateConVar("sm_afk_log_moves", "0", "Should the AFK Manager log client moves. [0 = FALSE, 1 = TRUE, DEFAULT: 1]", FCVAR_NONE, true, 0.0, true, 1.0);
	hCvarLogKicks = CreateConVar("sm_afk_log_kicks", "1", "Should the AFK Manager log client kicks. [0 = FALSE, 1 = TRUE, DEFAULT: 1]", FCVAR_NONE, true, 0.0, true, 1.0);
	hCvarLogDays = CreateConVar("sm_afk_log_days", "0", "How many days should we keep AFK Manager log files. [0 = INFINITE, DEFAULT: 0]");
	hCvarMinPlayersMove = CreateConVar("sm_afk_move_min_players", "16", "Minimum number of connected clients required for AFK move to be enabled. [DEFAULT: 4]");
	hCvarMinPlayersKick = CreateConVar("sm_afk_kick_min_players", "16", "Minimum number of connected clients required for AFK kick to be enabled. [DEFAULT: 6]");
	hCvarAdminsImmune = CreateConVar("sm_afk_admins_immune", "1", "Should admins be immune to the AFK Manager? [0 = DISABLED, 1 = COMPLETE IMMUNITY, 2 = KICK IMMUNITY, 3 = MOVE IMMUNITY]");
	hCvarAdminsFlag = CreateConVar("sm_afk_admins_flag", "", "Admin Flag for immunity? Leave Blank for any flag.");
	hCvarMoveSpec = CreateConVar("sm_afk_move_spec", "0", "Should the AFK Manager move AFK clients to spectator team? [0 = FALSE, 1 = TRUE, DEFAULT: 1]", FCVAR_NONE, true, 0.0, true, 1.0);
	hCvarMoveAnnounce = CreateConVar("sm_afk_move_announce", "2", "Should the AFK Manager announce AFK moves to the server? [0 = DISABLED, 1 = EVERYONE, 2 = ADMINS ONLY, DEFAULT: 1]", FCVAR_NONE, true, 0.0, true, 2.0);
	hCvarTimeToMove = CreateConVar("sm_afk_move_time", "0", "Time in seconds (total) client must be AFK before being moved to spectator. [0 = DISABLED, DEFAULT: 60.0 seconds]");
	hCvarWarnTimeToMove = CreateConVar("sm_afk_move_warn_time", "300.0", "Time in seconds remaining, player should be warned before being moved for AFK. [DEFAULT: 30.0 seconds]");
	hCvarKickPlayers = CreateConVar("sm_afk_kick_players", "1", "Should the AFK Manager kick AFK clients? [0 = DISABLED, 1 = KICK ALL, 2 = ALL EXCEPT SPECTATORS, 3 = SPECTATORS ONLY]");
	hCvarKickAnnounce = CreateConVar("sm_afk_kick_announce", "0", "Should the AFK Manager announce AFK kicks to the server? [0 = DISABLED, 1 = EVERYONE, 2 = ADMINS ONLY, DEFAULT: 1]", FCVAR_NONE, true, 0.0, true, 2.0);
	hCvarTimeToKick = CreateConVar("sm_afk_kick_time", "300.0", "Time in seconds (total) client must be AFK before being kicked. [0 = DISABLED, DEFAULT: 120.0 seconds]");
	hCvarWarnTimeToKick = CreateConVar("sm_afk_kick_warn_time", "300.0", "Time in seconds remaining, player should be warned before being kicked for AFK. [DEFAULT: 30.0 seconds]");
	hCvarSpawnTime = CreateConVar("sm_afk_spawn_time", "300.0", "Time in seconds (total) that player should have moved from their spawn position. [0 = DISABLED, DEFAULT: 20.0 seconds]");
	hCvarWarnSpawnTime = CreateConVar("sm_afk_spawn_warn_time", "300.0", "Time in seconds remaining, player should be warned for being AFK in spawn. [DEFAULT: 15.0 seconds]");
	hCvarExcludeDead = CreateConVar("sm_afk_exclude_dead", "1", "Should the AFK Manager exclude checking dead players? [0 = FALSE, 1 = TRUE, DEFAULT: 0]", FCVAR_NONE, true, 0.0, true, 1.0);
	hCvarWarnUnassigned = CreateConVar("sm_afk_move_warn_unassigned", "0", "Should the AFK Manager warn team 0 (Usually unassigned) players? (Disabling may not work for some games) [0 = FALSE, 1 = TRUE, DEFAULT: 1]", FCVAR_NONE, true, 0.0, true, 1.0);
	hCvarButtonsBuffer = CreateConVar("sm_afk_buttons", "5", "How many button changes should the AFK Manager track before resetting AFK status? [0 = DISABLED, DEFAULT: 5]", FCVAR_NONE, true, 0.0, true, float(BUTTONS_MAX_ARRAY));
}

void RegisterCmds() // Command Hook & Registrations
{
	RegAdminCmd("sm_afk_spec", Command_Spec, ADMFLAG_KICK, "sm_afk_spec <#userid|name>");
}

void EnablePlugin() // Enable Plugin Function
{
	g_bEnabled = true;

	for(int i = 1; i <= MaxClients; i++) // Reset timers for all players
		InitializePlayer(i);

	CheckMinPlayers(); // Check we have enough minimum players
}

void DisablePlugin() // Disable Plugin Function
{
#if _DEBUG
	LogDebug(false, "DisablePlugin - AFK Plugin Stopping!");
#endif
	g_bEnabled = false;

	for(int i = 1; i <= MaxClients; i++) // Stop timers for all players
		UnInitializePlayer(i);
}

public Action Command_Spec(int client, int args) // Admin Spectate Move Command
{
	if (args < 1)
	{
		ReplyToCommand(client, "[AFK Manager] Usage: sm_afk_spec <#userid|name>");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;

	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
#if _DEBUG
		LogDebug(false, "Command_Spec - Moving client: %i to Spectator and killing timer.", target_list[i]);
#endif
		if (MoveAFKClient(target_list[i], false) == Plugin_Stop)
			if (g_hAFKTimer[target_list[i]] != INVALID_HANDLE)
			{
				CloseHandle(g_hAFKTimer[target_list[i]]);
				g_hAFKTimer[target_list[i]] = INVALID_HANDLE;
			}
	}

	if (tn_is_ml)
	{
		if (GetConVarBool(hCvarPrefixShort))
			ShowActivity2(client, "[AFK] ", "%t", "Spectate_Force", target_name);
		else
			ShowActivity2(client, "[AFK Manager] ", "%t", "Spectate_Force", target_name);
		LogToFile(AFKM_LogFile, "%L: %T", client, "Spectate_Force", LANG_SERVER, target_name);
	}
	else
	{
		if (GetConVarBool(hCvarPrefixShort))
			ShowActivity2(client, "[AFK] ", "%t", "Spectate_Force", "_s", target_name);
		else
			ShowActivity2(client, "[AFK Manager] ", "%t", "Spectate_Force", "_s", target_name);
		LogToFile(AFKM_LogFile, "%L: %T", client, "Spectate_Force", LANG_SERVER, "_s", target_name);
	}
	return Plugin_Handled;
}

// SourceMod Events
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late; // Detect Late Load
	API_Init(); // Initialize API
	RegPluginLibrary("afkmanager"); // Register Plugin
#if defined _colors_included
    MarkNativeAsOptional("GetUserMessageType");
#endif
	MarkNativeAsOptional("GetEngineVersion");
	return APLRes_Success;
}

public void OnPluginStart() // AFK Manager Plugin has started
{
	BuildLogFilePath();

#if _DEBUG
	LogDebug(false, "AFK Plugin Started!");
#endif

	LoadTranslations("common.phrases");
	LoadTranslations("afk_manager.phrases");

	// Initialize Arrays
	//g_FWD_hPlugins = CreateArray();

	// Game Engine Detection
	if ( CanTestFeatures() && (GetFeatureStatus(FeatureType_Native, "GetEngineVersion") == FeatureStatus_Available) )
	{
		EngineVersion g_EngineVersion = Engine_Unknown;

		g_EngineVersion = GetEngineVersion();

		switch (g_EngineVersion)
		{
			case Engine_Original: // Original Source Engine (used by The Ship)
				OBS_MODE_ROAMING = 5;
			case Engine_SourceSDK2006: // Episode 1 Source Engine (second major SDK)
				OBS_MODE_ROAMING = 5;
			case Engine_DarkMessiah: // Dark Messiah Multiplayer (based on original engine)
				OBS_MODE_ROAMING = 5;
			case Engine_CSS: // Counter-Strike: Source
				OBS_MODE_ROAMING = 7;
			case Engine_HL2DM: // Half-Life 2 Deathmatch
				OBS_MODE_ROAMING = 7;
			case Engine_DODS: // Day of Defeat: Source
				OBS_MODE_ROAMING = 7;
			case Engine_TF2: // Team Fortress 2
				OBS_MODE_ROAMING = 7;
			case Engine_SDK2013: // Source SDK 2013
				OBS_MODE_ROAMING = 7;
			default:
				OBS_MODE_ROAMING = 6;
		}
	}

	RequireFeature(FeatureType_Capability, FEATURECAP_PLAYERRUNCMD_11PARAMS, "This plugin requires a newer version of SourceMod.");

	// Check Game Mod
	char game_mod[32];
	GetGameFolderName(game_mod, sizeof(game_mod));

	if (strcmp(game_mod, "synergy", false) == 0)
	{
		LogAction(0, -1, "[AFK Manager] %T", "Synergy", LANG_SERVER);
		Synergy = true;
	}
	else if (strcmp(game_mod, "tf", false) == 0)
	{
		LogAction(0, -1, "[AFK Manager] %T", "TF2", LANG_SERVER);
		TF2 = true;

		hCvarAFK = FindConVar("mp_idledealmethod"); // Hook AFK Convar
		hCvarTF2Arena = FindConVar("tf_gamemode_arena");
		//hCvarTF2WFPTime = FindConVar("mp_waitingforplayers_time");
	}
	else if (strcmp(game_mod, "csgo", false) == 0)
	{
		LogAction(0, -1, "[AFK Manager] %T", "CSGO", LANG_SERVER);
		CSGO = true;
		hCvarAFK = FindConVar("mp_autokick"); // Hook AFK Convar
	}
	else if (strcmp(game_mod, "cstrike", false) == 0)
	{
		LogAction(0, -1, "[AFK Manager] %T", "CSTRIKE", LANG_SERVER);
		CSTRIKE = true;

		hCvarAFK = FindConVar("mp_autokick"); // Hook AFK Convar
	}
	else if (strcmp(game_mod, "gesource", false) == 0)
	{
		LogAction(0, -1, "[AFK Manager] %T", "GESOURCE", LANG_SERVER);
		GESOURCE = true;

		//hCvarAFK = FindConVar("mp_autokick"); // Hook AFK Convar
	}

	RegisterCvars(); // Register Cvars
	SetConVarInt(hCvarLogWarnings, 0);
	SetConVarInt(hCvarEnabled, 0);

	HookConVars(); // Hook ConVars
	HookEvents(); // Hook Events

	AutoExecConfig(true, "afk_manager");

	RegisterCmds(); // Register Commands

	if (hCvarLogDays != INVALID_HANDLE)
		if (GetConVarInt(hCvarLogDays) > 0)
			PurgeOldLogs(); // Purge Old Log Files

	if (g_bLateLoad) // Account for Late Loading
		g_bWaitRound = false;
}

public void OnAllPluginsLoaded() // All Plugins have been loaded
{
#if defined _updater_included
	if (LibraryExists("updater"))
		Updater_AddPlugin(UPDATE_URL);
#endif
}

public void OnLibraryAdded(const char[] name)
{
#if defined _updater_included
	if (StrEqual(name, "updater"))
		Updater_AddPlugin(UPDATE_URL);
#endif
}

public void OnMapStart()
{
#if _DEBUG
	LogDebug(false, "OnMapStart - Event Fired");
#endif
	BuildLogFilePath();

	if (hCvarLogDays != INVALID_HANDLE)
		if (GetConVarInt(hCvarLogDays) > 0)
			PurgeOldLogs(); // Purge Old Log Files

	if (GetConVarBool(hCvarAutoUpdate))
	{
#if defined _updater_included
		if (LibraryExists("updater") && !GetConVarBool(FindConVar("sv_lan")))
		{
			Updater_ForceUpdate();
		}
#endif
	}

	AutoExecConfig(true, "afk_manager"); // Execute Config

	if (g_iMapEndTime != -1)
	{
		int iMapChangeTime = GetTime() - g_iMapEndTime; // Seconds from MapEnd to MapStart
		for (int i = 1; i <= MaxClients; i++)
			if (g_iAFKTime[i] != -1)
				g_iAFKTime[i] = g_iAFKTime[i] + iMapChangeTime;

		g_iMapEndTime = -1;
	}

	if (TF2) // Check TF2 Game Mode
	{
		if (TF2_DetectGameMode() == TF2GameMode_Arena) // Arena Mode
		{
#if _DEBUG
			LogDebug(false, "OnMapStart - Detected TF2 Arena Game Mode");
#endif
			g_bTF2Arena = true;
		}
		if (!g_bTF2Arena)
			g_bWaitRound = false; // Un-Pause Plugin on Map Start
	}
	else
		g_bWaitRound = false; // Un-Pause Plugin on Map Start
}

public void OnMapEnd()
{
#if _DEBUG
	LogDebug(false, "OnMapEnd - Event Fired");
#endif
	g_iMapEndTime = GetTime();
	g_bWaitRound = true; // Pause Plugin During Map Transitions?
}

public void OnClientPostAdminCheck(int client) // Client has joined server
{
#if _DEBUG
	LogDebug(false, "OnClientPostAdminCheck - Client: %L Put in server", client);
#endif

	if (g_bEnabled)
	{
		InitializePlayer(client);

		CheckMinPlayers(); // Increment Player Count
	}
}


public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (g_bEnabled)
	{
		if (IsClientSourceTV(client) || IsFakeClient(client)) // Ignore Source TV & Bots
			return Plugin_Continue;

		if (cmdnum <= 0) // NULL Commands?
			return Plugin_Handled;

#if _DEBUG > 2
		LogDebug(false, "OnPlayerRunCmd - Client: %i Eye Angles: %f %f %f", client, angles[0], angles[1], angles[2]);
#endif

#if _DEBUG > 2
		LogDebug(false, "OnPlayerRunCmd - Client: %i Mouse: %i %i", client, mouse[0], mouse[1]);
#endif

		if (g_hAFKTimer[client] != INVALID_HANDLE)
		{
			if ((mouse[0] != 0) || (mouse[1] != 0)) // Check if mouse has moved
			{
				bPlayerAFK[client] = false;
				return Plugin_Continue;
			}
			else
			{
				if (g_iButtonsArraySize > 0)
				{
					int iLastButtons = 0;
					if (g_iButtonsArraySize > 1)
					{
						if (iButtonsArrayIndex[client] == 0)
							iLastButtons = iButtonsArray[client][g_iButtonsArraySize-1];
						else
							iLastButtons = iButtonsArray[client][iButtonsArrayIndex[client]-1];
					}
					else
						iLastButtons = iButtonsArray[client][iButtonsArrayIndex[client]];

					if (iLastButtons != buttons) // ( (angles[0] != fEyeAngles[client][0]) || (angles[1] != fEyeAngles[client][1]) || (angles[2] != fEyeAngles[client][2]) )
					{
						if (IsClientObserver(client))
						{
							if (iObserverMode[client] == -1) // Player has an Invalid Observer Mode
							{
								iButtonsArray[client][iButtonsArrayIndex[client]] = buttons;
								//fEyeAngles[client] = angles;
								return Plugin_Continue;
							}
							else if (iObserverMode[client] != 4) // Check Observer Mode in case it has changed
								iObserverMode[client] = GetEntProp(client, Prop_Send, "m_iObserverMode");

							if ((iObserverMode[client] == 4) && (iLastButtons == buttons))
							{
#if _DEBUG > 1
								LogDebug(false, "OnPlayerRunCmd - Client: %i in chase cam and buttons have not changed.", client);
#endif
								return Plugin_Continue;
							}

							if (iLastButtons == buttons) // && ( (FloatAbs(FloatSub(angles[0],fEyeAngles[client][0])) < 2.0) && (FloatAbs(FloatSub(angles[1],fEyeAngles[client][1])) < 2.0) && (FloatAbs(FloatSub(angles[2],fEyeAngles[client][2])) < 2.0) )
							{
#if _DEBUG > 1
//								LogDebug(false, "OnPlayerRunCmd - Client: %i Eye Angles within threshold: %f %f %f", client, FloatSub(angles[0],fEyeAngles[client][0]),FloatSub(angles[1],fEyeAngles[client][1]),FloatSub(angles[2],fEyeAngles[client][2]));
#endif
								//fEyeAngles[client] = angles;
								return Plugin_Continue;
							}
						}

						if (g_iButtonsArraySize > 1)
						{
							for (int i = 0; i < g_iButtonsArraySize; i++)
							{
								if (iButtonsArray[client][i] == buttons)
								{
#if _DEBUG
									LogDebug(false, "OnPlayerRunCmd - Client: %i buttons found in buffer.", client);
#endif
									return Plugin_Continue;
								}
							}
							iButtonsArray[client][iButtonsArrayIndex[client]] = buttons;

							if (iButtonsArrayIndex[client]++ >= g_iButtonsArraySize) // Increment Array Index
								iButtonsArrayIndex[client] = 0;

						} else
							iButtonsArray[client][iButtonsArrayIndex[client]] = buttons;

#if _DEBUG
						LogDebug(false, "OnPlayerRunCmd - Client: %i buttons not in buffer.", client);
#endif

						if (bPlayerDeath[client])
							bPlayerDeath[client] = false;
						else
							if (bPlayerAFK[client])
							{
								Forward_OnClientBack(client);
								bPlayerAFK[client] = false;
							}
						//ResetPlayer(client, false);
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs) // Player Chat
{
	if (g_bEnabled)
		if (g_hAFKTimer[client] != INVALID_HANDLE)
			ResetPlayer(client, false); // Reset timer once player has said something in chat.
	return Plugin_Continue;
}

#if defined _tf2_included
public void TF2_OnWaitingForPlayersStart()
{
#if _DEBUG
	LogDebug(false, "TF2_OnWaitingForPlayersStart");
#endif
	if (g_bEnabled)
		if (TF2)
			g_bWaitRound = true;
}

public void TF2_OnWaitingForPlayersEnd()
{
#if _DEBUG
	LogDebug(false, "TF2_OnWaitingForPlayersEnd");
#endif
	if (g_bEnabled)
		if (TF2)
			g_bWaitRound = false;
}
#endif


// Game Events
public Action Event_PlayerDisconnectPost(Handle event, const char[] name, bool dontBroadcast)
{
	if (g_bEnabled)
	{
		int iUserID = GetEventInt(event, "userid");
		int iClient = GetClientOfUserId(iUserID);
#if _DEBUG
		LogDebug(false, "Event_PlayerDisconnectPost - Client: %i UserID: %i Disconnected", iClient, iUserID);
#endif
		if ( (iClient > 0) && (iClient <= MaxClients) )
			UnInitializePlayer(iClient); // UnInitializePlayer since they are leaving the server.
		else // Player might have timed out which returns 0 for Client
			for (int i = 1; i <= MaxClients; i++)
				if (g_iPlayerUserID[i] == iUserID)
					UnInitializePlayer(i);

		CheckMinPlayers();
	}
	return Plugin_Continue;
}

public Action Event_PlayerTeam(Handle event, const char[] name, bool dontBroadcast)
{
	if (g_bEnabled)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));

		if (client > 0) // Check the client is not console/world?
			if (IsValidClient(client))
			{
				if (g_hAFKTimer[client] != INVALID_HANDLE)
				{
					g_iPlayerTeam[client] = GetEventInt(event, "team");

#if _DEBUG
					LogDebug(false, "Event_PlayerTeam - Client: %i Joined Team: %i", client, g_iPlayerTeam[client]);
#endif
					if (g_iPlayerTeam[client] != g_iSpec_Team)
					{
						ResetObserver(client);
						ResetPlayer(client, false);
					}
				}
			}
	}
	return Plugin_Continue;
}

public Action Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	if (g_bEnabled)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));

#if _DEBUG
		LogDebug(false, "Event_PlayerSpawn - Client: %i", client);
#endif
		if (client > 0) // Check the client is not console/world?
			if (IsValidClient(client)) // Check client is not a bot or otherwise fake player.
			{
				if (g_hAFKTimer[client] != INVALID_HANDLE)
				{
					if ((!Synergy) && (g_iPlayerTeam[client] == 0)) // Unassigned Team? Fires in CSTRIKE?
						return Plugin_Continue;

					if (!IsClientObserver(client)) // Client is not an Observer/Spectator?
						if (IsPlayerAlive(client)) // Fix for Valve causing Unassigned to not be detected as an Observer in CSS?
							if (GetClientHealth(client) > 0) // Fix for Valve causing Unassigned to be alive?
							{
								ResetAttacker(client);
								ResetObserver(client);

								if (GetConVarFloat(hCvarSpawnTime) > 0.0) // Check if Spawn AFK is enabled.
								{
									g_iSpawnTime[client] = GetTime();
#if _DEBUG > 1
									LogDebug(false, "Event_PlayerSpawn - Client: %i Spawn Time: %i", client, g_iSpawnTime[client]);
#endif
								}
							}
				}
			}
	}
	return Plugin_Continue;
}

public Action Event_PlayerDeathPost(Handle event, const char[] name, bool dontBroadcast)
{
	if (g_bEnabled)
	{
		int client = GetClientOfUserId(GetEventInt(event,"userid"));

#if _DEBUG
		LogDebug(false, "Event_PlayerDeathPost - Client: %i", client);
#endif
		if (client > 0) // Check the client is not console/world?
			if (IsValidClient(client)) // Check client is not a bot or otherwise fake player.
			{
				if (g_hAFKTimer[client] != INVALID_HANDLE)
				{
					iPlayerAttacker[client] = GetClientOfUserId(GetEventInt(event,"attacker"));

					//if (CSGO)
					//	GetClientEyeAngles(client, fEyeAngles[client]);

					ResetSpawn(client);
					bPlayerDeath[client] = true;

					if (IsClientObserver(client))
					{
						iObserverMode[client] = GetEntProp(client, Prop_Send, "m_iObserverMode");
						iObserverTarget[client] = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
					}
				}
			}
	}
	return Plugin_Continue;
}

public Action Event_TeamplayRoundWin(Handle event, const char[] name, bool dontBroadcast)
{
#if _DEBUG
	LogDebug(false, "Event_TeamplayRoundWin");
#endif
	if (g_bEnabled)
		if ((TF2) && (g_bTF2Arena))
			g_bWaitRound = true;
	return Plugin_Continue;
}

public Action Event_ArenaRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
#if _DEBUG
	LogDebug(false, "Event_ArenaRoundStart");
#endif
	if (g_bEnabled)
		if ((TF2) && (g_bTF2Arena))
		{
			for(int i = 1; i <= MaxClients; i++)
				if (IsValidClient(i))
					if (g_hAFKTimer[i] != INVALID_HANDLE)
						if (g_iPlayerTeam[i] > 1) // Client is not Unassigned or on Spectator Team
							if (IsPlayerAlive(i))
								if (GetConVarFloat(hCvarSpawnTime) > 0.0)
									if (g_iSpawnTime[i] != -1)
										g_iSpawnTime[i] = GetTime();

			g_bWaitRound = false;
		}
	return Plugin_Continue;
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
#if _DEBUG
	LogDebug(false, "Event_RoundStart");
#endif
	if (g_bEnabled)
		if (CSGO)
		{
#if _DEBUG
			LogDebug(false, "Event_RoundStart - CSGO - Freeze Time: %i Warmup Period: %i", GetConVarInt(FindConVar("mp_freezetime")), GameRules_GetProp("m_bWarmupPeriod"));
#endif
			if (GameRules_GetProp("m_bWarmupPeriod") == 1)
				g_bWaitRound = true;
			else if (GameRules_GetProp("m_bWarmupPeriod") == 0)
				if (GetConVarInt(FindConVar("mp_freezetime")) > 0)
					g_bWaitRound = true;
				else
					g_bWaitRound = false;
		}
		else if ((CSTRIKE) && (GetConVarInt(FindConVar("mp_freezetime")) > 0))
		{
#if _DEBUG
			LogDebug(false, "Event_RoundStart - Freeztime Pausing AFK");
#endif
			g_bWaitRound = true;
		}

	return Plugin_Continue;
}

public Action Event_RoundFreezeEnd(Handle event, const char[] name, bool dontBroadcast)
{
#if _DEBUG
	LogDebug(false, "Event_RoundFreezeEnd");
#endif
	if (g_bEnabled)
		if (CSGO)
		{
#if _DEBUG
			LogDebug(false, "Event_RoundFreezeEnd - CSGO - Freeze Time: %i Warmup Period: %i", GetConVarInt(FindConVar("mp_freezetime")), GameRules_GetProp("m_bWarmupPeriod"));
#endif
			if (GetConVarInt(FindConVar("mp_freezetime")) > 0)
				if (GameRules_GetProp("m_bWarmupPeriod") == 0)
					g_bWaitRound = false;
		}
		else if ((CSTRIKE) && (GetConVarInt(FindConVar("mp_freezetime")) > 0))
		{
#if _DEBUG
			LogDebug(false, "Event_RoundFreezeEnd - Freeztime Unpausing AFK");
#endif
			g_bWaitRound = false;
		}
	return Plugin_Continue;
}

/*
public Action Event_JointeamFailed(Handle event, const char[] name, bool dontBroadcast)
{
#if _DEBUG
	LogDebug(false, "Event_JointeamFailed");
#endif
	if (g_bEnabled)
	{
		int iReason = GetEventInt(event, "reason");

#if _DEBUG
		LogDebug(false, "Event_JointeamFailed - Reason: %i", iReason);
#endif

		if (iReason == 0)
			return Plugin_Handled;

//0 "#Cstrike_TitlesTXT_Only_1_Team_Change"
//1 "#Cstrike_TitlesTXT_All_Teams_Full"
//2 "#Cstrike_TitlesTXT_Terrorists_Full"
//3 "#Cstrike_TitlesTXT_CTs_Full"
//4 "#Cstrike_TitlesTXT_Cannot_Be_Spectator"
//5 "#Cstrike_TitlesTXT_Humans_Join_Team_T"
//6 "#Cstrike_TitlesTXT_Humans_Join_Team_CT"
//7 "#Cstrike_TitlesTXT_Too_Many_Terrorists"
//8 "#Cstrike_TitlesTXT_Too_Many_CTs"
	}
	return Plugin_Continue;
}
*/


// Timers
public Action Timer_CheckPlayer(Handle Timer, int client) // General AFK Timers
{
#if _DEBUG
	LogDebug(false, "Timer_CheckPlayer - Client: %i", client);
#endif
	if(g_bEnabled) // Is the AFK Manager Enabled
	{
#if _DEBUG > 1
		LogDebug(false, "Timer_CheckPlayer - Client: %i Plugin Enabled", client);
#endif
		if (!IsClientInGame(client)) // Client is not in Game (Map Change)
		{
#if _DEBUG > 1
			LogDebug(false, "Timer_CheckPlayer - Client: %i is not in game", client);
#endif
			g_iAFKTime[client]++;
			return Plugin_Continue;
		}

		if (GetEntityFlags(client) & FL_FROZEN) // Ignore FROZEN Clients
		{
#if _DEBUG > 1
			LogDebug(false, "Timer_CheckPlayer - Client: %i is FROZEN.", client);
#endif
			g_iAFKTime[client]++;
			return Plugin_Continue;
		}

		if (IsClientObserver(client))
		{
			int m_iObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
#if _DEBUG > 1
			LogDebug(false, "Timer_CheckPlayer - Client: %i is Observer Current Mode: %i", client, m_iObserverMode);
#endif
			if (iObserverMode[client] == -1) // Invalid Observer Mode
			{
#if _DEBUG > 1
				LogDebug(false, "Timer_CheckPlayer - Client: %i has an invalid Observer Mode", client);
#endif
				iObserverMode[client] = m_iObserverMode;

				//if (CSGO)
				//	GetClientEyeAngles(client, fEyeAngles[client]);

				//g_iAFKTime[client]++;
				return Plugin_Continue;
			}
			else if (iObserverMode[client] != m_iObserverMode) // Player changed Observer Mode
			{
#if _DEBUG > 1
				LogDebug(false, "Timer_CheckPlayer - Client: %i has changed Observer Mode Previous: %i", client, iObserverMode[client]);
#endif
				if (iObserverMode[client] == OBS_MODE_DEATHCAM)
				{
#if _DEBUG > 1
				LogDebug(false, "Timer_CheckPlayer - Client: %i was in Death Cam", client);
#endif
					iObserverMode[client] = m_iObserverMode;

					if (iObserverMode[client] != OBS_MODE_ROAMING)
						iObserverTarget[client] = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

					//if (CSGO)
					//	GetClientEyeAngles(client, fEyeAngles[client]);

					return Plugin_Continue;
				}
				else if (iObserverMode[client] == OBS_MODE_FREEZECAM)
				{
#if _DEBUG > 1
				LogDebug(false, "Timer_CheckPlayer - Client: %i was in Freezecam", client);
#endif
					iObserverMode[client] = m_iObserverMode;

					if (iObserverMode[client] != OBS_MODE_ROAMING)
						iObserverTarget[client] = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

					//if (CSGO)
					//	GetClientEyeAngles(client, fEyeAngles[client]);

					return Plugin_Continue;
				}

				iObserverMode[client] = m_iObserverMode;

#if _DEBUG > 1
				LogDebug(false, "Timer_CheckPlayer - Client: %i has changed Observer Mode Previous Target: %i Current target: %i", client, iObserverTarget[client], GetEntPropEnt(client, Prop_Send, "m_hObserverTarget"));
#endif

				if (iObserverMode[client] != OBS_MODE_ROAMING)
				{
					int m_hObserverTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

					if ((iObserverTarget[client] == client) || (iObserverTarget[client] == iPlayerAttacker[client])) // Death Cam?
					{
#if _DEBUG > 1
						LogDebug(false, "Timer_CheckPlayer - Client: %i has changed Observer Mode and in Death Cam?", client);
#endif
						iObserverTarget[client] = m_hObserverTarget;
						return Plugin_Continue;
					}
					else if (!IsValidClient(m_hObserverTarget, false)) // No valid players left? Mass Suicide?
					{
						iObserverTarget[client] = m_hObserverTarget;
						return Plugin_Continue;
					}
					else
						iObserverTarget[client] = m_hObserverTarget;
				}
				SetClientAFK(client);
				return Plugin_Continue;
			}
			else if (iObserverMode[client] != OBS_MODE_ROAMING)
			{
				int m_hObserverTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

#if _DEBUG > 1
				LogDebug(false, "Timer_CheckPlayer - Client: %i Current Observer Target: %i", client, m_hObserverTarget);
#endif

				if (iObserverTarget[client] != m_hObserverTarget) // Player changed Observer Mode
				{
#if _DEBUG > 1
					LogDebug(false, "Timer_CheckPlayer - Client: %i has changed Observer Target Previous: %i Current: %i", client, iObserverTarget[client], m_hObserverTarget);
#endif
					if (!IsValidClient(iObserverTarget[client], false)) // Previous Target is now invalid
						iObserverTarget[client] = m_hObserverTarget;
					else if (iObserverTarget[client] == client) // Previous target was the themselves
						iObserverTarget[client] = m_hObserverTarget;
					else if (!IsPlayerAlive(iObserverTarget[client])) // Previous target has died
						iObserverTarget[client] = m_hObserverTarget;
					else
					{
#if _DEBUG > 1
						LogDebug(false, "Timer_CheckPlayer - Client: %i has changed Observer Target Themselves.", client);
#endif
						iObserverTarget[client] = m_hObserverTarget;
						SetClientAFK(client);
						return Plugin_Continue;
					}
				}
			}
		}


		int Time = GetTime();
		if (!bPlayerAFK[client]) // Player Marked as not AFK?
		{
			if ((g_iSpawnTime[client] > 0) && ((Time - g_iSpawnTime[client]) < 2)) // Check if player has just spawned
				SetClientAFK(client, false);
			else if ((!IsPlayerAlive(client)) && (iObserverTarget[client] == client)) // Player is in death cam?
			{
#if _DEBUG > 1
				LogDebug(false, "Timer_CheckPlayer - Client: %i Player in death cam?", client);
#endif
				SetClientAFK(client, false);
			}
			else
			{
#if _DEBUG > 1
				LogDebug(false, "Timer_CheckPlayer - Client: %i was previously not AFK, setting AFK", client);
#endif
				SetClientAFK(client);
			}
			return Plugin_Continue;
		}

		if (g_bWaitRound) // Are we waiting for the round to start
		{
#if _DEBUG > 1
			LogDebug(false, "Timer_CheckPlayer - Client: %i is waiting for round", client);
#endif
			if (g_iSpawnTime[client] != -1)
				g_iSpawnTime[client]++;
			g_iAFKTime[client]++;
			return Plugin_Continue;
		}

		if ((TF2) && (g_bTF2Arena))
			if ((g_iPlayerTeam[client] == g_iSpec_Team) && (GetEntProp(client, Prop_Send, "m_bArenaSpectator") == 0)) // Arena Waiting Mode
			{
				g_iAFKTime[client]++;
				return Plugin_Continue;
			}

		if ((bMovePlayers == false) && (bKickPlayers == false)) // Do we have enough players to start taking action
		{
			g_iAFKTime[client]++;
			return Plugin_Continue;
		}

#if _DEBUG > 1
		LogDebug(false, "Timer_CheckPlayer - Client: %i Not waiting for round and have minimum players", client);
#endif
#if _DEBUG > 1
		LogDebug(false, "Timer_CheckPlayer - Client: %i Team: %i", client, g_iPlayerTeam[client]);
#endif
		if ((Synergy) || ((g_iPlayerTeam[client] != 0) && (g_iPlayerTeam[client] != g_iSpec_Team))) // Make sure player is not Unassigned or Spectator
			if (!IsPlayerAlive(client) && (g_bExcludeDead)) // Excluding Dead players
			{
#if _DEBUG
				LogDebug(false, "Timer_CheckPlayer - Client: %i Exclude Dead: %b", client, g_bExcludeDead);
#endif
				g_iAFKTime[client]++;
				return Plugin_Continue;
			}


		int AFKSpawnTimeleft = -1;
		int AFKSpawnTime;
		int cvarSpawnTime;

		if ((g_iSpawnTime[client] > 0) && (!IsPlayerAlive(client))) // Check Spawn Time and Player Alive
		{
#if _DEBUG
			LogDebug(false, "Timer_CheckPlayer - Client: %i AFK Spawn Time: %i Player has died", client, AFKSpawnTime);
#endif
			ResetSpawn(client);
		}

		if (g_iSpawnTime[client] > 0)
		{
			cvarSpawnTime = GetConVarInt(hCvarSpawnTime);

			if (cvarSpawnTime > 0)
			{
				AFKSpawnTime = Time - g_iSpawnTime[client];
				//if (AFKSpawnTime <= 1)
				//	AFKSpawnTimeleft = cvarSpawnTime;
				//else
				AFKSpawnTimeleft = cvarSpawnTime - AFKSpawnTime;
#if _DEBUG
				LogDebug(false, "Timer_CheckPlayer - Client: %i AFK Spawn Time: %i AFK Spawn Timeleft: %i Round 1: %i Round 2: %i", client, AFKSpawnTime, AFKSpawnTimeleft, AFKSpawnTime%AFK_WARNING_INTERVAL, AFKSpawnTime-AFKSpawnTime%AFK_WARNING_INTERVAL);
#endif
			}
		}

		int AFKTime = g_iAFKTime[client] >= 0 ? Time - g_iAFKTime[client] : 0;

#if _DEBUG > 1
		LogDebug(false, "Timer_CheckPlayer - Client: %i AFK Time: %i", client, AFKTime);
#endif
		if (g_iPlayerTeam[client] != g_iSpec_Team) // Check we are not on the Spectator team
		{
			if (GetConVarBool(hCvarMoveSpec))
			{
				if (bMovePlayers == true)
				{
					if ( (g_iPlayerImmunity[client] == AFKImmunity_None) || (g_iPlayerImmunity[client] == AFKImmunity_Kick) ) // Check Admin Immunity
					{
						if (g_iTimeToMove > 0)
						{
							int AFKMoveTimeleft = g_iTimeToMove - AFKTime;
#if _DEBUG
							LogDebug(false, "Timer_CheckPlayer - Client: %i AFK Time: %i Move Timeleft: %i", client, AFKTime, AFKMoveTimeleft);
#endif
							//if (AFKMoveTimeleft >= 0)
							//{
								if (AFKSpawnTimeleft >= 0)
									if (AFKSpawnTimeleft < AFKMoveTimeleft) // Spawn time left is less than total AFK time left
									{
										if (AFKSpawnTime >= cvarSpawnTime) // Take Action on AFK Spawn Player
										{
#if _DEBUG
											LogDebug(false, "Timer_CheckPlayer - Client: %i Exceeded Spawn Move AFK Time", client);
#endif
											ResetSpawn(client);
											if (g_iPlayerTeam[client] == 0) // Are we moving player from the Unassigned team AKA team 0?
												return MoveAFKClient(client, GetConVarBool(hCvarWarnUnassigned)); // Are we warning unassigned players?
											else
												return MoveAFKClient(client);
										}
										else if (AFKSpawnTime%AFK_WARNING_INTERVAL == 0) // Warn AFK Spawn Player
										{
#if _DEBUG > 1
											LogDebug(false, "Timer_CheckPlayer - Client: %i Checking Spawn Move Warning AFK Spawn Timeleft: %i", client, AFKSpawnTimeleft);
#endif
											if ((cvarSpawnTime - AFKSpawnTime) <= GetConVarInt(hCvarWarnSpawnTime))
												AFK_PrintToChat(client, "%t", "Spawn_Move_Warning", AFKSpawnTimeleft);
										}
										return Plugin_Continue;
									}
#if _DEBUG > 1
								LogDebug(false, "Timer_CheckPlayer - Client: %i AFK Time: %i ConVar Move Time: %i", client, AFKTime, g_iTimeToMove);
#endif
								if (AFKTime >= g_iTimeToMove) // Take Action on AFK Player
								{
#if _DEBUG
									LogDebug(false, "Timer_CheckPlayer - Client: %i Exceeded Move AFK Time", client);
#endif
									if (g_iPlayerTeam[client] == 0) // Are we moving player from the Unassigned team AKA team 0?
										return MoveAFKClient(client, GetConVarBool(hCvarWarnUnassigned)); // Are we warning unassigned players?
									else
										return MoveAFKClient(client);
								}
								else if (AFKTime%AFK_WARNING_INTERVAL == 0) // Warn AFK Player
								{
#if _DEBUG > 1
									LogDebug(false, "Timer_CheckPlayer - Client: %i Checking Move Warning", client);
#endif
									if ((g_iTimeToMove - AFKTime) <= GetConVarInt(hCvarWarnTimeToMove))
										AFK_PrintToChat(client, "%t", "Move_Warning", AFKMoveTimeleft);
									return Plugin_Continue;
								}
								return Plugin_Continue; // Fix for AFK Spawn Kick Notifications
							}
						//}
					}
				}
			}
		}

		int iKickPlayers = GetConVarInt(hCvarKickPlayers);

		if (iKickPlayers > 0)
			if (bKickPlayers == true)
			{
				if ((iKickPlayers == 2) && (g_iPlayerTeam[client] == g_iSpec_Team)) // Kicking is set to exclude spectators. Player is on the spectator team. Spectators should not be kicked.
					return Plugin_Continue;
				else
				{
					if ( (g_iPlayerImmunity[client] == AFKImmunity_None) || (g_iPlayerImmunity[client] == AFKImmunity_Move) ) // Check Admin Immunity
					{
						if (g_iTimeToKick > 0)
						{
							int AFKKickTimeleft = g_iTimeToKick - AFKTime;

#if _DEBUG
							LogDebug(false, "Timer_CheckPlayer - Client: %i AFK Time: %i Kick Timeleft: %i", client, AFKTime, AFKKickTimeleft);
#endif
							if (AFKKickTimeleft >= 0)
							{
								if (AFKSpawnTimeleft >= 0)
									if ( (AFKSpawnTimeleft < AFKKickTimeleft) && !((g_iTimeToMove > 0) && (g_iPlayerImmunity[client] == AFKImmunity_Move)) ) // Spawn time left is less than total AFK time left
									{
										if (AFKSpawnTime >= cvarSpawnTime) // Take Action on AFK Spawn Player
											return KickAFKClient(client);
										else if (AFKSpawnTime%AFK_WARNING_INTERVAL == 0) // Warn AFK Spawn Player
										{
#if _DEBUG > 1
											LogDebug(false, "Timer_CheckPlayer - Client: %i Checking Spawn Kick Warning AFK Spawn Timeleft: %i", client, AFKSpawnTimeleft);
#endif
											if ((cvarSpawnTime - AFKSpawnTime) <= GetConVarInt(hCvarWarnSpawnTime))
												AFK_PrintToChat(client, "%t", "Spawn_Kick_Warning", AFKSpawnTimeleft);
											return Plugin_Continue;
										}
									}

#if _DEBUG > 1
								LogDebug(false, "Timer_CheckPlayer - Client: %i AFK Time: %i ConVar Kick Time: %i", client, AFKTime, g_iTimeToKick);
#endif
								if (AFKTime >= g_iTimeToKick) // Take Action on AFK Player
									return KickAFKClient(client);
								else if (AFKTime%AFK_WARNING_INTERVAL == 0) // Warn AFK Player
								{
#if _DEBUG > 1
									LogDebug(false, "Timer_CheckPlayer - Client: %i Checking Kick Warning", client);
#endif
									if ((g_iTimeToKick - AFKTime) <= GetConVarInt(hCvarWarnTimeToKick))
										AFK_PrintToChat(client, "%t", "Kick_Warning", AFKKickTimeleft);
									return Plugin_Continue;
								}
							}
							else
								return KickAFKClient(client);
						}
					}
				}
			}
	}

#if _DEBUG > 2
	LogDebug(false, "Timer_CheckPlayer - Client: %i Plugin_Continue", client);
#endif
	return Plugin_Continue;
}


// Move/Kick Functions
Action MoveAFKClient(int client, bool Advertise=true) // Move AFK Client to Spectator Team
{
#if _DEBUG
	LogDebug(false, "MoveAFKClient - Client: %i has been moved to Spectator.", client);
#endif
	Action ForwardResult = Plugin_Continue;

	if (g_iSpawnTime[client] != -1)
		ForwardResult = Forward_OnAFKEvent("afk_spawn_move", client);
	else
		ForwardResult = Forward_OnAFKEvent("afk_move", client);

	if (ForwardResult != Plugin_Continue)
	{
		if (g_bLogWarnings)
		{
			char Action_Name[32];
			Action_Name = ActionToString(ForwardResult);
			LogToFile(AFKM_LogFile, "AFK Manager Event: MoveAFKClient has been requested to: %s by an external plugin this action will affect the event outcome.", Action_Name);
		}
		return ForwardResult;
	}

	char f_Name[MAX_NAME_LENGTH];
	GetClientName(client, f_Name, sizeof(f_Name));

	if (Advertise) // Are we announcing the move to everyone?
	{
		int Announce = GetConVarInt(hCvarMoveAnnounce);

		if (Announce == 0)
			AFK_PrintToChat(client, "%t", "Move_Announce", f_Name);
		else if (Announce == 1)
			AFK_PrintToChat(0, "%t", "Move_Announce", f_Name);
		else
		{
			for(int i = 1; i <= MaxClients; i++)
				if (IsClientConnected(i))
					if (IsClientInGame(i))
						if ((i == client) || (GetUserAdmin(i) != INVALID_ADMIN_ID))
							AFK_PrintToChat(i, "%t", "Move_Announce", f_Name);
		}
	}

	if (GetConVarBool(hCvarLogMoves))
		LogToFile(AFKM_LogFile, "%T", "Move_Log", LANG_SERVER, client);

	if ((CSTRIKE) || (CSGO) || GESOURCE) // Kill Player so round ends properly, this is Valve's normal method.
	{
		if (g_iPlayerTeam[client] == 0)
			FakeClientCommand(client, "joingame");
		else
			ForcePlayerSuicide(client);
	}
	else if (GESOURCE)
		ForcePlayerSuicide(client);

	if (TF2)
	{
		// Fix for TF2 Intelligence
		int iEnt = -1;
		while ((iEnt = FindEntityByClassname(iEnt, "item_teamflag")) > -1) {
			if (IsValidEntity(iEnt))
			{
				if (GetEntPropEnt(iEnt, Prop_Data, "m_hMoveParent") == client)
				{
					AcceptEntityInput(iEnt, "ForceDrop");
				}
			}
		}

		if (g_bTF2Arena)
		{
			ForcePlayerSuicide(client);
			// Arena Spectator Fix by Rothgar
			//SetEntProp(client, Prop_Send, "m_nNextThinkTick", -1);
			SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", 0);
			SetEntProp(client, Prop_Send, "m_bArenaSpectator", 1);
			ChangeClientTeam(client, g_iSpec_Team);
/*
			if (GetConVarBool(FindConVar("tf_arena_use_queue")))
				FakeClientCommand(client,"jointeam %d", "spectatearena");
			else
				FakeClientCommand(client,"jointeam %d", g_iSpec_Team);
*/
		} else {
			ForcePlayerSuicide(client);
			ChangeClientTeam(client, g_iSpec_Team); // Move AFK Player to Spectator
		}
	}
	else
		ChangeClientTeam(client, g_iSpec_Team); // Move AFK Player to Spectator

	if (CSGO)
	{
		SetEntData(client, FindSendPropInfo("CCSPlayer", "m_unMusicID") - 45, 0, 1, true); // Fix by Asherkin
		//SetEntData(client, FindSendPropInfo("CCSPlayer", "m_unMusicID") - 21, 0, 1, true); // Fix by Asherkin
	}

	return Plugin_Continue; // Check This?
}

Action KickAFKClient(int client) // Kick AFK Client
{
	Action ForwardResult = Forward_OnAFKEvent("afk_kick", client);

	if (ForwardResult != Plugin_Continue)
	{
		if (g_bLogWarnings)
		{
			char Action_Name[32];
			Action_Name = ActionToString(ForwardResult);
			LogToFile(AFKM_LogFile, "AFK Manager Event: KickAFKClient has been requested to: %s by an external plugin this action will affect the event outcome.", Action_Name);
		}
		return ForwardResult;
	}

	char f_Name[MAX_NAME_LENGTH];
	GetClientName(client, f_Name, sizeof(f_Name));

#if _DEBUG
	LogDebug(false, "KickAFKClient - Kicking player %s for being AFK.", f_Name);
#endif

	int Announce = GetConVarInt(hCvarKickAnnounce);
	if (Announce == 1)
		AFK_PrintToChat(0, "%t", "Kick_Announce", f_Name);
	else if (Announce == 2)
	{
		for(int i = 1; i <= MaxClients; i++)
			if (IsClientConnected(i))
				if (IsClientInGame(i))
					if (GetUserAdmin(i) != INVALID_ADMIN_ID)
						AFK_PrintToChat(i, "%t", "Kick_Announce", f_Name);
	}

	if (GetConVarBool(hCvarLogKicks))
		LogToFile(AFKM_LogFile, "%T", "Kick_Log", LANG_SERVER, client);

	if (g_bForceLanguage)
		KickClient(client, "[%s] %T", g_sPrefix, "Kick_Message", LANG_SERVER);
	else
		KickClient(client, "[%s] %t", g_sPrefix, "Kick_Message");
	return Plugin_Continue;
}

// Admin/Immunity Functions

void ChangeImmunity(int type) // Change Immunity Type for all Admins
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsValidClient(i))
			if (CheckAdminImmunity(i))
				SetPlayerImmunity(i, type);
/*
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientConnected(i))
			if (IsClientInGame(i))
				if (CheckAdminImmunity(i))
					SetPlayerImmunity(i, type);
*/
}

bool CheckAdminImmunity(int client) // Check Admin Immunity
{
	int iUserFlagBits = GetUserFlagBits(client);

#if _DEBUG
	LogDebug(false, "CheckAdminImmunity - Checking client: %i for admin immunity Client flag bits: %i", client, iUserFlagBits);
#endif

	if (iUserFlagBits > 0) // Check if player is an admin
	{
		char sFlags[32];
		GetConVarString(hCvarAdminsFlag, sFlags, sizeof(sFlags));

		if (StrEqual(sFlags, "")) // No admin flags set
			return true;
		else if (iUserFlagBits & (ReadFlagString(sFlags)|ADMFLAG_ROOT) > 0) // Compare Flag Bits
			return true;
	}
	return false;
}

void SetPlayerImmunity(int client, int type, bool AFKImmunityType = false) // Set Admin Immunity
{
	if ( (AFKImmunityType) && ((view_as<AFKImmunity>(type) >= AFKImmunity_None) && (view_as<AFKImmunity>(type) <= AFKImmunity_Full)) )
	{
		g_iPlayerImmunity[client] = view_as<AFKImmunity>(type);

		if (g_iPlayerImmunity[client] == AFKImmunity_Full)
			ResetAFKTimer(client);
		else
			InitializeAFK(client);
	}
	else if ( (!AFKImmunityType) && ((type >= 0) && (type <= 3)) )
	{
		switch (type)
		{
			case 1: // COMPLETE IMMUNITY
			{
				g_iPlayerImmunity[client] = AFKImmunity_Full;
				ResetAFKTimer(client);
				return;
			}
			case 2: // KICK IMMUNITY
				g_iPlayerImmunity[client] = AFKImmunity_Kick;
			case 3: // MOVE IMMUNITY
				g_iPlayerImmunity[client] = AFKImmunity_Move;
			default: // NO IMMUNITY
				g_iPlayerImmunity[client] = AFKImmunity_None;
		}
		InitializeAFK(client);
	}
	else
		if (g_bLogWarnings)
			LogToFile(AFKM_LogFile, "SetAdminImmunity - AFK Manager Player Immunity was asked to set an invalid type: %i for client: %i", type, client);
}
