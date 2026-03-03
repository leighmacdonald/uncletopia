#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>

#include <tfdb>

#define PLUGIN_NAME        "[TFDB] Votes"
#define PLUGIN_AUTHOR      "x07x08"
#define PLUGIN_DESCRIPTION "Various rocket votes."
#define PLUGIN_VERSION     "1.1.0"
#define PLUGIN_URL         "https://github.com/Silorak/TF2-Dodgeball-Modified"

int g_iSpawnersCount;

ConVar CvarVoteBounceDuration;
ConVar CvarVoteClassDuration;
ConVar CvarVoteCountDuration;
ConVar CvarVoteBounceTimeout;
ConVar CvarVoteClassTimeout;
ConVar CvarVoteCountTimeout;
ConVar CvarVotePresetDuration;
ConVar CvarVotePresetTimeout;

bool VoteBounceAllowed;
bool VoteClassAllowed;
bool VoteCountAllowed;
bool VotePresetAllowed;

float LastVoteBounceTime;
float LastVoteClassTime;
float LastVoteCountTime;
float LastVotePresetTime;

bool BounceEnabled;
int MainRocketClass = -1;
int RocketsCount = -1;

int SavedMaxRockets[MAX_SPAWNER_CLASSES];

bool Loaded;

public Plugin myinfo =
{
	name        = PLUGIN_NAME,
	author      = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version     = PLUGIN_VERSION,
	url         = PLUGIN_URL
};

public void OnPluginStart()
{
	LoadTranslations("tfdb.phrases.txt");
	
	CvarVoteBounceDuration = CreateConVar("tf_dodgeball_votes_bounce_duration", "20", _, _, true, 0.0);
	CvarVoteClassDuration  = CreateConVar("tf_dodgeball_votes_class_duration", "20", _, _, true, 0.0);
	CvarVoteCountDuration  = CreateConVar("tf_dodgeball_votes_count_duration", "20", _, _, true, 0.0);
	CvarVoteBounceTimeout  = CreateConVar("tf_dodgeball_votes_bounce_timeout", "150", _, _, true, 0.0);
	CvarVoteClassTimeout   = CreateConVar("tf_dodgeball_votes_class_timeout", "150", _, _, true, 0.0);
	CvarVoteCountTimeout   = CreateConVar("tf_dodgeball_votes_count_timeout", "150", _, _, true, 0.0);
	CvarVotePresetDuration = CreateConVar("tf_dodgeball_votes_preset_duration", "20", _, _, true, 0.0);
	CvarVotePresetTimeout  = CreateConVar("tf_dodgeball_votes_preset_timeout", "150", _, _, true, 0.0);
	
	RegConsoleCmd("sm_vrb", CmdVoteBounce, "Start a rocket bounce vote");
	RegConsoleCmd("sm_vrc", CmdVoteClass, "Start a rocket class vote");
	RegConsoleCmd("sm_vrcount", CmdVoteCount, "Start a rocket count vote");
	RegConsoleCmd("sm_vrp", CmdVotePreset, "Start a preset vote");
	RegConsoleCmd("sm_votebounce", CmdVoteBounce, "Start a rocket bounce vote");
	RegConsoleCmd("sm_voteclass", CmdVoteClass, "Start a rocket class vote");
	RegConsoleCmd("sm_votecount", CmdVoteCount, "Start a rocket count vote");
	RegConsoleCmd("sm_votepreset", CmdVotePreset, "Start a preset vote");
	RegConsoleCmd("sm_voterocketbounce", CmdVoteBounce, "Start a rocket bounce vote");
	RegConsoleCmd("sm_voterocketclass", CmdVoteClass, "Start a rocket class vote");
	RegConsoleCmd("sm_voterocketcount", CmdVoteCount, "Start a rocket count vote");
	RegConsoleCmd("sm_voterocketpreset", CmdVotePreset, "Start a preset vote");
	
	if (!TFDB_IsDodgeballEnabled()) return;
	
	char strMapName[64]; GetCurrentMap(strMapName, sizeof(strMapName));
	GetMapDisplayName(strMapName, strMapName, sizeof(strMapName));
	char strMapFile[PLATFORM_MAX_PATH]; FormatEx(strMapFile, sizeof(strMapFile), "%s.cfg", strMapName);
	
	TFDB_OnRocketsConfigExecuted("general.cfg");
	TFDB_OnRocketsConfigExecuted(strMapFile);
}

public void OnMapEnd()
{
	if (!Loaded) return;
	
	VoteBounceAllowed =
	VoteClassAllowed  =
	VoteCountAllowed  =
	VotePresetAllowed = false;
	
	LastVoteBounceTime =
	LastVoteClassTime  =
	LastVoteCountTime  =
	LastVotePresetTime = 0.0;
	
	BounceEnabled = false;
	MainRocketClass = -1;
	RocketsCount = -1;
	
	Loaded = false;
	
	g_iSpawnersCount = 0;
}

public void TFDB_OnRocketsConfigExecuted(const char[] strConfigFile)
{
	if (!Loaded)
	{
		VoteBounceAllowed =
		VoteClassAllowed  =
		VoteCountAllowed  =
		VotePresetAllowed = true;
		
		LastVoteBounceTime =
		LastVoteClassTime  =
		LastVoteCountTime  =
		LastVotePresetTime = 0.0;
		
		BounceEnabled = false;
		MainRocketClass = -1;
		RocketsCount = -1;
		
		Loaded = true;
	}
	
	if (strcmp(strConfigFile, "general.cfg") == 0)
	{
		g_iSpawnersCount = 0;
	}
	
	ParseConfigurations(strConfigFile);
}

public Action CmdVoteBounce(int iClient, int iArgs)
{
	if (iClient == 0)
	{
		ReplyToCommand(iClient, "Command is in-game only.");
		
		return Plugin_Handled;
	}
	
	if (!TFDB_IsDodgeballEnabled())
	{
		CReplyToCommand(iClient, "%t", "Command_Disabled");
		
		return Plugin_Handled;
	}
	
	if (IsVoteInProgress())
	{
		CReplyToCommand(iClient, "%t", "Dodgeball_FFAVote_Conflict");
		
		return Plugin_Handled;
	}
	
	if (VoteBounceAllowed)
	{
		VoteBounceAllowed  = false;
		LastVoteBounceTime = GetGameTime();
		
		StartBounceVote();
		CreateTimer(CvarVoteBounceTimeout.FloatValue, VoteBounceTimeoutCallback, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		CReplyToCommand(iClient, "%t", "Dodgeball_BounceVote_Cooldown",
		                RoundToCeil((LastVoteBounceTime + CvarVoteBounceTimeout.FloatValue) - GetGameTime()));
	}
	
	return Plugin_Handled;
}

void StartBounceVote()
{
	char strMode[16];
	strMode = !BounceEnabled ? "Enable" : "Disable";
	
	Menu hMenu = new Menu(VoteMenuHandler);
	hMenu.VoteResultCallback = VoteBounceResultHandler;
	
	hMenu.SetTitle("%s no rocket bounce mode?", strMode);
	
	hMenu.AddItem("0", "Yes");
	hMenu.AddItem("1", "No");
	
	int iTotal;
	int[] iClients = new int[MaxClients];
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient) || IsFakeClient(iClient) || GetClientTeam(iClient) <= 1)
		{
			continue;
		}
		
		iClients[iTotal++] = iClient;
	}
	
	hMenu.DisplayVote(iClients, iTotal, CvarVoteBounceDuration.IntValue);
}

public int VoteMenuHandler(Menu hMenu, MenuAction iMenuActions, int iParam1, int iParam2)
{
	switch (iMenuActions)
	{
		case MenuAction_End :
		{
			delete hMenu;
		}
	}
	
	return 0;
}

public void VoteBounceResultHandler(Menu hMenu,
                                    int iNumVotes,
                                    int iNumClients,
                                    const int[][] iClientInfo,
                                    int iNumItems,
                                    const int[][] iItemInfo)
{
	int iWinnerIndex = 0;
	
	if (iNumItems > 1 &&
	    (iItemInfo[0][VOTEINFO_ITEM_VOTES] == iItemInfo[1][VOTEINFO_ITEM_VOTES]))
	{
		iWinnerIndex = GetRandomInt(0, 1);
	}
	
	char strWinner[8]; hMenu.GetItem(iItemInfo[iWinnerIndex][VOTEINFO_ITEM_INDEX], strWinner, sizeof(strWinner));
	
	if (StrEqual(strWinner, "0"))
	{
		ToggleBounce();
	}
	else
	{
		CPrintToChatAll("%t", "Dodgeball_BounceVote_Failed");
	}
}

void ToggleBounce()
{
	if (!BounceEnabled)
	{
		EnableBounce();
	}
	else
	{
		DisableBounce();
	}
}

void EnableBounce()
{
	BounceEnabled = true;
	
	for (int iIndex = 0; iIndex < MAX_ROCKETS; iIndex++)
	{
		if (!TFDB_IsValidRocket(iIndex)) continue;
		
		TFDB_SetRocketBounces(iIndex, TFDB_GetRocketClassMaxBounces(TFDB_GetRocketClass(iIndex)));
	}
	
	CPrintToChatAll("%t", "Dodgeball_BounceVote_Enabled");
}

void DisableBounce()
{
	BounceEnabled = false;
	
	for (int iIndex = 0; iIndex < MAX_ROCKETS; iIndex++)
	{
		if (!TFDB_IsValidRocket(iIndex)) continue;
		
		TFDB_SetRocketBounces(iIndex, 0);
	}
	
	CPrintToChatAll("%t", "Dodgeball_BounceVote_Disabled");
}

public Action CmdVoteClass(int iClient, int iArgs)
{
	if (iClient == 0)
	{
		ReplyToCommand(iClient, "Command is in-game only.");
		
		return Plugin_Handled;
	}
	
	if (!TFDB_IsDodgeballEnabled())
	{
		CReplyToCommand(iClient, "%t", "Command_Disabled");
		
		return Plugin_Handled;
	}
	
	if (IsVoteInProgress())
	{
		CReplyToCommand(iClient, "%t", "Dodgeball_FFAVote_Conflict");
		
		return Plugin_Handled;
	}
	
	if (VoteClassAllowed)
	{
		VoteClassAllowed  = false;
		LastVoteClassTime = GetGameTime();
		
		StartClassVote();
		CreateTimer(CvarVoteClassTimeout.FloatValue, VoteClassTimeoutCallback, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		CReplyToCommand(iClient, "%t", "Dodgeball_ClassVote_Cooldown",
		                RoundToCeil((LastVoteClassTime + CvarVoteClassTimeout.FloatValue) - GetGameTime()));
	}
	
	return Plugin_Handled;
}

void StartClassVote()
{
	Menu hMenu = new Menu(VoteMenuHandler);
	hMenu.VoteResultCallback = VoteClassResultHandler;
	
	hMenu.SetTitle("Change main rocket class?");
	
	if (MainRocketClass != -1)
	{
		hMenu.AddItem("-1", "Reset the spawn chances");
	}
	
	char strClass[8], strRocketClassLongName[32];
	
	for (int iClass = 0; iClass < TFDB_GetRocketClassCount(); iClass++)
	{
		IntToString(iClass, strClass, sizeof(strClass));
		TFDB_GetRocketClassLongName(iClass, strRocketClassLongName, sizeof(strRocketClassLongName));
		
		hMenu.AddItem(strClass, strRocketClassLongName, ITEMDRAW_DEFAULT);
	}
	
	int iTotal;
	int[] iClients = new int[MaxClients];
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient) || IsFakeClient(iClient) || GetClientTeam(iClient) <= 1)
		{
			continue;
		}
		
		iClients[iTotal++] = iClient;
	}
	
	hMenu.DisplayVote(iClients, iTotal, CvarVoteClassDuration.IntValue);
}

public void VoteClassResultHandler(Menu hMenu,
                                   int iNumVotes,
                                   int iNumClients,
                                   const int[][] iClientInfo,
                                   int iNumItems,
                                   const int[][] iItemInfo)
{
	int iWinnerIndex = 0;
	int iClassCount = TFDB_GetRocketClassCount();
	
	if (MainRocketClass != -1) iClassCount++;
	
	bool bEqual = AreVotesEqual(iItemInfo, iClassCount);
	
	if (bEqual) iWinnerIndex = GetRandomInt(0, (iClassCount - 1));
	
	char strWinner[8], strClassLongName[32];
	
	hMenu.GetItem(iItemInfo[iWinnerIndex][VOTEINFO_ITEM_INDEX], strWinner, sizeof(strWinner), _, strClassLongName, sizeof(strClassLongName));
	
	MainRocketClass = StringToInt(strWinner);
	
	if (MainRocketClass == -1)
	{
		CPrintToChatAll("%t", "Dodgeball_ClassVote_Reset");
	}
	else
	{
		CPrintToChatAll("%t", "Dodgeball_ClassVote_Changed", strClassLongName);
	}
	
	TFDB_DestroyRockets();
}

public Action CmdVoteCount(int iClient, int iArgs)
{
	if (iClient == 0)
	{
		ReplyToCommand(iClient, "Command is in-game only.");
		
		return Plugin_Handled;
	}
	
	if (!TFDB_IsDodgeballEnabled())
	{
		CReplyToCommand(iClient, "%t", "Command_Disabled");
		
		return Plugin_Handled;
	}
	
	if (IsVoteInProgress())
	{
		CReplyToCommand(iClient, "%t", "Dodgeball_FFAVote_Conflict");
		
		return Plugin_Handled;
	}
	
	if (VoteCountAllowed)
	{
		VoteCountAllowed  = false;
		LastVoteCountTime = GetGameTime();
		
		StartCountVote();
		CreateTimer(CvarVoteCountTimeout.FloatValue, VoteCountTimeoutCallback, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		CReplyToCommand(iClient, "%t", "Dodgeball_CountVote_Cooldown",
		                RoundToCeil((LastVoteCountTime + CvarVoteCountTimeout.FloatValue) - GetGameTime()));
	}
	
	return Plugin_Handled;
}

void StartCountVote()
{
	Menu hMenu = new Menu(VoteMenuHandler);
	hMenu.VoteResultCallback = VoteCountResultHandler;
	
	hMenu.SetTitle("Change rockets count?");
	
	if (RocketsCount != -1)
	{
		hMenu.AddItem("-1", "Reset rockets count");
	}
	
	hMenu.AddItem("0", "One rocket");
	hMenu.AddItem("1", "Two rockets");
	hMenu.AddItem("2", "Three rockets");
	hMenu.AddItem("3", "Four rockets");
	hMenu.AddItem("4", "Five rockets");
	
	int iTotal;
	int[] iClients = new int[MaxClients];
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient) || IsFakeClient(iClient) || GetClientTeam(iClient) <= 1)
		{
			continue;
		}
		
		iClients[iTotal++] = iClient;
	}
	
	hMenu.DisplayVote(iClients, iTotal, CvarVoteCountDuration.IntValue);
}

public void VoteCountResultHandler(Menu hMenu,
                                   int iNumVotes,
                                   int iNumClients,
                                   const int[][] iClientInfo,
                                   int iNumItems,
                                   const int[][] iItemInfo)
{
	int iWinnerIndex = 0;
	int iVotesCount = 5;
	
	if (RocketsCount != -1) iVotesCount++;
	
	bool bEqual = AreVotesEqual(iItemInfo, iVotesCount);
	
	if (bEqual) iWinnerIndex = GetRandomInt(0, (iVotesCount - 1));
	
	char strWinner[8]; hMenu.GetItem(iItemInfo[iWinnerIndex][VOTEINFO_ITEM_INDEX], strWinner, sizeof(strWinner));
	
	RocketsCount = StringToInt(strWinner);
	
	for (int iIndex = 0; iIndex < TFDB_GetSpawnersCount(); iIndex++)
	{
		TFDB_SetSpawnersMaxRockets(iIndex, RocketsCount == -1 ? SavedMaxRockets[iIndex] : (RocketsCount + 1));
	}
	
	if (RocketsCount == -1)
	{
		CPrintToChatAll("%t", "Dodgeball_CountVote_Reset");
	}
	else
	{
		CPrintToChatAll("%t", "Dodgeball_CountVote_Changed", (RocketsCount + 1));
	}
}

public Action CmdVotePreset(int iClient, int iArgs)
{
	if (iClient == 0)
	{
		ReplyToCommand(iClient, "Command is in-game only.");
		
		return Plugin_Handled;
	}
	
	if (!TFDB_IsDodgeballEnabled())
	{
		CReplyToCommand(iClient, "%t", "Command_Disabled");
		
		return Plugin_Handled;
	}
	
	if (IsVoteInProgress())
	{
		CReplyToCommand(iClient, "%t", "Dodgeball_FFAVote_Conflict");
		
		return Plugin_Handled;
	}
	
	if (TFDB_GetPresetCount() == 0)
	{
		CReplyToCommand(iClient, "%t", "Dodgeball_PresetVote_NoPresets");
		
		return Plugin_Handled;
	}
	
	if (VotePresetAllowed)
	{
		VotePresetAllowed  = false;
		LastVotePresetTime = GetGameTime();
		
		StartPresetVote();
		CreateTimer(CvarVotePresetTimeout.FloatValue, VotePresetTimeoutCallback, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		CReplyToCommand(iClient, "%t", "Dodgeball_PresetVote_Cooldown",
		                RoundToCeil((LastVotePresetTime + CvarVotePresetTimeout.FloatValue) - GetGameTime()));
	}
	
	return Plugin_Handled;
}

void StartPresetVote()
{
	Menu hMenu = new Menu(VoteMenuHandler);
	hMenu.VoteResultCallback = VotePresetResultHandler;
	
	hMenu.SetTitle("Select gameplay preset:");
	
	int iPresetCount = TFDB_GetPresetCount();
	for (int i = 0; i < iPresetCount; i++)
	{
		char strIndex[8], strName[64];
		IntToString(i, strIndex, sizeof(strIndex));
		TFDB_GetPresetName(i, strName, sizeof(strName));
		hMenu.AddItem(strIndex, strName);
	}
	
	int iTotal;
	int[] iClients = new int[MaxClients];
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient) || IsFakeClient(iClient) || GetClientTeam(iClient) <= 1)
		{
			continue;
		}
		
		iClients[iTotal++] = iClient;
	}
	
	hMenu.DisplayVote(iClients, iTotal, CvarVotePresetDuration.IntValue);
}

public void VotePresetResultHandler(Menu hMenu,
                                    int iNumVotes,
                                    int iNumClients,
                                    const int[][] iClientInfo,
                                    int iNumItems,
                                    const int[][] iItemInfo)
{
	int iWinnerIndex = 0;
	
	bool bEqual = AreVotesEqual(iItemInfo, iNumItems);
	
	if (bEqual) iWinnerIndex = GetRandomInt(0, (iNumItems - 1));
	
	char strWinner[8]; hMenu.GetItem(iItemInfo[iWinnerIndex][VOTEINFO_ITEM_INDEX], strWinner, sizeof(strWinner));
	
	int iPreset = StringToInt(strWinner);
	
	if (TFDB_ApplyPreset(iPreset))
	{
		char strName[64];
		TFDB_GetPresetName(iPreset, strName, sizeof(strName));
		CPrintToChatAll("%t", "Dodgeball_PresetVote_Applied", strName);
	}
}

public Action VoteBounceTimeoutCallback(Handle hTimer)
{
	VoteBounceAllowed = true;
	
	return Plugin_Continue;
}

public Action VoteClassTimeoutCallback(Handle hTimer)
{
	VoteClassAllowed = true;
	
	return Plugin_Continue;
}

public Action VoteCountTimeoutCallback(Handle hTimer)
{
	VoteCountAllowed = true;
	
	return Plugin_Continue;
}

public Action VotePresetTimeoutCallback(Handle hTimer)
{
	VotePresetAllowed = true;
	
	return Plugin_Continue;
}

public Action TFDB_OnRocketCreatedPre(int iIndex, int &iClass, RocketFlags &iFlags)
{
	if (MainRocketClass == -1) return Plugin_Continue;
	
	iClass = MainRocketClass;
	iFlags = TFDB_GetRocketClassFlags(MainRocketClass);
	
	return Plugin_Changed;
}

public void TFDB_OnRocketCreated(int iIndex)
{
	if (!BounceEnabled) return;
	
	TFDB_SetRocketBounces(iIndex, TFDB_GetRocketClassMaxBounces(TFDB_GetRocketClass(iIndex)));
}

void ParseConfigurations(const char[] strConfigFile)
{
	char strPath[PLATFORM_MAX_PATH];
	char strFileName[PLATFORM_MAX_PATH];
	FormatEx(strFileName, sizeof(strFileName), "configs/dodgeball/%s", strConfigFile);
	BuildPath(Path_SM, strPath, sizeof(strPath), strFileName);
	
	if (!FileExists(strPath, true)) return;
	
	KeyValues kvConfig = new KeyValues("TF2_Dodgeball");
	
	if (kvConfig.ImportFromFile(strPath) == false) SetFailState("Error while parsing the configuration file.");
	
	kvConfig.GotoFirstSubKey();
	
	do
	{
		char strSection[64]; kvConfig.GetSectionName(strSection, sizeof(strSection));
		
		if (StrEqual(strSection, "spawners")) ParseSpawners(kvConfig);
	}
	while (kvConfig.GotoNextKey());
	
	delete kvConfig;
}

void ParseSpawners(KeyValues kvConfig)
{
	kvConfig.GotoFirstSubKey();
	
	do
	{
		int iIndex = g_iSpawnersCount;
		
		SavedMaxRockets[iIndex] = kvConfig.GetNum("max rockets", 1);
		
		g_iSpawnersCount++;
	}
	while (kvConfig.GotoNextKey());
	
	kvConfig.GoBack();
}

bool AreVotesEqual(const int[][] iVoteItems, int iSize)
{
	int iFirst = iVoteItems[0][VOTEINFO_ITEM_VOTES];
	
	for (int iIndex = 1; iIndex < iSize; iIndex++)
	{
		if (iVoteItems[iIndex][VOTEINFO_ITEM_VOTES] != iFirst) return false;
	}
	
	return true;
}
